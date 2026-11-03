import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/hamza_replacement_mark.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';
import 'package:qiraat_mushaf/ui/quran_word_text.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';
import 'package:qiraat_mushaf/ui/theme.dart';
import 'package:qiraat_mushaf/ui/variant_sheet.dart';
import 'package:qiraat_mushaf/ui/reference_sheet.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';

import '../tool/build_warsh_usul.dart';
import '../tool/build_usul.dart' as usul_builder;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran, shamarly;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;

  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    shamarly = await QuranRepository.load(null, MushafEdition.shamarly);
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh', 'qunbul', 'susi', 'shubah', 'qalun']);
    mutashabihat = await MutashabihatRepository.load();
  });

  Variant rule(int s, int a, int w, String id) =>
      variants.at(['warsh'], s, a, w).singleWhere((v) => v.rule == id);

  test('a sakin hamza read as an alif follows the seat of the Hafs rasm', () {
    final warsh = jsonDecode(
      File('assets/data/reading_texts/warsh.json').readAsStringSync(),
    ) as Map;
    String word(int s, int a, int w) =>
        (warsh['ayahs'] as List).firstWhere((x) => x[0] == s && x[1] == a)[2][w]
            as String;
    // يَسۡتَأۡخِرُونَ, on an alif: a full alif.
    expect(word(7, 34, 7), 'يَسْتَاخِرُونَ');
    // يَسۡتَـٔۡخِرُونَ, on a kashida: a dagger alif.
    for (final (s, a, w) in [
      (10, 49, 18),
      (15, 5, 6),
      (16, 61, 19),
      (23, 43, 6),
    ]) {
      expect(word(s, a, w), 'يَسْتَٰخِرُونَ');
      expect(
        variants.at(['warsh'], s, a, w).any((v) => v.text.contains('ٰ')),
        isTrue,
      );
    }
  });

  test('أيحسبون and أيحسب tell the kasra of the sin beside their naql', () {
    for (final (s, a) in [(23, 55), (90, 5), (90, 7)]) {
      final at = variants.at(['warsh'], s, a, 0);
      expect(at.any((v) => v.description == 'بكسر السين'), isTrue);
      expect(at.any((v) => v.rule == 'naql'), isTrue);
    }
  });

  test('every eased أئ word has the tasheel dot and its usul row', () {
    for (final (s, a, w) in [
      (6, 19, 18),
      (26, 41, 5),
      (27, 55, 0),
      (27, 67, 7),
      (29, 29, 0),
      (36, 19, 3),
      (37, 36, 1),
      (37, 86, 0),
      (56, 47, 2),
    ]) {
      final text = variants.sourceTextAt('warsh', s, a, w)!;
      expect(text.contains('ىِ۪'), isTrue, reason: '$s:$a');
      expect(text.contains('ئ'), isFalse, reason: '$s:$a');
      final at = variants.at(['warsh'], s, a, w);
      expect(at.any((v) => v.rule == 'tasheel_word'), isTrue, reason: '$s:$a');
      expect(at.any((v) => v.rule == 'kharouf'), isFalse, reason: '$s:$a');
      expect(at.singleWhere((v) => v.rule == 'tasheel_word').usulWays, [
        'تحقيق الأولى وتسهيل الثانية بلا إدخال',
      ], reason: '$s:$a');
    }
  });

  test('أئن لنا has no farsh of the book at either word', () {
    for (final w in [5, 6]) {
      expect(
        variants.at(['warsh'], 26, 41, w).where((v) => v.inHamesh),
        isEmpty,
      );
    }
  });

  test('تراءا 26:61 has no badal and its taqlil on stopping only', () {
    final at = variants.at(['warsh'], 26, 61, 1);
    expect(at.any((v) => v.isBadal), isFalse);
    final v = at.single;
    expect(v.rule, 'taqlil_stop');
    expect(v.description, 'بتقليل الراء والهمزة وقفًا');
    expect(v.stopOnly, isTrue);
    expect(v.isStoppingTaqlil, isTrue);
    expect(v.isUsul, isTrue);
    expect(v.inHamesh, isFalse);
    // Written with its fatha in wasl, without the taqlil sign.
    expect(
      variants.sourceTextAt('warsh', 26, 61, 1)!.contains(imalaSign),
      isFalse,
    );
  });

  test(
    'the hamza of a lam-alif has no madd in Hafs or Warsh, its badal stays',
    () {
      for (final (s, a, w) in [(2, 4, 9), (26, 84, 5), (26, 103, 3)]) {
        expect(quran.ayah(s, a).words[w].contains('\u0623\u0653'), isFalse);
        expect(quran.ayah(s, a).words[w].contains('\u0623\u064e'), isTrue);
      }
      expect(
        variants.sourceTextAt('warsh', 26, 103, 3)!.contains('\u0623\u0653'),
        isFalse,
      );
      expect(variants.at(['warsh'], 26, 103, 3).any((v) => v.isBadal), isTrue);
      expect(variants.at(['warsh'], 26, 84, 5).any((v) => v.isBadal), isTrue);
    },
  );

  test('the hamza of a lam-alif with its madd unwritten is drawn apart', () {
    expect(HafsFontMarks.needsAdjustment('ٱلۡأَخِرَةِ'), isTrue);
    expect(HafsFontMarks.needsAdjustment('لَأَيَةٗ'), isTrue);
    // A sukun after it: the font's own lam-alif.
    expect(HafsFontMarks.needsAdjustment('ٱلۡأَرۡضِ'), isFalse);
  });

  test('قالا has no hamza, so no naql and no colour', () {
    for (final (s, a, w) in [(7, 23, 0), (20, 45, 0), (27, 15, 5)]) {
      expect(variants.at(['warsh'], s, a, w), isEmpty, reason: '$s:$a');
    }
  });

  test('ءالله and ءالذكرين are told in مد الفرق, written as Hafs', () {
    for (final (s, a, w) in [
      (6, 143, 9),
      (6, 144, 7),
      (10, 59, 13),
      (27, 59, 8),
    ]) {
      final v = variants.at(['warsh'], s, a, w).single;
      expect(v.rule, 'hamza_wasl', reason: '$s:$a');
      expect(v.usulWays, hasLength(2), reason: '$s:$a');
      expect(v.text, isEmpty, reason: '$s:$a');
      expect(
        variants.sourceTextAt('warsh', s, a, w),
        quran.ayah(s, a).words[w],
        reason: '$s:$a',
      );
    }
  });

  test('أءله and أءذا after a naql: an alif with the fatha, then the dot', () {
    expect(
      HafsFontMarks.needsAdjustment(
        '\u0627\u064e\u06df\u0644\u064e\u0670\u0647\u065e',
      ),
      isTrue,
    );
    expect(
      variants.at(['warsh'], 37, 16, 0).any((v) => v.rule == 'tasheel_word'),
      isTrue,
    );
    expect(
      variants.at(['warsh'], 27, 61, 14).any((v) => v.rule == 'tasheel_word'),
      isTrue,
    );
    expect(
      variants.at(['warsh'], 27, 61, 14).any((v) => v.rule == 'naql'),
      isTrue,
    );
  });

  test('أءله after a naql keeps its alif, wasl words keep their wasla', () {
    expect(
      variants
          .sourceTextAt('warsh', 27, 61, 14)!
          .startsWith('\u0627\u064e\u06df'),
      isTrue,
    );
    expect(
      madinahScript(
        '\u0627\u064f\u06df\u0639\u0652\u0628\u064f\u062f\u064f\u0648\u0627\u0652',
      ).startsWith('\u0671'),
      isTrue,
    );
  });

  test('كل ءاتوه 27:87 has its naql and its madd al-badal', () {
    final at = variants.at(['warsh'], 27, 87, 16);
    expect(at.any((v) => v.rule == 'naql'), isTrue);
    expect(at.any((v) => v.isBadal), isTrue);
  });

  test('the muqattaat with nothing told are written as Hafs writes them', () {
    for (final (s, a) in [
      (2, 1),
      (3, 1),
      (7, 1),
      (26, 1),
      (27, 1),
      (28, 1),
      (29, 1),
      (30, 1),
      (31, 1),
      (32, 1),
      (38, 1),
      (42, 2),
      (50, 1),
    ]) {
      expect(
        variants.sourceTextAt('warsh', s, a, 0),
        quran.ayah(s, a).words[0],
        reason: '$s:$a',
      );
      expect(variants.at(['warsh'], s, a, 0), isEmpty, reason: '$s:$a');
    }
  });

  test('أساءوا السوأى 30:10 has no badal, the other words of the ayah do', () {
    expect(variants.at(['warsh'], 30, 10, 4), isEmpty);
    expect(variants.at(['warsh'], 30, 10, 8).any((v) => v.isBadal), isTrue);
    expect(variants.at(['warsh'], 30, 10, 12).any((v) => v.isBadal), isTrue);
  });

  test('بلقاء and ولقاء 30:8, 30:16 are written as Hafs, nothing told', () {
    for (final (a, w) in [(8, 19), (16, 5)]) {
      final hafs = quran.ayah(30, a).words[w];
      expect(hafs, contains('يٕ'), reason: '$a');
      expect(variants.sourceTextAt('warsh', 30, a, w), hafs, reason: '$a');
      expect(variants.at(['warsh'], 30, a, w), isEmpty, reason: '$a');
    }
  });

  test('لتربوا 30:39 tells its ta, its damma and its sakin waw', () {
    expect(
      variants.at(['warsh'], 30, 39, 4).single.description,
      'بالتاء وضمها وإسكان الواو',
    );
  });

  test('a ya or waw after a merging nun has no shadda, as in Hafs', () {
    for (final (s, a, w) in [
      (2, 8, 3),
      (2, 26, 5),
      (2, 107, 14),
      (6, 59, 15),
    ]) {
      expect(
        variants
            .sourceTextAt('warsh', s, a, w)!
            .startsWith(RegExp('[\u064a\u0648][\u064e\u064f\u0650]?\u0651')),
        isFalse,
        reason: '$s:$a',
      );
    }
    // Warsh's own idgham keeps its shadda: قَد ضَّلَّ.
    expect(
      variants
          .sourceTextAt('warsh', 2, 108, 15)!
          .startsWith(RegExp('ض[\u064e\u0651]{2}')),
      isTrue,
    );
    expect(variants.at(['warsh'], 10, 35, 24).single.description, 'بالتقليل');
    expect(
      variants.at(['warsh'], 3, 111, 1).single.description,
      'بصلة ميم الجمع',
    );
  });

  test('ورءا المجرمون and تبوءو الدار have no badal before the wasl', () {
    expect(variants.at(['warsh'], 18, 53, 0), isEmpty);
    expect(variants.at(['warsh'], 59, 9, 1), isEmpty);
    expect(variants.at(['warsh'], 59, 9, 3).any((v) => v.isBadal), isTrue);
  });

  test('هلك 69:29 has no shadda, مالية before it its sukun', () {
    expect(
      variants.sourceTextAt('warsh', 69, 29, 0)!.contains('\u0651'),
      isFalse,
    );
    expect(
      variants.sourceTextAt('warsh', 69, 28, 3)!.endsWith('\u0647\u06e1\u06dc'),
      isTrue,
    );
  });

  test(
    'تظهرون 33:4 tells its reading, اللائي has its dagger alif and madd',
    () {
      expect(
        variants
            .at(['warsh'], 33, 4, 12)
            .firstWhere((v) => !v.isUsul)
            .description,
        'بفتح التاء وتشديد الظاء وحذف الألف وتشديد الهاء مع فتحها',
      );
      for (final (s, a, w) in [
        (33, 4, 11),
        (58, 2, 11),
        (65, 4, 0),
        (65, 4, 11),
      ]) {
        expect(
          variants.sourceTextAt('warsh', s, a, w),
          contains('\u0644\u0640\u0670\u0653'),
          reason: '$s:$a',
        );
      }
    },
  );

  test(
    'لأتوها 33:14 keeps its hamza over the alif, tells the dropped madd',
    () {
      final text = variants.sourceTextAt('warsh', 33, 14, 8)!;
      expect(text, contains('\u200c'));
      expect(HafsFontMarks.needsAdjustment(text), isFalse);
      expect(
        HafsFontMarks.needsAdjustment(quran.ayah(33, 14).words[8]),
        isTrue,
      );
      expect(
        variants.at(['warsh'], 33, 14, 8).single.description,
        'بحذف المد الطبيعي بعد الهمزة',
      );
    },
  );

  test('أبناء أخواتهن 33:55 is the usul of its hamza, no farsh', () {
    for (final w in [13, 14]) {
      expect(
        variants.at(['warsh'], 33, 55, w).where((v) => !v.isUsul || v.inHamesh),
        isEmpty,
      );
    }
    expect(variants.at(['warsh'], 33, 55, 14).single.rule, 'ibdal_ya');
  });

  test('أليم 34:5, 45:11 tells its tanween with kasra beside its naql', () {
    for (final (s, a) in [(34, 5), (45, 11)]) {
      final at = variants.at(['warsh'], s, a, 10);
      expect(
        at.where((v) => v.description == 'بالتنوين بالكسر').single.inHamesh,
        isTrue,
        reason: '$s:$a',
      );
      expect(at.any((v) => v.rule == 'naql'), isTrue, reason: '$s:$a');
    }
  });

  test('يجازى 34:17 is farsh told in the hamesh, not in the taqlil usul', () {
    final at = variants.at(['warsh'], 34, 17, 5);
    final v = at.firstWhere((v) => !v.isUsul);
    expect(at.singleWhere((v) => v.isUsul).description, 'بالتقليل بخلف');
    expect(v.description, 'بالياء وتقليل الزاي وإبدال الياء ألفًا مقصورة');
    expect(v.isUsul, isFalse);
    expect(v.inHamesh, isTrue);
  });

  test('يشاء إن 35:1 is told in the usul of two hamzas, no farsh', () {
    for (final w in [17, 18]) {
      expect(
        variants.at(['warsh'], 35, 1, w).where((v) => v.inHamesh),
        isEmpty,
      );
    }
    expect(variants.at(['warsh'], 35, 1, 18).single.rule, 'ibdal_waw');
  });

  test('والبغضاء إلى and جاء أمة are only their usul, no farsh', () {
    for (final (a, w) in [(5, 64), (23, 44)]) {
      expect(
        variants
            .at(['warsh'], a, w, a == 5 ? 29 : 6)
            .where((v) => v.rule == 'kharouf'),
        isEmpty,
        reason: '$a:$w',
      );
    }
  });

  test('يس والقرآن is one farsh shaded on its two words, told once', () {
    final first = variants.at(['warsh'], 36, 1, 0).single;
    final second = variants.at(['warsh'], 36, 2, 0).single;
    // Its idgham told, يس is still written as Hafs writes it.
    expect(
      variants.sourceTextAt('warsh', 36, 1, 0),
      quran.ayah(36, 1).words[0],
    );
    for (final v in [first, second]) {
      expect(v.inHamesh, isTrue);
      expect(v.usulText, 'يسٓ وَٱلۡقُرۡءَانِ');
    }
    expect(first.description, second.description);
    expect(first.description, 'بإدغام النون من «يس» في واو «والقرآن»');
  });

  test('a ya zaida the book only quotes (لترديني) has no farsh', () {
    for (final (surah, ayah, word) in [
      (18, 24, 11),
      (28, 34, 13),
      (34, 45, 13),
      (37, 56, 4),
      (44, 20, 5),
      (44, 21, 4),
    ]) {
      final at = variants.at(['warsh'], surah, ayah, word);
      expect(at.map((v) => v.rule), ['ya_zaida'], reason: '$surah:$ayah');
      expect(at.single.inHamesh, isFalse, reason: '$surah:$ayah');
    }
  });

  test('the eased hamza that had a damma is no hamzat wasl after a naql', () {
    for (final word in ['اَ۟نزِلَ', 'اَ۟لْقِيَ', 'اَ۟شْهِدُواْ']) {
      expect(madinahScript(word), startsWith('اَ۟'));
      expect(
        HafsFontMarks.needsAdjustment(madinahScript(word)),
        isTrue,
        reason: word,
      );
    }
    // A hamzat wasl with the same vowel stays one.
    expect(madinahScript('اَ۟نظُرْ'), isNot(contains('۟')));
  });

  test('عذاب اركض in the usul, سخريا in the hamesh', () {
    final tanween = variants.at(['warsh'], 38, 41, 10).single;
    expect(tanween.rule, 'first_sakin');
    expect(tanween.isUsul, isTrue);
    expect(variants.sourceTextAt('warsh', 38, 41, 10), 'وَعَذَابٍ');
    final at = variants.at(['warsh'], 38, 63, 1);
    final farsh = at.singleWhere((v) => v.inHamesh);
    expect(farsh.description, 'بضم السين');
    expect(farsh.text, startsWith('سُ'));
    expect(at.singleWhere((v) => v.rule == 'naql_source').text, isEmpty);
  });

  test('حين 38:88 is written as Hafs writes it, its iqlab mim, no farsh', () {
    expect(
      variants.sourceTextAt('warsh', 38, 88, 3),
      quran.ayah(38, 88).words[3],
    );
    expect(variants.at(['warsh'], 38, 88, 3), isEmpty);
  });

  test('جزاء 39:34 is written as Hafs writes it, no farsh', () {
    expect(
      variants.sourceTextAt('warsh', 39, 34, 6),
      quran.ayah(39, 34).words[6],
    );
    expect(variants.at(['warsh'], 39, 34, 6), isEmpty);
  });

  test('تأمروني 39:64 is told in the hamesh, its ibdal still in the usul', () {
    final at = variants.at(['warsh'], 39, 64, 3);
    final farsh = at.singleWhere((v) => v.inHamesh);
    expect(farsh.description, 'بتخفيف النون وفتح الياء مع إبدال الهمزة ألفًا');
    expect(farsh.text, 'تَامُرُونِيَ');
    expect(at.singleWhere((v) => v.rule == 'ibdal_single').text, isEmpty);
  });

  test('وجاىء 39:69 and 89:23 are written as Hafs writes them, no farsh', () {
    for (final (surah, ayah, word) in [(39, 69, 6), (89, 23, 0)]) {
      expect(
        variants.sourceTextAt('warsh', surah, ayah, word),
        quran.ayah(surah, ayah).words[word],
      );
      expect(variants.at(['warsh'], surah, ayah, word), isEmpty);
    }
  });

  test('the dagger alif of الغفار 40:42 is drawn apart from its shadda', () {
    final word = madinahScript(variants.sourceTextAt('warsh', 40, 42, 14)!);
    expect(HafsFontMarks.needsAdjustment(word), isTrue);
    // Only with the imala sign: Hafs\'s and the others\' stay with the font.
    expect(
      HafsFontMarks.needsAdjustment(quran.ayah(40, 42).words[14]),
      isFalse,
    );
  });

  test('ونئا 41:51 is taqlil with its other face, بجانبه nothing at all', () {
    final at = variants.at(['warsh'], 41, 51, 5);
    expect(at.where((v) => v.inHamesh), isEmpty);
    final taqlil = at.singleWhere((v) => v.isImala);
    expect(taqlil.description, 'بالتقليل بخلف');
    expect(taqlil.count, 1);
    expect(at.where((v) => v.isBadal), hasLength(1));
    expect(variants.at(['warsh'], 41, 51, 6), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 41, 51, 6),
      quran.ayah(41, 51).words[6],
    );
  });

  test('وراء 42:51 is written as Hafs writes it, with nothing told', () {
    expect(variants.at(['warsh'], 42, 51, 10), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 42, 51, 10),
      quran.ayah(42, 51).words[10],
    );
  });

  test('ينشؤا 43:18 has a fatha on its ya, no shadda', () {
    final word = variants.sourceTextAt('warsh', 43, 18, 1)!;
    expect(word, 'يَنشَؤُاْ');
    expect(word, isNot(contains('\u0651')));
  });

  test('أشهدوا 43:19 is in the usul of two hamzas, its second eased', () {
    final at = variants.at(['warsh'], 43, 19, 7);
    expect(
      at.singleWhere((v) => v.rule == 'tasheel_word').description,
      'بتحقيق الأولى وتسهيل الثانية بلا إدخال',
    );
    expect(at.where((v) => v.rule == 'naql'), hasLength(1));
  });

  test('ءآلهتنا 43:58 and السماء إله 43:84 are told in the usul only', () {
    for (final (surah, ayah, word) in [(43, 58, 1), (43, 84, 4)]) {
      expect(
        variants.at(['warsh'], surah, ayah, word).where((v) => v.inHamesh),
        isEmpty,
        reason: '$surah:$ayah',
      );
    }
    expect(
      variants.at(['warsh'], 43, 58, 1).map((v) => v.rule),
      containsAll(['badal', 'tasheel_word']),
    );
    expect(variants.at(['warsh'], 43, 84, 4).single.rule, 'tasheel_pair');
  });

  test('جدلا 43:58 is written as Hafs writes it, no farsh', () {
    expect(variants.at(['warsh'], 43, 58, 9), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 43, 58, 9),
      quran.ayah(43, 58).words[9],
    );
  });

  test('فاسر has the wasl sign over its alif', () {
    for (final (surah, ayah, word) in [(11, 81, 8), (15, 65, 0), (44, 23, 0)]) {
      expect(
        variants.sourceTextAt('warsh', surah, ayah, word),
        startsWith('فَٱس'),
        reason: '$surah:$ayah',
      );
      expect(
        variants.at(['warsh'], surah, ayah, word).single.text,
        startsWith('فَٱس'),
        reason: '$surah:$ayah',
      );
    }
  });

  test('ألقي 54:25 and أئنكم 41:9 share the one wording of easing alone', () {
    for (final (surah, ayah, word) in [(54, 25, 0), (41, 9, 1)]) {
      final v = variants
          .at(['warsh'], surah, ayah, word)
          .singleWhere((v) => v.rule == 'tasheel_word');
      expect(v.description, 'بتحقيق الأولى وتسهيل الثانية بلا إدخال');
      expect(v.usulWays, ['تحقيق الأولى وتسهيل الثانية بلا إدخال']);
    }
    expect(
      variants
          .allOf('warsh')
          .where((v) => v.description == 'بتسهيل الهمزة الثانية بلا إدخال'),
      isEmpty,
    );
    expect(
      variants
          .allOf('warsh')
          .where(
            (v) => v.description == 'بتحقيق الأولى وتسهيل الثانية بلا إدخال',
          ),
      hasLength(37),
    );
  });

  test('السماء أن 22:65 is told in the usul only', () {
    for (final w in [15, 16]) {
      expect(
        variants.at(['warsh'], 22, 65, w).where((v) => v.inHamesh),
        isEmpty,
      );
    }
    expect(variants.at(['warsh'], 22, 65, 16).single.rule, 'tasheel_pair');
  });

  test('the tanween before a damma of wasl across ayahs is told', () {
    for (final (surah, ayah, word) in [
      (4, 49, 13),
      (12, 8, 14),
      (15, 45, 4),
      (17, 20, 11),
      (17, 47, 18),
      (25, 8, 16),
      (38, 41, 10),
    ]) {
      // In the usul «التقاء الساكنين», as for all who read it so.
      final v = variants
          .at(['warsh'], surah, ayah, word)
          .singleWhere((v) => v.rule == 'first_sakin');
      expect(
        v.description,
        'بضم نون التنوين وصلاً لالتقاء الساكنين',
        reason: '$surah:$ayah',
      );
      expect(v.isUsul, isTrue, reason: '$surah:$ayah');
    }
  });

  test('ونئا 17:83 is taqlil with its other face', () {
    final v = variants.at(['warsh'], 17, 83, 5).singleWhere((v) => v.isImala);
    expect(v.description, 'بالتقليل بخلف');
  });

  test('بأييد 51:47 is written as Hafs writes it, with nothing told', () {
    expect(variants.at(['warsh'], 51, 47, 2), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 51, 47, 2),
      quran.ayah(51, 47).words[2],
    );
  });

  test('امرئ 52:21 is written as Hafs writes it, with nothing told', () {
    expect(variants.at(['warsh'], 52, 21, 15), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 52, 21, 15),
      quran.ayah(52, 21).words[15],
    );
    expect(HafsFontMarks.needsAdjustment(quran.ayah(52, 21).words[15]), isTrue);
  });

  test('every sajda of Warsh is where Hafs marks it', () {
    var count = 0;
    for (var p = 1; p <= 604; p++) {
      for (final a in quran.page(p)) {
        for (var w = 0; w < a.words.length; w++) {
          final own = variants.sourceTextAt('warsh', a.surah, a.number, w)!;
          expect(
            own.contains('۩'),
            a.words[w].contains('۩'),
            reason: '${a.surah}:${a.number}:$w',
          );
          if (own.contains('۩')) count++;
        }
      }
    }
    expect(count, 15);
  });

  test('اللؤلؤ 55:22 is written as Hafs writes it, with nothing told', () {
    expect(variants.at(['warsh'], 55, 22, 2), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 55, 22, 2),
      quran.ayah(55, 22).words[2],
    );
  });

  test('المنشئات 55:24 is written as Hafs writes it, with its badal only', () {
    expect(variants.at(['warsh'], 55, 24, 2).single.rule, 'badal');
    expect(
      variants.sourceTextAt('warsh', 55, 24, 2),
      quran.ayah(55, 24).words[2],
    );
  });

  test('وجنى 55:54 is written as Hafs writes it, its taqlil on stopping', () {
    expect(variants.at(['warsh'], 55, 54, 6).single.rule, 'taqlil_stop');
    expect(
      variants.sourceTextAt('warsh', 55, 54, 6),
      quran.ayah(55, 54).words[6],
    );
  });

  test('the badal of أوءاباؤنا is the alif after its second hamza', () {
    final letters = lettersOf(quran.ayah(56, 48).words[0]);
    final at = badalLetter(letters)!;
    expect(letters[at], 'ا');
    expect(letters[at - 1], startsWith('ء'));
  });

  test('أوءاباؤنا 37:17 is one word, as at 56:48', () {
    expect(
      variants.sourceTextAt('warsh', 37, 17, 0),
      variants.sourceTextAt('warsh', 56, 48, 0),
    );
    expect(variants.sourceTextAt('warsh', 37, 17, 0), isNot(contains(' ')));
  });

  test('يظهرون 58:2 and 58:3 tell their farsh in the hamesh', () {
    for (final ayah in [2, 3]) {
      final v = variants
          .at(['warsh'], 58, ayah, 1)
          .singleWhere((v) => v.inHamesh);
      expect(
        v.description,
        'بفتح الياء وتشديد الظاء وحذف الألف وتشديد الهاء مع فتحها',
      );
    }
  });

  test('ماليه 69:28 has the sakt, as Hafs writes it', () {
    final word = madinahScript(variants.sourceTextAt('warsh', 69, 28, 3)!);
    expect(word, quran.ayah(69, 28).words[3]);
    expect(HafsFontMarks.needsAdjustment(word), isTrue);
  });

  test('وألو 72:16 is as Hafs writes it, قال 72:20 with a dagger alif', () {
    expect(variants.at(['warsh'], 72, 16, 0), isEmpty);
    expect(
      variants.sourceTextAt('warsh', 72, 16, 0),
      quran.ayah(72, 16).words[0],
    );
    const said = '\u0642\u064e\u0670\u0644\u064e';
    expect(variants.sourceTextAt('warsh', 72, 20, 0), said);
    expect(variants.at(['warsh'], 72, 20, 0).single.text, said);
  });

  test(
    'no badal is coloured on a letter with its own vowel after the hamza',
    () {
      final hamza = RegExp('[ءأإؤئإٓٔ]');
      final vowel = RegExp('[َُِ]');
      final wrong = <String>[];
      for (final v in variants.allOf('warsh').where((v) => v.isBadal)) {
        final hafs = quran.ayah(v.surah, v.ayah).words[v.word];
        for (final word in [
          hafs,
          madinahScript(
            variants.sourceTextAt('warsh', v.surah, v.ayah, v.word)!,
          ),
        ]) {
          final letters = lettersOf(word);
          if (!letters.any((l) => hamza.hasMatch(l))) continue;
          final at = badalLetter(letters);
          if (at == null) continue;
          final l = letters[at];
          if ('وي'.contains(l[0]) && vowel.hasMatch(l) && !hamza.hasMatch(l)) {
            wrong.add('${v.surah}:${v.ayah}:${v.word} $word');
          }
        }
      }
      expect(wrong, isEmpty);
      // لِأَيَٰتِنَا: the alif of the lam-alif, with its hamza.
      final letters = lettersOf(quran.ayah(74, 16).words[3]);
      expect(letters[badalLetter(letters)!], startsWith('أ'));
    },
  );

  test('هو 57:24: those who leave it out are told alike', () async {
    const ids = [
      'warsh',
      'qalun',
      'hisham',
      'ibn_dhakwan',
      'ibn_wardan',
      'ibn_jammaz',
    ];
    await variants.ensureLoaded(ids);
    for (final id in ids) {
      final v = variants.at([id], 57, 24, 9).single;
      expect(v.description, 'بحذف هو', reason: id);
      expect(v.count, 3, reason: id);
      expect(variants.at([id], 57, 24, 8), isEmpty, reason: id);
    }
    final keys = {
      for (final id in ids)
        readingVariantKey(
          variants.at([id], 57, 24, 9).single,
          baseline: quran.ayah(57, 24).words.sublist(9, 12).join(' '),
        ),
    };
    expect(keys, hasLength(1));
  });

  test('نذرا 77:6 tells its damma, بشرر 77:32 only its tarqiq', () {
    final at = variants.at(['warsh'], 77, 6, 2);
    expect(at.singleWhere((v) => v.inHamesh).description, 'بضم الذال');
    expect(at.singleWhere((v) => v.rule == 'naql_source').text, isEmpty);
    expect(variants.at(['warsh'], 77, 6, 1).where((v) => v.inHamesh), isEmpty);
    final ra = variants.at(['warsh'], 77, 32, 2).single;
    expect(ra.rule, 'tarqiq');
    expect(ra.inHamesh, isFalse);
  });

  test('the stop sign of بلى is drawn apart from its madd', () {
    expect(HafsFontMarks.needsAdjustment(quran.ayah(84, 15).words[0]), isTrue);
    expect(
      HafsFontMarks.needsAdjustment(
        madinahScript(variants.sourceTextAt('warsh', 84, 15, 0)!),
      ),
      isTrue,
    );
  });

  test('فحدث ألم 93:11 is a naql across the surahs, no farsh', () {
    final source = variants.at(['warsh'], 93, 11, 3).single;
    expect(source.rule, 'naql_source');
    expect(source.inHamesh, isFalse);
    final naql = variants.at(['warsh'], 94, 1, 0).single;
    expect(naql.rule, 'naql');
    expect(naql.inHamesh, isFalse);
  });

  test('واقترب 96:19 is a naql into إنا, with its sajda, no farsh', () {
    final source = variants.at(['warsh'], 96, 19, 4).single;
    expect(source.rule, 'naql_source');
    expect(source.inHamesh, isFalse);
    expect(variants.sourceTextAt('warsh', 96, 19, 4), endsWith('۩'));
    expect(variants.at(['warsh'], 97, 1, 0).single.rule, 'naql');
  });

  test('البريئة 98:6 and 98:7 have the hamza on a kashida after the madd', () {
    for (final (a, w) in [(6, 15), (7, 8)]) {
      final v = variants.at(['warsh'], 98, a, w).single;
      expect(v.description, 'بتخفيف الياء مع المد ثم همزة');
      expect(v.inHamesh, isTrue);
      expect(v.text, contains('\u064a\u0653\u0640\u064e\u0654'));
      expect(
        variants.sourceTextAt('warsh', 98, a, w),
        contains('\u064a\u0653\u0640\u064e\u0654'),
      );
    }
  });

  test('صلواتهم 23:9 has only the taghliz, the book\'s note adds no farsh', () {
    final at = variants.at(['warsh'], 23, 9, 3);
    expect(at.map((v) => v.rule), ['taghliz']);
    expect(at.single.isUsul, isTrue);
  });

  test(
    'every Warsh naql after tanween links both words throughout the Quran',
    () {
      var checked = 0;
      for (final surah in quran.surahs) {
        String? previous;
        Ayah? previousAyah;
        var previousWord = 0;
        for (var a = 1; a <= surah.ayahCount; a++) {
          final ayah = quran.ayah(surah.number, a);
          for (final (w, text) in ayah.words.indexed) {
            final boundary = variants
                .at(['warsh'], surah.number, a, w)
                .any(
                  (v) =>
                      v.rule == 'naql' &&
                      v.description.startsWith(
                        'بنقل حركة الهمزة إلى الساكن قبلها',
                      ),
                );
            if (boundary &&
                previous != null &&
                RegExp(r'[ًٌٍٖٗٞ][اى]?[ۖ-ۭ]*$').hasMatch(previous)) {
              final source = variants
                  .at(
                    ['warsh'],
                    surah.number,
                    previousAyah!.number,
                    previousWord,
                  )
                  .where((v) => v.rule == 'naql_source');
              expect(
                source,
                hasLength(1),
                reason: '${surah.number}:$a:$w after $previous',
              );
              expect(source.single.inHamesh, isFalse);
              checked++;
            }
            previous = text;
            previousAyah = ayah;
            previousWord = w;
          }
        }
      }
      expect(checked, greaterThan(1000));
    },
  );

  test(
    'Warsh tarqiq excludes kasratan and preserves open ra in both scripts',
    () {
      for (final word in [
        'خَيۡرٖ',
        'خَيْرٍ',
        'كَثِيرٖ',
        'بَصِيرٍ',
        'مُّدَّكِرٖ',
      ]) {
        expect(usul_builder.hasTarqiq(word), isFalse, reason: word);
      }
      for (final word in ['خَيۡرَ', 'خَيۡرٗا', 'خَيۡرًا', 'خَيۡرٌ']) {
        expect(usul_builder.hasTarqiq(word), isTrue, reason: word);
      }
      expect(
        variants.at(['warsh'], 2, 197, 18).any((v) => v.rule == 'tarqiq'),
        isFalse,
      );
      expect(rule(2, 197, 23, 'tarqiq').isUsul, isTrue);
      expect(rule(2, 158, 19, 'tarqiq').isUsul, isTrue);
      final ghayr = variants.at(['warsh'], 13, 4, 10).toList();
      expect(ghayr.any((v) => v.rule == 'tarqiq'), isFalse);
      expect(
        ghayr.any((v) => v.inHamesh),
        isTrue,
        reason: 'The independent genitive farsh must survive.',
      );
      var checked = 0;
      for (final surah in quran.surahs) {
        for (var a = 1; a <= surah.ayahCount; a++) {
          final ayah = quran.ayah(surah.number, a);
          for (final (w, text) in ayah.words.indexed) {
            final source =
                variants.sourceTextAt('warsh', surah.number, a, w) ?? text;
            final letters = lettersOf(madinahScript(source));
            if (letters.any(
                  (l) => l.startsWith('ر') && RegExp('[ٍࣲِٖ]').hasMatch(l),
                ) &&
                raLetter(letters) == null) {
              expect(
                variants
                    .at(['warsh'], surah.number, a, w)
                    .any((v) => v.rule == 'tarqiq'),
                isFalse,
                reason: '${surah.number}:$a:$w $source',
              );
              checked++;
            }
          }
        }
      }
      expect(checked, greaterThan(100));
    },
  );

  test(
    'nunshiruha retains its lexical reading and gains tarqiq after the change',
    () {
      expect(hasWarshTarqiq('نُنشِزُهَا'), isFalse);
      expect(hasWarshTarqiq('نُنۡشِرُهَا'), isTrue);
      expect(rule(2, 259, 52, 'tarqiq').isUsul, isTrue);
      expect(
        variants
            .at(['warsh'], 2, 259, 52)
            .any((v) => v.inHamesh && v.text.contains('ر')),
        isTrue,
      );
    },
  );

  test('falan on page 29 has naql as well as badal', () {
    expect(quran.pageOf(2, 187), 29);
    final naql = rule(2, 187, 23, 'naql');
    expect(naql.description, contains('نقل حركة الهمزة إلى اللام'));
    expect(naql.text, 'فَالَٰنَ');
    expect(naql.isUsul, isTrue);
    expect(rule(2, 187, 23, 'badal').isBadal, isTrue);
    expect(variants.at(['warsh'], 2, 187, 23).every((v) => v.isUsul), isTrue);
  });

  test('laraufun on page 268 is madd al-badal only, no farsh', () {
    expect(quran.pageOf(16, 7), 268);
    for (final (a, w) in [(7, 12), (47, 6)]) {
      final readings = variants.at(['warsh'], 16, a, w).toList();
      expect(readings.single.rule, 'badal', reason: '16:$a:$w');
      expect(readings.single.isUsul, isTrue);
    }
  });

  test('yuhda on page 271 is one farsh with its description', () {
    expect(quran.pageOf(16, 37), 271);
    final farsh = {
      for (final w in [6, 7])
        ...variants.at(['warsh'], 16, 37, w).where((v) => !v.isUsul),
    };
    expect(farsh.single.description, 'بضم الياء وإبدال الياء ألفًا مقصورة');
  });

  test('yuha on page 272 is farsh with its description', () {
    expect(quran.pageOf(16, 43), 272);
    for (final (s, a, w) in [
      (12, 109, 6),
      (16, 43, 6),
      (21, 7, 5),
      (21, 25, 7),
    ]) {
      final farsh = variants.at(['warsh'], s, a, w).where((v) => !v.isUsul);
      expect(
        farsh.single.description,
        'بالياء وتقليل الحاء وإبدال الياء ألفًا مقصورة مع المد',
      );
      // Not told again with the imala of the usul below the page.
      expect(farsh.single.inHamesh, isTrue);
    }
  });

  test('afaraayta on page 311 is usul with two faces beside its naql', () {
    expect(quran.pageOf(19, 77), 311);
    final readings = variants.at(['warsh'], 19, 77, 0).toList();
    expect(
      readings.singleWhere((v) => v.rule == 'tasheel_word').description,
      'بوجهين: تسهيل الهمزة الثانية، أو إبدالها ألفًا خالصة مع المد المشبع للساكنين وصلاً فقط',
    );
    expect(readings.where((v) => v.rule == 'naql'), hasLength(1));
    expect(readings.where((v) => v.inHamesh), isEmpty);
  });

  test('ash-shafaa has no farsh and the shin doubled as in Hafs', () {
    for (final (s, a, w) in [(19, 87, 2), (20, 109, 3), (34, 23, 2)]) {
      expect(variants.at(['warsh'], s, a, w).where((v) => !v.isUsul), isEmpty);
      expect(
        variants.sourceTextAt('warsh', s, a, w),
        contains('\u0644\u0634\u0651\u064e'),
      );
    }
  });

  test('taha on page 312 is the taqlil of the ha in the usul', () {
    expect(quran.pageOf(20, 1), 312);
    final reading = variants.at(['warsh'], 20, 1, 0).single;
    expect(reading.isUsul, isTrue);
    expect(reading.description, 'بتقليل الهاء');
    expect(reading.isImala, isTrue);
  });

  test('an isri on page 317 is one farsh, not in the hamza usul', () {
    expect(quran.pageOf(20, 77), 317);
    for (final w in [4, 5]) {
      final reading = variants.at(['warsh'], 20, 77, w).single;
      expect(reading.isUsul, isFalse);
      expect(reading.count, 2);
      expect(
        reading.description,
        'بوصل الهمزة، ويلزم منه كسر النون وصلاً، والابتداء بهمزة مكسورة',
      );
    }
  });

  test('fa-sri and an isri are farsh of the hamzat wasl everywhere', () {
    for (final (s, a, w, n) in [
      (11, 81, 8, 1),
      (15, 65, 0, 1),
      (44, 23, 0, 1),
      (26, 52, 3, 2),
    ]) {
      final reading = variants.at(['warsh'], s, a, w).single;
      expect(reading.isUsul, isFalse, reason: '$s:$a');
      expect(reading.count, n);
      expect(reading.description, startsWith('بوصل الهمزة'));
    }
  });

  test('dhikran, wizran and their bab show both faces of the ra', () {
    for (final (s, a, w) in [(20, 99, 12), (20, 100, 7), (18, 90, 0)]) {
      final words = quran.ayah(s, a).words;
      final i = s == 18 ? words.indexWhere((t) => t.contains('سِتۡر')) : w;
      final reading = rule(s, i >= 0 ? a : a, i, 'tarqiq');
      expect(reading.description, 'بوجهين: تفخيم الراء وترقيقها');
      expect(reading.usulWays, ['تفخيم الراء', 'ترقيق الراء']);
    }
  });

  test('aimmatan draws the easing dot in place of the second hamza', () {
    for (final (s, a, w) in [
      (21, 73, 1),
      (28, 5, 9),
      (28, 41, 1),
      (32, 24, 2),
    ]) {
      expect(
        variants.sourceTextAt('warsh', s, a, w),
        '\u0623\u064e\u0649\u0650\u06ea\u0645\u0651\u064e\u0629\u0657',
      );
    }
  });

  test('yuakhidhu on page 273 is the ibdal usul only, no farsh', () {
    expect(quran.pageOf(16, 61), 273);
    final readings = variants.at(['warsh'], 16, 61, 1).toList();
    expect(readings.single.rule, 'ibdal_single');
  });

  test('extra ya is an independent usul with wasl and waqf faces', () {
    for (final w in [8, 10]) {
      final readings = variants.at(['warsh'], 2, 186, w).toList();
      final ya = readings.singleWhere((v) => v.rule == 'ya_zaida');
      expect(ya.isUsul, isTrue);
      expect(ya.description, 'بإثبات الياء الزائدة وصلاً وحذفها وقفًا');
      expect(readings.any((v) => v.description.contains('هاء')), isFalse);
      expect(readings.any((v) => v.inHamesh), isFalse);
    }
  });

  test(
    'yartadid retains the two dal reading without shared idgham in farsh',
    () {
      final farsh = variants
          .at(['warsh'], 5, 54, 4)
          .singleWhere((v) => v.inHamesh);
      expect(farsh.text, 'يَرۡتَدِدۡ');
      expect(farsh.shownDescription, isNot(contains('بالإدغام')));
      expect(farsh.shownDescription, contains('زيادة الدال'));
      expect(variants.sourceTextAt('warsh', 5, 54, 4), 'يَرۡتَدِدۡ');
      expect(variants.sourceTextAt('warsh', 5, 54, 3), 'مَن');
    },
  );

  test('hadyan agrees with Hafs and has no farsh or usul row', () {
    expect(variants.at(['warsh'], 5, 95, 23), isEmpty);
    expect(variants.sourceTextAt('warsh', 5, 95, 23), 'هَدۡيَۢا');
    // A genuine neighbouring lexical difference remains.
    expect(variants.at(['warsh'], 5, 95, 12).any((v) => v.inHamesh), isTrue);
    expect(variants.at(['warsh'], 7, 57, 4).any((v) => v.inHamesh), isTrue);
  });

  test('shared nun idgham is not a Warsh difference alongside ibdal', () {
    for (var p = 1; p <= 604; p++) {
      for (final a in quran.page(p)) {
        for (var w = 1; w < a.words.length; w++) {
          for (final v in variants.at(['warsh'], a.surah, a.number, w)) {
            if (v.rule == 'ibdal_single' &&
                RegExp(r'ن[ْۡ]?[ۖ-ۭ]*$').hasMatch(a.words[w - 1]) &&
                RegExp(r'^[يرملون][َُِ]*ّ').hasMatch(v.text)) {
              expect(
                v.description,
                isNot(contains('الإدغام')),
                reason: '${a.surah}:${a.number}:$w',
              );
            }
          }
        }
      }
    }
    expect(rule(2, 75, 2, 'ibdal_single').description, 'بإبدال الهمزة واوًا');
    expect(variants.sourceTextAt('warsh', 2, 75, 1), 'أَن');
  });

  test('badal follows lexical additions and deletions throughout Warsh', () {
    for (final (s, a, w) in [(2, 81, 6), (37, 130, 2), (43, 38, 2)]) {
      expect(
        variants.at(['warsh'], s, a, w).any((v) => v.isBadal),
        isTrue,
        reason: '$s:$a:$w',
      );
      expect(variants.at(['warsh'], s, a, w).any((v) => v.inHamesh), isTrue);
    }
    expect(variants.at(['warsh'], 41, 51, 5).any((v) => v.isBadal), isTrue);
    for (final (s, a, w) in [
      (2, 62, 6),
      (5, 69, 5),
      (22, 17, 5),
      (30, 50, 2),
      (33, 14, 8),
    ]) {
      expect(
        variants.at(['warsh'], s, a, w).any((v) => v.isBadal),
        isFalse,
        reason: '$s:$a:$w',
      );
    }
  });

  test('Warsh Sabiin and Sabiun are farsh without madd al-badal', () {
    for (final (s, a, w) in [(2, 62, 6), (5, 69, 5), (22, 17, 5)]) {
      final word = quran.ayah(s, a).words[w];
      expect(usul_builder.hasBadal(word, '$s:$a'), isFalse);
      final readings = variants.at(['warsh'], s, a, w).toList();
      expect(readings, hasLength(1));
      expect(readings.single.kind, VariantKind.farsh);
      expect(readings.single.inHamesh, isTrue);
      expect(readings.single.isUsul, isFalse);
      expect(readings.single.description, 'بلا همز');
    }
    expect(usul_builder.hasBadal(quran.ayah(2, 62).words[2], '2:62'), isTrue);
  });

  test(
    'faddaratum agrees with Hafs in Warsh while Susi retains its reading',
    () {
      expect(variants.at(['warsh'], 2, 72, 3), isEmpty);
      final susi = variants.at(['susi'], 2, 72, 3).single;
      expect(susi.text, 'فَاَدَّٰرَٰتُمۡ');
      expect(susi.description, 'بحذف الهمزة');
    },
  );

  test('both huda words on page 2 have stopping taqlil in usul', () {
    for (final (a, w) in [(2, 5), (5, 2)]) {
      final v = rule(2, a, w, 'taqlil_stop');
      expect(v.stopOnly, isTrue);
      expect(v.isImala, isTrue);
      expect(v.isUsul, isTrue);
      expect(v.inHamesh, isFalse);
    }
  });

  test('naql includes both words and removes the false farsh on khalaw', () {
    final alim = rule(2, 10, 8, 'naql');
    expect(alim.usulText, 'عَذَابٌ أَلِيمُۢ');
    final ila = rule(2, 14, 8, 'naql');
    expect(ila.usulText, 'خَلَوۡاْ إِلَىٰ');
    for (final v in [alim, ila, rule(2, 14, 7, 'naql_source')]) {
      expect(v.isUsul, isTrue);
      expect(v.inHamesh, isFalse);
      expect(v.shownDescription, contains('نقل'));
      expect(v.shownDescription, isNot(contains('تخفيف')));
    }
    expect(rule(2, 107, 0, 'naql').usulText, 'قَدِيرٌ أَلَمۡ');
    expect(rule(3, 28, 16, 'naql').usulText, 'شَيۡءٍ إِلَّآ');
  });

  test('two-word hamza rules distinguish both vowels and keep other ways', () {
    final waw = rule(2, 13, 12, 'ibdal_waw');
    expect(waw.hamzaReplacement, 'و');
    expect(waw.usulText, 'ٱلسُّفَهَآءُۗ أَلَآ');
    final ya = rule(2, 235, 9, 'ibdal_ya');
    expect(ya.hamzaReplacement, 'ي');
    expect(ya.usulText, 'ٱلنِّسَآءِ أَوۡ');
    expect(rule(4, 43, 27, 'tasheel_pair').hamzaReplacement, isNull);
    expect(rule(4, 43, 27, 'tasheel_pair').description, contains('تسهيل'));
    expect(
      rule(2, 142, 18, 'ibdal_waw').description,
      contains('تسهيل الهمزة الثانية'),
    );
    for (final v in [waw, ya]) {
      expect(v.inHamesh, isFalse);
    }
  });

  test('data generation is repeatable and preserves independent farsh', () {
    final q =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final b =
        jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
    final rows =
        (jsonDecode(File('assets/data/qiraat/warsh.json').readAsStringSync())
                as Map)['variants']
            as List;
    final before = jsonEncode(rows);
    // Regenerating the generic comparisons must not restore this false
    // Warsh difference.
    rows.add([2, 72, 3, 1, 'فَادَّٰرَٰٔتُمْ', 'h', 'بالهمز وحذف الهمزة']);
    correctWarshUsul(
      q,
      b,
      rows,
      sourceText: jsonDecode(
        File('assets/data/reading_texts/warsh.json').readAsStringSync(),
      ) as Map,
    );
    final beforeRows = jsonDecode(before) as List;
    final differences = [
      for (var i = 0; i < rows.length && i < beforeRows.length; i++)
        if (jsonEncode(rows[i]) != jsonEncode(beforeRows[i]))
          [beforeRows[i], rows[i]],
    ];
    expect(
      jsonEncode(rows) == before,
      isTrue,
      reason:
          'A second generation must preserve the existing rows exactly. '
          '${differences.take(3).toList()}',
    );
    expect(variants.at(['warsh'], 6, 63, 11).any((v) => v.inHamesh), isTrue);
    expect(
      variants
          .at(['warsh'], 4, 152, 11)
          .any((v) => v.inHamesh && v.description.contains('النون')),
      isTrue,
    );
    expect(variants.at(['warsh'], 2, 10, 11).single.kind, VariantKind.farsh);
  });

  Future<void> page(
    WidgetTester t,
    int number, {
    ReaderSettings? settings,
    VariantRepository? repository,
    QuranRepository? mushaf,
    Size? viewport,
  }) async {
    t.view.physicalSize = viewport ?? const Size(1080, 2000);
    t.view.devicePixelRatio = viewport == null ? 2.5 : 1;
    addTearDown(t.view.reset);
    final theme = buildTheme(MushafPalette.light);
    await t.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: number,
              quran: mushaf ?? quran,
              variants: repository ?? variants,
              mutashabihat: mutashabihat,
              settings: settings ?? ReaderSettings.memory(selected: {'warsh'}),
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets(
    'Hafs page 15 with Warsh comparison anchors iqlab outside ta',
    tags: 'golden',
    (t) async {
      await page(t, 15);
      final word = find.byKey(const ValueKey('word:2:99:3'));
      expect(word, findsOneWidget);
      expect(t.widget<InkText>(word).text, quran.ayah(2, 99).words[3]);
      expect(t.widget<InkText>(word).text, contains('تِۭ'));
      expect(
        find.descendant(of: word, matching: find.byType(HafsFontMarks)),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile('goldens/p15_hafs_warsh_iqlab.png'),
      );
    },
  );

  testWidgets(
    'yaslaha on page 284 has taqlil and its two faces in the hamesh',
    (t) async {
      final v = variants.at(['warsh'], 17, 18, 15).single;
      expect(v.isUsul, isTrue);
      expect(v.isImala, isTrue);
      expect(v.text, contains('۪'));
      expect(v.description, contains('تغليظ اللام مع الفتح'));
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          284,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed
            ..compareHafs = displayed != null,
        );
        expect(
          find.textContaining('ترقيقها مع التقليل', findRichText: true),
          findsWidgets,
          reason: '$displayed',
        );
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('lattakhadhta on page 302 is farsh with its idgham coloured', (
    t,
  ) async {
    final v = variants.at(['warsh'], 18, 77, 21).single;
    expect(v.kind, VariantKind.farsh);
    expect(v.description, 'بإدغام الذال في التاء');
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        302,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed
          ..compareHafs = displayed != null,
      );
      final word = t.widget<InkText>(
        find.byKey(const ValueKey('word:18:77:21')),
      );
      // Coloured whole, in the farsh colour.
      expect(word.style.color, isNot(MushafColors.ink), reason: '$displayed');
    }
    expect(t.takeException(), isNull);
  });

  test('atbaa on pages 302-303 is farsh told in the hamesh', () {
    for (final (a, w) in [(85, 0), (89, 1), (92, 1)]) {
      final v = variants.at(['warsh'], 18, a, w).single;
      expect(v.kind, VariantKind.farsh);
      expect(v.inHamesh, isTrue);
      expect(v.description, 'بإبدال همزة القطع همزة وصل وتشديد التاء وفتحها');
    }
  });

  test('sayyiatan on page 285 and liyasu on page 282', () {
    expect(
      variants.at(['warsh'], 17, 38, 3).single.description,
      'بفتح الهمزة وإبدال الهاء تاءً منونة مفتوحة',
    );
    expect(
      variants.sourceTextAt('warsh', 17, 7, 11),
      '\u0644\u0650\u064a\u064e\u0633\u064f\u0640\u06e5\u0653\u0640\u0640\u0654\u064f\u0648\u0627\u0652',
    );
    expect(variants.at(['warsh'], 17, 7, 1).map((v) => v.rule), ['naql']);
  });

  testWidgets('a sakin hamza written as a dagger alif colours its letter', (
    t,
  ) async {
    await page(
      t,
      345,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    final word = t.widget<InkText>(find.byKey(const ValueKey('word:23:43:6')));
    final coloured = [
      for (final (l, c) in word.parts!)
        if (c == ReadingColors.hamza) l,
    ].join();
    expect(coloured, contains('\u0670'));
    expect(coloured, isNot(contains('\u062e')));
  });

  testWidgets('al-aala colours its lam for the naql and its taqlil', (t) async {
    await page(
      t,
      407,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    final word = t.widget<InkText>(find.byKey(const ValueKey('word:30:27:11')));
    expect(
      word.parts!.any(
        (p) => p.$2 == ReadingColors.naql && p.$1.contains('\u0644'),
      ),
      isTrue,
    );
    expect(
      word.parts!.any(
        (p) => p.$2 == MushafColors.green && p.$1.contains('\u06ea'),
      ),
      isTrue,
    );
  });

  testWidgets('ذكرا tells its two faces beside the word in the usul', (
    t,
  ) async {
    await page(
      t,
      319,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    expect(find.text(' (بالتفخيم والترقيق)'), findsWidgets);
  });

  testWidgets('لأتوها is told in the hamesh though its rasm is that of Hafs', (
    t,
  ) async {
    await page(t, 419, settings: ReaderSettings.memory(selected: {'warsh'}));
    expect(
      find.textContaining('بحذف المد الطبيعي بعد الهمزة', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('يجازى is under the taqlil, with its other face told', (t) async {
    await page(
      t,
      430,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    expect(find.text(' (بخلف)'), findsOneWidget);
  });

  testWidgets('Warsh has no imala in the usul, زلفى and أهدى are taqlil', (
    t,
  ) async {
    for (final p in [86, 432, 477]) {
      await page(
        t,
        p,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = 'warsh',
      );
      expect(find.text('الإمالة'), findsNothing, reason: 'page $p');
    }
    await page(
      t,
      432,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    expect(find.text(' (بخلف)'), findsOneWidget);
    expect(variants.at(['warsh'], 41, 9, 1).any((v) => v.isImala), isFalse);
  });

  test('نكير 34:45 is only its ya zaida, no farsh', () {
    final at = variants.at(['warsh'], 34, 45, 13);
    expect(at.map((v) => v.rule), ['ya_zaida']);
    expect(at.single.inHamesh, isFalse);
  });

  testWidgets('أشهدوا beside Hafs has no tasheel colour on its shin', (
    t,
  ) async {
    await page(t, 490, settings: ReaderSettings.memory(selected: {'warsh'}));
    final word = t.widget<InkText>(find.byKey(const ValueKey('word:43:19:7')));
    final colors = word.parts!.map((p) => p.$2).toSet();
    expect(colors, isNot(contains(ReadingColors.hamza)));
    expect(colors, hasLength(2));
  });

  testWidgets('a label of the key opens the rule explained', (t) async {
    // Read outside the test's fake clock: the sources are cached for the rest.
    await t.runAsync(() async {
      await Manzumat.load();
      await Kharouf.load();
    });
    await page(
      t,
      3,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    final label = find.byKey(const ValueKey('usul-guide:مد البدل'));
    await t.ensureVisible(label);
    await t.pump();
    await t.tap(label);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('usul-guide-title')), findsOneWidget);
  });

  testWidgets(
    'a tanween damma in wasl colours its last letter with the tanween',
    (t) async {
      String colored(WidgetTester t, String key) {
        final word = t.widget<InkText>(find.byKey(ValueKey(key)));
        return [
          for (final (l, c) in word.parts!)
            if (c != null) l,
        ].join();
      }

      for (final settings in [
        ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
        ReaderSettings.memory(selected: {'warsh'}),
      ]) {
        await page(t, 519, settings: settings);
        expect(colored(t, 'word:50:33:6'), startsWith('ب'));
        await page(t, 455, settings: settings);
        expect(colored(t, 'word:38:41:10'), startsWith('ب'));
        await page(t, 284, settings: settings);
        expect(colored(t, 'word:17:20:11'), startsWith('ر'));
      }
    },
  );

  testWidgets('هو 57:24: all three words beside Hafs, the two in Warsh', (
    t,
  ) async {
    bool colored(WidgetTester t, int w) {
      final word = t.widget<InkText>(find.byKey(ValueKey('word:57:24:$w')));
      final parts = word.parts;
      return parts != null && parts.any((p) => p.$2 != null) ||
          word.style.color != MushafColors.ink;
    }

    await page(t, 540, settings: ReaderSettings.memory(selected: {'warsh'}));
    for (final w in [9, 10, 11]) {
      expect(colored(t, w), isTrue, reason: 'Hafs $w');
    }
    expect(find.textContaining('بحذف هو'), findsOneWidget);
    await page(
      t,
      540,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    for (final w in [10, 11]) {
      expect(colored(t, w), isTrue, reason: 'Warsh $w');
    }
    await page(
      t,
      540,
      settings: ReaderSettings.memory(selected: {'warsh'})
        ..compareHafs = true
        ..displayed = 'warsh'
        ..compareHafs = true,
    );
    expect(find.textContaining('بزيادة هو'), findsOneWidget);
  });

  testWidgets('سأل 70:1 is told under the ibdal, its alif coloured', (t) async {
    final v = variants.at(['warsh'], 70, 1, 0).single;
    expect(v.rule, 'ibdal_single');
    expect(v.inHamesh, isFalse);
    await page(
      t,
      568,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    expect(
      find.byKey(const ValueKey('usul-guide:الهمز المفرد (إبدال الهمز)')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('usul-guide:الهمزات')), findsNothing);
  });

  testWidgets('بناها and its neighbours are taqlil with the fath told', (
    t,
  ) async {
    for (final (a, w) in [
      (27, 5),
      (28, 2),
      (29, 3),
      (31, 3),
      (32, 1),
      (42, 4),
      (44, 2),
      (45, 4),
      (46, 8),
      (30, 3),
    ]) {
      final v = variants.at(['warsh'], 79, a, w).singleWhere((v) => v.isImala);
      expect(v.isUsul, isTrue, reason: '$a');
      expect(v.inHamesh, isFalse, reason: '$a');
      expect(variants.sourceTextAt('warsh', 79, a, w), contains('۪'));
    }
    for (var a = 1; a <= 15; a++) {
      final words = quran.ayah(91, a).words;
      final w = words.indexWhere((t) => t.contains('\u0670\u0647\u064e\u0627'));
      final v = variants.at(['warsh'], 91, a, w).singleWhere((v) => v.isImala);
      expect(v.description, contains('والتقليل مقدم'), reason: '91:$a');
      expect(variants.sourceTextAt('warsh', 91, a, w), contains('۪'));
    }
    await page(
      t,
      584,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    expect(find.text(' (له الفتح والتقليل والتقليل مقدم)'), findsNWidgets(10));
    await page(
      t,
      595,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    expect(find.text(' (له الفتح والتقليل والتقليل مقدم)'), findsNWidgets(15));
  });

  testWidgets(
    'إيلافهم 106:2 has no hamza, it is naql, its small ya the badal',
    (t) async {
      expect(
        variants.sourceTextAt('warsh', 106, 2, 0),
        quran.ayah(106, 2).words[0].replaceFirst('إ', 'ا'),
      );
      final at = variants.at(['warsh'], 106, 2, 0);
      expect(at.where((v) => v.inHamesh), isEmpty);
      expect(at.where((v) => v.isBadal), hasLength(1));
      expect(at.where((v) => v.rule == 'naql'), hasLength(1));
      await page(
        t,
        602,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = 'warsh',
      );
      final word = t.widget<InkText>(
        find.byKey(const ValueKey('word:106:2:0')),
      );
      expect(
        word.parts!.where((p) => p.$2 == MushafColors.green).map((p) => p.$1),
        ['ۦ'],
      );
    },
  );

  test('يؤتين 18:40 has no silah of a ha, only its ibdal and its added ya', () {
    final at = variants.at(['warsh'], 18, 40, 3);
    expect(
      at.map((v) => v.rule),
      unorderedEquals(['ibdal_single', 'ya_zaida']),
    );
    expect(
      at.singleWhere((v) => v.rule == 'ibdal_single').description,
      'بإبدال الهمزة واوًا',
    );
  });

  testWidgets('لأهب 19:19 is written with a circled ya on its hamza', (
    t,
  ) async {
    expect(variants.sourceTextAt('warsh', 19, 19, 5), 'لِأَهَبَ');
    final at = variants.at(['warsh'], 19, 19, 5);
    expect(at.map((v) => v.rule), ['ibdal_ya']);
    expect(at.single.description, 'بإبدال الهمزة ياءً مفتوحة');
    await page(
      t,
      306,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    final mark = t.widget<HamzaReplacementMark>(
      find.ancestor(
        of: find.byKey(const ValueKey('word:19:19:5')),
        matching: find.byType(HamzaReplacementMark),
      ),
    );
    expect(mark.letter, 'ي');
    expect(mark.originalHamza, startsWith('أ'));
    expect(mark.offset, 'لِ'.length);
    final word = t.widget<InkText>(find.byKey(const ValueKey('word:19:19:5')));
    expect(
      word.parts!.where((p) => p.$2 == ReadingColors.hamza).map((p) => p.$1),
      isNot(contains('لِ')),
    );
  });

  test('من راق is told in ترك السكت alone, and تشاء أنت once', () {
    final raq = variants.at(['warsh'], 75, 27, 1).single;
    expect(raq.rule, 'no_sakt');
    expect(variants.at(['warsh'], 83, 14, 1).single.rule, 'no_sakt');
    expect(variants.at(['warsh'], 7, 155, 32), isEmpty);
    expect(variants.at(['warsh'], 7, 155, 33).single.rule, 'ibdal_waw');
  });

  test('ءأعجمي 41:44 has the two faces of the open hamzas, no badal', () {
    expect(variants.at(['warsh'], 41, 44, 8).where((v) => v.isBadal), isEmpty);
    final v = variants
        .at(['warsh'], 41, 44, 8)
        .singleWhere((v) => v.rule == 'tasheel_word');
    expect(v.usulWays, [
      'تسهيل الهمزة الثانية بلا إدخال',
      'إبدال الهمزة الثانية ألفًا مع المد المشبع (٦ حركات)',
    ]);
    expect(v.kind, VariantKind.hamza);
    expect(v.inHamesh, isFalse);
  });

  testWidgets(
    'ءأعجمي 41:44 marks its alif as the second hamza, not as a badal',
    (t) async {
      await page(
        t,
        481,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = 'warsh',
      );
      final word = t.widget<InkText>(
        find.byKey(const ValueKey('word:41:44:8')),
      );
      final parts = word.parts!;
      expect(parts.where((p) => p.$2 == ReadingColors.hamza), hasLength(1));
      expect(parts.where((p) => p.$2 == MushafColors.green), isEmpty);
    },
  );

  testWidgets(
    'a hamza told as eased at the head of a word is coloured as naql',
    (t) async {
      for (final (p, key) in [(601, 'word:105:1:0'), (163, 'word:7:98:0')]) {
        await page(
          t,
          p,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = 'warsh',
        );
        expect(find.text('الهمزات:'), findsNothing);
        final parts = t.widget<InkText>(find.byKey(ValueKey(key))).parts!;
        expect(parts.where((x) => x.$2 == ReadingColors.naql), isNotEmpty);
        expect(parts.where((x) => x.$2 == ReadingColors.hamza), isEmpty);
      }
    },
  );

  testWidgets('رَبَّهُۥٓ 98:8 colours its small waw and madd sign alone', (
    t,
  ) async {
    await page(
      t,
      599,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    final parts = t
        .widget<InkText>(find.byKey(const ValueKey('word:98:8:20')))
        .parts!;
    expect(parts.where((p) => p.$2 != null).map((p) => p.$1), ['\u06e5\u0653']);
    expect(
      parts.singleWhere((p) => p.$2 != null).$2,
      ReadingColors.separatedMadd,
    );
  });

  testWidgets('أَنَا۠ colours its last alif alone, a naql apart', (t) async {
    for (final (p, key, naql) in [
      (43, 'word:2:258:20', false),
      (241, 'word:12:45:7', true),
    ]) {
      await page(
        t,
        p,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = 'warsh',
      );
      final parts = t.widget<InkText>(find.byKey(ValueKey(key))).parts!;
      expect(parts.last.$2, MushafColors.green, reason: key);
      expect(parts.where((x) => x.$2 == MushafColors.green), hasLength(1));
      expect(
        parts.where((x) => x.$2 == ReadingColors.naql),
        hasLength(naql ? 1 : 0),
        reason: key,
      );
    }
  });

  testWidgets(
    'one rule of several verified readers is named once, faces by reader',
    (t) async {
      await t.runAsync(
        () => variants.ensureLoaded(['warsh', 'hisham', 'ruways']),
      );
      await page(
        t,
        3,
        settings: ReaderSettings.memory(
          selected: {'warsh', 'hisham', 'ruways'},
        ),
      );
      expect(
        find.byKey(const ValueKey('usul-guide:الهمزتان من كلمة (المفتوحتان)')),
        findsOneWidget,
      );
      // One table for the kind, in the order of the readers' list.
      final kind = t.getTopLeft(find.text('المفتوحتان:')).dy;
      final y = [
        for (final r in ['ورش', 'هشام', 'رويس'])
          find
              .text(r)
              .evaluate()
              .map((e) => t.getTopLeft(find.byWidget(e.widget)).dy)
              .where((dy) => dy > kind)
              .reduce((a, b) => a < b ? a : b),
      ];
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
      expect(find.text('وجه القراءة'), findsNothing);
      // Ruways's ibdal in السفهاء ألا, as Warsh's: their names in one cell.
      expect(find.text('ورش، رويس'), findsOneWidget);
      expect(
        find.textContaining('إبدال الهمزة الثانية واوًا خالصة وصلاً'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a damma before a hamzat wasl colours the two letters', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        156,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed
          ..compareHafs = displayed != null,
      );
      // بِرَحۡمَةٍ ٱدۡخُلُواْ: the ta of the tanween, the wasl alif.
      final first = t.widget<InkText>(
        find.byKey(const ValueKey('word:7:49:6')),
      );
      final second = t.widget<InkText>(
        find.byKey(const ValueKey('word:7:49:7')),
      );
      final coloured = [
        for (final (l, c) in first.parts!)
          if (c != null) l,
      ];
      expect(coloured, hasLength(1), reason: '$displayed ${first.parts}');
      expect(coloured.single, startsWith('ة'));
      expect(second.parts!.first.$2, isNotNull);
      expect(second.parts!.first.$1, startsWith('ٱ'));
      expect(second.parts!.skip(1).every((p) => p.$2 == null), isTrue);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'page 30 naql colours both tanween and hamza with Hafs displayed',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          30,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed,
        );
        for (final start in [20, 28, 30, 52]) {
          final first = t.widget<InkText>(
            find.byKey(ValueKey('word:2:196:$start')),
          );
          final second = t.widget<InkText>(
            find.byKey(ValueKey('word:2:196:${start + 1}')),
          );
          expect(
            first.parts
                ?.where((p) => RegExp('[ًٌٍٖٗٞ]').hasMatch(p.$1))
                .single
                .$2,
            ReadingColors.naql,
            reason: first.text,
          );
          expect(
            second.parts?.any((p) => p.$2 == ReadingColors.naql),
            isTrue,
            reason: second.text,
          );
          if (displayed == null) {
            expect(first.text, quran.ayah(2, 196).words[start]);
          }
        }
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(MushafPage),
          matchesGoldenFile(
            displayed == null
                ? 'goldens/p30_hafs_warsh_tanween_naql.png'
                : 'goldens/p30_warsh_tanween_naql.png',
          ),
        );
      }
    },
    tags: 'golden',
  );

  testWidgets(
    'page 31 leaves khayrin uncoloured and keeps the ra of khayra orange',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          31,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed,
        );
        final kasra = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:197:18')),
        );
        final fatha = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:197:23')),
        );
        expect(kasra.style.color, MushafColors.ink);
        expect(kasra.parts?.where((p) => p.$2 != null), anyOf(isNull, isEmpty));
        // Only the ra of خَيۡرٖ is orange; the rest of the word is in ink.
        expect(fatha.style.color, MushafColors.ink);
        final orange = fatha.parts!.where((p) => p.$2 == MushafColors.rule);
        expect(orange.map((p) => p.$1[0]), ['ر']);
        expect(
          find.byKey(
            const ValueKey('usul-reference:ترقيق الراء:2:197:18:warsh'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('usul-reference:ترقيق الراء:2:197:23:warsh'),
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(MushafPage),
          matchesGoldenFile(
            displayed == null
                ? 'goldens/p31_hafs_warsh_tarqiq.png'
                : 'goldens/p31_warsh_tarqiq.png',
          ),
        );
      }
    },
    tags: 'golden',
  );

  testWidgets(
    'stopping taqlil colours and glows only final alif, with no sign under it',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        for (final (p, a, w) in [(33, 213, 32), (35, 222, 5), (2, 2, 5)]) {
          final settings = ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed
            ..diffAlert = DiffAlert.glow;
          await page(t, p, settings: settings);
          await t.pump(const Duration(milliseconds: 300));
          final target = find.byKey(ValueKey('word:2:$a:$w'));
          final ink = t.widget<InkText>(target);
          expect(ink.style.color, MushafColors.ink);
          expect(ink.text, isNot(contains(imalaSign)));
          final coloured = ink.parts!.where((p) => p.$2 != null).toList();
          expect(coloured, hasLength(1), reason: ink.text);
          expect(coloured.single.$1, startsWith('ى'));
          expect(coloured.single.$2, MushafColors.green);
          expect(ink.glowFinalAlif, isTrue);
          expect(ink.glowStrength, greaterThan(0));
          expect(
            find.ancestor(of: target, matching: find.byType(CustomPaint)),
            findsWidgets,
          );
          final glowing = [
            for (final text in t.widgetList<Text>(
              find.descendant(of: target, matching: find.byType(Text)),
            ))
              if (text.textSpan is TextSpan)
                for (final span
                    in (text.textSpan as TextSpan).children ?? <InlineSpan>[])
                  if (span is TextSpan &&
                      span.style?.shadows?.isNotEmpty == true)
                    span,
          ];
          expect(glowing, hasLength(1));
          expect(glowing.single.text, startsWith('ى'));
          expect(rule(2, a, w, 'taqlil_stop').isStoppingTaqlil, isTrue);
          final example = find.byKey(
            ValueKey('usul-reference:التقليل:2:$a:$w:warsh'),
          );
          expect(example, findsOneWidget);
          expect(
            find.descendant(of: example, matching: find.text(' (وقفًا فقط)')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          settings.diffAlert = null;
          await t.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets('stopping taqlil examples on pages 33 and 35', (t) async {
    for (final p in [33, 35]) {
      await page(t, p);
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile('goldens/p${p}_stopping_taqlil.png'),
      );
    }
  }, tags: 'golden');

  testWidgets('page 38 ya circle retains the above-alif source seat', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        38,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      final example = find.byKey(
        const ValueKey(
          'usul-reference:الهمزتان من كلمتين (مكسورة فمفتوحة):2:235:9:warsh',
        ),
      );
      expect(example, findsOneWidget);
      final circle = t.widget<HamzaReplacementMark>(
        find.descendant(
          of: example,
          matching: find.byType(HamzaReplacementMark),
        ),
      );
      expect(circle.letter, 'ي');
      expect(circle.originalHamza, startsWith('أ'));
      if (displayed == 'warsh') {
        final word = find.byKey(const ValueKey('word:2:235:9'));
        final onPage = t.widget<HamzaReplacementMark>(
          find.ancestor(of: word, matching: find.byType(HamzaReplacementMark)),
        );
        expect(onPage.originalHamza, startsWith('أ'));
      }
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile(
          displayed == null
              ? 'goldens/p38_hafs_warsh_hamza_seat.png'
              : 'goldens/p38_warsh_hamza_seat.png',
        ),
      );
    }
  }, tags: 'golden');

  testWidgets(
    'page 43 keeps lexical colour while the actual ra is tarqiq orange',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        final settings = ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed
          ..compareHafs = displayed != null;
        await page(t, 43, settings: settings);
        final ink = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:259:52')),
        );
        if (displayed == 'warsh') {
          expect(ink.text, contains('ر'));
          expect(
            ink.parts!.where((p) => p.$1.startsWith('ر')).single.$2,
            MushafColors.rule,
          );
          expect(
            ink.parts!
                .where((p) => !p.$1.startsWith('ر'))
                .every((p) => p.$2 == qiraaOf(hafsId).color),
            isTrue,
          );
        } else {
          expect(ink.text, contains('ز'));
          expect(ink.parts!.any((p) => p.$2 == MushafColors.rule), isFalse);
        }
        expect(
          find.byKey(
            const ValueKey('usul-reference:ترقيق الراء:2:259:52:warsh'),
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(MushafPage),
          matchesGoldenFile(
            displayed == null
                ? 'goldens/p43_hafs_warsh_compound_tarqiq.png'
                : 'goldens/p43_warsh_compound_tarqiq.png',
          ),
        );
      }
      await page(
        t,
        43,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..displayed = 'warsh',
      );
      // Warsh shown alone: nothing compared, nothing coloured.
      final alone = t.widget<InkText>(
        find.byKey(const ValueKey('word:2:259:52')),
      );
      expect(alone.parts?.where((p) => p.$2 != null) ?? [], isEmpty);
    },
    tags: 'golden',
  );

  testWidgets('page 93 Hafs hamza and fatha survive Warsh comparison', (
    t,
  ) async {
    await page(t, 93);
    final ink = t.widget<InkText>(find.byKey(const ValueKey('word:4:94:12')));
    expect(ink.text, startsWith('أَ'));
    expect(ink.parts?.map((p) => p.$1).join() ?? ink.text, startsWith('أَ'));
    for (final rich in t.widgetList<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('word:4:94:12')),
        matching: find.byType(RichText),
      ),
    )) {
      Iterable<String> runs(InlineSpan span) sync* {
        if (span is TextSpan) {
          if (span.text?.isNotEmpty ?? false) yield span.text!;
          for (final child in span.children ?? <InlineSpan>[]) {
            yield* runs(child);
          }
        }
      }

      expect(runs(rich.text).first, startsWith('أَ'));
    }
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p93_hafs_warsh_hamza.png'),
    );
  }, tags: 'golden');

  testWidgets('page 340 marks long ibdal alif while Hafs keeps its hamza', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        340,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      final ink = t.widget<InkText>(
        find.byKey(const ValueKey('word:22:65:16')),
      );
      expect(
        ink.text,
        displayed == null ? quran.ayah(22, 65).words[16] : 'آن',
      );
      final footer = find.byKey(
        const ValueKey(
          'usul-reference:الهمزتان من كلمتين (مفتوحتان):22:65:16:warsh',
        ),
      );
      expect(footer, findsOneWidget);
      expect(
        t
            .widgetList<QuranWordText>(
              find.descendant(of: footer, matching: find.byType(QuranWordText)),
            )
            .any((w) => w.text.endsWith(' آن')),
        isTrue,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('page 51 tasheel sits above waw without sukun', (t) async {
    final v = rule(3, 15, 1, 'tasheel_word');
    expect(v.usulWays, ['تحقيق الأولى وتسهيل الثانية بلا إدخال']);
    expect(
      variants.at(['warsh'], 3, 15, 1).any((v) => v.rule == 'naql'),
      isTrue,
    );
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        51,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      final footer = find.byKey(
        const ValueKey(
          'usul-reference:الهمزتان من كلمة (المفتوحة والمضمومة):3:15:1:warsh',
        ),
      );
      final annotation = t.widget<HamzaReplacementMark>(
        find.descendant(
          of: footer,
          matching: find.byType(HamzaReplacementMark),
        ),
      );
      expect(annotation.letter, isEmpty);
      expect(annotation.originalHamza, startsWith('ؤ'));
      if (displayed == 'warsh') {
        final key = find.byKey(const ValueKey('word:3:15:1'));
        final ink = t.widget<InkText>(key);
        expect(ink.parts![1].$1, 'و');
        final marker = find.ancestor(
          of: key,
          matching: find.byType(HamzaReplacementMark),
        );
        final paint = find
            .descendant(of: marker, matching: find.byType(CustomPaint))
            .first;
        expect(
          (Canvas c) => t
              .widget<CustomPaint>(paint)
              .foregroundPainter!
              .paint(c, t.getSize(paint)),
          paints..something(
            (method, args) =>
                method == #drawCircle &&
                (args[1] as double) < ink.style.fontSize! * .1,
          ),
        );
      }
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile(
          displayed == null
              ? 'goldens/p51_hafs_warsh_tasheel.png'
              : 'goldens/p51_warsh_tasheel.png',
        ),
      );
    }
  }, tags: 'golden');

  test('taghliz after an alif after sad or ta, with its two ways', () {
    for (final (s, a, w) in [(2, 233, 35), (4, 128, 12), (21, 44, 5)]) {
      expect(
        rule(s, a, w, 'taghliz').description,
        'بتغليظ اللام وترقيقها، والتغليظ مقدَّم',
      );
    }
    // Its lam, after the alif (طَالَ), and in Hafs's word (يُصۡلِحَا).
    expect(lamLetter(lettersOf('طَالَ')), 2);
    expect(lamLetter(lettersOf('يُصۡلِحَا')), isNull);
    expect(lamLetter(lettersOf('يُصۡلِحَا'), anyVowel: true), 2);
  });

  test('the book writing out a hamza turned to waw is no farsh', () {
    // يُؤَدِّهِۦٓ: «يُوَدِّهِ» in the book's farsh is Warsh's ibdal, in the usul.
    for (final w in [7, 15]) {
      final at = variants.at(['warsh'], 3, 75, w);
      expect(at.where((v) => v.inHamesh), isEmpty, reason: '3:75:$w');
      expect(at.any((v) => v.rule == 'ibdal_single'), isTrue);
    } // نُؤۡتِهِۦ: the book quotes it with مِنۡهَا.
    for (final w in [14, 20]) {
      expect(
        variants.at(['warsh'], 3, 145, w).where((v) => v.inHamesh),
        isEmpty,
        reason: '3:145:$w',
      );
    }
  });

  test('two hamzas of a word eased as the book says, no farsh', () {
    // أَئِنَّكُمۡ (6:19), أَئِمَّةٗ (21:73), أَءِلَٰهٞ after naql (27:61).
    for (final (s, a, w) in [(6, 19, 18), (21, 73, 1), (27, 61, 14)]) {
      final at = variants.at(['warsh'], s, a, w);
      expect(at.any((v) => v.rule == 'tasheel_word'), isTrue, reason: '$s:$a');
      expect(at.where((v) => v.inHamesh), isEmpty, reason: '$s:$a');
    }
    // إِنِّيٓ أُمِرۡتُ: the ya opened, its own farsh; أُمِرۡتُ no difference.
    expect(
      variants
          .at(['warsh'], 6, 14, 13)
          .where((v) => v.inHamesh)
          .single
          .description,
      'بفتح الياء',
    );
    expect(variants.at(['warsh'], 6, 14, 14), isEmpty);
  });

  test('a word with a hamza added is farsh wherever it is', () {
    // زَكَرِيَّآءُ ٱلۡمِحۡرَابَ, without a quotation of the book, as the one
    // before it in the ayah.
    for (final w in [8, 12]) {
      expect(
        variants.at(['warsh'], 3, 37, w).single.inHamesh,
        isTrue,
        reason: '3:37:$w',
      );
    }
  });

  test('a sakin hamza after a wasl alif is read by the vowel before it', () {
    // يَٰصَٰلِحُ ٱئۡتِنَا: a waw after the damma, a ya when begun with.
    expect(
      rule(7, 77, 8, 'ibdal_waw').description,
      'بإبدال الهمزة واوًا وصلاً، وياءً ابتداءً',
    );
    // ٱلَّذِي ٱؤۡتُمِنَ: a ya after the kasra.
    expect(rule(2, 283, 15, 'ibdal_ya').hamzaReplacement, 'ي');
    expect(rule(8, 32, 16, 'ibdal_ya').description, 'بإبدال الهمزة ياءً');
    // ٱلۡهُدَى ٱئۡتِنَا: an alif after the fatha.
    expect(
      rule(6, 71, 28, 'ibdal_single').description,
      'بإبدال الهمزة ألفًا وصلاً، وياءً ابتداءً',
    );
    // An alif in the circle on its seat.
    expect(rule(6, 71, 28, 'ibdal_single').hamzaReplacement, 'ا');
  });

  testWidgets('a farsh word with its ibdal: farsh colour, the ibdal letter', (
    t,
  ) async {
    // نُوتِيهِمُ (4:152, يُؤۡتِيهِمۡ): بالنون, and the hamza a waw.
    await page(
      t,
      102,
      settings: ReaderSettings.memory(selected: {'warsh'})
        ..compareHafs = true
        ..displayed = 'warsh'
        ..compareHafs = true,
    );
    final parts = t
        .widget<InkText>(find.byKey(const ValueKey('word:4:152:11')))
        .parts!;
    expect(parts.where((p) => p.$2 == ReadingColors.hamza).map((p) => p.$1), [
      'و',
    ]);
    expect(parts.first.$2, isNot(anyOf(isNull, ReadingColors.hamza)));
    expect(t.takeException(), isNull);
  });

  testWidgets('imala colours its letter alone, in the farsh colour', (t) async {
    List<(String, Color?)> coloured(String key) => [
      for (final (s, c) in t.widget<InkText>(find.byKey(ValueKey(key))).parts!)
        if (c != null) (s, c),
    ];
    // فَأَحۡيَٰكُمۡ: the ya and its sign green, the rest in ink.
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        5,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      final green = coloured('word:2:28:5');
      expect(green.map((p) => p.$1[0]).join(), 'ي');
      expect(green.single.$1, contains(imalaSign));
      expect(green.single.$2, MushafColors.green);
    }
    // يَٰبُشۡرَىٰ, farsh against Hafs, in Hafs's text or Warsh's: the ra green,
    // the rest in the farsh colour.
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        237,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      final parts = coloured('word:12:19:7');
      expect(
        parts.where((p) => p.$2 == MushafColors.green).map((p) => p.$1[0]),
        ['ر'],
      );
      expect(parts.where((p) => p.$2 != MushafColors.green), isNotEmpty);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('page 55 yahya keeps imala clear of ya dots', (t) async {
    await page(
      t,
      55,
      settings: ReaderSettings.memory(selected: {'warsh'})..compareHafs = true..displayed = 'warsh',
    );
    final word = find.byKey(const ValueKey('word:3:39:10'));
    expect(t.widget<InkText>(word).text, contains(imalaSign));
    expect(
      find.descendant(of: word, matching: find.byType(HafsFontMarks)),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p55_warsh_imala_spacing.png'),
    );
  }, tags: 'golden');

  testWidgets('page 2 footer explicitly labels stopping taqlil', (t) async {
    await page(t, 2);
    expect(find.text('التقليل:'), findsOneWidget);
    expect(find.text(' (وقفًا فقط)'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'page 29 lists falan under naql and badal and extra ya separately',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          29,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed,
        );
        for (final label in ['النقل', 'مد البدل']) {
          expect(
            find.byKey(ValueKey('usul-reference:$label:2:187:23:warsh')),
            findsOneWidget,
          );
        }
        final ink = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:187:23')),
        );
        final parts = ink.parts!;
        expect(
          parts.map((p) => p.$1).join().replaceAll(tatweel, ''),
          ink.text.replaceAll(tatweel, ''),
        );
        expect(
          parts.where((p) => p.$1.contains('ٰ')).single.$2,
          MushafColors.green,
        );
        expect(
          parts.where((p) => p.$1.startsWith('ل')).single.$2,
          displayed == 'warsh' ? MushafColors.green : ReadingColors.naql,
        );
        await page(
          t,
          quran.pageOf(2, 186),
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed,
        );
        for (final w in [8, 10]) {
          expect(
            find.byKey(ValueKey('usul-reference:ياءات الزوائد:2:186:$w:warsh')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              ValueKey('usul-reference:صلة هاء الضمير:2:186:$w:warsh'),
            ),
            findsNothing,
          );
        }
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('badal green takes priority over naql on ataynahum and aya', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        quran.pageOf(2, 211),
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      for (final w in [4, 6]) {
        final ink = t.widget<InkText>(find.byKey(ValueKey('word:2:211:$w')));
        final parts = ink.parts!;
        final target = badalLetter(lettersOf(ink.text))!;
        expect(
          parts[target].$2,
          MushafColors.green,
          reason: '$displayed: ${ink.text}',
        );
        expect(
          parts.map((p) => p.$1).join().replaceAll(tatweel, ''),
          ink.text.replaceAll(tatweel, ''),
        );
      }
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'page 123 hadyan has no difference colour or alert with either base',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          123,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed
            ..mode = DisplayMode.highlight
            ..diffAlert = DiffAlert.glow
            ..showMutashabihat = false,
        );
        final main = find.byKey(const ValueKey('word:5:95:23'));
        final word = t.widget<InkText>(main);
        expect(word.style.color, MushafColors.ink);
        expect(word.parts?.every((p) => p.$2 == null) ?? true, isTrue);
        expect(
          find.ancestor(
            of: main,
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_Alerting',
            ),
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'page 117 yartadid has no extra ya shadda and preserves the dal reading',
    (t) async {
      await page(
        t,
        117,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = 'warsh',
      );
      final word = t.widget<InkText>(find.byKey(const ValueKey('word:5:54:4')));
      expect(lettersOf(word.text).first, 'يَ');
      expect(word.text, endsWith('دِدۡ'));
      final preceding = t.widget<InkText>(
        find.byKey(const ValueKey('word:5:54:3')),
      );
      expect(preceding.text, 'مَن');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Warsh base with Hafs selected shows the reverse farsh in every printed mode',
    (t) async {
      for (final mode in [
        DisplayMode.hamesh,
        DisplayMode.replace,
        DisplayMode.highlight,
      ]) {
        final settings = ReaderSettings.memory(selected: {'warsh'}, mode: mode)
          ..displayed = 'warsh'
          ..compareHafs = true;
        await page(t, 123, settings: settings);
        for (final w in [12, 13, 27, 28]) {
          final margin = find.byKey(ValueKey('margin-reference:5:95:$w'));
          expect(margin, findsOneWidget, reason: '${mode.name}: $w');
          // Adjusted marks are painted separately. Check the complete Quran
          // source as well as plain text spans, rather than requiring the
          // detached madd to remain in the low-level shaping run.
          final texts = [
            ...t
                .widgetList<QuranWordText>(
                  find.descendant(
                    of: margin,
                    matching: find.byType(QuranWordText),
                  ),
                )
                .map((v) => v.text),
            ...t
                .widgetList<Text>(
                  find.descendant(of: margin, matching: find.byType(Text)),
                )
                .map((v) => v.data ?? v.textSpan?.toPlainText() ?? ''),
          ];
          expect(
            texts.any((text) => text.contains(quran.ayah(5, 95).words[w])),
            isTrue,
            reason: '${mode.name}: $w',
          );
        }
        expect(find.textContaining('حفص', findRichText: true), findsWidgets);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'reverse Hafs farsh follows the visible words in landscape replacement mode',
    (t) async {
      await page(
        t,
        123,
        settings:
            ReaderSettings.memory(
                selected: {'warsh'},
                mode: DisplayMode.replace,
              )
              ..displayed = 'warsh'
              ..compareHafs = true,
        viewport: const Size(800, 432),
      );
      final scroll = t
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('landscape-page-scroll')),
          )
          .controller!;
      final target = t
          .getTopLeft(find.byKey(const ValueKey('word:5:95:12')))
          .dy;
      final print = t.getTopLeft(find.byKey(const ValueKey('mushaf-print'))).dy;
      scroll.jumpTo((target - print).clamp(0, scroll.position.maxScrollExtent));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('margin-reference:5:95:12')),
        findsOneWidget,
      );
      expect(find.textContaining('حفص', findRichText: true), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Warsh and Shubah compare directly without selecting Hafs', (
    t,
  ) async {
    for (final base in ['warsh', 'shubah']) {
      final settings = ReaderSettings.memory(
        selected: {'warsh', 'shubah'},
        mode: DisplayMode.replace,
      )..displayed = base;
      await page(t, 123, settings: settings);
      final margin = find.byKey(const ValueKey('margin-reference:5:95:12'));
      expect(margin, findsOneWidget);
      final text = t
          .widgetList<Text>(
            find.descendant(of: margin, matching: find.byType(Text)),
          )
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
          .join(' ');
      expect(text, contains(base == 'warsh' ? 'شعبة' : 'ورش'));
      expect(text, isNot(contains('حفص')));
      expect(t.takeException(), isNull);
    }
    await page(
      t,
      123,
      settings: ReaderSettings.memory(selected: {'warsh', 'qalun'})
        ..displayed = 'warsh'
        ..showMutashabihat = false,
    );
    expect(
      find.byKey(const ValueKey('margin-reference:5:95:12')),
      findsNothing,
    );
    final word = t.widget<InkText>(find.byKey(const ValueKey('word:5:95:12')));
    expect(word.style.color, MushafColors.ink);
  });

  testWidgets(
    'word details name the displayed base and resolve an implicit Shubah reading',
    (t) async {
      await t.runAsync(() async {
        await variants.ensureLoaded(variants.available);
        await Manzumat.load();
        await Kharouf.load();
      });
      final settings = ReaderSettings.memory(selected: {'warsh', 'shubah'})
        ..displayed = 'warsh';
      await page(t, 123, settings: settings);
      VariantSheet.show(
        t.element(find.byType(MushafPage)),
        VariantSheet(
          ayah: quran.ayah(5, 95),
          word: 12,
          surahName: quran.surah(5).nameAr,
          settings: settings,
          variants: variants,
          surahNames: [for (final s in quran.surahs) s.nameAr],
        ),
      );
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pumpAndSettle();
      expect(find.text('ورش عن نافع (الرواية المعروضة)'), findsOneWidget);
      expect(find.text('حفص عن عاصم (النص الأساسي)'), findsNothing);
      final evidence = find.byKey(const ValueKey('word-reading-evidence'));
      await t.scrollUntilVisible(
        evidence,
        150,
        scrollable: find
            .descendant(
              of: find.byType(VariantSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      final readings = t.widget<ReadingReferences>(evidence).readings;
      expect(
        readings.singleWhere((v) => v.riwayaId == 'shubah').text,
        quran.ayah(5, 95).words[12],
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'page 11 lists yuminun only under ibdal and leaves the preceding nun bare',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          11,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed,
        );
        expect(
          t.widget<InkText>(find.byKey(const ValueKey('word:2:75:1'))).text,
          'أَن',
        );
        expect(
          find.byKey(
            const ValueKey(
              'usul-reference:الهمز المفرد (إبدال الهمز):2:75:2:warsh',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('usul-reference:الإدغام:2:75:2:warsh')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('page 11 has no Warsh colour, animation or usul for faddaratum', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..compareHafs = true
        ..displayed = displayed
        ..mode = DisplayMode.highlight
        ..diffAlert = DiffAlert.glow
        ..showMutashabihat = false;
      await page(t, 11, settings: settings);
      final main = find.byKey(const ValueKey('word:2:72:3'));
      final word = t.widget<InkText>(main);
      expect(word.style.color, MushafColors.ink);
      expect(word.parts?.every((p) => p.$2 == null) ?? true, isTrue);
      expect(
        find.ancestor(
          of: main,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_Alerting',
          ),
        ),
        findsNothing,
      );
      final notes = find.byKey(const ValueKey('usul-notes'));
      expect(
        find.descendant(
          of: notes,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                skeleton(widget.data ?? widget.textSpan?.toPlainText() ?? '')
                    .contains('فدرتم'),
          ),
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('page 10 keeps Sabiin in farsh and out of the badal footer', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        10,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed,
      );
      final notes = find.byKey(const ValueKey('usul-notes'));
      expect(
        find.descendant(
          of: notes,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                skeleton(widget.data ?? widget.textSpan?.toPlainText() ?? '')
                    .contains('لصبين'),
          ),
        ),
        findsNothing,
      );
      if (displayed == null) {
        expect(
          find.byKey(const ValueKey('margin-reference:2:62:6')),
          findsOneWidget,
        );
      }
      expect(find.text('مد البدل:'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'naql before badal includes both words without a vague hamza group',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          8,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = displayed,
        );
        final notes = find.byKey(const ValueKey('usul-notes'));
        Finder example(String value) =>
            find.descendant(of: notes, matching: find.text(value));
        expect(example('مِّنَ اٰلِ'), findsOneWidget);
        expect(example('وَإِذَ اٰتَيۡنَا'), findsOneWidget);
        expect(
          example('اٰلِ'),
          findsOneWidget,
        ); // The independent badal example.
        expect(example('اٰتَيۡنَا'), findsOneWidget);
        expect(example('مِّنَ'), findsNothing);
        expect(example('وَإِذَ'), findsNothing);
        expect(example('تخفيف الهمز:'), findsNothing);
        expect(example('الهمزات:'), findsNothing);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Israel notes stay in the margin without colouring a difference',
    (t) async {
      final places = <(Ayah, int)>[
        for (var p = 1; p <= 604; p++)
          for (final a in quran.page(p))
            for (final (w, text) in a.words.indexed)
              if (skeleton(text) == 'سريل') (a, w),
      ];
      expect(places, hasLength(42));
      for (final (a, w) in places) {
        final readings = variants.at(['warsh'], a.surah, a.number, w).toList();
        expect(readings.every((v) => v.isMarginNote), isTrue);
        expect(ReadingColors.ofReadings(readings), isNull);
      }
      for (final displayed in [null, 'warsh']) {
        final settings = ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed
          ..mode = DisplayMode.hamesh
          ..compareHafs = true
          ..showMutashabihat = false;
        await page(t, 7, settings: settings);
        final word = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:40:1')),
        );
        expect(word.style.color, MushafColors.ink);
        expect(word.parts?.every((p) => p.$2 == null) ?? true, isTrue);
        final note = find.byKey(const ValueKey('margin-reference:2:40:1'));
        expect(note, findsOneWidget);
        expect(
          find.textContaining('ولا ترقق راؤه لأنه اسم أعجمي'),
          findsOneWidget,
        );
        settings.mode = DisplayMode.highlight;
        settings.diffAlert = DiffAlert.glow;
        await page(t, 7, settings: settings);
        final main = find.byKey(const ValueKey('word:2:40:1'));
        expect(t.widget<InkText>(main).style.color, MushafColors.ink);
        expect(
          find.ancestor(
            of: main,
            matching: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_Alerting',
            ),
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('replacement circles belong only to a Warsh base or its margin', (
    t,
  ) async {
    for (final displayed in [null, 'warsh', 'qunbul']) {
      final settings = ReaderSettings.memory(selected: {'warsh', 'qunbul'})
        ..displayed = displayed;
      for (final (number, a, w, letter) in [
        (3, 13, 12, 'و'),
        (6, 31, 12, 'ي'),
        (38, 235, 9, 'ي'),
      ]) {
        await page(t, number, settings: settings);
        final word = find.byKey(ValueKey('word:2:$a:$w'));
        expect(word, findsOneWidget);
        final main = find.ancestor(
          of: word,
          matching: find.byType(HamzaReplacementMark),
        );
        if (displayed == 'warsh') {
          expect(main, findsOneWidget);
          expect(t.widget<HamzaReplacementMark>(main).letter, letter);
        } else {
          // No circled letter; Qunbul's own tasheel dot only (إِن، 2:31).
          expect(
            t
                .widgetList<HamzaReplacementMark>(main)
                .every((m) => m.letter.isEmpty),
            isTrue,
          );
        }
        final notes = find.byKey(const ValueKey('usul-notes'));
        expect(
          t
              .widgetList<HamzaReplacementMark>(
                find.descendant(
                  of: notes,
                  matching: find.byType(HamzaReplacementMark),
                ),
              )
              .any((m) => m.letter == letter),
          isTrue,
        );
        expect(t.takeException(), isNull);
      }
    }
  });

  test(
    'two broken hamzas show the ya replacement as well as their other ways',
    () {
      final v = rule(2, 31, 12, 'tasheel_pair');
      expect(v.hamzaReplacement, 'ي');
      expect(v.usulWays.any((w) => w.contains('تسهيل')), isTrue);
      expect(v.usulWays.any((w) => w.contains('ياءً')), isTrue);
      const text = 'هَٰٓؤُلَآءِ إِن';
      expect(
        HamzaReplacementMark.seatText(text, text.lastIndexOf(' ') + 1),
        'هَٰٓؤُلَآءِ ان',
      );
    },
  );

  test('the two ways of open hamzas belong to usul without insertion', () {
    for (final (s, a, w) in [(2, 6, 5), (3, 20, 13), (36, 10, 2)]) {
      final v = rule(s, a, w, 'tasheel_word');
      expect(v.inHamesh, isFalse);
      expect(v.isImala, isFalse);
      expect(v.usulWays, [
        'تسهيل الهمزة الثانية بلا إدخال',
        'إبدال الهمزة الثانية ألفًا مع المد المشبع (٦ حركات)',
      ]);
      expect(ReadingColors.of(v), ReadingColors.hamza);
    }
    expect(rule(43, 58, 1, 'tasheel_word').usulWays, hasLength(1));
    expect(rule(2, 31, 12, 'tasheel_pair').isImala, isFalse);
  });

  testWidgets('hamza ways are explicit in the compact usul margin', (t) async {
    await page(t, 3);
    final explanation = t.widget<Text>(
      find.byKey(const ValueKey('hamza-word-ways')),
    );
    expect(explanation.data, contains('تسهيل الهمزة الثانية بلا إدخال'));
    expect(explanation.data, contains('مع المد المشبع (٦ حركات)'));
    expect(find.text('المفتوحتان:'), findsOneWidget);
    expect(
      t.widget<Text>(find.text('الأصول')).style?.fontSize,
      lessThanOrEqualTo(8),
    );
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(800 - print.height, greaterThan(0));
    expect(800 - print.height, lessThan(2 * print.height / 15));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'portrait uses one outer margin and a wider print on either page',
    (t) async {
      for (final width in [432.0, 360.0]) {
        for (final number in [3, 4]) {
          await page(
            t,
            number,
            repository: _DenseVariants(),
            viewport: Size(width, 800),
          );
          await t.pumpAndSettle();
          final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
          final right = quran.isRightPage(number);
          expect(print.width, greaterThanOrEqualTo(width * .83));
          expect(right ? print.left : print.right, right ? 0 : width);
          final notes = <Rect>[];
          for (
            var i = 0;
            find.byKey(ValueKey('side-note-$i')).evaluate().isNotEmpty;
            i++
          ) {
            final rect = t.getRect(find.byKey(ValueKey('side-note-$i')));
            expect(rect.top, greaterThanOrEqualTo(-0.1));
            expect(rect.bottom, lessThanOrEqualTo(print.bottom + 0.1));
            if (right) {
              expect(rect.left, greaterThanOrEqualTo(print.right));
            } else {
              expect(rect.right, lessThanOrEqualTo(print.left));
            }
            notes.add(rect);
          }
          expect(notes, isNotEmpty);
          notes.sort((a, b) => a.top.compareTo(b.top));
          for (var i = 1; i < notes.length; i++) {
            expect(notes[i].top, greaterThanOrEqualTo(notes[i - 1].bottom));
          }
          expect(find.byKey(const ValueKey('bottom-notes')), findsOneWidget);
          expect(
            t.getTopLeft(find.byKey(const ValueKey('bottom-notes'))).dy,
            lessThan(800),
          );
          expect(t.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'extra portrait width enlarges letters without changing printed lines',
    (t) async {
      await page(t, 3, repository: _DenseVariants());
      await t.pumpAndSettle();
      final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
      final lines = t.widget<MushafLines>(find.byType(MushafLines));
      expect(lines.lines, quran.lines(3));
      // Previously the two margins left 74% of the viewport to the print.
      final oldSize = lines.metrics(432 * .74 - 48).fontSize;
      expect(
        lines.metrics(print.width - 48).fontSize,
        greaterThan(oldSize * 1.1),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('portrait margin follows the Shamarly page side too', (t) async {
    for (final number in [3, 4]) {
      await page(t, number, repository: _DenseVariants(), mushaf: shamarly);
      await t.pumpAndSettle();
      final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
      final note = t.getRect(find.byKey(const ValueKey('side-note-0')));
      if (shamarly.isRightPage(number)) {
        expect(note.left, greaterThanOrEqualTo(print.right));
      } else {
        expect(note.right, lessThanOrEqualTo(print.left));
      }
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('two-word faces stay with their own contexts in the footer', (
    t,
  ) async {
    await page(t, 424);
    final details = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '');
    final arid = details.where((s) => s.contains('الحركة العارضة')).toList();
    expect(arid, hasLength(1));
    expect(arid.single, contains('السكون الأصلي'));
    expect(arid.single, contains('القصر (حركتان)'));
    expect(arid.single, contains('٦ حركات'));
    // A separate group on the same page permits a moving waw or tasheel;
    // it must not acquire the ya-madd faces of للنبيء إن أراد.
    final waw = details.where((s) => s.contains('واوًا مكسورة خالصة')).toList();
    expect(waw, hasLength(1));
    expect(waw.single, isNot(contains('الحركة العارضة')));
    expect(waw.single, isNot(contains('حركات')));
    expect(t.takeException(), isNull);
  });

  testWidgets('a narrow phone keeps the right margin and uses the bottom', (
    t,
  ) async {
    await page(
      t,
      3,
      repository: _DenseVariants(),
      viewport: const Size(360, 740),
    );
    await t.pumpAndSettle();
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(print.left, 0);
    expect(
      t.getRect(find.byKey(const ValueKey('side-note-0'))).left,
      greaterThanOrEqualTo(print.right),
    );
    expect(find.byKey(const ValueKey('bottom-notes')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('compound hamza, silah and madd descriptions remain usul', () {
    final v = variants.at(['warsh'], 2, 6, 5).single;
    expect(v.isUsul, isTrue);
    expect(v.inHamesh, isFalse);
    expect(ReadingColors.of(v), ReadingColors.hamza);
    expect(variants.at(['warsh'], 2, 10, 11).single.isUsul, isFalse);
    expect(ReadingColors.of(rule(2, 10, 8, 'naql')), ReadingColors.naql);
    expect(ReadingColors.forLabel('النقل'), ReadingColors.naql);
    expect(ReadingColors.forLabel('تسهيل الهمز'), ReadingColors.hamza);
    expect(ReadingColors.forLabel('صلة ميم الجمع'), ReadingColors.silah);
    expect(
      variants.at(['warsh'], 2, 13, 11),
      isEmpty,
      reason: 'The paired hamza rule belongs to the second word.',
    );
    expect(
      variants.at(['warsh'], 2, 14, 15).every((v) => v.isUsul),
      isTrue,
      reason: 'The book must not duplicate madd al-badal as farsh.',
    );
  });

  testWidgets(
    'rule colours survive switching the displayed riwaya and Hafs comparison',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        final settings = ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = displayed
          ..compareHafs = true;
        await page(t, 3, settings: settings);
        InkText word(int a, int w) =>
            t.widget<InkText>(find.byKey(ValueKey('word:2:$a:$w')));
        List<Color> colours(int a, int w) => [
          for (final p in word(a, w).parts ?? <(String, Color?)>[])
            if (p.$2 != null) p.$2!,
        ];
        expect(
          colours(6, 5),
          containsAll([ReadingColors.hamza, ReadingColors.silah]),
        );
        expect(colours(6, 10), contains(ReadingColors.hamza));
        expect(colours(10, 8), contains(ReadingColors.naql));
        expect(colours(14, 7), contains(ReadingColors.naql));
        expect(colours(14, 8), contains(ReadingColors.naql));
        expect(
          word(10, 11).style.color,
          qiraaOf(displayed == null ? 'warsh' : hafsId).color,
        );
        expect(
          t
              .widget<HamzaReplacementMark>(
                find.byType(HamzaReplacementMark).first,
              )
              .color,
          ReadingColors.hamza,
        );
        expect(
          t.widget<Text>(find.text('النقل:')).style?.color,
          ReadingColors.naql,
        );
        expect(
          t.widget<Text>(find.text('إبدال الهمز:')).style?.color,
          ReadingColors.hamza,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('page 3 groups the two-word rules and paints the circled waw', (
    t,
  ) async {
    await page(t, 3);
    expect(find.text('النقل:'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is QuranWordText && w.text == 'عَذَابٌ اَلِيمُۢ',
      ),
      findsOneWidget,
    );
    expect(find.text('خَلَوِاْ اِلَىٰ'), findsOneWidget);
    final marks = t.widgetList<HamzaReplacementMark>(
      find.byType(HamzaReplacementMark),
    );
    expect(
      marks.where((m) => m.letter == 'و'),
      hasLength(1),
    ); // Warsh's footer example; the Hafs page keeps its original hamza.
    expect(t.takeException(), isNull);
  });

  testWidgets('usul examples use their own riwaya when the main text changes', (
    t,
  ) async {
    for (final displayed in [null, 'warsh', 'qunbul']) {
      final settings = ReaderSettings.memory(selected: {'warsh', 'qunbul'})
        ..displayed = displayed;
      await page(t, 3, settings: settings);
      final notes = find.byKey(const ValueKey('usul-notes'));
      Finder example(String text) => find.descendant(
        of: notes,
        matching: find.byWidgetPredicate(
          (w) => w is QuranWordText && w.text == text,
        ),
      );
      expect(example('عَلَيۡهِمُۥٓ'), findsOneWidget);
      expect(example('عَلَيۡهِمُۥ'), findsOneWidget);
      expect(example('عَذَابٌ اَلِيمُۢ'), findsOneWidget);
      expect(example('خَلَوِاْ اِلَىٰ'), findsOneWidget);
      // Hafs's stop signs: none at the ayah's end (يُؤۡمِنُونَ).
      expect(example('يُومِنُونَ'), findsOneWidget);
      expect(example('عَذَابٌ أَلِيمُۢ'), findsNothing);
      expect(t.takeException(), isNull);
    }
  });

  test('a replacement circle removes only the target hamza from its seat', () {
    for (final target in ['أَ', 'إِ', 'أَ', 'إِ', 'ٱ', 'اَ۬', 'اِ۪']) {
      final text = 'ٱلسُّفَهَآءُ $targetلَا';
      final offset = text.lastIndexOf(' ') + 1;
      final shown = HamzaReplacementMark.seatText(text, offset);
      expect(shown.substring(0, offset), text.substring(0, offset));
      expect(shown.substring(offset), startsWith('ا'));
      expect(shown.substring(offset), isNot(matches('[أإٱٕ۪ٔ۬]')));
      expect(shown.substring(offset, offset + 1), 'ا');
      expect(
        RegExp('[َُِ]')
            .hasMatch(shown.substring(offset, shown.indexOf('لَا', offset))),
        isFalse,
      );
      expect(shown.endsWith('لَا'), isTrue);
    }
  });

  testWidgets(
    'wasl uses the Hafs sign without a vowel or circle across Warsh',
    (t) async {
      for (var p = 1; p <= 604; p++) {
        for (final a in quran.page(p)) {
          for (var w = 0; w < a.words.length; w++) {
            final text = variants.sourceTextAt('warsh', a.surah, a.number, w)!;
            // The eased hamza after a naql (أءله، أءذا) is no wasl.
            if (RegExp(
              '^\u0627\u064e\u06df([\u0644\u0630]\u064e|\u0646\u0632\u0650\u0644\u064e|\u0644[\u0652\u06e1]\u0642\u0650\u064a\u064e|\u0634[\u0652\u06e1]\u0647\u0650\u062f\u064f\u0648\u0627)',
            ).hasMatch(text)) {
              continue;
            }
            expect(
              text,
              isNot(matches('ا[َُِ]۟')),
              reason: '${a.surah}:${a.number}:$w',
            );
          }
        }
      }
      for (final (p, a, w) in [(4, 21, 2), (6, 34, 3), (6, 35, 2)]) {
        await page(
          t,
          p,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..compareHafs = true
            ..displayed = 'warsh',
        );
        final word = t.widget<InkText>(find.byKey(ValueKey('word:2:$a:$w')));
        expect(word.text, startsWith('ٱ'));
        expect(word.text, isNot(contains('۟')));
      }
      expect(t.takeException(), isNull);
    },
  );

  test(
    'a standalone hamza keeps its width, vowel and neighbouring colours',
    () {
      const before = 'هَٰٓؤُلَآءِ ';
      final parts = HamzaReplacementMark.hideHamza([
        (before, Colors.green),
        ('ءَالِهَةً', Colors.red),
      ], before.length);
      expect(parts.map((p) => p.$1).join(), 'هَٰٓؤُلَآءِ ءَالِهَةً');
      expect(parts.where((p) => p.$2 == Colors.transparent).single.$1, 'ء');
      expect(parts.first, (before, Colors.green));
      expect(parts.last, ('َالِهَةً', Colors.red));
    },
  );

  testWidgets(
    'circles stay on the target seat at different scales and widths',
    (t) async {
      addTearDown(t.view.reset);
      for (final size in [const Size(430, 860), const Size(860, 430)]) {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        for (final scale in [1.0, 1.8]) {
          for (final fontSize in [12.0, 32.0]) {
            for (final letter in ['و', 'ي']) {
              const original = 'ٱلسُّفَهَآءُ أَلَآ';
              final offset = original.lastIndexOf(' ') + 1;
              final style = TextStyle(
                fontFamily: 'Hafs',
                fontSize: fontSize,
                height: 1.4,
              );
              await t.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Center(
                      child: HamzaReplacementMark(
                        text: original,
                        offset: offset,
                        letter: letter,
                        style: style,
                        color: ReadingColors.hamza,
                        builder: (shown, _) => Text(
                          shown,
                          textDirection: TextDirection.rtl,
                          style: style,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final text = find.descendant(
                of: find.byType(HamzaReplacementMark),
                matching: find.byType(Text),
              );
              final paragraph = t.renderObject<RenderParagraph>(text);
              final box = paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: offset, extentOffset: offset + 1),
                  )
                  .single;
              final paint = find
                  .descendant(
                    of: find.byType(HamzaReplacementMark),
                    matching: find.byType(CustomPaint),
                  )
                  .first;
              final painter = t.widget<CustomPaint>(paint).foregroundPainter!;
              late Offset center;
              expect(
                (Canvas canvas) => painter.paint(canvas, t.getSize(paint)),
                paints..something((method, args) {
                  if (method != #drawCircle) return false;
                  center = args[0] as Offset;
                  return true;
                }),
              );
              expect(center.dx, closeTo((box.left + box.right) / 2, 0.1));
              expect(center.dy, inInclusiveRange(box.top, box.bottom));
              expect(
                center.dy,
                lessThan((box.top + box.bottom) / 2),
                reason: 'The original hamza is above alif for either replacement letter.',
              );
              expect(t.takeException(), isNull);
            }
          }
        }
      }
    },
  );

  testWidgets(
    'circled waw and ya follow the original hamza seat',
    tags: 'golden',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('marks'),
                child: Container(
                  width: 640,
                  height: 460,
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final (text, letter) in [
                        ('ٱلسُّفَهَآءُ أَلَآ', 'و'),
                        ('ٱلنِّسَآءِ أَوۡ', 'ي'),
                        ('يَشَآءُ إِلَىٰ', 'و'),
                        ('هَٰٓؤُلَآءِ ءَالِهَةً', 'ي'),
                        ('هَٰٓؤُلَآءِ إِن', 'ي'),
                      ])
                        HamzaReplacementMark(
                          text: text,
                          letter: letter,
                          offset: text.lastIndexOf(' ') + 1,
                          style: const TextStyle(
                            fontFamily: 'Hafs',
                            fontSize: 54,
                            height: 1,
                          ),
                          color: ReadingColors.hamza,
                          builder: (shown, hidden) => Text.rich(
                            TextSpan(
                              children: [
                                for (final (part, color)
                                    in HamzaReplacementMark.hideHamza([
                                      (shown, Colors.black),
                                    ], hidden))
                                  TextSpan(
                                    text: part,
                                    style: TextStyle(color: color),
                                  ),
                              ],
                            ),
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: 'Hafs',
                              fontSize: 54,
                              height: 1,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('marks')),
        matchesGoldenFile('goldens/warsh_hamza_marks.png'),
      );
    },
  );

  testWidgets('page 3 with corrected Warsh rules', tags: 'golden', (t) async {
    await page(t, 3);
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p3_warsh_rules.png'),
    );
    await t.ensureVisible(find.text('النقل:'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p3_warsh_usul_footer.png'),
    );
  });

  testWidgets('portrait left page has its margin on the left', tags: 'golden', (
    t,
  ) async {
    await page(t, 20);
    await t.pumpAndSettle();
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(
      t.getRect(find.byKey(const ValueKey('side-note-0'))).right,
      lessThanOrEqualTo(print.left),
    );
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p20_warsh_left_margin.png'),
    );
  });

  testWidgets('Warsh hamza faces in the footer of page 424', tags: 'golden', (
    t,
  ) async {
    await page(t, 424);
    await t.ensureVisible(find.textContaining('الحركة العارضة'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p424_warsh_hamza_faces.png'),
    );
  });

  testWidgets(
    'Warsh displayed with Hafs compared keeps rule colours',
    tags: 'golden',
    (t) async {
      await page(
        t,
        3,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..compareHafs = true
          ..displayed = 'warsh'
          ..compareHafs = true,
      );
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile('goldens/p3_warsh_rule_colors_compared.png'),
      );
    },
  );
}

class _DenseVariants extends VariantRepository {
  _DenseVariants() : super({'warsh'});

  @override
  bool isLoaded(String id) => id == 'warsh';

  @override
  Iterable<Variant> at(
    Iterable<String> ids,
    int surah,
    int ayah,
    int word,
  ) sync* {
    if (!ids.contains('warsh') || word.isOdd) return;
    yield Variant(
      riwayaId: 'warsh',
      surah: surah,
      ayah: ayah,
      word: word,
      count: 1,
      text: 'قِرَاءَة',
      kind: VariantKind.farsh,
      description: 'بفتح الحرف وتشديده وتغيير الحركة في هذا الموضع رقم $word',
    );
  }
}
