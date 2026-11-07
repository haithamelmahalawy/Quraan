import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/tafsir_repository.dart';
import 'audio_library.dart' show DownloadStatus;

/// A book's text on this device.
class BookDownload {
  const BookDownload({
    this.status = DownloadStatus.notStarted,
    this.done = 0,
    this.total = 0,
    this.bytes = 0,
    this.error,
  });

  final DownloadStatus status;

  /// Its ayahs fetched, of all of them.
  final int done, total;
  final int bytes;

  /// Why it stopped: no connection, or no room left on the device.
  final String? error;

  double get progress => total == 0 ? 0 : done / total;
}

/// The books read online kept on the device, to be read with no connection:
/// each book in a folder, a file for each surah, written under a temporary name
/// once all its ayahs are in. A download resumes at the first surah missing.
class ReadingDownloads extends ChangeNotifier {
  ReadingDownloads({
    http.Client? client,
    Future<Directory> Function()? root,
    this.concurrency = 4,
    Duration Function(int attempt)? retryDelay,
  }) : _retryDelay = retryDelay ?? _backoff,
       _client = client ?? http.Client(),
       _rootOf = root ?? getApplicationSupportDirectory;

  static final instance = ReadingDownloads();

  static const noConnection = 'تعذر الاتصال بالإنترنت، أعد المحاولة للإكمال.';
  static const noRoom = 'لا توجد مساحة كافية على الجهاز.';
  static const serverBusy =
      'الخادم مشغول أو لا يجيب الآن، أعد المحاولة بعد قليل للإكمال.';

  /// Tries for each ayah before the download stops.
  static const attempts = 5;

  static Duration _backoff(int attempt) =>
      Duration(seconds: 1 << (attempt - 1));

  final http.Client _client;
  final Future<Directory> Function() _rootOf;

  /// The ayahs asked at once, of all the books downloading together: the
  /// server refuses many at once.
  final int concurrency;
  final Duration Function(int attempt) _retryDelay;
  var _asking = 0;
  final _waiting = <Completer<void>>[];

  Directory? _root;
  final _progress = <int, BookDownload>{};
  final _running = <int>{};
  final _stopping = <int>{};
  final _surahs = <String, Map<int, String?>>{};

  Future<Directory> _folder(int book) async {
    _root ??= await _rootOf();
    return Directory('${_root!.path}/readings/$book');
  }

  File _file(Directory folder, int surah) => File('${folder.path}/$surah.json');

  BookDownload statusOf(int book) => _progress[book] ?? const BookDownload();

  /// What is on the device of [book], whose surahs have [ayahCounts] ayahs.
  Future<BookDownload> load(int book, List<int> ayahCounts) async {
    if (_running.contains(book)) return statusOf(book);
    final folder = await _folder(book);
    var done = 0, bytes = 0;
    for (var s = 1; s <= ayahCounts.length; s++) {
      final file = _file(folder, s);
      if (await file.exists()) {
        done += ayahCounts[s - 1];
        bytes += await file.length();
      }
    }
    final total = ayahCounts.fold(0, (a, b) => a + b);
    final status = done == 0
        ? DownloadStatus.notStarted
        : done == total
        ? DownloadStatus.complete
        : DownloadStatus.paused;
    final loaded = BookDownload(
      status: status,
      done: done,
      total: total,
      bytes: bytes,
      error: statusOf(book).error,
    );
    _progress[book] = loaded;
    notifyListeners();
    return loaded;
  }

  /// The ayah's text if its surah is on the device: first whether it is, then
  /// the text, null where the book has none.
  Future<(bool, String?)> lookup(int book, int surah, int ayah) async {
    try {
      final key = '$book:$surah';
      var texts = _surahs[key];
      if (texts == null) {
        final file = _file(await _folder(book), surah);
        if (!await file.exists()) return (false, null);
        final json = jsonDecode(await file.readAsString()) as Map;
        texts = _surahs[key] = {
          for (final e in json.entries)
            int.parse(e.key as String): e.value as String?,
        };
      }
      return (true, texts[ayah]);
    } catch (_) {
      return (false, null);
    }
  }

