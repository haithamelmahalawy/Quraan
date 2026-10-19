import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';

void main() {
  test('riwaya text in the script of the Madinah page', () {
    // Warsh's أَرَىٰكُمۡ (Hud 29): ya before the dagger alef is ى, as in Hafs.
    expect(madinahScript('أَر۪يٰكُمْ'), 'أَر۪ىٰكُمْ');
    // The Maghribi yeh barree.
    expect(madinahScript('مُوسَےٰ'), 'مُوسَىٰ');
    // Shu'bah's dot below for imala becomes the Madinah imala sign.
    expect(madinahScript('رَمَٜى'), 'رَمَ۪ى');
    // Warsh's naql (قَرِيبٌ اُجِيبُ) and alef of wasl, without the circles.
    expect(madinahScript('ا۟جِيبُ'), 'اجِيبُ');
    expect(madinahScript('ا۟خَرَۖ'), 'اخَرَۖ');
    expect(madinahScript('اَ۬لدَّاعِۦٓ'), 'ٱلدَّاعِۦٓ');
    expect(madinahScript('قَالُواْ اَ۬لْءَٰنَ'), 'قَالُواْ ٱلْءَٰنَ');
  });

  test('the letters of naql and madd al-badal', () {
    // Warsh's وَلَقَدَ اٰتَيْنَا: the dal takes the vowel, the alef is the madd.
    expect(naqlLetter(lettersOf('وَلَقَدَ'), last: true), 3);
    expect(badalLetter(lettersOf('اٰتَيْنَا')), 0);
    // وَبِالَاخِرَةِ: the lam (4th letter) takes it, the alef after is the madd.
    final akhira = lettersOf('وَبِالَاخِرَةِ');
    expect(naqlLetter(akhira), 3);
    expect(badalLetter(akhira), 4);
    // Hafs text: ءَامَنُواْ, أُوتُواْ, ٱلۡأٓخِرَةِ.
    expect(badalLetter(lettersOf('ءَامَنُواْ')), 1);
    expect(badalLetter(lettersOf('أُوتُواْ')), 1);
    expect(badalLetter(lettersOf('ٱلۡأٓخِرَةِ')), 2);
    // Tarqiq and taghliz: the ra of وَبِالَاخِرَةِ, the lam of ٱلصَّلَوٰةَ.
    expect(raLetter(akhira), 6);
    expect(lamLetter(lettersOf('ٱلصَّلَوٰةَ')), 3);
  });

  test('the imala sign goes under the letter read with imala', () {
    String under(String word) {
      final i = withImalaSign(word).indexOf(imalaSign);
      // The letter the sign belongs to: the last base letter before it.
      return String.fromCharCodes(
        withImalaSign(word)
            .substring(0, i)
            .runes
            .where((c) => c >= 0x0621 && c <= 0x064A),
      );
    }

    // Before ى.
    expect(under('هُدٗى'), 'هد');
    expect(under('أَرَىٰكُمۡ'), 'أر');
    // Before an alef followed by ra.
    expect(under('ٱلنَّارِ'), 'لن');
    // Before the ta marbuta.
    expect(under('رَحۡمَةٞ'), 'رحم');
    // Already marked: unchanged.
    expect(withImalaSign('مَجۡر۪ىٰهَا'), 'مَجۡر۪ىٰهَا');
  });

  test('kashida draws out the last join of a word, never lam-alef', () {
    // خَالِصَةً: after the sad (before the ta marbuta), the lam, the kha.
    final khalisa = lettersOf('خَالِصَةً');
    expect(kashidaSlots(khalisa), [3, 2, 0]);
    expect(withKashida(khalisa, 2).join(), 'خَالِصَــةً');
    // No join to stretch in دَارُ; none inside lam-alef (ٱلۡأٓخِرَةِ's لأ).
    expect(kashidaSlots(lettersOf('دَارُ')), isEmpty);
    expect(kashidaSlots(lettersOf('لَا')), isEmpty);
  });
}
