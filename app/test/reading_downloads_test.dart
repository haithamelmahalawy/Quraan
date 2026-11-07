import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/tafsir_repository.dart';
import 'package:qiraat_mushaf/services/audio_library.dart' show DownloadStatus;
import 'package:qiraat_mushaf/services/reading_downloads.dart';
import 'package:qiraat_mushaf/ui/readings_screen.dart';

void main() {
  late Directory root;
  const counts = [3, 2];
  const book = 136;

  setUp(() => root = Directory.systemTemp.createTempSync('readings'));
  tearDown(() => root.deleteSync(recursive: true));

  http.Response answer(http.Request r) {
    final parts = r.url.pathSegments;
    final surah = parts[2], ayah = parts[3];
    return http.Response('{"content":[{"text":"text $surah:$ayah"}]}', 200);
  }

  ReadingDownloads downloads(http.Client client) => ReadingDownloads(
    client: client,
    root: () async => root,
    concurrency: 2,
    retryDelay: (_) => Duration.zero,
  );

  test('a book comes down whole and is read from the device', () async {
    var calls = 0;
    final d = downloads(
      MockClient((r) async {
        calls++;
        return answer(r);
      }),
    );
    await d.download(book, counts);
    expect(calls, 5);
    expect(d.statusOf(book).status, DownloadStatus.complete);
    expect(d.statusOf(book).done, 5);
    expect(d.statusOf(book).bytes, greaterThan(0));

    // No connection now: the repository reads it from the device.
    final repo = TafsirRepository(
      client: MockClient((_) async => throw const SocketException('offline')),
      local: d.lookup,
    );
    final tafsir = TafsirRepository.book(book);
    expect(await repo.text(tafsir, 1, 2), 'text 1:2');
    expect(await repo.text(tafsir, 2, 2), 'text 2:2');
  });

  test('a book not on the device is read from the network', () async {
    final d = downloads(MockClient((_) async => http.Response('', 500)));
    final repo = TafsirRepository(
      client: MockClient((r) async => answer(r)),
      local: d.lookup,
    );
    expect(await repo.text(TafsirRepository.book(book), 1, 1), 'text 1:1');
  });

  test('a cut connection stops it, and it resumes where it stopped', () async {
    var online = true;
    var calls = 0;
    final d = downloads(
      MockClient((r) async {
        calls++;
        if (!online || r.url.pathSegments[2] == '2') {
          throw const SocketException('offline');
        }
        return answer(r);
      }),
    );
    await d.download(book, counts);
    expect(d.statusOf(book).status, DownloadStatus.paused);
    expect(d.statusOf(book).done, 3);
    expect(d.statusOf(book).error, ReadingDownloads.noConnection);
    expect(File('${root.path}/readings/$book/1.json').existsSync(), isTrue);
    expect(File('${root.path}/readings/$book/2.json').existsSync(), isFalse);

    // The first surah is not fetched again.
    online = true;
    calls = 0;
    final again = downloads(
      MockClient((r) async {
        calls++;
        expect(r.url.pathSegments[2], '2');
        return answer(r);
      }),
    );
    await again.load(book, counts);
    expect(again.statusOf(book).status, DownloadStatus.paused);
    await again.download(book, counts);
    expect(calls, 2);
    expect(again.statusOf(book).status, DownloadStatus.complete);
    expect(again.statusOf(book).error, isNull);
  });

  test('a failing ayah tried again does not stop the book', () async {
    final tries = <String, int>{};
    final d = downloads(
      MockClient((r) async {
        final key = r.url.path;
        tries[key] = (tries[key] ?? 0) + 1;
        // Busy twice, then answers.
        if (tries[key]! <= 2) return http.Response('busy', 429);
        return answer(r);
      }),
    );
    await d.download(book, counts);
    expect(d.statusOf(book).status, DownloadStatus.complete);
    expect(d.statusOf(book).error, isNull);
  });

  test(
    'a server that will not answer is told apart from no connection',
    () async {
      final d = downloads(MockClient((_) async => http.Response('down', 503)));
      await d.download(book, counts);
      expect(d.statusOf(book).status, DownloadStatus.paused);
      expect(d.statusOf(book).error, ReadingDownloads.serverBusy);
      // A page in place of the answer: the server's too.
      final page = downloads(
        MockClient((_) async => http.Response('<html>', 200)),
      );
      await page.download(book, counts);
      expect(page.statusOf(book).error, ReadingDownloads.serverBusy);
    },
  );

  test(
    'books downloaded together ask no more at once than the limit',
    () async {
      var asking = 0, most = 0;
      final d = downloads(
        MockClient((r) async {
          most = asking + 1 > most ? asking + 1 : most;
          asking++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          asking--;
          return answer(r);
        }),
      );
      await Future.wait([
        for (final b in [136, 4, 2, 184]) d.download(b, counts),
      ]);
      expect(most, 2);
      for (final b in [136, 4, 2, 184]) {
        expect(d.statusOf(b).status, DownloadStatus.complete);
      }
    },
  );

  test('deleting takes it off the device', () async {
    final d = downloads(MockClient((r) async => answer(r)));
    await d.download(book, counts);
    await d.delete(book, counts);
    expect(d.statusOf(book).status, DownloadStatus.notStarted);
    expect(await d.lookup(book, 1, 1), (false, null));
  });

  testWidgets('the screen lists every book, those online to download', (
    t,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final quran = await t.runAsync(QuranRepository.load);
    addTearDown(t.view.reset);
    t.view.physicalSize = const Size(600, 3000);
    t.view.devicePixelRatio = 1;
    final d = downloads(MockClient((r) async => answer(r)));
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ReadingsScreen(quran: quran!, downloads: d),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump();
    for (final book in [
      ...TafsirRepository.books,
      ...TafsirRepository.e3rabBooks,
      ...TafsirRepository.tawjihBooks,
      ...TafsirRepository.waqfBooks,
    ]) {
      expect(
        find.byKey(ValueKey('reading-book-${book.id}')),
        findsOneWidget,
        reason: book.name,
      );
      expect(
        find.byKey(ValueKey('reading-download-${book.id}')),
        book.offline ? findsNothing : findsOneWidget,
        reason: book.name,
      );
    }
    expect(find.byKey(const ValueKey('readings-texts')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('every book read online can be kept, the others are in the app', () {
    final online = [
      ...TafsirRepository.books,
      ...TafsirRepository.e3rabBooks,
      ...TafsirRepository.tawjihBooks,
      ...TafsirRepository.waqfBooks,
    ].where((b) => !b.offline);
    expect(online.map((b) => b.id), [
      136,
      4,
      2,
      184,
      321,
      340,
      350,
      343,
      308,
      309,
      318,
    ]);
  });
}
