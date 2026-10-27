import 'package:flutter_test/flutter_test.dart';
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
