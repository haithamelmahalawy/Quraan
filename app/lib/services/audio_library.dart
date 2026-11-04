import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/audio_numbering.dart';
import '../data/recitations.dart';

/// Where a reciter's download stands.
enum DownloadStatus { notStarted, downloading, paused, complete }

/// A reciter's files on this device.
class ReciterDownload {
  const ReciterDownload({
    this.status = DownloadStatus.notStarted,
    this.done = 0,
    this.total = 0,
    this.bytes = 0,
    this.failed = 0,
    this.error,
  });

  final DownloadStatus status;
  final int done, total, bytes, failed;

  /// Why it stopped: no connection, or no room left on the device.
  final String? error;

  double get progress => total == 0 ? 0 : done / total;
}

/// A whole recitation kept on the device, to be heard with no connection: each
/// reciter's clips in a folder of their own, the player taking a clip from it
/// when it is there. A download resumes where it stopped: a clip is written
/// under a temporary name and only named once complete.
class AudioLibrary extends ChangeNotifier {
  AudioLibrary({
    http.Client? client,
    Future<Directory> Function()? root,
    Future<AudioNumbering> Function()? numbering,
    this.concurrency = 6,
    @visibleForTesting this.clipsOverride,
  }) : _client = client ?? http.Client(),
       _rootOf = root ?? getApplicationSupportDirectory,
       _numberingOf = numbering ?? AudioNumbering.load;

  static final instance = AudioLibrary();

  /// So many clips failing in a row is the connection, not the clips.
  static const _stopAfterFailures = 20;

  final http.Client _client;
  final Future<Directory> Function() _rootOf;
  final Future<AudioNumbering> Function() _numberingOf;
  final int concurrency;

  /// A short recording in place of the whole, to test with.
  final List<(int, int)>? clipsOverride;
  final _states = <int, ReciterDownload>{};
  final _running = <int>{};
  Directory? _root;

  Future<void> init() async {
    _root ??= await _rootOf();
  }

  ReciterDownload stateOf(Reciter reciter) =>
      _states[reciter.id] ?? const ReciterDownload();

  bool isRunning(Reciter reciter) => _running.contains(reciter.id);

  String _name(int surah, int native) =>
      '${surah.toString().padLeft(3, '0')}'
      '${native.toString().padLeft(3, '0')}.mp3';

  Directory _folder(Reciter reciter) =>
      Directory('${_root!.path}/recitations/${reciter.id}');

  File _file(Reciter reciter, int surah, int native) =>
      File('${_folder(reciter).path}/${_name(surah, native)}');

  /// The clip on the device if it is there, else where it is streamed from.
  Uri clipUri(Reciter reciter, int surah, int native) {
    if (_root != null) {
      final file = _file(reciter, surah, native);
      if (file.existsSync()) return Uri.file(file.path);
    }
    return reciter.ayah(surah, native);
  }

  /// Every clip of the reciter's recording, in order.
  Future<List<(int, int)>> _clips(Reciter reciter) async {
    if (clipsOverride != null) return clipsOverride!;
    final numbering = await _numberingOf();
    return [
      for (var s = 1; s <= numbering.hafsCounts.length; s++)
        for (final n in numbering.nativeClips(reciter.numbering, s)) (s, n),
    ];
  }

  /// Reads what is on the device already.
  Future<void> scan(Reciter reciter) async {
    await init();
    if (_running.contains(reciter.id)) return;
    final clips = await _clips(reciter);
    var done = 0, bytes = 0;
    final folder = _folder(reciter);
    if (folder.existsSync()) {
      final wanted = {for (final (s, n) in clips) _name(s, n)};
      for (final entity in folder.listSync().whereType<File>()) {
        if (wanted.contains(entity.uri.pathSegments.last)) {
          done++;
          bytes += entity.lengthSync();
        }
      }
    }
    _states[reciter.id] = ReciterDownload(
      status: done == 0
          ? DownloadStatus.notStarted
          : done >= clips.length
          ? DownloadStatus.complete
          : DownloadStatus.paused,
      done: done,
      total: clips.length,
      bytes: bytes,
    );
    notifyListeners();
  }

  /// About how much the whole recording takes, from a few clips along it;
  /// null when they cannot be asked for.
  Future<int?> estimateBytes(Reciter reciter) async {
    final clips = await _clips(reciter);
    const samples = 12;
    final step = clips.length ~/ samples;
    var total = 0, seen = 0;
    for (var i = 0; i < samples; i++) {
      final (s, n) = clips[i * step];
      try {
        final response = await _client
            .head(reciter.ayah(s, n))
            .timeout(const Duration(seconds: 10));
        final length = response.contentLength;
        if (response.statusCode == 200 && length != null && length > 0) {
          total += length;
          seen++;
        }
      } catch (_) {
        // A sample the fewer.
      }
    }
    return seen == 0 ? null : total ~/ seen * clips.length;
  }

