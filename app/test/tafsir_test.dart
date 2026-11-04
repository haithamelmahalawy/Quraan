import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/e3rab_text.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/recitations.dart';
import 'package:qiraat_mushaf/data/tafsir_repository.dart';
import 'package:qiraat_mushaf/data/tafsir_text.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
 
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline tafsir books are in the app', () async {
    final tafsir = TafsirRepository();
    for (final book in TafsirRepository.books.where((b) => b.offline)) {
      final text = await tafsir.text(book, 2, 255);
      expect(text, isNotEmpty, reason: book.name);
    }
    final muyassar = await tafsir.text(TafsirRepository.book(2012), 1, 1);
    expect(muyassar, startsWith('أبتدئ قراءة القرآن باسم الله'));
  });

  test(
    'offline books of i\'rab are in the app, the ayah word by word',
    () async {
      final tafsir = TafsirRepository();
      for (final book in TafsirRepository.e3rabBooks.where((b) => b.offline)) {
        expect(await tafsir.text(book, 2, 255), isNotEmpty, reason: book.name);
      }
      final daas = await tafsir.text(TafsirRepository.book(316), 2, 2);
      expect(daas, contains('مبتدأ'));
      // The next ayah has its own i'rab (the recitation goes on to it).
      expect(await tafsir.text(TafsirRepository.book(316), 2, 7), isNotEmpty);
    },
  );

  test('al-Da\'as\'s i\'rab of one ayah, word by word', () async {
    final quran = await QuranRepository.load();
    final tafsir = TafsirRepository();
    final book = TafsirRepository.book(316);
    Future<List<({String word, String e3rab})>> of(int s, int a) async {
      final to = math.min(quran.surah(s).ayahCount, a + 2);
      final texts = await tafsir.textsOf(book, s, math.max(1, a - 8), to);
      return e3rabWords(texts, [
        for (var n = math.max(1, a - 20); n <= to; n++)
          (n, quran.ayah(s, n).words),
      ], a);
    }

    // Its text of 2:1-5 together: only the words of 2:2.
    final dhalika = await of(2, 2);
    expect(dhalika, hasLength(6));
    expect(dhalika.first.word, 'ذلِكَ');
    expect(dhalika.first.e3rab, startsWith('ذا اسم إشارة'));
    // The entry of 2:255 begins with the end of 2:254's i'rab.
    final kursi = await of(2, 255);
    expect(kursi.first.e3rab, 'لفظ الجلالة مبتدأ');
    expect(kursi.last.word, 'الْعَظِيمُ');
  });

  test('the book HTML becomes text', () {
    expect(
      tafsirText(
        '<span class="book-ayah">﴿اللَّهُ﴾</span> الحي<br />\r'
        'القيوم&nbsp;&quot;الدائم&quot;',
      ),
      '﴿اللَّهُ﴾ الحي\nالقيوم "الدائم"',
    );
  });

  test('every riwaya has a sheikh, recorded ayah by ayah', () async {
    final recitations = await Recitations.load();
    for (final q in qiraat) {
      for (final r in q.riwayat) {
        expect(recitations.of(r.id), isNotEmpty, reason: r.id);
      }
    }
    final warsh = recitations.of('warsh').first;
    expect(warsh.ayah(2, 5).toString(), endsWith('/002005.mp3'));
  });
}
