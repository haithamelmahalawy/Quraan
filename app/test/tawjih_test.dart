import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/tafsir_repository.dart';
import 'package:qiraat_mushaf/data/tawjih_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the reasons of the readings are in the app, ayah by ayah', () async {
    final tafsir = TafsirRepository();
    final book = TafsirRepository.tawjihBooks.single;
    expect(book.offline, isTrue);
    final malik = await tafsir.text(book, 1, 4);
    expect(malik, startsWith('﴿مالك يوم الدين﴾'));
    expect(malik, contains('قرأ عاصم والكسائي'));
    // A passage the book does not head is of its own ayah (4:10).
    expect(await tafsir.text(book, 4, 10), contains('وسيصلون'));
    expect(await tafsir.text(book, 4, 5), isNot(contains('وسيصلون')));
  });

  test('only the chosen riwayat\'s readings and their reasons', () {
    const text =
        '﴿مالك يوم الدين﴾\n'
        'قرأ عاصم والكسائي ﴿مالك﴾ بألف\n'
        'وحجتهما قوله ﴿مالك الملك﴾\n'
        'وقرأ الباقون بغير ألف\n'
        'وحجتهم ﴿الملك القدوس﴾';
    // Hafs (Asim) is named: his reading and its reason.
    expect(
      tawjihOf(text, ['hafs']),
      '﴿مالك يوم الدين﴾\n'
      'قرأ عاصم والكسائي ﴿مالك﴾ بألف\n'
      'وحجتهما قوله ﴿مالك الملك﴾',
    );
    // Hisham (Ibn Amir) is not: he is of «الباقون».
    expect(
      tawjihOf(text, ['hisham']),
      '﴿مالك يوم الدين﴾\n'
      'وقرأ الباقون بغير ألف\n'
      'وحجتهم ﴿الملك القدوس﴾',
    );
    // Both, in the book's order; none of the seven, nothing.
    expect(tawjihOf(text, ['hisham', 'hafs']).split('\n'), hasLength(5));
    expect(tawjihOf(text, ['ruways']), isEmpty);
  });
}
