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
}
