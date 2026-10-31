import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/tafsir_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('al-Dani\'s stops are in the app, each at its ayah', () async {
    final tafsir = TafsirRepository();
    final book = TafsirRepository.waqfBooks.single;
    expect(book.offline, isTrue);
    expect(TafsirRepository.book(90002), book);
    // A paragraph judging several stops is cut at each one.
    final rayb = await tafsir.text(book, 2, 2);
    expect(rayb, startsWith('﴿لا ريب فيه﴾ كاف.'));
    expect(rayb, contains('﴿هدى للمتقين﴾ تام'));
    expect(await tafsir.text(book, 2, 5), '﴿المفلحون﴾ تام.');
    // A lead-in goes with its stop.
    expect(await tafsir.text(book, 1, 4), startsWith('وعلى قوله ﴿مالك'));
    // «ومثله» judges a stop as the one before it, said in brackets.
    expect(await tafsir.text(book, 4, 5), 'ومثله ﴿معروفا﴾ [أي: كاف]');
    // What is said of a whole surah is at its opening.
    expect(await tafsir.text(book, 113, 1), startsWith('ليس فيها وقف كاف'));
    // Al-Munafiqun, under al-Jumu'a without a heading, and after it.
    expect(await tafsir.text(book, 63, 7), startsWith('﴿حتى ينفضوا﴾ تام.'));
    expect(await tafsir.text(book, 64, 3), startsWith('﴿فأحسن صوركم﴾ تام.'));
  });
}
