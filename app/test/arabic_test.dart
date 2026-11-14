import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';

void main() {
  test('nun sukun is omitted only at a marked boundary idgham', () {
    expect(madinahScript('أَنْ يُّومِنُواْ'), 'أَن يُّومِنُواْ');
    expect(madinahScript('أَنْ', followingWord: 'يُّومِنُواْ'), 'أَن');
    expect(madinahScript('مِنْ رَّبِّهِمْ'), 'مِن رَّبِّهِمۡ');
    expect(madinahScript('مِنْ أَهْلِهِ'), 'مِنۡ أَهۡلِهِ');
    expect(madinahScript('مِنْ', followingWord: 'أَهْلِهِ'), 'مِنۡ');
    expect(madinahScript('الدُّنْيَا'), 'الدُّنۡيَا');
  });
  test('riwaya text in the script of the Madinah page', () {
    // Warsh's أَرَىٰكُمۡ (Hud 29): ya before the dagger alef is ى, as in Hafs.
    expect(madinahScript('أَر۪يٰكُمْ'), 'أَر۪ىٰكُمۡ');
    // The Maghribi yeh barree.
    expect(madinahScript('مُوسَےٰ'), 'مُوسَىٰ');
    // Shu'bah's dot below for imala becomes the Madinah imala sign.
    expect(madinahScript('رَمَٜى'), 'رَمَ۪ى');
    // Warsh's naql (قَرِيبٌ اُجِيبُ) and alef of wasl, without the circles.
    expect(madinahScript('ا۟جِيبُ'), 'اجِيبُ');
    expect(madinahScript('ا۟خَرَۖ'), 'اخَرَۖ');
    expect(madinahScript('اَ۬لدَّاعِۦٓ'), 'ٱلدَّاعِۦٓ');
    expect(madinahScript('قَالُواْ اَ۬لْءَٰنَ'), 'قَالُواْ ٱلۡءَٰنَ');
    expect(madinahScript('يُوَ۬اخِذُكُمُ'), 'يُوَاخِذُكُمُ');
    expect(madinahScript('فَلْيُوَ۬دِّ'), 'فَلۡيُوَدِّ');
    expect(madinahScript('لِيَ۬لَّا'), 'لِيَلَّا');
    expect(madinahScript('يَّرْتَدِدْ'), 'يَرۡتَدِدۡ');
    expect(madinahScript('مَنْ يَّرْتَدِدْ'), 'مَن يَرۡتَدِدۡ');
    expect(madinahScript('هَدْياَۢ'), 'هَدۡيَۢا');
    expect(madinahScript('قَوْلاَۢۖ'), 'قَوۡلَۢاۖ');
  });

  test(
    'lin ya and the following hamza keep separate letters in the Hafs font',
    () {
      for (final word in ['شَئْاٗ', 'شَئْاً', 'شَئْاٗۖ']) {
        final shown = madinahScript(word);
        expect(
          shown,
          word
              .replaceAll('ئْ', 'يۡـٔ')
              // The tanween before its alif, as Hafs's «شَيۡـٔٗا».
              .replaceAllMapped(RegExp('ا([ًٗ])'), (m) => '${m[1]}ا'),
        );
        expect(lettersOf(shown).map((l) => l[0]), ['ش', 'ي', 'ـ', 'ا']);
        expect(madinahScript(shown), shown);
      }
      expect(madinahScript('بِئْرٍ'), 'بِئۡرٍ');
      expect(madinahScript('شَيۡـٔٗا'), 'شَيۡـٔٗا');
    },
  );

  test('pronounced sukun uses jazm while silent-letter circles survive', () {
    for (final (input, expected) in [
      ('شَيْءٍ', 'شَيۡءٍ'),
      ('مِنْ آمَنَ', 'مِنۡ آمَنَ'),
      ('قُلْ هُوَ', 'قُلۡ هُوَ'),
      ('يَوْمٍ', 'يَوۡمٍ'),
      ('مُرْجَئُوْنَ', 'مُرۡجَئُونَ'),
      ('بَيْتِىْ', 'بَيۡتِى'),
      ('أُوْلَٰٓئِكَ', 'أُوْلَٰٓئِكَ'),
      ('وَمَلَإِيْهِمْ', 'وَمَلَإِيْهِمۡ'),
      ('ءَامَنُواْ', 'ءَامَنُواْ'),
      ('أُو۟لَٰٓئِكَ', 'أُو۟لَٰٓئِكَ'),
      ('أَنَا۠', 'أَنَا۠'),
    ]) {
      expect(madinahScript(input), expected);
      expect(madinahScript(expected), expected);
    }
  });

  test('the letters of naql and madd al-badal', () {
    // Warsh's وَلَقَدَ اٰتَيْنَا: the dal takes the vowel, the alef is the madd.
    expect(naqlLetter(lettersOf('وَلَقَدَ'), last: true), 3);
    expect(badalLetter(lettersOf('اٰتَيْنَا')), 0);
    // وَبِالَاخِرَةِ: the lam (4th letter) takes it, the alef after is the madd.
    final akhira = lettersOf('وَبِالَاخِرَةِ');
    expect(naqlLetter(akhira), 3);
    expect(naqlLetter(lettersOf('فَٱلۡـَٰٔنَ')), 2);
    expect(naqlLetter(lettersOf('فَالَٰنَ')), 2);
    expect(badalLetter(lettersOf('فَالَٰنَ')), 2);
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
    // The alif of a final «ها» not the one leaned when another is before it
    // (أحياها: under the ya, the user, 2026-11-14).
    expect(withImalaSign('أَحۡيَاهَا'), 'أَحۡيَ۪اهَا');
    expect(withImalaSign('ضُحَىٰهَا'), 'ضُحَ۪ىٰهَا');
  });

  test('tarqiq distinguishes fathatan/dammatan from shared kasratan', () {
    for (final text in [
      'خَيْرَ',
      'خَيْرُ',
      'خَيْرًا',
      'خَيْراً',
      'خَيْرٗا',
      'خَيْراٗ',
      'خَيْرٌ',
      'خَيْرٞ',
      'كَثِيراٗۖ',
    ]) {
      expect(raLetter(lettersOf(text)), isNotNull, reason: text);
    }
    for (final text in [
      'خَيْرِ',
      'خَيْرٍ',
      'خَيْرٖ',
      'خَيْرࣲ',
      'مُّدَّكِرٖۖ',
    ]) {
      expect(raLetter(lettersOf(text)), isNull, reason: text);
    }
  });

  test('naql targets tanween before a silent alif instead of that alif', () {
    for (final text in [
      'مَّرِيضًا',
      'صِيَامٍ',
      'صَدَقَةٍ',
      'مَرِيضٗا',
      'صِيَامٖ',
      'عَذَابٌ',
      'عَذَابٞ',
    ]) {
      final letters = lettersOf(text);
      final at = naqlLetter(letters, last: true)!;
      expect(RegExp('[ًٌٍٖٗٞ]').hasMatch(letters[at]), isTrue, reason: text);
    }
    expect(naqlLetter(lettersOf('وَلَقَدۡ'), last: true), 3);
    expect(naqlLetter([], last: true), isNull);
  });

  test('naql: the alef keeps the vowel of the hamza', () {
    expect(withNaqlVowel(madinahScript('ا۟خَرَۖ'), 'أُخَرَۚ'), 'اُخَرَۖ');
    expect(withNaqlVowel(madinahScript('ا۟جِيبُ'), 'أُجِيبُ'), 'اُجِيبُ');
    // Not a naql: unchanged.
    expect(withNaqlVowel('ءَامَنُواْ', 'ءَامَنُوٓاْ'), 'ءَامَنُواْ');
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
  test('badal after naql colours the madd ya, not the bare hamza seat', () {
    int? at(String w) => badalLetter(lettersOf(w));
    expect(lettersOf('بِالِايمَٰنِ')[at('بِالِايمَٰنِ')!], 'ي');
    // The alif itself is the madd after a fatha (اَ۬لَاخِرَةِ).
    expect(lettersOf('اَ۬لَاخِرَةِ')[at('اَ۬لَاخِرَةِ')!], 'ا');
  });

  test('the ya of the zawaid is the small one beside the word', () {
    expect(withSmallYa('ٱتَّبَعَنِى'), 'ٱتَّبَعَنِۦ');
    expect(withSmallYa('يَٰعِبَادِي'), 'يَٰعِبَادِۦ');
    expect(withSmallYa('يَٰعِبَادِے'), 'يَٰعِبَادِۦ');
    expect(withSmallYa('يُرِدۡنِىَ'), 'يُرِدۡنِۦَ');
    expect(withSmallYa('دُعَآئِى'), 'دُعَآءِۦ');
    expect(withSmallYa('نَبْغِىۚ'), 'نَبْغِۦۚ');
    expect(withSmallYa('دُعَآئِۦ'), 'دُعَآءِۦ');
    expect(withSmallYa('دُعَآئِۦ'), 'دُعَآءِۦ');
    // Already small, or no ya at all.
    expect(withSmallYa('تَرَنِۦ'), 'تَرَنِۦ');
    expect(withSmallYa('كِتَٰبِ'), 'كِتَٰبِ');
  });
}
