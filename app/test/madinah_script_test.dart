import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';

void main() {
  test(
    'the Maghribi export drawn as Hafs writes what changes nothing read',
    () {
      // The Name's lam doubled, and the relative's.
      expect(madinahScript('لِلهِ'), 'لِل\u0651\u064Eهِ');
      expect(madinahScript('وَلِلهِ'), 'وَلِل\u0651\u064Eهِ');
      expect(madinahScript('اَ۬لذِے'), 'ٱل\u0651\u064Eذِى');
      expect(madinahScript('اَ۬لتِے'), 'ٱل\u0651\u064Eتِى');
      expect(madinahScript('فَاَ۬لذِينَ'), 'فَٱل\u0651\u064Eذِينَ');
      // The tanween before its alif.
      expect(madinahScript('نَاراٗ'), 'نَارٗا');
      expect(madinahScript('شَيْـٔاٗۖ'), 'شَيۡـٔٗاۖ');
      // The article's alif of wasl after a waw.
      expect(madinahScript('وَاَ۬للَّهُ'), 'وَٱللَّهُ');
      // The wasl's alif bare after a waw, fa or ba: the article, its naql, a
      // doubled or quiet letter, the nun hidden.
      expect(madinahScript('وَالنَّبِيٓـِٕـۧنَ'), 'وَٱلنَّبِيٓـِٕـۧنَ');
      expect(madinahScript('وَاتَّخَذُواْ'), 'وَٱتَّخَذُواْ');
      expect(madinahScript('وَالَارۡضِ'), 'وَٱلَارۡضِ');
      expect(madinahScript('فَانفَجَرَتۡ'), 'فَٱنفَجَرَتۡ');
      expect(madinahScript('فَانۢبَجَسَتۡ'), 'فَٱنۢبَجَسَتۡ');
      // A long alif after them stays: «وَالِدَيۡهِ».
      expect(madinahScript('وَالِدَيۡهِ'), 'وَالِدَيۡهِ');
      // A reading's marks stay: the shadda of «ٱلذِّكۡرَ», the eased hamza.
      expect(madinahScript('اَ۬لذِّكْرَ'), 'ٱلذِّكۡرَ');
      expect(madinahScript('ءَا۬ـٰمَنتُم'), 'ءَا۬ـٰمَنتُم');
      expect(madinahScript('وَاٰ۬مَنتُمُۥ'), 'وَاٰ۬مَنتُمُۥ');
    },
  );
}
