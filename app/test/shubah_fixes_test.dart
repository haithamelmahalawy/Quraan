import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

/// Shu'ba's readings the user reviewed (2026-11-15).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VariantRepository variants;
  late QuranRepository quran;
  setUpAll(() async {
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['shubah', 'khalaf_hamzah', 'duri_kisai']);
    quran = await QuranRepository.load();
  });

  List<Variant> against(int s, int a, int w) => compareReadings(
    repository: variants,
    ayah: quran.ayah(s, a),
    word: w,
    displayed: null,
    selected: {'shubah'},
  );

  // «ضَعۡفٖ ... ضَعۡفٗا» (الروم ٥٤): the book's quote of the three together was
  // drawn as each word; Hafs's words, read with the fatha alone.
  test('da\'f in al-Rum: Hafs\'s words, the fatha alone', () {
    for (final w in [4, 9, 16]) {
      final r = against(30, 54, w).single;
      expect(r.text, quran.ayah(30, 54).words[w], reason: '$w');
      expect(r.description, 'بفتح الضاد وجهًا واحدًا', reason: '$w');
      for (final id in ['shubah', 'khalaf_hamzah']) {
        for (final v in variants.at([id], 30, 54, w)) {
          expect(v.text, isNot(contains('»')), reason: '$id $w');
        }
      }
    }
  });

  // «مِن كُلِّ زَوۡجَيۡنِ» (المؤمنون ٢٧): the book's quote of Hafs, wrongly
  // without the tanween, hid Shu'ba's row; al-Ashab's as everyone's.
  test('kulli of al-Mu\'minun 27 against Hafs', () {
    expect(against(23, 27, 15).single.description, 'بكسر اللام دون تنوين');
    final shubah = variants.at(['shubah'], 23, 27, 15).single;
    for (final id in ['khalaf_hamzah', 'duri_kisai']) {
      final v = variants.at([id], 23, 27, 15).where((v) => !v.isUsul).single;
      expect(v.text, shubah.text, reason: id);
      expect(v.description, shubah.description, reason: id);
    }
  });

  // «ٱلۡمُصَيۡطِرُونَ» (الطور ٣٧): the sad alone, one way where Hafs reads two.
  test('al-musaytirun with the sad alone', () {
    final v = against(52, 37, 6).single;
    expect(v.text, 'ٱلۡمُصَيۡطِرُونَ');
    expect(v.text, isNot(contains('ۣ')));
    expect(v.description, 'بالصاد وجهًا واحدًا');
  });

  // «سُوٗى» (طه ٥٨): leaned at the stop alone, in the imala.
  test('suwan of Ta-Ha leaned at the stop', () {
    final v = variants.at(['shubah'], 20, 58, 13).single;
    expect(v.isUsul, isTrue);
    expect(v.isImala, isTrue);
    expect(v.stopOnly, isTrue);
    expect(v.text, contains('۪'));
  });
}
