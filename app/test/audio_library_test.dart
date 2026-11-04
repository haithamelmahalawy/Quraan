import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qiraat_mushaf/data/audio_numbering.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/recitations.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/services/audio_library.dart';
import 'package:qiraat_mushaf/ui/audio_library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const reciter = Reciter(7, 'شيخ', 'https://example.test/r/');
  late AudioNumbering numbering;
  late Directory root;
  // A short recording: writing the whole, thousands of files, is slow and
  // the desktop's virus scanner gets in the way. Its count is tested apart.
  final short = <(int, int)>[
    for (var n = 1; n <= 7; n++) (1, n),
    for (var n = 1; n <= 20; n++) (2, n),
    (2, 255),
    for (var n = 1; n <= 6; n++) (114, n),
  ];
  final total = short.length;

  setUpAll(() async {
    numbering = await AudioNumbering.load();
  });
  setUp(() => root = Directory.systemTemp.createTempSync('audio_library'));
  tearDown(() async {
    // A virus scanner may hold the last files for a moment.
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        root.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  });

  AudioLibrary library(http.Client client) => AudioLibrary(
    client: client,
    root: () async => root,
    numbering: () async => numbering,
    concurrency: 4,
    clipsOverride: short,
  );

  MockClient serving({bool Function(Uri)? fails, List<Uri>? asked}) =>
      MockClient((request) async {
        asked?.add(request.url);
        if (fails?.call(request.url) ?? false) {
          return http.Response('', 404);
        }
        return http.Response.bytes(utf8.encode('audio'), 200);
      });

  File clip(String name) => File('${root.path}/recitations/7/$name');

  test('every clip of every surah is asked for, once', () {
    final whole = [
      for (var s = 1; s <= 114; s++) numbering.nativeClips('kufi', s).length,
    ].reduce((a, b) => a + b);
    expect(whole, 6236);
    expect(numbering.nativeClips('kufi', 1).first, 1);
    // The basmala of a reading that does not count it has its clip 0.
    expect(numbering.nativeClips('madani-last', 1).first, 0);
  });

  test('downloads the whole recitation, then plays from the device', () async {
    final lib = library(serving());
    await lib.download(reciter);
    final state = lib.stateOf(reciter);
    expect(state.status, DownloadStatus.complete);
    expect(state.done, total);
    expect(state.bytes, total * 5);
    expect(clip('114006.mp3').existsSync(), isTrue);
    final uri = lib.clipUri(reciter, 2, 255);
    expect(uri.scheme, 'file');
    expect(uri.path, endsWith('recitations/7/002255.mp3'));
    // No temporary file is left behind.
    expect(
      clip('x').parent.listSync().where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('streams a clip that is not on the device', () async {
    final lib = library(serving());
    await lib.init();
    expect(
      lib.clipUri(reciter, 2, 255).toString(),
      'https://example.test/r/002255.mp3',
    );
  });

  test('goes on from where it stopped, not from the start', () async {
    final asked = <Uri>[];
    await clip('001001.mp3').create(recursive: true);
    await clip('001001.mp3').writeAsBytes(utf8.encode('audio'));
    final lib = library(serving(asked: asked));
    await lib.download(reciter);
    expect(asked, hasLength(total - 1));
    expect(asked.any((u) => u.path.endsWith('001001.mp3')), isFalse);
    expect(lib.stateOf(reciter).status, DownloadStatus.complete);
  });

  test('a clip that fails is left to be fetched again', () async {
    final lib = library(serving(fails: (u) => u.path.endsWith('002255.mp3')));
    await lib.download(reciter);
    final state = lib.stateOf(reciter);
    expect(state.status, DownloadStatus.paused);
    expect(state.failed, 1);
    expect(state.done, total - 1);
    expect(clip('002255.mp3').existsSync(), isFalse);
    expect(state.error, isNull);
  });

  test('a truncated clip is not kept', () async {
    final lib = library(
      MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('aud')),
          200,
          contentLength: 5,
        );
      }),
    );
    await lib.download(reciter);
    expect(lib.stateOf(reciter).done, 0);
    expect(clip('001001.mp3').existsSync(), isFalse);
  });

  test('with no connection it stops soon and says so', () async {
    var asked = 0;
    final lib = library(
      MockClient((request) async {
        asked++;
        throw http.ClientException('no connection');
      }),
    );
    await lib.download(reciter);
    final state = lib.stateOf(reciter);
    expect(state.error, contains('الاتصال'));
    expect(state.status, isNot(DownloadStatus.downloading));
    expect(lib.isRunning(reciter), isFalse);
    expect(asked, lessThan(100));
  });

  test('pause stops it, and it resumes', () async {
    final gate = Completer<void>();
    late AudioLibrary lib;
    lib = library(
      MockClient((request) async {
        if (!gate.isCompleted) {
          lib.pause(reciter);
          gate.complete();
        }
        return http.Response.bytes(utf8.encode('audio'), 200);
      }),
    );
    await lib.download(reciter);
    final paused = lib.stateOf(reciter);
    expect(lib.isRunning(reciter), isFalse);
    expect(paused.status, isNot(DownloadStatus.complete));
    expect(paused.done, lessThan(total));
    await lib.download(reciter);
    expect(lib.stateOf(reciter).status, DownloadStatus.complete);
  });

  test('scan finds what is there, delete removes it', () async {
    final lib = library(serving());
    await clip('001001.mp3').create(recursive: true);
    await clip('001001.mp3').writeAsBytes(utf8.encode('audio'));
    await clip('001002.mp3.part').writeAsBytes(utf8.encode('au'));
    await lib.scan(reciter);
    expect(lib.stateOf(reciter).done, 1);
    expect(lib.stateOf(reciter).bytes, 5);
    expect(lib.stateOf(reciter).status, DownloadStatus.paused);
    await lib.delete(reciter);
    expect(clip('x').parent.existsSync(), isFalse);
    expect(lib.stateOf(reciter).status, DownloadStatus.notStarted);
  });

  test('one surah alone downloads, and is told apart', () async {
    final asked = <Uri>[];
    final lib = library(serving(asked: asked));
    await lib.download(reciter, surah: 114);
    expect(asked, hasLength(6));
    expect(asked.every((u) => u.path.contains('/114')), isTrue);
    expect(lib.surahProgress(reciter, 114), (done: 6, total: 6));
    expect(lib.surahProgress(reciter, 1), (done: 0, total: 7));
    expect(lib.isSurahRunning(reciter, 114), isFalse);
    expect(lib.clipUri(reciter, 114, 1).scheme, 'file');
    expect(lib.clipUri(reciter, 1, 1).scheme, 'https');
    // The whole is partly there, and goes on from it.
    final state = lib.stateOf(reciter);
    expect(state.status, DownloadStatus.paused);
    expect(state.done, 6);
    expect(state.bytes, 30);
    asked.clear();
    await lib.download(reciter);
    expect(asked, hasLength(total - 6));
    expect(lib.stateOf(reciter).status, DownloadStatus.complete);
  });

  test('a surah can be paused and deleted alone', () async {
    final gate = Completer<void>();
    late AudioLibrary lib;
    lib = library(
      MockClient((request) async {
        if (!gate.isCompleted) {
          lib.pause(reciter, surah: 2);
          gate.complete();
        }
        return http.Response.bytes(utf8.encode('audio'), 200);
      }),
    );
    await lib.download(reciter, surah: 2);
    expect(lib.surahProgress(reciter, 2).done, lessThan(21));
    expect(lib.isSurahRunning(reciter, 2), isFalse);
    await lib.download(reciter, surah: 2);
    expect(lib.surahProgress(reciter, 2).done, 21);
    await lib.download(reciter, surah: 1);
    await lib.deleteSurah(reciter, 2);
    expect(lib.surahProgress(reciter, 2).done, 0);
    expect(lib.surahProgress(reciter, 1).done, 7);
    expect(clip('002001.mp3').existsSync(), isFalse);
    expect(clip('001001.mp3').existsSync(), isTrue);
  });

  test('two downloads never fetch one clip twice', () async {
    final asked = <Uri>[];
    final lib = library(serving(asked: asked));
    await Future.wait([
      lib.download(reciter, surah: 114),
      lib.download(reciter),
    ]);
    expect(asked.toSet(), hasLength(asked.length));
  });

  test('estimates the whole from a few clips', () async {
    final lib = library(
      MockClient(
        (request) async => http.Response.bytes(List.filled(1000, 0), 200),
      ),
    );
    expect(await lib.estimateBytes(reciter), 1000 * total);
  });

  test('every reciter has a folder of its own', () async {
    final recitations = await Recitations.load();
    final ids = <int, String>{};
    for (final q in qiraat) {
      for (final r in q.riwayat) {
        for (final reciter in recitations.of(r.id)) {
          final other = ids[reciter.id];
          expect(other == null || other == reciter.server, isTrue);
          ids[reciter.id] = reciter.server;
        }
      }
    }
    expect(ids, isNotEmpty);
  });

  testWidgets('the screen lists every qari, riwaya and reciter', (t) async {
    final quran = await t.runAsync(QuranRepository.load);
    final recitations = await t.runAsync(Recitations.load);
    final lib = library(serving());
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AudioLibraryScreen(
            quran: quran!,
            library: lib,
            recitations: recitations,
          ),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump();
    expect(find.text('المسموعات'), findsOneWidget);
    for (final q in qiraat) {
      expect(find.byKey(ValueKey('audio-qiraa-${q.id}')), findsOneWidget);
    }
    final q = qiraat.firstWhere((q) => q.riwayat.any((r) => r.id == 'qalun'));
    await t.tap(find.byKey(ValueKey('audio-qiraa-${q.id}')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('audio-riwaya-qalun')));
    await t.pumpAndSettle();
    final first = recitations!.of('qalun').first;
    expect(find.byKey(ValueKey('audio-reciter-${first.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('audio-download-${first.id}')), findsOneWidget);
    // Each surah has its own download beside it.
    await t.tap(find.byKey(ValueKey('audio-reciter-${first.id}')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('audio-surah-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('audio-surah-download-1')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
}