  /// Downloads what is missing, until done or paused. A clip that fails is left
  /// for the next attempt, and is streamed meanwhile.
  Future<void> download(Reciter reciter) async {
    await init();
    if (!_running.add(reciter.id)) return;
    final clips = await _clips(reciter);
    final folder = _folder(reciter);
    String? stopped;
    try {
      await folder.create(recursive: true);
    } on FileSystemException {
      stopped = 'تعذر الحفظ على الجهاز';
    }
    var done = 0, bytes = 0, failed = 0, inARow = 0;
    final pending = <(int, int)>[];
    for (final (s, n) in clips) {
      final file = _file(reciter, s, n);
      if (file.existsSync()) {
        done++;
        bytes += file.lengthSync();
      } else {
        pending.add((s, n));
      }
    }
    void publish(DownloadStatus status) {
      _states[reciter.id] = ReciterDownload(
        status: status,
        done: done,
        total: clips.length,
        bytes: bytes,
        failed: failed,
        error: stopped,
      );
      notifyListeners();
    }

    publish(DownloadStatus.downloading);
    var next = 0;
    final tries = <(int, int), int>{};
    // A clip that fails goes round again, twice, before it is left for later.
    void failedClip((int, int) clip) {
      final tried = tries[clip] = (tries[clip] ?? 0) + 1;
      if (tried < 3) {
        pending.add(clip);
      } else {
        failed++;
      }
    }

    Future<void> worker() async {
      while (next < pending.length &&
          stopped == null &&
          _running.contains(reciter.id)) {
        final (s, n) = pending[next++];
        try {
          final size = await _fetch(reciter, s, n);
          if (size == null) return; // Paused in the middle of it.
          done++;
          bytes += size;
          inARow = 0;
        } on FileSystemException catch (e) {
          // No room stops it all; any other trouble is this clip's alone.
          if (const {28, 39, 112}.contains(e.osError?.errorCode)) {
            stopped = 'مساحة الجهاز ممتلئة';
          } else {
            failedClip((s, n));
          }
        } catch (_) {
          failedClip((s, n));
          if (++inARow >= _stopAfterFailures) {
            stopped = 'تعذر الاتصال بالإنترنت';
          }
        }
        publish(DownloadStatus.downloading);
      }
    }

    if (stopped == null) {
      await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    }
    _running.remove(reciter.id);
    publish(
      done >= clips.length ? DownloadStatus.complete : DownloadStatus.paused,
    );
  }

  /// One clip, named only once whole. Its size; null when paused meanwhile.
  Future<int?> _fetch(Reciter reciter, int surah, int native) async {
    final file = _file(reciter, surah, native);
    final part = File('${file.path}.part');
    final response = await _client
        .send(http.Request('GET', reciter.ayah(surah, native)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      throw http.ClientException('${response.statusCode}');
    }
    final sink = part.openWrite();
    var size = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (!_running.contains(reciter.id)) {
          await sink.close();
          await part.delete();
          return null;
        }
        sink.add(chunk);
        size += chunk.length;
      }
      await sink.close();
    } catch (_) {
      await sink.close().catchError((_) {});
      if (part.existsSync()) await part.delete();
      rethrow;
    }
    final expected = response.contentLength;
    if (size == 0 || expected != null && size != expected) {
      await part.delete();
      throw http.ClientException('incomplete');
    }
    // A virus scanner may hold a new file for a moment.
    for (var attempt = 0; ; attempt++) {
      try {
        await part.rename(file.path);
        return size;
      } on FileSystemException {
        // Moved after all, though it was reported otherwise.
        if (file.existsSync() && !part.existsSync()) return size;
        if (attempt >= 4) {
          if (part.existsSync()) await part.delete();
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 100 << attempt));
      }
    }
  }

  /// Stops after the clips in hand; [download] goes on from there.
  void pause(Reciter reciter) {
    _running.remove(reciter.id);
    notifyListeners();
  }

  /// Takes the reciter's files off the device.
  Future<void> delete(Reciter reciter) async {
    await init();
    _running.remove(reciter.id);
    final folder = _folder(reciter);
    if (folder.existsSync()) await folder.delete(recursive: true);
    await scan(reciter);
  }
}