  /// Fetches what is missing of [book], until done or stopped.
  Future<void> download(int book, List<int> ayahCounts) async {
    if (!_running.add(book)) return;
    _stopping.remove(book);
    final total = ayahCounts.fold(0, (a, b) => a + b);
    var done = 0, bytes = 0;
    void report(DownloadStatus status, [String? error]) {
      _progress[book] = BookDownload(
        status: status,
        done: done,
        total: total,
        bytes: bytes,
        error: error,
      );
      notifyListeners();
    }

    try {
      final folder = await _folder(book);
      await folder.create(recursive: true);
      for (var s = 1; s <= ayahCounts.length; s++) {
        final file = _file(folder, s);
        if (await file.exists()) {
          done += ayahCounts[s - 1];
          bytes += await file.length();
        }
      }
      report(DownloadStatus.downloading);
      for (var s = 1; s <= ayahCounts.length; s++) {
        if (_stopping.contains(book)) break;
        final file = _file(folder, s);
        if (await file.exists()) continue;
        final texts = await _fetchSurah(book, s, ayahCounts[s - 1], () {
          done++;
          report(DownloadStatus.downloading);
        });
        if (texts == null) {
          // Stopped within it: that surah's count starts over.
          done = await _doneOn(folder, ayahCounts);
          break;
        }
        await _write(file, jsonEncode(texts));
        bytes += await file.length();
      }
      done = await _doneOn(folder, ayahCounts);
      report(done == total ? DownloadStatus.complete : DownloadStatus.paused);
    } on FileSystemException {
      done = await _doneOnSafely(book, ayahCounts);
      report(DownloadStatus.paused, noRoom);
    } on TafsirServerException {
      done = await _doneOnSafely(book, ayahCounts);
      report(DownloadStatus.paused, serverBusy);
    } catch (_) {
      done = await _doneOnSafely(book, ayahCounts);
      report(DownloadStatus.paused, noConnection);
    } finally {
      _running.remove(book);
      _stopping.remove(book);
    }
  }

  Future<int> _doneOn(Directory folder, List<int> ayahCounts) async {
    var done = 0;
    for (var s = 1; s <= ayahCounts.length; s++) {
      if (await _file(folder, s).exists()) done += ayahCounts[s - 1];
    }
    return done;
  }

  Future<int> _doneOnSafely(int book, List<int> ayahCounts) async {
    try {
      return await _doneOn(await _folder(book), ayahCounts);
    } catch (_) {
      return 0;
    }
  }

  /// The surah's ayahs, or null when asked to stop; throws when one cannot be
  /// reached after trying again.
  Future<Map<String, String?>?> _fetchSurah(
    int book,
    int surah,
    int ayahs,
    VoidCallback onAyah,
  ) async {
    final texts = <String, String?>{};
    var next = 1;
    Future<void> worker() async {
      while (next <= ayahs && !_stopping.contains(book)) {
        final ayah = next++;
        texts['$ayah'] = await _fetchAyah(book, surah, ayah);
        onAyah();
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    return _stopping.contains(book) ? null : texts;
  }

  Future<String?> _fetchAyah(int book, int surah, int ayah) async {
    for (var attempt = 1; ; attempt++) {
      Duration? wait;
      await _slot();
      try {
        return await fetchTafsirAyah(_client, book, surah, ayah);
      } on TafsirServerException catch (e) {
        if (attempt == attempts) rethrow;
        if (e.retryAfter case final s? when s > 0 && s <= 60) {
          wait = Duration(seconds: s);
        }
      } catch (_) {
        if (attempt == attempts) rethrow;
      } finally {
        _free();
      }
      await Future<void>.delayed(wait ?? _retryDelay(attempt));
    }
  }

  Future<void> _slot() async {
    if (_asking < concurrency) {
      _asking++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
  }

  /// Its place handed to the next waiting, or given up.
  void _free() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _asking--;
    }
  }

  Future<void> _write(File file, String text) async {
    final part = File('${file.path}.part');
    await part.writeAsString(text, flush: true);
    await part.rename(file.path);
  }

  /// Stops at the end of the ayahs being fetched; the surahs written stay.
  void pause(int book) {
    if (_running.contains(book)) _stopping.add(book);
  }

  Future<void> delete(int book, List<int> ayahCounts) async {
    pause(book);
    while (_running.contains(book)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final folder = await _folder(book);
    if (await folder.exists()) await folder.delete(recursive: true);
    _surahs.removeWhere((key, _) => key.startsWith('$book:'));
    _progress.remove(book);
    await load(book, ayahCounts);
  }
}
