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

/// A recitation kept on the device, whole or surah by surah, to be heard with
/// no connection: each reciter's clips in a folder of their own, the player
/// taking a clip from it when it is there. A download resumes where it stopped:
/// a clip is written under a temporary name and only named once complete.
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

  /// What stopped each reciter's last download.
  final _stops = <int, ({int failed, String? error})>{};

  /// The downloads under way: a reciter's whole, or one surah of it.
  final _running = <String>{};

  /// The clips being fetched, so that two downloads never write one file.
  final _fetching = <String>{};

  /// Each reciter's recording, and the clips and bytes on the device.
  final _recording = <int, List<(int, int)>>{};
  final _have = <int, Set<String>>{};
  final _bytes = <int, int>{};
  Directory? _root;

  Future<void> init() async {
    _root ??= await _rootOf();
  }

  String _job(Reciter reciter, [int? surah]) =>
      surah == null ? '${reciter.id}' : '${reciter.id}:$surah';

  /// The whole recitation is downloading.
  bool isRunning(Reciter reciter) => _running.contains(_job(reciter));

  /// This surah is downloading, by itself or with the whole.
  bool isSurahRunning(Reciter reciter, int surah) =>
      isRunning(reciter) || _running.contains(_job(reciter, surah));

  ReciterDownload stateOf(Reciter reciter) {
    final clips = _recording[reciter.id];
    if (clips == null) return const ReciterDownload();
    final have = _have[reciter.id] ?? const <String>{};
    final done = clips.where((c) => have.contains(_name(c.$1, c.$2))).length;
    final stop = _stops[reciter.id];
    return ReciterDownload(
      status: isRunning(reciter)
          ? DownloadStatus.downloading
          : done == 0
          ? DownloadStatus.notStarted
          : done >= clips.length
          ? DownloadStatus.complete
          : DownloadStatus.paused,
      done: done,
      total: clips.length,
      bytes: _bytes[reciter.id] ?? 0,
      failed: stop?.failed ?? 0,
      error: stop?.error,
    );
  }

  /// How much of a surah is on the device: clips held, of how many.
  ({int done, int total}) surahProgress(Reciter reciter, int surah) {
    final clips = (_recording[reciter.id] ?? const <(int, int)>[]).where(
      (c) => c.$1 == surah,
    );
    final have = _have[reciter.id] ?? const <String>{};
    return (
      done: clips.where((c) => have.contains(_name(c.$1, c.$2))).length,
      total: clips.length,
    );
  }

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
    final clips = _recording[reciter.id] ??= await _clips(reciter);
    final have = <String>{};
    var bytes = 0;
    final folder = _folder(reciter);
    if (folder.existsSync()) {
      final wanted = {for (final (s, n) in clips) _name(s, n)};
      for (final entity in folder.listSync().whereType<File>()) {
        final name = entity.uri.pathSegments.last;
        if (wanted.contains(name)) {
          have.add(name);
          bytes += entity.lengthSync();
        }
      }
    }
    _have[reciter.id] = have;
    _bytes[reciter.id] = bytes;
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

  /// Downloads what is missing of the whole recitation, or of one [surah],
  /// until done or paused. A clip that fails is left for the next attempt, and
  /// is streamed meanwhile.
  Future<void> download(Reciter reciter, {int? surah}) async {
    await init();
    final job = _job(reciter, surah);
    if (!_running.add(job)) return;
    notifyListeners();
    await scan(reciter);
    final clips = [
      for (final c in _recording[reciter.id]!)
        if (surah == null || c.$1 == surah) c,
    ];
    // Read afresh each time: a scan meanwhile replaces it.
    Set<String> have() => _have[reciter.id] ??= <String>{};
    String? stopped;
    try {
      await _folder(reciter).create(recursive: true);
    } on FileSystemException {
      stopped = 'تعذر الحفظ على الجهاز';
    }
    var failed = 0, inARow = 0;
    final pending = [
      for (final c in clips)
        if (!have().contains(_name(c.$1, c.$2))) c,
    ];
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

    void publish() {
      _stops[reciter.id] = (failed: failed, error: stopped);
      notifyListeners();
    }

    publish();
    Future<void> worker() async {
      while (next < pending.length &&
          stopped == null &&
          _running.contains(job)) {
        final (s, n) = pending[next++];
        final fetching = '${reciter.id}/${_name(s, n)}';
        // The other download, of the whole or of this surah, has it or has
        // it in hand.
        if (have().contains(_name(s, n)) || !_fetching.add(fetching)) continue;
        try {
          final size = await _fetch(reciter, s, n, job);
          if (size == null) return; // Paused in the middle of it.
          have().add(_name(s, n));
          _bytes[reciter.id] = (_bytes[reciter.id] ?? 0) + size;
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
        } finally {
          _fetching.remove(fetching);
        }
        publish();
      }
    }

    if (stopped == null) {
      await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    }
    _running.remove(job);
    publish();
  }

  /// One clip, named only once whole. Its size; null when paused meanwhile.
  Future<int?> _fetch(
    Reciter reciter,
    int surah,
    int native,
    String job,
  ) async {
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
        if (!_running.contains(job)) {
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
  void pause(Reciter reciter, {int? surah}) {
    _running.remove(_job(reciter, surah));
    notifyListeners();
  }

  /// Takes the reciter's files off the device.
  Future<void> delete(Reciter reciter) async {
    await init();
    _running.removeWhere(
      (job) => job == _job(reciter) || job.startsWith('${reciter.id}:'),
    );
    _stops.remove(reciter.id);
    final folder = _folder(reciter);
    if (folder.existsSync()) await folder.delete(recursive: true);
    await scan(reciter);
  }

  /// Takes one surah's files off the device.
  Future<void> deleteSurah(Reciter reciter, int surah) async {
    await init();
    _running.remove(_job(reciter, surah));
    for (final (s, n) in _recording[reciter.id] ?? const <(int, int)>[]) {
      if (s != surah) continue;
      final file = _file(reciter, s, n);
      if (file.existsSync()) await file.delete();
    }
    await scan(reciter);
  }
}
