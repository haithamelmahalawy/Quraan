import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Manzumat manzumat;
  late List<String> surahs;
  late Kharouf book;
  setUpAll(() async {
    manzumat = await Manzumat.load();
    book = await Kharouf.load();
    surahs = [for (final s in (await QuranRepository.load()).surahs) s.nameAr];
  });

  Reference ref(
    String riwaya,
    int surah,
    String hafs, {
    String text = '',
    String description = '',
    String rule = '',
    VariantKind kind = VariantKind.farsh,
  }) => manzumat.referenceOf(
    Variant(
      riwayaId: riwaya,
      surah: surah,
      ayah: 1,
      word: 0,
      count: 1,
      text: text,
      kind: kind,
      description: description,
      rule: rule,
    ),
    hafs,
    surah,
    surahs,
  );

  test("Abu Ja'far's sakt of the opening letters cites the Durrah", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final r = ref(
        id,
        2,
        'الٓمٓ',
        description: 'بالسكت على الحروف المقطعة',
        rule: 'fawatih',
        kind: VariantKind.usul,
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {62}, reason: id);
      expect(r.chapter, contains('الْبَقَرَةِ'), reason: id);
    }
  });

  test("al-Bazzi's «لَا تَّفَرَّقُواْ» cites the head of the rule too", () {
    final v = Variant(
      riwayaId: 'bazzi',
      surah: 3,
      ayah: 103,
      word: 5,
      count: 1,
      text: 'تَّفَرَّقُواْ',
      kind: VariantKind.usul,
      description: 'بتشديد التاء وصلاً مع المد المشبع قبلها',
      rule: 'bazzi_ta',
    );
    final r = manzumat.referenceOf(v, 'تَفَرَّقُواْ', 3, surahs);
    expect(r.poem, Poem.shatibiyya);
    expect(r.mention, {526, 527});
  });

  test("Ibn Kathir's «ءَا۬ن» cites «يُشَفَّعُ أَنْ يُؤْتَى»", () {
    for (final id in ['bazzi', 'qunbul']) {
      final v = Variant(
        riwayaId: id,
        surah: 3,
        ayah: 73,
        word: 11,
        count: 1,
        text: 'ءَا۬ن',
        kind: VariantKind.hamza,
        description: 'بهمزتين مع تسهيل الثانية',
        rule: 'ha_antum',
      );
      final r = manzumat.referenceOf(v, 'أَن', 3, surahs);
      expect(r.mention, {188}, reason: id);
    }
  });

  test("Khalaf's «تَحۡسِبَنَّ» (الأنفال ٥٩) cites «وَيَحْسَبْ أُدْ وَخَاطَبَ فَاعْتَلَا»", () {
    for (final (id, poem, bayt) in [
      ('ishaq', Poem.durrah, 119),
      ('idris', Poem.durrah, 119),
      ('rawh', Poem.shatibiyya, 720),
      ('ruways', Poem.shatibiyya, 720),
    ]) {
      final v = Variant(
        riwayaId: id,
        surah: 8,
        ayah: 59,
        word: 1,
        count: 1,
        text: 'تَحۡسِبَنَّ',
        kind: VariantKind.farsh,
        description: 'بالتاء وكسر السين',
      );
      final r = manzumat.referenceOf(v, 'يَحۡسَبَنَّ', 8, surahs);
      expect(r.poem, poem, reason: id);
      expect(r.mention, {bayt}, reason: id);
    }
  });

  test("Abu Ja'far's «ٱثۡنَآ عۡشَرَ» cites the two bayts it spans", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 9,
        ayah: 36,
        word: 5,
        count: 2,
        text: 'ٱثۡنَآ عۡشَرَ',
        kind: VariantKind.farsh,
        description: 'بإسكان العين ومد الألف مدًّا لازمًا',
      );
      final r = manzumat.referenceOf(v, 'ٱثۡنَا عَشَرَ', 9, surahs);
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {122, 123}, reason: id);
    }
  });

  test(
    "Abu Ja'far's «أُذُنٞ» cites «وَالاذْنُ» with the bayt that rules it",
    () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = Variant(
          riwayaId: id,
          surah: 9,
          ayah: 61,
          word: 6,
          count: 1,
          text: 'أُذُنٞۚ',
          kind: VariantKind.farsh,
          description: 'بضم الذال',
          rule: 'comparison',
        );
        final r = manzumat.referenceOf(
          v,
          'أُذُنٞۚ',
          9,
          surahs,
          entries: book.at(9, 61, 6),
        );
        expect(r.poem, Poem.durrah, reason: id);
        expect(r.mention, {74, 75}, reason: id);
      }
    },
  );

  test("Abu Ja'far's «يَضُرُّكُمۡ» cites its farsh, not its silah", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 3,
        ayah: 120,
        word: 13,
        count: 1,
        text: 'يَضُرُّكُمُۥ',
        kind: VariantKind.usul,
        description: 'بصلة ميم الجمع',
      );
      final r = manzumat.referenceOf(v, 'يَضُرُّكُمۡ', 3, surahs);
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {88}, reason: id);
    }
  });

  test("al-Bazzi's «تَمَنَّوۡنَ» and «تَفَكَّهُونَ» cite their two faces", () {
    for (final (s, a, w, hafs) in [
      (3, 143, 2, 'تَمَنَّوۡنَ'),
      (56, 65, 5, 'تَفَكَّهُونَ'),
    ]) {
      final v = Variant(
        riwayaId: 'bazzi',
        surah: s,
        ayah: a,
        word: w,
        count: 1,
        text: '',
        kind: VariantKind.usul,
        description: 'بوجهين: بتخفيف التاء، وهو المقدم والأرجح؛ وبتشديدها مع المد المشبع',
        rule: 'bazzi_ta',
      );
      final r = manzumat.referenceOf(v, hafs, s, surahs);
      expect(r.poem, Poem.shatibiyya);
      expect(r.mention, {526, 535}, reason: '$s:$a');
    }
  });

  test("«قَٰتَلَ» cites «وَقَاتَلَ بَعْدَهُ يُمَدُّ»", () {
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      final v = Variant(
        riwayaId: id,
        surah: 3,
        ayah: 146,
        word: 3,
        count: 1,
        text: 'قُتِلَ',
        kind: VariantKind.farsh,
        description: 'بضم القاف وحذف الألف وكسر التاء',
      );
      final r = manzumat.referenceOf(v, 'قَٰتَلَ', 3, surahs);
      expect(r.mention, {571}, reason: id);
    }
  });

  test(
    "Abu Ja'far's «يَحۡزُنكَ» cites its couplet, «يَحۡزَنُونَ» does not",
    () {
      Reference of(String hafs, int s, int a, int w, String text) =>
          manzumat.referenceOf(
            Variant(
              riwayaId: 'ibn_wardan',
              surah: s,
              ayah: a,
              word: w,
              count: 1,
              text: text,
              kind: VariantKind.farsh,
            ),
            hafs,
            s,
            surahs,
          );
      expect(of('يَحۡزُنكَ', 3, 176, 1, '').mention, {91});
      expect(of('لَيَحۡزُنُنِيٓ', 12, 13, 2, 'لَيَحۡزُنُنِيَ').mention, {91});
      expect(of('يَحۡزُنُهُمُ', 21, 103, 1, 'يُحۡزِنُهُمُ').mention, {91});
      expect(of('يَحۡزَنُونَ', 2, 38, 13, '').mention, isNot(contains(91)));
    },
  );

  test("Ibn Kathir's «وَقُتِّلُواْ» cites «بِمَا قُتِلُوا التَّشْدِيدُ»", () {
    for (final id in ['bazzi', 'qunbul']) {
      final v = Variant(
        riwayaId: id,
        surah: 3,
        ayah: 195,
        word: 25,
        count: 1,
        text: 'وَقُتِّلُواْ',
        kind: VariantKind.farsh,
        description: 'بتشديد التاء',
      );
      final r = manzumat.referenceOf(v, 'وَقُتِلُواْ', 3, surahs);
      expect(r.mention, {576, 577}, reason: id);
    }
  });

  test("«وَأُحِلَّ» cites «وَضَمٌّ وَكَسْرٌ فِي أَحَلَّ»", () {
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      final v = Variant(
        riwayaId: id,
        surah: 4,
        ayah: 24,
        word: 10,
        count: 1,
        text: 'وَأَحَلَّ',
        kind: VariantKind.farsh,
        description: 'بفتح الهمزة والحاء',
      );
      final r = manzumat.referenceOf(v, 'وَأُحِلَّ', 4, surahs);
      expect(r.mention, {597}, reason: id);
    }
  });

  test("Ibn Kathir's «ٱلۡقُرَانَ» cites «وَنَقْلُ قُرَانٍ» in any sura", () {
    for (final id in ['bazzi', 'qunbul']) {
      for (final (s, a, w, hafs, text) in [
        (2, 185, 5, 'ٱلۡقُرۡءَانُ', 'ٱلۡقُرَانُ'),
        (4, 82, 3, 'ٱلۡقُرۡءَانَۚ', 'ٱلۡقُرَانَۚ'),
        (17, 88, 12, 'قُرۡءَانٗا', 'قُرَانٗا'),
      ]) {
        final v = Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: w,
          count: 1,
          text: text,
          kind: VariantKind.hamza,
          description: 'بفتح الراء وحذف الهمزة',
        );
        final r = manzumat.referenceOf(v, hafs, s, surahs);
        expect(r.poem, Poem.shatibiyya, reason: '$id $s:$a');
        expect(r.mention, {502}, reason: '$id $s:$a');
      }
    }
  });

  test("«مُؤۡمِنٗا» of النساء cites «وَأُخْرَى مُؤْمِنًا فَتْحُهُ بَلَا»", () {
    for (final (id, text, d) in [
      ('ibn_wardan', 'مُومَنٗا', 'بإبدال الهمزة واوًا وفتح الميم'),
      ('ibn_jammaz', 'مُومِنٗا', 'بإبدال الهمزة واوًا وكسر الميم'),
    ]) {
      final v = Variant(
        riwayaId: id,
        surah: 4,
        ayah: 94,
        word: 16,
        count: 1,
        text: text,
        kind: VariantKind.hamza,
        description: d,
        rule: 'ibdal_single',
      );
      final r = manzumat.referenceOf(v, 'مُؤۡمِنٗا', 4, surahs);
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {96}, reason: id);
    }
  });

  test('«هَٰٓأَنتُمۡ» of Qalun and Ibn Kathir cites its couplet, all four', () {
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      for (final (s, a) in [(3, 66), (3, 119), (4, 109), (47, 38)]) {
        final v = Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: 0,
          count: 1,
          text: 'هَٰأَنتُمُۥ',
          kind: VariantKind.hamza,
          description: 'بإثبات الألف وهمزة محققة بعدها',
          rule: 'ha_antum',
        );
        final r = manzumat.referenceOf(v, 'هَٰٓأَنتُمۡ', s, surahs);
        expect(r.poem, Poem.shatibiyya, reason: '$id $s:$a');
        expect(r.mention, {559}, reason: '$id $s:$a');
      }
    }
  });

  test("Abu Ja'far's ha sakin cites its couplet, not the hamza's", () {
    for (final (s, a, w, text, d) in [
      (3, 75, 7, 'يُوَدِّهۡ', 'بإبدال الهمزة واوًا وإسكان الهاء'),
      (3, 145, 14, 'نُوتِهۡ', 'بإبدال الهمزة واوًا وإسكان الهاء'),
      (4, 115, 16, 'وَنُصۡلِهۡ', 'بإسكان الهاء'),
    ]) {
      final v = Variant(
        riwayaId: 'ibn_wardan',
        surah: s,
        ayah: a,
        word: w,
        count: 1,
        text: text,
        kind: VariantKind.hamza,
        description: d,
      );
      final r = manzumat.referenceOf(v, text, s, surahs);
      expect(r.poem, Poem.durrah, reason: '$s:$a');
      expect(r.mention, {18}, reason: '$s:$a');
    }
  });

  test("Abu Ja'far's «أَمَانِي» cites «خِفُّ الْأَمَانِيَ»", () {
    for (final (s, a, w, hafs, text) in [
      (2, 111, 11, 'أَمَانِيُّهُمۡۗ', 'أَمَانِيهِمُۥ'),
      (4, 123, 1, 'بِأَمَانِيِّكُمۡ', 'بِأَمَانِيكُمُۥ'),
      (4, 123, 3, 'أَمَانِيِّ', 'أَمَانِي'),
    ]) {
      final v = Variant(
        riwayaId: 'ibn_jammaz',
        surah: s,
        ayah: a,
        word: w,
        count: 1,
        text: text,
        kind: VariantKind.farsh,
        description: 'بإسكان الياء',
      );
      final r = manzumat.referenceOf(v, hafs, s, surahs);
      expect(r.poem, Poem.durrah, reason: '$s:$a');
      expect(r.mention, {66}, reason: '$s:$a');
    }
  });

  test('the first of two sakins cites its couplet, in any sura', () {
    Reference of(String id, String text, String rule) => manzumat.referenceOf(
      Variant(
        riwayaId: id,
        surah: 5,
        ayah: 3,
        word: 50,
        count: 1,
        text: text,
        kind: VariantKind.usul,
        description: 'بضم النون لالتقاء الساكنين',
        rule: rule,
      ),
      'فَمَنِ',
      5,
      surahs,
    );
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      final r = of(id, 'فَمَنُ', 'first_sakin');
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {495}, reason: id);
    }
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final r = of(id, 'فَمَنُ', 'first_sakin');
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {72, 73}, reason: id);
      expect(of(id, 'ٱضۡطِرَّ', '').mention, {72, 73}, reason: id);
      expect(of(id, 'نَضۡطَرُّهُمُۥ', '').mention, isNot(contains(72)));
    }
  });

  test("Abu Ja'far's «مِنِ ٱجۡلِ» cites «مِنِ اجْلِ اكْسِرْ انْقُلْ أُدْ»", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 5,
        ayah: 32,
        word: 0,
        count: 2,
        text: 'مِنِ ٱجۡلِ',
        kind: VariantKind.hamza,
        description: 'بكسر الهمزة ونقل حركتها إلى النون',
        rule: 'naql',
      );
      final r = manzumat.referenceOf(v, 'مِنۡ أَجۡلِ', 5, surahs);
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {100}, reason: id);
    }
  });

  test('the reviewed verses stand before what the book quotes', () {
    Reference of(
      String id,
      int s,
      int a,
      int w,
      String hafs,
      String text,
      VariantKind kind,
      String d, [
      String rule = '',
    ]) => manzumat.referenceOf(
      Variant(
        riwayaId: id,
        surah: s,
        ayah: a,
        word: w,
        count: 1,
        text: text,
        kind: kind,
        description: d,
        rule: rule,
      ),
      hafs,
      s,
      surahs,
      entries: book.at(s, a, w),
    );
    const f = VariantKind.farsh, h = VariantKind.hamza, u = VariantKind.usul;
    for (final (r, want) in [
      (
        of('qalun', 5, 45, 10, 'وَٱلۡأُذُنَ', 'وَالْأُذْنَ', f, 'بإسكان الذال'),
        617,
      ),
      (
        of('qalun', 5, 45, 11, 'بِٱلۡأُذُنِ', 'بِالْأُذْنِ', f, 'بإسكان الذال'),
        617,
      ),
      (of('qalun', 9, 61, 6, 'أُذُنٞۚ', 'أُذْنٞۖ', f, 'بإسكان الذال'), 617),
      (of('warsh', 69, 12, 4, 'أُذُنٞ', 'أُذْنٞ', f, 'بإسكان الذال'), 617),
      (
        of(
          'bazzi',
          4,
          82,
          3,
          'ٱلۡقُرۡءَانَۚ',
          'ٱلۡقُرَانَۚ',
          h,
          'بفتح الراء وحذف الهمزة',
        ),
        502,
      ),
      (
        of(
          'qunbul',
          2,
          185,
          5,
          'ٱلۡقُرۡءَانُ',
          'ٱلۡقُرَانُ',
          h,
          'بفتح الراء وحذف الهمزة',
        ),
        502,
      ),
      (
        of(
          'qalun',
          3,
          146,
          3,
          'قَٰتَلَ',
          'قُتِلَۖ',
          f,
          'بضم القاف وحذف الألف وكسر التاء',
        ),
        571,
      ),
      (
        of(
          'bazzi',
          3,
          146,
          3,
          'قَٰتَلَ',
          'قُتِلَ',
          f,
          'بضم القاف وحذف الألف وكسر التاء',
        ),
        571,
      ),
      (
        of(
          'qalun',
          3,
          66,
          0,
          'هَٰٓأَنتُمۡ',
          'هَٰا۬نتُمُۥ',
          h,
          'بإثبات الألف وهمزة مسهلة',
          'ha_antum',
        ),
        559,
      ),
      (
        of(
          'qunbul',
          4,
          109,
          0,
          'هَٰٓأَنتُمۡ',
          'هَأَنتُمُۥ',
          h,
          'بحذف الألف مع تحقيق الهمزة',
          'ha_antum',
        ),
        559,
      ),
      (
        of(
          'bazzi',
          3,
          73,
          11,
          'أَن',
          'ءَا۬ن',
          h,
          'بهمزتين مع تسهيل الثانية',
          'ha_antum',
        ),
        188,
      ),
      (
        of(
          'bazzi',
          3,
          195,
          25,
          'وَقُتِلُواْ',
          'وَقُتِّلُواْ',
          f,
          'بتشديد التاء',
        ),
        576,
      ),
      (
        of(
          'qalun',
          5,
          3,
          50,
          'فَمَنِ',
          'فَمَنُ',
          u,
          'بضم النون لالتقاء الساكنين',
          'first_sakin',
        ),
        495,
      ),
      (
        of(
          'ibn_wardan',
          5,
          3,
          50,
          'فَمَنِ',
          'فَمَنُ',
          u,
          'بضم النون لالتقاء الساكنين',
          'first_sakin',
        ),
        72,
      ),
      (of('ibn_wardan', 5, 3, 51, 'ٱضۡطُرَّ', 'ٱضۡطِرَّ', f, 'بكسر الطاء'), 73),
      (
        of(
          'ibn_wardan',
          3,
          66,
          0,
          'هَٰٓأَنتُمۡ',
          'هَٰا۬نتُمُۥ',
          h,
          'بإثبات الألف وهمزة مسهلة',
          'ha_antum',
        ),
        34,
      ),
      (
        of(
          'ibn_wardan',
          3,
          75,
          7,
          'يُؤَدِّهِۦٓ',
          'يُوَدِّهۡ',
          h,
          'بإبدال الهمزة واوًا وإسكان الهاء',
          'ibdal_single',
        ),
        18,
      ),
      (
        of(
          'ibn_wardan',
          4,
          123,
          1,
          'بِأَمَانِيِّكُمۡ',
          'بِأَمَانِيكُمُۥ',
          f,
          'بإسكان الياء',
        ),
        66,
      ),
      (of('ibn_wardan', 3, 176, 1, 'يَحۡزُنكَ', '', f, ''), 91),
      (
        of(
          'ibn_wardan',
          3,
          146,
          0,
          'وَكَأَيِّن',
          'وَكَآئِ۬ن',
          f,
          'بألف بعد الكاف',
        ),
        34,
      ),
      (
        of(
          'ibn_wardan',
          5,
          32,
          0,
          'مِنۡ أَجۡلِ',
          'مِنِ ٱجۡلِ',
          h,
          'بكسر الهمزة ونقل حركتها إلى النون',
          'naql',
        ),
        100,
      ),
      (
        of(
          'ibn_wardan',
          4,
          94,
          16,
          'مُؤۡمِنٗا',
          'مُومَنٗا',
          h,
          'بإبدال الهمزة واوًا وفتح الميم',
          'ibdal_single',
        ),
        96,
      ),
      (
        of(
          'ibn_wardan',
          3,
          91,
          10,
          'مِّلۡءُ',
          'مِلُ',
          h,
          'بضم اللام وحذف الهمزة',
          'naql',
        ),
        36,
      ),
      (
        of(
          'ibn_wardan',
          3,
          120,
          13,
          'يَضُرُّكُمۡ',
          'يَضُرُّكُمُۥ',
          u,
          'بصلة ميم الجمع',
        ),
        88,
      ),
    ]) {
      expect(r.mention, contains(want), reason: '$want ${r.chapter}');
    }
  });

  test('«ٱسۡتُحِقَّ» cites «وَضَمَّ اسْتُحِقَّ» for every reader', () {
    for (final id in [
      'qalun',
      'bazzi',
      'warsh',
      'ibn_wardan',
      'ruways',
      'idris',
    ]) {
      final v = Variant(
        riwayaId: id,
        surah: 5,
        ayah: 107,
        word: 11,
        count: 1,
        text: 'ٱسۡتُحِقَّ',
        kind: VariantKind.farsh,
        description: 'بضم التاء وكسر الحاء',
      );
      final r = manzumat.referenceOf(
        v,
        'ٱسۡتَحَقَّ',
        5,
        surahs,
        entries: book.at(5, 107, 11),
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {627}, reason: id);
    }
  });

  test('«طَٰٓئِرَۢا» cites its couplet in each poem', () {
    Reference of(String id, int s, int a, int w, String hafs) =>
        manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: s,
            ayah: a,
            word: w,
            count: 1,
            text: 'طَٰٓئِرَۢا',
            kind: VariantKind.farsh,
            description: 'بألف بعد الطاء وبعدها همزة مكسورة',
          ),
          hafs,
          s,
          surahs,
          entries: book.at(s, a, w),
        );
    for (final id in ['qalun', 'warsh']) {
      expect(of(id, 3, 49, 20, 'طَيۡرَۢا').mention, {558}, reason: id);
      expect(of(id, 5, 110, 36, 'طَيۡرَۢا').mention, {558}, reason: id);
    }
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      expect(of(id, 3, 49, 16, 'ٱلطَّيۡرِ').mention, {87}, reason: id);
      expect(of(id, 3, 49, 20, 'طَيۡرَۢا').mention, {87}, reason: id);
      expect(of(id, 5, 110, 31, 'ٱلطَّيۡرِ').mention, {87}, reason: id);
      expect(of(id, 5, 110, 36, 'طَيۡرَۢا').mention, {87}, reason: id);
    }
  });

  test("Ibn Kathir's «يُنزِلَ» cites «وَيُنْزِلُ خَفِّفْهُ»", () {
    Reference of(int s, int a, int w, String text, String hafs) =>
        manzumat.referenceOf(
          Variant(
            riwayaId: 'bazzi',
            surah: s,
            ayah: a,
            word: w,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: 'بإسكان النون وتخفيف الزاي',
          ),
          hafs,
          s,
          surahs,
          entries: book.at(s, a, w),
        );
    expect(of(5, 112, 10, 'يُنزِلَ', 'يُنَزِّلَ').mention, {468});
    expect(of(2, 90, 11, 'يُنزِلَ', 'يُنَزِّلَ').mention, {468});
    // Its own line, which the book quotes too.
    expect(of(6, 37, 13, 'يُنزِلَ', 'يُنَزِّلَ').mention, contains(469));
  });

  test('the ya before a hamza with a damma cites its couplet in each poem', () {
    Reference of(String id, int s, int a, int w) => manzumat.referenceOf(
      Variant(
        riwayaId: id,
        surah: s,
        ayah: a,
        word: w,
        count: 1,
        text: 'فَإِنِّيَ',
        kind: VariantKind.usul,
        description: 'بفتح الياء',
        rule: 'ya_idafa',
      ),
      'فَإِنِّيٓ',
      s,
      surahs,
      entries: book.at(s, a, w),
    );
    expect(of('qalun', 5, 115, 9).mention, {405, 406});
    expect(of('qalun', 3, 36, 17).mention, {405, 406});
    expect(of('ibn_wardan', 5, 115, 9).mention, {52});
    expect(of('ibn_jammaz', 39, 11, 1).mention, {52});
  });

  test("Abu Ja'far's «يَسۡتَهۡزُونَ» cites «وَيَحْذِفُ مُسْتَهْزُونَ»", () {
    Reference of(int s, int a, int w, String text, String hafs, String d) =>
        manzumat.referenceOf(
          Variant(
            riwayaId: 'ibn_wardan',
            surah: s,
            ayah: a,
            word: w,
            count: 1,
            text: text,
            kind: VariantKind.hamza,
            description: d,
            rule: 'hamza_hadhf',
          ),
          hafs,
          s,
          surahs,
          entries: book.at(s, a, w),
        );
    const d = 'بضم الزاي وحذف الهمزة';
    expect(of(6, 5, 11, 'يَسۡتَهۡزُونَ', 'يَسۡتَهۡزِءُونَ', d).mention, {32});
    expect(of(2, 14, 15, 'مُسۡتَهۡزُونَ', 'مُسۡتَهۡزِءُونَ', d).mention, {32});
    expect(
      of(
        21,
        41,
        12,
        'يَسۡتَهۡزُونَ',
        'يَسۡتَهۡزِءُونَ',
        'بضم الزاء وحذف الهمزة',
      ).mention,
      {32},
    );
    expect(
      of(
        15,
        95,
        2,
        'ٱلۡمُسۡتَهۡزِينَ',
        'ٱلۡمُسۡتَهۡزِءِينَ',
        'بحذف الهمزة بعد الزاي',
      ).mention,
      {32, 33},
    );
  });

  test('«إِنَّهُۥ مَنۡ عَمِلَ» cites «وَإِنَّ بِفَتْحٍ عَمَّ نَصْرًا»', () {
    for (final (id, w) in [('bazzi', 13), ('qunbul', 24), ('qalun', 24)]) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 54,
        word: w,
        count: 1,
        text: 'إِنَّهُۥ',
        kind: VariantKind.farsh,
        description: 'بكسر الهمزة',
      );
      final r = manzumat.referenceOf(
        v,
        'أَنَّهُۥ',
        6,
        surahs,
        entries: book.at(6, 54, w),
      );
      expect(r.mention, {641}, reason: '$id $w');
    }
  });

  test("Abu Ja'far's «فَإِنَّهُۥ» cites «وَحُزْ فَتْحَ إِنَّهْ»", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 54,
        word: 24,
        count: 1,
        text: 'فَإِنَّهُۥ',
        kind: VariantKind.farsh,
        description: 'بكسر الهمزة',
      );
      final r = manzumat.referenceOf(
        v,
        'فَأَنَّهُۥ',
        6,
        surahs,
        entries: book.at(6, 54, 24),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {106}, reason: id);
    }
  });

  test("Qalun's «وَمَحْيَايْ» cites «وَمَحْيَايَ وَالإِسْكَانُ»", () {
    final v = Variant(
      riwayaId: 'qalun',
      surah: 6,
      ayah: 162,
      word: 4,
      count: 1,
      text: 'وَمَحْيَايْ',
      kind: VariantKind.farsh,
      description: 'بإسكان الياء مع المد المشبع',
    );
    final r = manzumat.referenceOf(
      v,
      'وَمَحۡيَايَ',
      6,
      surahs,
      entries: book.at(6, 162, 4),
    );
    expect(r.poem, Poem.shatibiyya);
    expect(r.mention, {680});
  });

  test("Abu Ja'far's «كَهَيَّةِ» cites «وَجُزْءًا ادْغِمْ كَهَيْئَهْ»", () {
    for (final (s, a, w) in const [(3, 49, 15), (5, 110, 30)]) {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: w,
          count: 1,
          text: 'كَهَيَّةِ',
          kind: VariantKind.hamza,
          description: 'بإبدال الهمزة ياءً وإدغام الياء فيها',
          rule: 'ibdal_single',
        );
        final r = manzumat.referenceOf(
          v,
          'كَهَيۡـَٔةِ',
          s,
          surahs,
          entries: book.at(s, a, w),
        );
        expect(r.poem, Poem.durrah, reason: '$id $s:$a');
        expect(r.mention, {33}, reason: '$id $s:$a');
      }
    }
  });

  test("Abu Ja'far's «وَمَحْيَايْ» cites «وَغَيْرَ مَحْيَايَ»", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 162,
        word: 4,
        count: 1,
        text: 'وَمَحْيَايْ',
        kind: VariantKind.farsh,
        description: 'بإسكان الياء مع المد المشبع',
      );
      final r = manzumat.referenceOf(
        v,
        'وَمَحۡيَايَ',
        6,
        surahs,
        entries: book.at(6, 162, 4),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {53}, reason: id);
    }
  });

  test('«وَأَنَا» of الأنعام ١٦٣ cites «وَمَدُّ أَنَا فِي الْوَصْلِ»', () {
    for (final id in ['qalun', 'ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 163,
        word: 5,
        count: 1,
        text: 'وَأَنَا',
        kind: VariantKind.usul,
        description: 'بإثبات الألف وصلاً',
        rule: 'ana_madd',
      );
      final r = manzumat.referenceOf(
        v,
        'وَأَنَا۠',
        6,
        surahs,
        entries: book.at(6, 163, 5),
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {521}, reason: id);
    }
  });

  test('«أُكْلُهُۥ» and «حِصَادِهِۦ» of الأنعام ١٤١ cite their verses', () {
    for (final (id, w, hafs, text, how, cited) in const [
      ('qalun', 10, 'أُكُلُهُۥ', 'أُكْلُهُۥ', 'بإسكان الكاف', {524}),
      ('bazzi', 10, 'أُكُلُهُۥ', 'أُكۡلُهُۥ', 'بإسكان الكاف', {524}),
      ('qunbul', 10, 'أُكُلُهُۥ', 'أُكۡلُهُۥ', 'بإسكان الكاف', {524}),
      ('qalun', 24, 'حَصَادِهِۦ', 'حِصَادِهِۦ', 'بكسر الحاء', {675, 676}),
      ('bazzi', 24, 'حَصَادِهِۦ', 'حِصَادِهِۦ', 'بكسر الحاء', {675, 676}),
      ('ibn_wardan', 24, 'حَصَادِهِۦ', 'حِصَادِهِۦ', 'بكسر الحاء', {675, 676}),
      ('ibn_jammaz', 24, 'حَصَادِهِۦ', 'حِصَادِهِۦ', 'بكسر الحاء', {675, 676}),
    ]) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 141,
        word: w,
        count: 1,
        text: text,
        kind: VariantKind.farsh,
        description: how,
      );
      final r = manzumat.referenceOf(
        v,
        hafs,
        6,
        surahs,
        entries: book.at(6, 141, w),
      );
      expect(r.poem, Poem.shatibiyya, reason: '$id $w');
      expect(r.mention, cited, reason: '$id $w');
    }
  });

  test('«وَخَرَّقُواْ» cites «خَرَّقُوا ثِقْلُهُ انْجَلَا»', () {
    for (final id in ['qalun', 'ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 100,
        word: 5,
        count: 1,
        text: 'وَخَرَّقُواْ',
        kind: VariantKind.farsh,
        description: 'بتشديد الراء',
      );
      final r = manzumat.referenceOf(
        v,
        'وَخَرَّقُواْ',
        6,
        surahs,
        entries: book.at(6, 100, 5),
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {656}, reason: id);
    }
  });

  test("«لَسِحۡرٞ» (يونس ٢), Abu Ja'far's as Qalun's: «سَاحِرٌ ظُبَى»", () {
    for (final id in ['qalun', 'warsh', 'ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 10,
        ayah: 2,
        word: 24,
        count: 1,
        text: 'لَسِحۡرٞ',
        kind: VariantKind.farsh,
        description: 'بكسر السين وحذف الألف وإسكان الحاء',
      );
      final r = manzumat.referenceOf(
        v,
        'لَسَٰحِرٞ',
        10,
        surahs,
        entries: book.at(10, 2, 24),
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {742}, reason: id);
    }
  });

  test(
    "«تَذَّكَّرُونَ» cites «وَتَذَّكَّرُونَ الْكُلُّ خَفَّ عَلَى شَذَا», Abu "
    "Ja'far's with the Durrah's asl; Qunbul's «ضِئَآءٗ» «وَحَيْثُ ضِيَاءً»",
    () {
      for (final id in [
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      ]) {
        final v = Variant(
          riwayaId: id,
          surah: 10,
          ayah: 3,
          word: 28,
          count: 1,
          text: 'تَذَّكَّرُونَ',
          kind: VariantKind.farsh,
          description: 'بتشديد الذال',
        );
        final r = manzumat.referenceOf(
          v,
          'تَذَكَّرُونَ',
          10,
          surahs,
          entries: book.at(10, 3, 28),
        );
        // Abu Ja'far's from the Durrah alone: as Nafi', it silent.
        // Abu Ja'far's: the Durrah silent, its asl's two bayts before it.
        expect(r.poem, Poem.shatibiyya, reason: id);
        expect(r.mention, {677}, reason: id);
        expect(
          [for (final b in r.asl) b.n],
          id.startsWith('ibn_') ? [7, 8] : isEmpty,
          reason: id,
        );
      }
      for (final (s, a, w) in [(10, 5, 4), (21, 48, 5), (28, 71, 16)]) {
        final v = Variant(
          riwayaId: 'qunbul',
          surah: s,
          ayah: a,
          word: w,
          count: 1,
          text: 'ضِئَآءٗ',
          kind: VariantKind.farsh,
          description: 'بإبدال الياء همزة مفتوحة',
        );
        final r = manzumat.referenceOf(
          v,
          'ضِيَآءٗ',
          s,
          surahs,
          entries: book.at(s, a, w),
        );
        expect(r.mention, {742}, reason: '$s:$a');
      }
    },
  );

  test(
    "Ibn Kathir's «وَلَا۟ أَدۡرَىٰكُمُۥ» cites «وَقَصْرُ وَلاَ هَادٍ بِخُلْفٍ "
    "زَكَا»",
    () {
      for (final id in ['bazzi', 'qunbul']) {
        final v = Variant(
          riwayaId: id,
          surah: 10,
          ayah: 16,
          word: 7,
          count: 2,
          text: 'وَلَا۟ أَدۡرَىٰكُمُۥ',
          kind: VariantKind.farsh,
          description: 'بقصر اللام أي بحذف المد بعدها',
        );
        final r = manzumat.referenceOf(
          v,
          'وَلَآ',
          10,
          surahs,
          entries: book.at(10, 16, 7),
        );
        expect(r.poem, Poem.shatibiyya, reason: id);
        expect(r.mention, {744}, reason: id);
      }
    },
  );

  test("Abu Ja'far's «تَجۡمَعُونَ» cites «يَجْمَعُوا طَلَى» and «إِذًا»", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 10,
        ayah: 58,
        word: 9,
        count: 1,
        text: 'تَجۡمَعُونَ',
        kind: VariantKind.farsh,
        description: 'بالتاء',
      );
      final r = manzumat.referenceOf(
        v,
        'يَجۡمَعُونَ',
        10,
        surahs,
        entries: book.at(10, 58, 9),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {129, 130}, reason: id);
    }
  });

  test("Abu Ja'far's «ءَآلسِّحۡرُ» cites «اسْئَلَا» and «ءَأَلسِّحْرُ أَمْ أَخْبِرْ»; "
      "Khalaf's «فَسَلِ» «وَسَلْ مَعْ فَسَلْ فَشَا»", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 10,
        ayah: 81,
        word: 7,
        count: 1,
        text: 'ءَآلسِّحۡرُ',
        kind: VariantKind.hamza,
        rule: 'hamza_wasl',
        description: 'بوجهين',
      );
      final r = manzumat.referenceOf(
        v,
        'ٱلسِّحۡرُۖ',
        10,
        surahs,
        entries: book.at(10, 81, 7),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {130, 131}, reason: id);
    }
    for (final id in ['ishaq', 'idris']) {
      for (final (s, a, w) in [(10, 94, 7), (4, 32, 17), (43, 45, 0)]) {
        final v = Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: w,
          count: 1,
          text: 'فَسَلِ',
          kind: VariantKind.farsh,
          description: 'بفتح السين وحذف الهمزة',
        );
        final r = manzumat.referenceOf(
          v,
          'فَسۡـَٔلِ',
          s,
          surahs,
          entries: book.at(s, a, w),
        );
        expect(r.poem, Poem.durrah, reason: '$id $s:$a');
        expect(r.mention, {37}, reason: '$id $s:$a');
      }
    }
  });

  test(
    "Hud: Abu Ja'far's «يُضَعَّفُ» and «أَنِّي لَكُمۡ» from the Durrah; "
    "«مُجۡرَىٰهَا» «يَٰبُنَيِّ» and «ٱرۡكَب مَّعَنَا» from the Shatibiyya",
    () {
      Reference ref(
        String id,
        int a,
        int w,
        String text,
        String hafs, {
        String description = '',
        String rule = '',
        bool usul = false,
      }) {
        final v = Variant(
          riwayaId: id,
          surah: 11,
          ayah: a,
          word: w,
          count: 1,
          text: text,
          kind: usul ? VariantKind.usul : VariantKind.farsh,
          description: description,
          rule: rule,
        );
        return manzumat.referenceOf(
          v,
          hafs,
          11,
          surahs,
          entries: book.at(11, a, w),
        );
      }

      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final da = ref(
          id,
          20,
          14,
          'يُضَعَّفُ',
          'يُضَٰعَفُ',
          description: 'بحذف الألف وتشديد العين',
        );
        expect(da.poem, Poem.durrah, reason: id);
        expect(da.mention, {81}, reason: id);
        final anni = ref(
          id,
          25,
          5,
          'أَنِّي',
          'إِنِّي',
          description: 'بفتح الهمزة',
        );
        expect(anni.poem, Poem.durrah, reason: id);
        expect(anni.mention, {131}, reason: id);
        final irkab = ref(
          id,
          42,
          13,
          'ٱرۡكَبۡ مَعَنَا',
          'ٱرۡكَب',
          description: 'بالإظهار',
        );
        expect(irkab.poem, Poem.durrah, reason: id);
        expect(irkab.mention, {41}, reason: id);
      }
      for (final id in ['qalun', 'bazzi', 'qunbul']) {
        final majraha = ref(
          id,
          41,
          5,
          'مُجۡرَىٰهَا',
          'مَجۡر۪ىٰهَا',
          description: 'بضم الميم وفتح الراء وعدم إمالتها',
        );
        expect(majraha.poem, Poem.shatibiyya, reason: id);
        expect(majraha.mention, {757}, reason: id);
        final bunayya = ref(
          id,
          42,
          12,
          'يَٰبُنَيِّ',
          'يَٰبُنَيَّ',
          description: 'بكسر الياء',
        );
        expect(bunayya.poem, Poem.shatibiyya, reason: id);
        expect(bunayya.mention, {757}, reason: id);
        final irkab = ref(
          id,
          42,
          13,
          'ٱرۡكَب مَّعَنَا',
          'ٱرۡكَب',
          description: 'بإدغام الباء في الميم',
          rule: 'idgham_saghir',
          usul: true,
        );
        expect(irkab.poem, Poem.shatibiyya, reason: id);
        expect(irkab.mention, {284}, reason: id);
        final salat = ref(
          id,
          87,
          2,
          'أَصَلَوَٰتُكَ',
          'أَصَلَوٰتُكَ',
          description: 'بالجمع',
        );
        expect(salat.poem, Poem.shatibiyya, reason: id);
        expect(salat.mention, {733, 734}, reason: id);
        if (id != 'qalun') {
          final nasha = manzumat.referenceOf(
            Variant(
              riwayaId: id,
              surah: 12,
              ayah: 56,
              word: 8,
              count: 1,
              text: 'نَشَآءُۚ',
              kind: VariantKind.farsh,
              description: 'بالنون',
            ),
            'يَشَآءُۚ',
            12,
            surahs,
            entries: book.at(12, 56, 8),
          );
          expect(nasha.poem, Poem.shatibiyya, reason: id);
          expect(nasha.mention, {780}, reason: id);
          final ansani = manzumat.referenceOf(
            Variant(
              riwayaId: id,
              surah: 18,
              ayah: 63,
              word: 10,
              count: 1,
              text: 'أَنسَىٰنِيهِۦ',
              kind: VariantKind.farsh,
              description: 'بكسر الهاء',
            ),
            'أَنسَىٰنِيهُ',
            18,
            surahs,
            entries: book.at(18, 63, 10),
          );
          expect(ansani.poem, Poem.shatibiyya, reason: id);
          expect(ansani.mention, {844}, reason: id);
          for (final (a, w, text, n) in [
            (87, 12, 'نُّكۡرٗا', 618),
            (93, 4, 'ٱلسَّدَّيۡنِ', 851),
            (94, 18, 'سَدّٗا', 851),
            (98, 10, 'دَكًّا', 697),
          ]) {
            final r = manzumat.referenceOf(
              Variant(
                riwayaId: id,
                surah: 18,
                ayah: a,
                word: w,
                count: 1,
                text: text,
                kind: VariantKind.farsh,
              ),
              text,
              18,
              surahs,
              entries: book.at(18, a, w),
            );
            expect(r.mention, {n}, reason: '$id $a');
          }
          for (final (a, w, text, hafs, n) in [
            (70, 4, 'تَسۡـَٔلۡنِي', 'تَسۡـَٔلۡنِي', 760),
            (74, 15, 'نُّكۡرٗا', 'نُّكۡرٗا', 618),
          ]) {
            final r = manzumat.referenceOf(
              Variant(
                riwayaId: id,
                surah: 18,
                ayah: a,
                word: w,
                count: 1,
                text: text,
                kind: VariantKind.farsh,
              ),
              hafs,
              18,
              surahs,
              entries: book.at(18, a, w),
            );
            expect(r.mention, {n}, reason: '$id $a');
          }
          final rubama = manzumat.referenceOf(
            Variant(
              riwayaId: id,
              surah: 15,
              ayah: 2,
              word: 0,
              count: 1,
              text: 'رُّبَّمَا',
              kind: VariantKind.farsh,
              description: 'بتشديد الباء',
            ),
            'رُّبَمَا',
            15,
            surahs,
            entries: book.at(15, 2, 0),
          );
          expect(rubama.poem, Poem.shatibiyya, reason: id);
          expect(rubama.mention, {802}, reason: id);
          final kaain = manzumat.referenceOf(
            Variant(
              riwayaId: id,
              surah: 12,
              ayah: 105,
              word: 0,
              count: 1,
              // As the riwaya's file writes it: the alif, then its madd.
              // As the riwaya's file writes it: the alif, then its madd.
              text: 'وَكَآئِن',
              kind: VariantKind.farsh,
              description: 'بإثبات الألف وكسر الهمزة وحذف الياء والمد',
            ),
            'وَكَأَيِّن',
            12,
            surahs,
            entries: book.at(12, 105, 0),
          );
          expect(kaain.poem, Poem.shatibiyya, reason: id);
          expect(kaain.mention, {570}, reason: id);
          if (id == 'bazzi') {
            for (final (s, a, w) in [(12, 80, 1), (12, 87, 7), (13, 31, 19)]) {
              final yas = manzumat.referenceOf(
                Variant(
                  riwayaId: id,
                  surah: s,
                  ayah: a,
                  word: w,
                  count: 1,
                  text: 'ٱسۡتَٰيَسُواْ',
                  kind: VariantKind.hamza,
                  rule: 'hamza_hadhf',
                  description: 'بخلف',
                ),
                'ٱسۡتَيۡـَٔسُواْ',
                s,
                surahs,
                entries: book.at(s, a, w),
              );
              expect(yas.poem, Poem.shatibiyya, reason: '$s:$a');
              expect(yas.mention, {782}, reason: '$s:$a');
            }
          }
          for (final (s, a, w, hafs) in [
            (12, 82, 0, 'وَسۡـَٔلِ'),
            (4, 32, 17, 'وَسۡـَٔلُواْ'),
          ]) {
            final sal = manzumat.referenceOf(
              Variant(
                riwayaId: id,
                surah: s,
                ayah: a,
                word: w,
                count: 1,
                text: 'وَسَلِ',
                kind: VariantKind.hamza,
                description: 'بنقل حركة الهمزة إلى السين وحذف الهمزة',
              ),
              hafs,
              s,
              surahs,
              entries: book.at(s, a, w),
            );
            expect(sal.poem, Poem.shatibiyya, reason: '$id $s:$a');
            expect(sal.mention, {598}, reason: '$id $s:$a');
          }
        }
      }
      // Abu Ja'far's «سَعِدُواْ» (هود ١٠٨), the Durrah silent: its asl's two,
      // then Nafi''s bayt, «وَفِي سَعِدُوا فَاضْمُمْ صِحَابًا».
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final sa = ref(
          id,
          108,
          2,
          'سَعِدُواْ',
          'سُعِدُواْ',
          description: 'بفتح السين',
        );
        expect(sa.poem, Poem.shatibiyya, reason: id);
        expect(sa.mention, {766}, reason: id);
        expect([for (final b in sa.asl) b.n], [7, 8], reason: id);
        final inna = ref(
          id,
          111,
          0,
          'وَإِنَّ',
          'وَإِنَّ',
          description: 'بتشديد النون',
        );
        expect(inna.poem, Poem.durrah, reason: id);
        expect(inna.mention, {133}, reason: id);
        final zulaf = ref(
          id,
          114,
          4,
          'وَزُلُفٗا',
          'وَزُلَفٗا',
          description: 'بضم اللام',
        );
        expect(zulaf.poem, Poem.durrah, reason: id);
        expect(zulaf.mention, {134}, reason: id);
        final innaka = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 12,
            ayah: 90,
            word: 1,
            count: 1,
            text: 'إِنَّكَ',
            kind: VariantKind.hamza,
            description: 'بكسر الهمزة وحذف الهمزة',
          ),
          'أَءِنَّكَ',
          12,
          surahs,
          entries: book.at(12, 90, 1),
        );
        expect(innaka.poem, Poem.durrah, reason: id);
        expect(innaka.mention, {24}, reason: id);
        final najzi = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 16,
            ayah: 96,
            word: 7,
            count: 1,
            text: 'وَلَنَجۡزِيَنَّ',
            kind: VariantKind.farsh,
            description: 'بالنون',
          ),
          'وَلَنَجۡزِيَنَّ',
          16,
          surahs,
          entries: book.at(16, 96, 7),
        );
        expect(najzi.poem, Poem.durrah, reason: id);
        expect(najzi.mention, {143}, reason: id);
        final yukhraj = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 17,
            ayah: 13,
            word: 6,
            count: 1,
            text: 'وَيُخۡرَجُ',
            kind: VariantKind.farsh,
            description: 'بياء مضمومة وفتح الراء',
          ),
          'وَنُخۡرِجُ',
          17,
          surahs,
          entries: book.at(17, 13, 6),
        );
        expect(yukhraj.poem, Poem.durrah, reason: id);
        expect(yukhraj.mention, {143, 144}, reason: id);
        final khata = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 17,
            ayah: 31,
            word: 11,
            count: 1,
            text: 'خَطَأً',
            kind: VariantKind.farsh,
            description: 'بفتح الخاء والطاء وبعدهما همزة منونة بالفتح',
          ),
          'خِطۡـٔٗا',
          17,
          surahs,
          entries: book.at(17, 31, 11),
        );
        expect(khata.poem, Poem.durrah, reason: id);
        expect(khata.mention, {145}, reason: id);
        // «وَنَآءَ»: the Shatibiyya's «نَآى أَخِّرْ مَعاً هَمْزَهُ مَلَا», the Durrah's
        // «نَاءَ أُدْ مَعًا» over it.
        for (final (s, a) in [(17, 83), (41, 51)]) {
          final naa = manzumat.referenceOf(
            Variant(
              riwayaId: id,
              surah: s,
              ayah: a,
              word: 5,
              count: 1,
              text: 'وَنَآءَ',
              kind: VariantKind.farsh,
              description: 'بألف بعد النون مع المد المتصل',
            ),
            'وَنَـَٔا',
            s,
            surahs,
            entries: book.at(s, a, 5),
          );
          expect(naa.poem, Poem.shatibiyya, reason: '$id $s');
          expect(naa.mention, {826}, reason: '$id $s');
          expect([for (final b in naa.asl) b.n], [147], reason: '$id $s');
        }
        final allah = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 14,
            ayah: 2,
            word: 0,
            count: 1,
            text: 'ٱللَّهُ',
            kind: VariantKind.farsh,
            description: 'برفع الهاء',
          ),
          'ٱللَّهِ',
          14,
          surahs,
          entries: book.at(14, 2, 0),
        );
        expect(allah.poem, Poem.durrah, reason: id);
        expect(allah.mention, {138}, reason: id);
        final nunji = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 12,
            ayah: 110,
            word: 10,
            count: 1,
            text: 'فَنُـۨجِي',
            kind: VariantKind.farsh,
            description: 'بزيادة النون وتخفيف الجيم وإسكان الياء',
          ),
          'فَنُجِّيَ',
          12,
          surahs,
          entries: book.at(12, 110, 10),
        );
        // The Durrah's «نُجِّيَ حَامِدٌ» is Ya'qub's: its asl's two, then Nafi''s.
        expect(nunji.poem, Poem.shatibiyya, reason: id);
        expect(nunji.mention, isNotEmpty, reason: id);
        expect([for (final b in nunji.asl) b.n], [7, 8], reason: id);
        final ukul = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 13,
            ayah: 4,
            word: 20,
            count: 1,
            text: 'ٱلۡأُكُلِۚ',
            kind: VariantKind.farsh,
            description: 'بضم الكاف',
          ),
          'ٱلۡأُكُلِۚ',
          13,
          surahs,
          entries: book.at(13, 4, 20),
        );
        expect(ukul.poem, Poem.durrah, reason: id);
        expect(ukul.mention, {74, 75}, reason: id);
        final ruub = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 18,
            ayah: 18,
            word: 21,
            count: 1,
            text: 'رُعُبٗا',
            kind: VariantKind.farsh,
            description: 'بضم العين',
          ),
          'رُعۡبٗا',
          18,
          surahs,
          entries: book.at(18, 18, 21),
        );
        expect(ruub.poem, Poem.durrah, reason: id);
        expect(ruub.mention, {74, 75}, reason: id);
        final usr = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 18,
            ayah: 73,
            word: 9,
            count: 1,
            text: 'عُسُرٗا',
            kind: VariantKind.farsh,
            description: 'بضم السين',
          ),
          'عُسۡرٗا',
          18,
          surahs,
          entries: book.at(18, 73, 9),
        );
        expect(usr.poem, Poem.durrah, reason: id);
        expect(usr.mention, {74}, reason: id);
        final yusr = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 18,
            ayah: 88,
            word: 12,
            count: 1,
            text: 'يُسُرٗا',
            kind: VariantKind.farsh,
            description: 'بضم السين',
          ),
          'يُسۡرٗا',
          18,
          surahs,
          entries: book.at(18, 88, 12),
        );
        expect(yusr.mention, {74}, reason: id);
        final ruhm = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 18,
            ayah: 81,
            word: 8,
            count: 1,
            text: 'رُحُمٗا',
            kind: VariantKind.farsh,
            description: 'بضم الحاء',
          ),
          'رُحۡمٗا',
          18,
          surahs,
          entries: book.at(18, 81, 8),
        );
        expect(ruhm.poem, Poem.durrah, reason: id);
        expect(ruhm.mention, {74, 75}, reason: id);
        for (final (a, w) in [(34, 2), (42, 1)]) {
          final thamar = manzumat.referenceOf(
            Variant(
              riwayaId: id,
              surah: 18,
              ayah: a,
              word: w,
              count: 1,
              text: 'بِثَمَرِهِۦ',
              kind: VariantKind.farsh,
              description: 'بفتح الثاء والميم',
            ),
            'بِثَمَرِهِۦ',
            18,
            surahs,
            entries: book.at(18, a, w),
          );
          expect(thamar.poem, Poem.durrah, reason: '$id $a');
          expect(thamar.mention, {148}, reason: '$id $a');
        }
        final yarji = ref(
          id,
          123,
          5,
          'يَرۡجِعُ',
          'يُرۡجَعُ',
          description: 'بفتح الياء وكسر الجيم',
        );
        expect(yarji.poem, Poem.durrah, reason: id);
        expect(yarji.mention, {63, 64}, reason: id);
        final ashar = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 12,
            ayah: 4,
            word: 8,
            count: 1,
            text: 'عۡشَرَ',
            kind: VariantKind.farsh,
            description: 'بإسكان العين',
          ),
          'عَشَرَ',
          12,
          surahs,
          entries: book.at(12, 4, 8),
        );
        expect(ashar.poem, Poem.durrah, reason: id);
        expect(ashar.mention, {122, 123}, reason: id);
        final abata = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 12,
            ayah: 4,
            word: 4,
            count: 1,
            text: 'يَٰأَبَتَ',
            kind: VariantKind.farsh,
            description: 'فتح التاء',
          ),
          'يَٰٓأَبَتِ',
          12,
          surahs,
          entries: book.at(12, 4, 4),
        );
        expect(abata.poem, Poem.durrah, reason: id);
        expect(abata.mention, {136}, reason: id);
      }
      for (final id in ['qalun', 'bazzi', 'qunbul']) {
        for (final (w, text, how) in [
          (0, 'وَإِن', 'بإسكان النون مخففة'),
          (2, 'لَّمَا', 'بتخفيف الميم'),
        ]) {
          final r = ref(id, 111, w, text, '', description: how);
          expect(r.poem, Poem.shatibiyya, reason: '$id $w');
          expect(r.mention, {766, 767}, reason: '$id $w');
        }
      }
    },
  );

  test(
    "the second «نُنَجِّ» (يونس ١٠٣) cites «الْخِفُّ نُنْجِ رِضىً عَلَا» and "
    "«وَذَاكَ هُوَ الثَّانِي», Abu Ja'far's too",
    () {
      for (final id in [
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      ]) {
        final v = Variant(
          riwayaId: id,
          surah: 10,
          ayah: 103,
          word: 8,
          count: 1,
          text: 'نُنَجِّ',
          kind: VariantKind.farsh,
          description: 'بفتح النون وتشديد الجيم',
        );
        final r = manzumat.referenceOf(
          v,
          'نُنجِ',
          10,
          surahs,
          entries: book.at(10, 103, 8),
        );
        expect(r.poem, Poem.shatibiyya, reason: id);
        expect(r.mention, {753, 754}, reason: id);
      }
    },
  );

  test("Abu Ja'far's «يَنشُرُكُمُۥ» cites «وَيَنْشُرُكُمْ أُدْ»", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 10,
        ayah: 22,
        word: 2,
        count: 1,
        text: 'يَنشُرُكُمُۥ',
        kind: VariantKind.farsh,
        description: 'بفتح الياء وبعدها نون ساكنة ثم شين مضمومة',
      );
      final r = manzumat.referenceOf(
        v,
        'يُسَيِّرُكُمۡ',
        10,
        surahs,
        entries: book.at(10, 22, 2),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {128}, reason: id);
    }
  });

  test("Ibn Kathir's «فَمُسۡتَقِرّٞ» cites «وَاكْسِرْ بِمُسْتَقَرْ»", () {
    for (final id in ['bazzi', 'qunbul']) {
      final v = Variant(
        riwayaId: id,
        surah: 6,
        ayah: 98,
        word: 6,
        count: 1,
        text: 'فَمُسۡتَقِرّٞ',
        kind: VariantKind.farsh,
        description: 'بكسر القاف',
      );
      final r = manzumat.referenceOf(
        v,
        'فَمُسۡتَقَرّٞ',
        6,
        surahs,
        entries: book.at(6, 98, 6),
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {656}, reason: id);
    }
  });

  test("Ibn Kathir's «ٱلرِّيحَ» cites 490 and 491, as in الروم", () {
    for (final id in ['bazzi', 'qunbul']) {
      for (final (s, a, w) in [(7, 57, 3), (27, 63, 8), (35, 9, 3)]) {
        final v = Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: w,
          count: 1,
          text: 'ٱلرِّيحَ',
          kind: VariantKind.farsh,
          description: 'بإسكان الياء وحذف الألف',
        );
        final r = manzumat.referenceOf(
          v,
          'ٱلرِّيَٰحَ',
          s,
          surahs,
          entries: book.at(s, a, w),
        );
        expect(r.poem, Poem.shatibiyya, reason: '$id $s:$a');
        expect(r.mention, {490, 491}, reason: '$id $s:$a');
      }
    }
  });

  test("Abu Ja'far's «بَصۡطَةٗ» of الأعراف cites Durrah 81", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 7,
        ayah: 69,
        word: 21,
        count: 1,
        text: 'بَصۡطَةٗ',
        kind: VariantKind.farsh,
        description: 'بالصاد',
      );
      final r = manzumat.referenceOf(
        v,
        'بَصۜۡطَةٗۖ',
        7,
        surahs,
        entries: book.at(7, 69, 21),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {81}, reason: id);
    }
  });

  test("Abu Ja'far's «عَلَىٰٓ» of الأعراف ١٠٥ cites Durrah 115 and 116", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = Variant(
        riwayaId: id,
        surah: 7,
        ayah: 105,
        word: 1,
        count: 1,
        text: 'عَلَىٰٓ',
        kind: VariantKind.farsh,
        rule: 'comparison',
      );
      final r = manzumat.referenceOf(
        v,
        'عَلَىٰٓ',
        7,
        surahs,
        entries: book.at(7, 105, 1),
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {115, 116}, reason: id);
    }
  });

  test('«ءَآمَنتُم» of Ashab al-Silah cites Shatibiyya 189-191', () {
    for (final id in ['qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz']) {
      for (final (s, a, w) in [(7, 123, 2), (20, 71, 1), (26, 49, 1)]) {
        final v = Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: w,
          count: 1,
          text: 'ءَا۬ ٰم',
          kind: VariantKind.hamza,
          rule: 'tasheel_word',
        );
        final r = manzumat.referenceOf(
          v,
          'ءَامَنتُم',
          s,
          surahs,
          entries: book.at(s, a, w),
        );
        expect(r.poem, Poem.shatibiyya, reason: '$id $s:$a');
        expect(r.mention, {189, 190, 191}, reason: '$id $s:$a');
      }
    }
  });

  test("the Durrah's bayts have al-Zubaydi's sharh, its letters put back", () {
    final told = [
      for (final b in manzumat.verses(Poem.durrah))
        if (manzumat.explanation(Poem.durrah, b.n) != null) b.n,
    ];
    expect(told.length, greaterThan(200));
    final e = manzumat.explanation(Poem.durrah, 10)!;
    expect(e.source, contains('الزبيدي'));
    expect(e.text, contains('الاستعاذة'));
    // «أَلَا ... وَقُلْ عَلَى لَهُ» (115-116) told together.
    expect(manzumat.explanation(Poem.durrah, 115), isNotNull);
    final all = {
      for (final b in manzumat.verses(Poem.durrah))
        manzumat.explanation(Poem.durrah, b.n)?.text ?? '',
    }.join(' ');
    // The font's letters: «عمى» for «على»، «ىذا» for «هذا»، «كتابو» for «كتابه».
    for (final wrong in ['عمى', 'ىذا', 'اليمز', 'كتابو', 'ازلت']) {
      // A word of its own: «أعمى»، «العمى» are words.
      expect(
        all,
        isNot(matches(RegExp('(^|[^ء-ي])$wrong([^ء-ي]|\$)'))),
        reason: wrong,
      );
    }
    // The Shatibiyya's, Abu Shama's, as it was.
    expect(
      manzumat.explanation(Poem.shatibiyya, 1)!.source,
      contains('أبو شامة'),
    );
  });

  test('yuqattiluna and wa\'adna of الأعراف cite their verses', () {
    Reference of(String id, int s, int a, int w, String text, String hafs) =>
        manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: s,
            ayah: a,
            word: w,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            rule: 'comparison',
          ),
          hafs,
          s,
          surahs,
          entries: book.at(s, a, w),
        );
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final k = of(id, 7, 161, 17, 'خَطِيٓـَٰٔتُكُمُۥ', 'خَطِيٓـَٰٔتِكُمۡۚ');
      expect(k.poem, Poem.durrah);
      expect(k.mention, {116, 117}, reason: id);
      // «يَبۡطُشُونَ»: the ta with the damma, wherever it comes.
      for (final (s, a, w) in [(7, 195, 7), (28, 19, 4), (44, 16, 1)]) {
        final r = of(id, s, a, w, 'يَبۡطُشُونَ', 'يَبۡطِشُونَ');
        expect(r.poem, Poem.durrah, reason: '$id $s:$a');
        expect(r.mention, {117}, reason: '$id $s:$a');
      }
      // «لَا يَتَّبِعُوكُمۡ»: doubled, as Hafs's.
      final y = of(id, 7, 193, 5, 'يَتَّبِعُوكُمُۥ', 'يَتَّبِعُوكُمۡۚ');
      expect(y.poem, Poem.durrah);
      expect(y.mention, {115}, reason: id);
      // «أَنَا۠ إِلَّا»: short before the broken hamza.
      for (final (s, a, w) in [(7, 188, 22), (26, 115, 1), (46, 9, 20)]) {
        final r = of(id, s, a, w, 'أَنَا۠', 'أَنَا۠');
        expect(r.poem, Poem.durrah, reason: '$id $s:$a');
        expect(r.mention, {118}, reason: '$id $s:$a');
      }
      // «بِيسٍ» (الأعراف ١٦٥): the Durrah tells it not, he reads as Nafi'.
      final b = of(id, 7, 165, 14, 'بِيسٍ', 'بَـِٔيسِۭ');
      expect(b.poem, Poem.shatibiyya, reason: id);
      expect(b.mention, {704}, reason: id);
      final s = of(id, 7, 163, 0, 'وَسۡأَلۡهُمُۥ', 'وَسۡـَٔلۡهُمۡ');
      expect(s.poem, Poem.durrah);
      expect(s.mention, {37}, reason: id);
      final q = of(id, 7, 141, 8, 'يُقَتِّلُونَ', 'يُقَتِّلُونَ');
      expect(q.poem, Poem.durrah);
      expect(q.mention, {115}, reason: id);
      for (final (s, a, w) in [(2, 51, 1), (7, 142, 0), (20, 80, 6)]) {
        final r = of(id, s, a, w, 'وَعَدۡنَا', 'وَٰعَدۡنَا');
        expect(r.poem, Poem.durrah);
        expect(r.mention, {66}, reason: '$id $s:$a');
      }
    }
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      // «طَٰٓئِفٞ»: «وَقُلْ طَائِفٌ طَيْفٌ رِضًى حَقُّهُ».
      final t = of(id, 7, 201, 5, 'طَيۡفٞ', 'طَٰٓئِفٞ');
      expect(t.poem, Poem.shatibiyya, reason: id);
      expect(t.mention, {712}, reason: id);
      for (final (s, a, w) in [(2, 51, 1), (7, 142, 0), (20, 80, 6)]) {
        final r = of(id, s, a, w, 'وَٰعَدۡنَا', 'وَٰعَدۡنَا');
        expect(r.poem, Poem.shatibiyya);
        expect(r.mention, {453}, reason: '$id $s:$a');
      }
    }
  });

  test("Abu Ja'far's «يُنَجِّيكُم» cites «بِثَانٍ أَتَى»", () {
    for (final a in [63, 64]) {
      final v = Variant(
        riwayaId: 'ibn_jammaz',
        surah: 6,
        ayah: a,
        word: 2,
        count: 1,
        text: 'يُنَجِّيكُمُۥ',
        kind: VariantKind.usul,
        description: 'بصلة ميم الجمع',
      );
      final r = manzumat.referenceOf(
        v,
        'يُنَجِّيكُم',
        6,
        surahs,
        entries: book.at(6, a, 2),
      );
      expect(r.poem, Poem.durrah, reason: '$a');
      expect(r.mention, contains(107), reason: '$a');
    }
  });

  test("Abu Ja'far's «يُظۡلَمُونَ» cites «وَلَا يُظْلَمُوا أُدْ»", () {
    final v = Variant(
      riwayaId: 'ibn_wardan',
      surah: 4,
      ayah: 77,
      word: 45,
      count: 1,
      text: 'يُظۡلَمُونَ',
      kind: VariantKind.farsh,
      description: 'بالياء',
    );
    final r = manzumat.referenceOf(v, 'تُظۡلَمُونَ', 4, surahs);
    expect(r.poem, Poem.durrah);
    expect(r.mention, {96});
  });

  test("Abu Ja'far's «وَكَآئِ۬ن» cites «كَائِنْ»", () {
    final v = Variant(
      riwayaId: 'ibn_wardan',
      surah: 3,
      ayah: 146,
      word: 0,
      count: 1,
      text: 'وَكَآئِ۬ن',
      kind: VariantKind.farsh,
      description: 'بألف بعد الكاف وبعدها همزة مكسورة مسهلة ثم نون ساكنة',
    );
    final r = manzumat.referenceOf(v, 'وَكَأَيِّن', 3, surahs);
    expect(r.poem, Poem.durrah);
    expect(r.mention, {34});
  });

  test("Ibn Wardan's «مِلُ» cites «وَأَبْدِلْ أَمَّ مِلْءُ بِهِ انْقُلَا»", () {
    final r = ref(
      'ibn_wardan',
      3,
      'مِّلۡءُ',
      text: 'مِلُ',
      description: 'بضم اللام وحذف الهمزة',
      rule: 'naql',
      kind: VariantKind.hamza,
    );
    expect(r.poem, Poem.durrah);
    expect(r.mention, {36});
  });

  test("Abu Ja'far's «هَٰٓأَنتُمۡ» cites the Durrah", () {
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final r = ref(
        id,
        3,
        'هَٰا۬نتُمُۥ',
        description: 'بإثبات الألف وهمزة مسهلة',
        rule: 'ha_antum',
        kind: VariantKind.hamza,
      );
      expect(r.poem, Poem.durrah, reason: id);
      expect(r.mention, {34}, reason: id);
    }
  });

  test(
    "Qalun's two faces of «ٱلتَّوۡرَىٰةَ» cite «وَبِالْخُلْفِ بَلَّلَا»",
    () {
      for (final surah in [3, 5, 62]) {
        final r = ref(
          'qalun',
          surah,
          'ٱلتَّوۡرَىٰةَ',
          description: 'بالفتح والتقليل، والراجح الفتح',
          rule: 'fath_taqlil',
          kind: VariantKind.usul,
        );
        expect(r.poem, Poem.shatibiyya);
        expect(r.mention, {546}, reason: '$surah');
      }
    },
  );

  test('«سراط» with the sin cites its own verse in every place', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['qunbul', 'ruways', 'qalun', 'khallad']);
    // «وَعَنْدَ سِرَاطٍ وَالسِّرَاطَ لِ قُنْبُلَا»; «وَبِالسِّيْنِ طِبْ».
    for (final (id, verses) in [
      ('qunbul', {108}),
      ('ruways', {10, 11}),
    ]) {
      final sirat = [
        for (final v in variants.allOf(id))
          if (!v.isUsul &&
              v.text.replaceAll(RegExp('[ً-ٰ]'), '').contains('صۜرط'))
            v,
      ];
      expect(sirat.length, greaterThan(40), reason: id);
      for (final v in sirat) {
        final r = manzumat.referenceOf(
          v,
          quran.ayah(v.surah, v.ayah).words[v.word],
          v.surah,
          surahs,
          entries: book.at(v.surah, v.ayah, v.word),
        );
        expect(r.mention, verses, reason: '$id ${v.surah}:${v.ayah}');
      }
    }
    // «وَمَالِكِ يَوْمِ الدِّينِ رَاوِيهِ نَاَصِرٌ», without Hamzah's ishmam.
    for (final id in ['qunbul', 'qalun', 'khallad']) {
      final v = variants.at([id], 1, 4, 0).first;
      final r = manzumat.referenceOf(
        v,
        'مَٰلِكِ',
        1,
        surahs,
        entries: book.at(1, 4, 0),
      );
      expect(r.mention, {108}, reason: id);
    }
  });

  test("Abu Ja'far's «مستهزءون» and its bab are one hamza rule", () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['ibn_wardan', 'ibn_jammaz']);
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final bab = [
        for (final v in variants.allOf(id))
          if (RegExp('تَهۡزِءُونَ|تَهۡزِءُوا')
              .hasMatch(quran.ayah(v.surah, v.ayah).words[v.word]))
            v,
      ];
      expect(bab.length, greaterThan(15), reason: id);
      for (final v in bab) {
        expect(v.kind, VariantKind.hamza, reason: '$id ${v.surah}:${v.ayah}');
        expect(v.description, contains('حذف الهمزة'));
        final r = manzumat.referenceOf(
          v,
          quran.ayah(v.surah, v.ayah).words[v.word],
          v.surah,
          surahs,
          entries: book.at(v.surah, v.ayah, v.word),
        );
        // «وَيَحْذِفُ مُسْتَهْزُونَ وَالْبَابَ مَعْ تَطَوْا يَطَوْا مُتَّكًا».
        expect(r.mention, contains(32), reason: '$id ${v.surah}:${v.ayah}');
      }
      // «أنبُوني» of the book (البقرة ٣١), in the same bab.
      final anbi = variants
          .at([id], 2, 31, 9)
          .where((v) => v.kind == VariantKind.hamza)
          .single;
      expect(anbi.text, 'أَنۢبُونِي');
      expect(manzumat.referenceOf(anbi, 'أَنۢبِـُٔونِي', 2, surahs).mention, {
        32,
      });
    }
    // «مُنْشُونَ خُلْفٌ بَدَا»: Ibn Wardan's two faces, Ibn Jammaz as Hafs.
    final munshi = variants.at(['ibn_wardan'], 56, 72, 5).single;
    expect(munshi.usulWays, hasLength(2));
    expect(munshi.usulWays.first, contains('المقدّم'));
    expect(variants.at(['ibn_jammaz'], 56, 72, 5), isEmpty);
  });

  test(
    'Nafi\'s hamza of «النبيء» and without it in «الصابئين»: usul',
    () async {
      final quran = await QuranRepository.load();
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded([
        'qalun',
        'warsh',
        'ibn_wardan',
        'ibn_jammaz',
      ]);
      for (final id in ['qalun', 'warsh']) {
        final nabiyyin = variants
            .at([id], 2, 61, 51)
            .where((v) => v.rule == 'hamza_zaida')
            .single;
        expect(nabiyyin.isUsul, isTrue, reason: id);
        expect(nabiyyin.inHamesh, isFalse, reason: id);
        expect(nabiyyin.description, isNot(contains('والمد')), reason: id);
        expect(
          nabiyyin.description,
          id == 'warsh'
              ? 'بزيادة الهمزة وإسكان الياء مخففة وحذف الياء مع ثلاثة البدل'
              : 'بزيادة الهمزة وإسكان الياء مخففة وحذف الياء',
        );
        // Its small ya after the hamza, apart from it.
        expect(nabiyyin.text, matches(RegExp('ـ[ِٕ]+ـۧ')), reason: id);
        expect(
          manzumat
              .referenceOf(nabiyyin, quran.ayah(2, 61).words[51], 2, surahs)
              .mention,
          {458},
        );
        // No farsh of the book beside it.
        expect(
          variants.at([id], 2, 61, 51).where((v) => v.inHamesh),
          isEmpty,
          reason: id,
        );
      }
      for (final id in ['qalun', 'warsh', 'ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [(2, 62, 6), (5, 69, 5), (22, 17, 5)]) {
          final rows = variants.at([id], s, a, w).toList();
          final v = rows.single;
          expect(v.rule, 'hamza_hadhf', reason: '$id $s:$a');
          // The dagger alif, as Hafs's rasm; vowelled.
          expect(v.text, contains('صَّٰب'), reason: '$id $s:$a');
          expect(
            manzumat
                .referenceOf(v, quran.ayah(s, a).words[w], s, surahs)
                .mention,
            {460},
            reason: '$id $s:$a',
          );
        }
      }
    },
  );

  test('«هزؤا، كفؤا» with the hamza, one usul for six', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    const ids = [
      'qalun',
      'bazzi',
      'qunbul',
      'ibn_wardan',
      'ibn_jammaz',
      'warsh',
    ];
    await variants.ensureLoaded(ids);
    var places = 0;
    for (var p = quran.firstPage; p < quran.firstPage + quran.pageCount; p++) {
      for (final a in quran.page(p)) {
        for (final (w, word) in a.words.indexed) {
          if (!RegExp('^(هُزُو|كُفُو)[ًٗ]ا').hasMatch(word)) continue;
          places++;
          for (final id in ids) {
            final rows = variants
                .at([id], a.surah, a.number, w)
                .where(
                  (v) =>
                      v.description.contains('همز') && v.rule != 'naql_source',
                );
            final v = rows.single;
            expect(v.rule, 'hamza_zaida', reason: '$id ${a.surah}:${a.number}');
            expect(v.description, 'بإبدال الواو همزة');
            expect((v.word, v.count), (w, 1));
            expect(v.inHamesh, isFalse);
            expect(manzumat.referenceOf(v, word, a.surah, surahs).mention, {
              460,
              461,
            }, reason: '$id ${a.surah}:${a.number}');
          }
        }
      }
    }
    expect(places, 12);
  });

  test("«الآن»: Ibn Wardan's naql, Qalun and Ibn Jammaz as Hafs", () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['qalun', 'ibn_wardan', 'ibn_jammaz']);
    for (final (s, a, w) in [
      (2, 71, 17),
      (2, 187, 23),
      (4, 18, 13),
      (8, 66, 0),
      (12, 51, 19),
      (72, 9, 8),
    ]) {
      final naql = variants.at(['ibn_wardan'], s, a, w).single;
      expect(naql.rule, 'naql', reason: '$s:$a');
      expect((naql.word, naql.count), (w, 1));
      expect(
        naql.description,
        // البقرة ٧١ told by its chapter alone: no waw in the word to drop.
        s == 2 && a == 71 ? '' : 'بالنقل',
      );
      expect(naql.inHamesh, isFalse);
      // «وَلاَ نَقْلَ إِلاَّ الآنَ مَعْ يُوْنُسٍ بَدَا».
      expect(manzumat.referenceOf(naql, naql.text, s, surahs).mention, {36});
      for (final id in ['qalun', 'ibn_jammaz']) {
        expect(variants.at([id], s, a, w), isEmpty, reason: '$id $s:$a');
      }
    }
  });

  test("Abu Ja'far's «هو وهي» cite «هُوْ وَهِيْ يُمِلَّ هْوَ»", () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['ibn_wardan']);
    for (final (s, a, w) in [
      (2, 29, 15),
      (2, 74, 6),
      (3, 62, 2),
      (28, 61, 12),
    ]) {
      final v = variants
          .at(['ibn_wardan'], s, a, w)
          .where((v) => v.description.contains('إسكان الهاء'))
          .single;
      final r = manzumat.referenceOf(
        v,
        v.text,
        s,
        surahs,
        entries: book.at(s, a, w),
      );
      expect(r.mention, {64}, reason: '$s:$a');
    }
  });

  test(
    '«خطيئاته» in the plural, one text for Nafi\' and Abu Ja\'far',
    () async {
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded([
        'qalun',
        'ibn_wardan',
        'ibn_jammaz',
        'warsh',
      ]);
      final qalun = variants
          .at(['qalun'], 2, 81, 6)
          .where((v) => v.inHamesh)
          .single;
      // Its alif the dagger one, as the rasm.
      expect(qalun.text, contains('ٰ'));
      for (final id in ['ibn_wardan', 'ibn_jammaz', 'warsh']) {
        final v = variants.at([id], 2, 81, 6).where((v) => v.inHamesh).single;
        expect(v.text, qalun.text, reason: id);
        expect(v.description, 'بإثبات الألف', reason: id);
      }
      // «تَظَّٰهَرُونَ» too, as Qalun's.
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = variants.at([id], 2, 85, 10).single;
        expect(v.text, matches(RegExp('ظ[َّ]+ٰ')), reason: id);
        expect(v.description, 'بتشديد الظاء', reason: id);
      }
    },
  );

  test("al-Bazzi's «فَلِمَهۡ» and the four with it: two faces", () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['bazzi']);
    final rows = variants.allOf('bazzi').where((v) => v.rule == 'ha_sakt');
    expect(rows, hasLength(25));
    final lima = rows.where((v) => v.surah == 2 && v.ayah == 91).single;
    expect(lima.stopOnly, isTrue);
    expect(lima.stopText, startsWith('فَلِ'));
    expect(lima.stopText, endsWith('هۡ'));
    expect(lima.usulWays, [
      'الوقف بدون هاء السكت، وهو المقدم',
      'الوقف بهاء السكت',
    ]);
    for (final v in rows) {
      // «وَفِيمَهْ وَمِمَّهْ قِفْ وَعَمَّهْ لِمَهْ بِمَهْ بِخُلْفٍ عَنِ الْبَزِّيِّ».
      expect(manzumat.referenceOf(v, v.stopText, v.surah, surahs).mention, {
        386,
      }, reason: '${v.surah}:${v.ayah}');
    }
  });

  test('«ننسأها» of Ibn Kathir, and «وأوصى» one note', () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded([
      'bazzi',
      'qunbul',
      'qalun',
      'ibn_wardan',
      'ibn_jammaz',
    ]);
    for (final id in ['bazzi', 'qunbul']) {
      final v = variants.at([id], 2, 106, 5).single;
      expect(v.description, 'بفتح النون الأولى والسين وزيادة الهمزة بعد السين');
      final r = manzumat.referenceOf(
        v,
        'نُنسِهَا',
        2,
        surahs,
        entries: book.at(2, 106, 5),
      );
      expect(r.mention, {475}, reason: id);
    }
    // «ءَأَنتُمۡ» (البقرة ١٤٠): Abu Ja'far's as Qalun's, on its word alone.
    final antum = variants.at(['qalun'], 2, 140, 13).single;
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = variants.at([id], 2, 140, 13).single;
      expect(v.text, antum.text, reason: id);
      expect(v.description, antum.description, reason: id);
      expect(v.count, 1, reason: id);
      expect(variants.at([id], 2, 140, 12), isEmpty, reason: id);
      expect(variants.at([id], 2, 140, 14), isEmpty, reason: id);
    }
    final qalun = variants.at(['qalun'], 2, 132, 0).single;
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final v = variants.at([id], 2, 132, 0).single;
      expect(v.text, qalun.text, reason: id);
      expect(v.description, qalun.description, reason: id);
    }
  });

  test("Abu Ja'far's ikhfa cites «وَبِخَا وَغَيْنِ الاِخْفَا»", () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['ibn_wardan', 'ibn_jammaz']);
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final rows = variants.allOf(id).where((v) => v.rule == 'ikhfa');
      expect(rows.length, greaterThan(200), reason: id);
      for (final v in rows) {
        final r = manzumat.referenceOf(v, v.text, v.surah, surahs);
        expect(r.mention, {42}, reason: '$id ${v.surah}:${v.ayah}');
      }
    }
  });

  test('«اتخذتم، أخذتم» merged cite «فَازَ اتَخَذْتُمْ أَخَذْتُمْ»', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    const ids = [
      'shubah', 'qalun', 'ibn_wardan', 'ibn_jammaz', 'warsh', 'hisham', //
      'ibn_dhakwan',
    ];
    await variants.ensureLoaded([...ids, 'rawh']);
    for (final id in ids) {
      final rows = [
        for (final v in variants.allOf(id))
          if (v.description == 'بإدغام الذال في التاء' &&
              quran.ayah(v.surah, v.ayah).words[v.word].contains('خَذۡت'))
            v,
      ];
      expect(rows, hasLength(18), reason: id);
      for (final v in rows) {
        final hafs = quran.ayah(v.surah, v.ayah).words[v.word];
        // From the page (Hafs's word) and from the usul (the word as read).
        for (final word in [hafs, if (v.text.isNotEmpty) v.text]) {
          final r = manzumat.referenceOf(
            v,
            word,
            v.surah,
            surahs,
            entries: book.at(v.surah, v.ayah, v.word),
          );
          expect(r.poem, Poem.shatibiyya, reason: '$id ${v.surah}:${v.ayah}');
          expect(r.mention, {283}, reason: '$id ${v.surah}:${v.ayah}');
        }
      }
    }
    // Rawh by the Durrah's «أَخَذْتُ طُلُ»: Ruways alone shows it.
    final rawh = variants
        .at(['rawh'], 2, 51, 6)
        .where((v) => v.rule == 'idgham_saghir')
        .single;
    expect(manzumat.referenceOf(rawh, rawh.text, 2, surahs).mention, {40});
  });

  test(
    "Abu Ja'far's «إسرائيل» cites «أَرَيْتَ وَإِسْرَائِيْلَ كَائِنْ»",
    () async {
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded(['ibn_wardan', 'ibn_jammaz']);
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final rows = [
          for (final v in variants.allOf(id))
            if (v.text.contains('سۡرَٰٓءِ۬يل')) v,
        ];
        expect(rows, hasLength(43), reason: id);
        for (final v in rows) {
          // From the page (Hafs's word) and from the usul (its own text).
          for (final word in ['إِسۡرَٰٓءِيلَ', v.text]) {
            final r = manzumat.referenceOf(
              v,
              word,
              v.surah,
              surahs,
              entries: book.at(v.surah, v.ayah, v.word),
            );
            expect(r.mention, {34}, reason: '$id ${v.surah}:${v.ayah}');
          }
        }
      }
    },
  );

  test("Qunbul's second hamza changed: its letter and one length", () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['qunbul']);
    const tasheel = 'تسهيل الهمزة الثانية، وهو المقدم';
    for (final (s, a, w, ibdal) in [
      (2, 31, 12, 'ياءً مدية مع المد المشبع (٦ حركات)'),
      (32, 5, 4, 'ياءً مدية مع القصر (حركتان)'),
      // The kasra of wasl: as هَٰٓؤُلَآءِ إِن.
      (33, 32, 6, 'ياءً مدية مع المد المشبع (٦ حركات)'),
      (11, 40, 3, 'ألفًا مع المد المشبع (٦ حركات)'),
      (4, 43, 27, 'ألفًا مع القصر (حركتان)'),
      // Before the alif of «ءَالَ»: the qasr alone.
      (15, 61, 2, 'ألفًا مع القصر (حركتان)'),
      (54, 41, 2, 'ألفًا مع القصر (حركتان)'),
      (46, 32, 14, 'واوًا مدية مع القصر (حركتان)'),
    ]) {
      final v = variants
          .at(['qunbul'], s, a, w)
          .where((v) => v.rule == 'tasheel_pair')
          .single;
      expect(v.usulWays, [
        tasheel,
        'إبدال الهمزة الثانية $ibdal',
      ], reason: '$s:$a');
    }
  });

  test("Abu Ja'far's «أنبئهم، ونبئهم» keep the hamza", () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['ibn_wardan', 'ibn_jammaz']);
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      for (final (s, a, w) in [(2, 33, 2), (15, 51, 0), (54, 28, 0)]) {
        expect(
          variants.at([id], s, a, w).where((v) => v.kind == VariantKind.hamza),
          isEmpty,
          reason: '$id $s:$a',
        );
      }
      // The rule stays elsewhere: «يُؤۡمِنُونَ» with a waw.
      expect(
        variants.allOf(id).where((v) => v.rule == 'ibdal_single').length,
        greaterThan(1000),
      );
    }
  });

  test('only Hamzah and Hisham read a hamza change on stopping alone', () {
    // «يستهزُون»: Abu Ja'far in wasl and waqf, Hamzah on stopping; «وبيس»:
    // Warsh and al-Susi always.
    for (final (s, a, w, always) in [
      (6, 5, 11, 'ibn_wardan'),
      (6, 10, 12, 'ibn_jammaz'),
      (3, 12, 7, 'warsh'),
      (3, 12, 7, 'susi'),
    ]) {
      final readings = [for (final e in book.at(s, a, w)) ...e.readings];
      final own = readings.where((r) => r.riwayat.contains(always));
      expect(own, isNotEmpty, reason: '$s:$a');
      expect(own.every((r) => !r.stopOnly), isTrue, reason: '$s:$a');
      expect(
        readings.where((r) => r.riwayat.contains('khallad') && r.stopOnly),
        isNotEmpty,
        reason: '$s:$a',
      );
    }
  });

  test('an isri quotes bayt 765 of the book for Warsh', () {
    const v = Variant(
      riwayaId: 'warsh',
      surah: 20,
      ayah: 77,
      word: 4,
      count: 2,
      text: 'أَنِ اِ۪سْرِ',
      kind: VariantKind.farsh,
      description:
          'بوصل الهمزة، ويلزم منه كسر النون وصلاً، والابتداء بهمزة مكسورة',
      rule: '',
    );
    final r = manzumat.referenceOf(
      v,
      'أَنۡ أَسۡرِ',
      20,
      surahs,
      entries: book.at(20, 77, 4),
    );
    expect(r.fromBook, isTrue);
    expect(r.mention, {765});
  });

  test('fa-sri and an isri quote bayt 765, the bab of dhikran bayt 346', () {
    for (final (surah, ayah, word) in [
      (11, 81, 8),
      (15, 65, 0),
      (44, 23, 0),
      (26, 52, 3),
    ]) {
      final v = Variant(
        riwayaId: 'warsh',
        surah: surah,
        ayah: ayah,
        word: word,
        count: 1,
        text: 'فَاسْرِ',
        kind: VariantKind.farsh,
        description: 'بوصل الهمزة',
        rule: '',
      );
      final r = manzumat.referenceOf(
        v,
        'فَأَسۡرِ',
        surah,
        surahs,
        entries: book.at(surah, ayah, word),
      );
      expect(r.mention, {765}, reason: '$surah:$ayah');
    }
    final ra = ref(
      'warsh',
      20,
      'ذِكۡرٗا',
      description: 'بوجهين: تفخيم الراء وترقيقها',
      rule: 'tarqiq',
      kind: VariantKind.usul,
    );
    expect(ra.mention, {346});
  });

  test(
    'every araayta of the question is Warsh usul quoting bayt 638',
    () async {
      final quran = await QuranRepository.load();
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded(['warsh']);
      final question = RegExp('^أَ(فَ)?رَءَيۡت');
      var seen = 0;
      for (final surah in quran.surahs) {
        for (var a = 1; a <= surah.ayahCount; a++) {
          for (final (w, word) in quran.ayah(surah.number, a).words.indexed) {
            if (!question.hasMatch(word)) continue;
            seen++;
            final farsh = variants
                .at(['warsh'], surah.number, a, w)
                .singleWhere((v) => v.rule == 'tasheel_word');
            expect(farsh.isUsul, isTrue);
            expect(farsh.usulWays, hasLength(2));
            expect(
              farsh.description,
              contains('تسهيل الهمزة الثانية، أو إبدالها ألفًا'),
            );
            final r = manzumat.referenceOf(
              farsh,
              word,
              surah.number,
              surahs,
              entries: book.at(surah.number, a, w),
            );
            expect(r.mention, contains(638), reason: '${surah.number}:$a');
          }
        }
      }
      expect(seen, 34);
    },
  );

  test('yuha of al-Anbiya quotes bayt 783 for Warsh', () {
    for (final (ayah, word) in [(7, 5), (25, 7)]) {
      final v = Variant(
        riwayaId: 'warsh',
        surah: 21,
        ayah: ayah,
        word: word,
        count: 1,
        text: 'يُوح۪ىٰٓ',
        kind: VariantKind.farsh,
        description: 'بالياء وتقليل الحاء وإبدال الياء ألفًا مقصورة مع المد',
        rule: '',
      );
      expect(v.isUsul, isFalse);
      final r = manzumat.referenceOf(
        v,
        'نُوحِيٓ',
        21,
        surahs,
        entries: book.at(21, ayah, word),
      );
      expect(r.mention, contains(783), reason: '21:$ayah');
    }
  });

  test('wa-ana and fa-ana before hamza quote bayt 521 for Warsh', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh']);
    for (final (surah, ayah, word) in [
      (6, 163, 5),
      (7, 143, 38),
      (40, 42, 10),
      (43, 81, 5),
      (60, 1, 35),
    ]) {
      final v = variants
          .at(['warsh'], surah, ayah, word)
          .singleWhere((r) => r.description == 'بالمد');
      final r = manzumat.referenceOf(
        v,
        quran.ayah(surah, ayah).words[word],
        surah,
        surahs,
        entries: book.at(surah, ayah, word),
      );
      expect(r.mention, {521}, reason: '$surah:$ayah');
    }
  });

  test('ana before hamza points to bayt 521 in Baqarah with book priority', () {
    for (final id in ['warsh', 'qalun']) {
      final v = Variant(
        riwayaId: id,
        surah: 2,
        ayah: 258,
        word: 20,
        count: 1,
        text: 'أَنَآ',
        kind: VariantKind.usul,
        description: 'بالمد',
      );
      final direct = manzumat.referenceOf(v, 'أَنَا۠', 2, surahs);
      expect(direct.mention, {521});
      expect(direct.chapter, 'سُوْرَةُ الْبَقَرَةِ');
      final cited = manzumat.referenceOf(
        v,
        'أَنَا۠',
        2,
        surahs,
        entries: book.at(2, 258, 20),
      );
      expect(cited.mention, {521});
      expect(cited.fromBook, isTrue);
      expect(
        cited.verses.singleWhere((b) => b.n == 521).sadr,
        contains('وَمَدُّ'),
      );
    }
  });

  test('the whole of both poems', () {
    expect(manzumat.verses(Poem.shatibiyya), hasLength(1173));
    expect(manzumat.verses(Poem.durrah).length, greaterThanOrEqualTo(240));
  });

  test('a farsh: the chapter of its surah, the verse naming the word', () {
    final r = ref('warsh', 2, 'يَخۡدَعُونَ', text: 'يُخَٰدِعُونَ');
    expect((r.poem, r.chapter), (Poem.shatibiyya, 'سُوْرَةُ الْبَقَرَةِ'));
    expect(r.mention, contains(445));
    expect(
      ref('hisham', 2, 'يَكۡذِبُونَ', text: 'يُكَذِّبُونَ').mention,
      contains(446),
    );
    // مَلِكِ (1:4): the Shatibiyya for the seven, the Durrah for Abu Ja'far.
    expect(ref('hisham', 1, 'مَٰلِكِ', text: 'مَلِكِ').mention, contains(108));
    final durrah = ref('ibn_wardan', 1, 'مَٰلِكِ', text: 'مَلِكِ');
    expect(durrah.poem, Poem.durrah);
    expect(durrah.mention, contains(10));
  });

  test('the usul: the chapter of the rule', () {
    String chapter(
      String riwaya, {
      String description = '',
      String rule = '',
    }) => ref(
      riwaya,
      2,
      'ءَامَنُواْ',
      description: description,
      rule: rule,
      kind: VariantKind.usul,
    ).chapter;
    expect(skeleton(chapter('warsh', rule: 'badal')), contains('لمد'));
    expect(
      skeleton(chapter('warsh', rule: 'ya_zaida')),
      contains(skeleton('الزوائد')),
    );
    expect(skeleton(chapter('warsh', rule: 'tarqiq')), contains('لرت'));
    expect(skeleton(chapter('warsh', rule: 'taghliz')), contains('للمت'));
    expect(skeleton(chapter('khalaf_hamzah', rule: 'sakt')), contains('نقل'));
    expect(
      skeleton(chapter('duri_kisai', description: 'بالإمالة')),
      contains('لمله'),
    );
  });

  test(
    'Ibn Dhakwan\'s imala of شاء and زاد cites «وَجَاءَ ابْنُ ذَكْوَانٍ»',
    () {
      Set<int> mention(String hafs) => ref(
        'ibn_dhakwan',
        2,
        hafs,
        description: 'بالإمالة',
        kind: VariantKind.usul,
      ).mention;
      expect(mention('شَآءَ'), {319});
      expect(mention('جَآءَهُمۡ'), {319});
      expect(mention('وَزَادَهُۥ'), {319, 320});
      expect(mention('عِمۡرَٰنَ'), {332, 333});
      expect(mention('ٱلۡإِكۡرَامِ'), {332, 333});
      expect(mention('حِمَارِكَ'), {332, 333});
    },
  );

  test(
    'Ibn Dhakwan\'s imala of التوراة cites «وَإِضْجَاعُكَ التَّوْرَاةَ»',
    () {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ibn_dhakwan',
          surah: 3,
          ayah: 3,
          word: 9,
          count: 1,
          text: 'ٱلتَّوۡر۪ىٰةَ',
          kind: VariantKind.usul,
          description: 'بالإمالة',
        ),
        'ٱلتَّوۡرَىٰةَ',
        3,
        surahs,
      );
      expect(r.mention, {546});
    },
  );

  test(
    'Ibn Amir قتلوا with the shadda cites «بِمَا قُتِلُوا التَّشْدِيدُ لَبَّى»',
    () {
      Set<int> mention(String id, int surah, int ayah, int word, String text) =>
          manzumat
              .referenceOf(
                Variant(
                  riwayaId: id,
                  surah: surah,
                  ayah: ayah,
                  word: word,
                  count: 1,
                  text: text,
                  kind: VariantKind.farsh,
                  description: 'بتشديد التاء',
                ),
                'قُتِلُواْ',
                surah,
                surahs,
              )
              .mention;
      expect(mention('hisham', 3, 168, 7, 'قُتِّلُواْ'), {576});
      expect(mention('ibn_dhakwan', 3, 169, 3, 'قُتِّلُواْ'), {576});
      expect(mention('hisham', 3, 195, 25, 'وَقُتِّلُواْ'), {576, 577});
      expect(mention('ibn_dhakwan', 22, 58, 6, 'قُتِّلُواْ'), {576});
    },
  );

  test('Ibn Amir وسيصلون cites «يَصْلَوْنَ ضُمَّ كَمْ صَفَا»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 4,
          ayah: 10,
          word: 11,
          count: 1,
          text: 'وَسَيُصۡلَوۡنَ',
          kind: VariantKind.farsh,
          description: 'بضم الياء',
        ),
        'وَسَيَصۡلَوۡنَ',
        4,
        surahs,
      );
      expect(r.mention, {588});
    }
  });

  test('al-Hajj and al-Naba are not taken for al-Hijr and al-Anbiya', () {
    String chapter(int surah) => manzumat
        .referenceOf(
          Variant(
            riwayaId: 'hisham',
            surah: surah,
            ayah: 1,
            word: 0,
            count: 1,
            text: '',
            kind: VariantKind.farsh,
          ),
          '',
          surah,
          surahs,
        )
        .chapter;
    expect(skeleton(chapter(22)), contains('لحج'));
    expect(skeleton(chapter(22)), isNot(contains('لحجر')));
    expect(skeleton(chapter(15)), contains('لحجر'));
    expect(skeleton(chapter(78)), contains('لنب'));
    expect(skeleton(chapter(21)), contains('لنبي'));
  });

  test('Hisham stopping on the hamza cites its own chapter', () {
    final r = manzumat.referenceOf(
      Variant(
        riwayaId: 'hisham',
        surah: 52,
        ayah: 24,
        word: 5,
        count: 1,
        text: '',
        kind: VariantKind.usul,
        description: 'وقفًا: إبدالها واوًا ساكنة، أو تسهيلها بالروم',
        rule: 'hisham_waqf',
        stopOnly: true,
      ),
      'لُؤۡلُؤٞ',
      52,
      surahs,
    );
    expect(skeleton(r.chapter), contains('وقف'));
    expect(r.mention, contains(236));
    expect(r.mention, isNot(contains(223)));
  });

  test('Ibn Dhakwan عيون، شيوخ، جيوب cite «يَكْسِرَانِ عُيُوناً»', () {
    for (final (surah, ayah, text, hafs, verses) in [
      (26, 57, 'وَعِيُونٖ', 'وَعُيُونٖ', {628}),
      (36, 34, 'ٱلۡعِيُونِ', 'ٱلۡعُيُونِ', {628}),
      (40, 67, 'شِيُوخٗا', 'شُيُوخٗا', {628}),
      (24, 31, 'جِيُوبِهِنَّ', 'جُيُوبِهِنَّۖ', {628, 629}),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ibn_dhakwan',
          surah: surah,
          ayah: ayah,
          word: 0,
          count: 1,
          text: text,
          kind: VariantKind.farsh,
          description: 'بكسر العين',
        ),
        hafs,
        surah,
        surahs,
      );
      expect(r.mention, verses, reason: '$surah:$ayah');
      expect(skeleton(r.chapter), contains('لمده'));
    }
  });

  test('Ibn Dhakwan رأى cites the farsh of al-An\'am', () {
    for (final (text, stop, verses) in [
      ('ر۪ء۪اهَا', false, {646, 647}),
      ('ر۪ء۪ا', false, {646}),
      ('ر۪ء۪ا', true, {648, 649}),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ibn_dhakwan',
          surah: 27,
          ayah: 10,
          word: 3,
          count: 1,
          text: text,
          kind: VariantKind.usul,
          description: 'بإمالة الراء والهمزة',
          stopOnly: stop,
        ),
        'رَءَاهَا',
        27,
        surahs,
      );
      expect(r.mention, verses, reason: '$text $stop');
    }
  });

  test('Ibn Amir يا أبت and فزع يومئذ cite their verses', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs, verse, chapter) in [
        (19, 42, 'يَٰٓأَبَتَ', 'يَٰٓأَبَتِ', 772, 'يوسف'),
        (28, 26, 'يَٰٓأَبَتَ', 'يَٰٓأَبَتِ', 772, 'يوسف'),
        (27, 89, 'فَزَعِ يَوۡمِئِذٍ', 'فَزَعٖ يَوۡمَئِذٍ', 761, 'هود'),
        (30, 54, 'ضُعۡفٗا', 'ضَعۡفٗا', 722, 'الأنفال'),
        (35, 9, 'مَّيۡتٖ', 'مَّيِّتٖ', 550, 'عمران'),
        (36, 68, 'نَنۡكُسۡهُ', 'نُنَكِّسۡهُ', 991, 'يس'),
        (37, 17, 'أَوۡ ءَابَآؤُنَا', 'أَوَءَابَآؤُنَا', 996, 'الصافات'),
        (37, 102, 'يَٰبُنَيِّ', 'يَٰبُنَيَّ', 757, 'هود'),
        (39, 7, 'يَرۡضَهۡ', 'يَرۡضَهُ', 164, 'الكناية'),
        (40, 26, 'وَأَن', 'أَوۡ أَن', 1010, 'المؤمن'),
        (44, 47, 'فَٱعۡتُلُوهُ', 'فَٱعۡتِلُوهُ', 1030, 'الدخان'),
        (40, 26, 'يَظۡهَرَ', 'يُظۡهِرَ', 1011, 'المؤمن'),
        if (id == 'ibn_dhakwan')
          (41, 51, 'وَنَآءَ', 'وَنَـَٔا', 826, 'الإسراء'),
        (48, 10, 'فَسَنُؤۡتِيهِ', 'فَسَيُؤۡتِيهِ', 1041, 'محمد'),
        (58, 21, 'وَرُسُلِىَ', 'وَرُسُلِيٓ', 402, 'ياءات الإضافة'),
        if (id == 'ibn_dhakwan')
          (98, 6, 'ٱلۡبَرِيٓـَٔةِ', 'ٱلۡبَرِيَّةِ', 1116, 'العلق'),
        (77, 6, 'نُذُرًا', 'نُذۡرًا', 618, 'المائدة'),
        if (id == 'hisham') ...[
          (76, 4, 'سَلَٰسِلًا', 'سَلَٰسِلَاْ', 1093, 'القيامة'),
          (76, 16, 'قَوَارِيرَا', 'قَوَارِيرَاْ', 1095, 'القيامة'),
        ],
        (75, 20, 'يُحِبُّونَ', 'تُحِبُّونَ', 1092, 'القيامة'),
        (75, 21, 'وَيَذَرُونَ', 'وَتَذَرُونَ', 1092, 'القيامة'),
        (73, 6, 'وِطَآءً', 'وَطۡـٔٗا', 1088, 'سورة ن'),
        (73, 9, 'رَبِّ', 'رَّبُّ', 1088, 'سورة ن'),
        (64, 17, 'يُضَعِّفۡهُ', 'يُضَٰعِفۡهُ', 516, 'البقرة'),
        (57, 11, 'فَيُضَعِّفَهُۥ', 'فَيُضَٰعِفَهُۥ', 516, 'البقرة'),
        (2, 245, 'فَيُضَعِّفَهُۥ', 'فَيُضَٰعِفَهُۥ', 516, 'البقرة'),
        (4, 40, 'يُضَعِّفۡهَا', 'يُضَٰعِفۡهَا', 516, 'البقرة'),
        (25, 69, 'يُضَعَّفُ', 'يُضَٰعَفۡ', 516, 'البقرة'),
        if (id == 'hisham')
          (52, 37, 'ٱلۡمُصَۜيۡطِرُونَ', 'ٱلۡمُصَۣيۡطِرُونَ', 1048, 'محمد'),
        (7, 172, 'ذُرِّيَّٰتِهِمۡ', 'ذُرِّيَّتَهُمۡ', 706, 'الأعراف'),
        (36, 41, 'ذُرِّيَّٰتِهِمۡ', 'ذُرِّيَّتَهُمۡ', 707, 'الأعراف'),
        (52, 21, 'ذُرِّيَّٰتُهُم', 'ذُرِّيَّتُهُم', 707, 'الأعراف'),
        (52, 21, 'ذُرِّيَّٰتِهِمۡ', 'ذُرِّيَّتَهُمۡ', 706, 'الأعراف'),
        if (id == 'ibn_dhakwan') ...[
          (48, 29, 'شَطَـَٔهُۥ', 'شَطۡـَٔهُۥ', 1043, 'محمد'),
          (48, 29, 'فَأَزَرَهُۥ', 'فَـَٔازَرَهُۥ', 1043, 'محمد'),
        ],
        if (id == 'ibn_dhakwan')
          (46, 19, 'وَلِنُوَفِّيَهُمْ', 'وَلِيُوَفِّيَهُمۡ', 1035, 'الأحقاف'),
        if (id == 'hisham')
          (46, 17, 'أَتَعِدَآنِّيٓ', 'أَتَعِدَانِنِيٓ', 1035, 'الأحقاف'),
        (31, 13, 'يَٰبُنَيِّ', 'يَٰبُنَيَّ', 757, 'هود'),
        (56, 48, 'أَوۡ ءَابَآؤُنَا', 'أَوَءَابَآؤُنَا', 996, 'الصافات'),
        (3, 27, 'ٱلۡمَيۡتِ', 'ٱلۡمَيِّتِ', 550, 'عمران'),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: text.contains('يۡت') ? 'بإسكان الياء مخففة' : '',
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, contains(verse), reason: '$id $surah:$ayah');
        expect(skeleton(r.chapter), contains(skeleton(chapter)));
      }
    }
  });

  test('Ibn Amir ندخله، نعذبه، نكفر cite «وَنُدْخِلْهُ نُونٌ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs) in [
        (4, 13, 'نُدْخِلۡهُ', 'يُدۡخِلۡهُ'),
        (4, 14, 'نُدْخِلۡهُ', 'يُدۡخِلۡهُ'),
        (48, 17, 'نُدْخِلْهُ', 'يُدۡخِلۡهُ'),
        (48, 17, 'نُعَذِّبْهُ', 'يُعَذِّبۡهُ'),
        (64, 9, 'نُكَفِّرْ', 'يُكَفِّرۡ'),
        (64, 9, 'وَنُدْخِلْهُ', 'وَيُدۡخِلۡهُ'),
        (65, 11, 'نُدۡخِلۡهُ', 'يُدۡخِلۡهُ'),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: 'بالنون',
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, {592}, reason: '$id $surah:$ayah $text');
        expect(skeleton(r.chapter), contains(skeleton('النساء')));
      }
    }
  });

  test('Ibn Amir without Hafs\'s sakt cites «وَالْبَاقُونَ لاَ سَكْتَ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs, kind, rule, verse) in [
        (18, 1, 'عِوَجٗا', 'عِوَجَاۜ', VariantKind.farsh, '', 830),
        (36, 52, 'مَّرۡقَدِنَا', 'مَّرۡقَدِنَاۜ', VariantKind.farsh, '', 831),
        (
          75,
          27,
          'مَن رَّاقٖ',
          'مَنۡۜ رَاقٖ',
          VariantKind.usul,
          'idgham_saghir',
          831,
        ),
        (
          83,
          14,
          'بَل رَّانَ',
          'بَلۡۜ رَانَ',
          VariantKind.usul,
          'idgham_saghir',
          831,
        ),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: kind,
            rule: rule,
            description: 'بإدغام',
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, {verse}, reason: '$id $surah:$ayah');
        expect(skeleton(r.chapter), contains(skeleton('الكهف')));
      }
    }
  });

  test('Ibn Amir «مُوصَدَةٌ» cites «وَمُؤْصَدَةٌ فَاهْمِزْ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah) in [(90, 20), (104, 8)]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 2,
            count: 1,
            text: 'مُوصَدَةٌ',
            kind: VariantKind.hamza,
            description: 'إبدال الهمزة واوًا ساكنة',
          ),
          'مُّؤۡصَدَةُۢ',
          surah,
          surahs,
        );
        expect(r.mention, {1114}, reason: '$id $surah:$ayah');
      }
    }
  });

  test(
    'Ruways «ٱللَّهُ» when starting (14:2) cites «وَطِبْ رَفْعَ أَللهِ»',
    () {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ruways',
          surah: 14,
          ayah: 2,
          word: 0,
          count: 1,
          text: '',
          kind: VariantKind.farsh,
          description: 'بالرفع «ٱللَّهُ» ابتداءً، وبالخفض وصلاً كحفص',
        ),
        'ٱللَّهِ',
        14,
        surahs,
      );
      expect(r.mention, {138});
    },
  );

  test('Yaqub الرهب (28:32) cites the Shatibiyya, the Durrah being silent', () {
    for (final id in ['ruways', 'rawh']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 28,
          ayah: 32,
          word: 13,
          count: 1,
          text: 'الرَّهَبِ',
          kind: VariantKind.farsh,
          description: 'بفتح الراء والهاء',
        ),
        'ٱلرَّهۡبِ',
        28,
        surahs,
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {947}, reason: id);
    }
  });

  test('Yaqub stopping on the kaf of ويكأن (28:82) cites the Durrah', () {
    for (final id in ['ruways', 'rawh']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 28,
          ayah: 82,
          word: 6,
          count: 1,
          text: '',
          kind: VariantKind.usul,
          description: 'بالوقف على الكاف',
          rule: 'rasm_stop',
        ),
        'وَيۡكَأَنَّ',
        28,
        surahs,
      );
      expect(r.mention, {51}, reason: id);
    }
  });

  test('Yaqub الظنون and her sisters cite the Shatibiyya (Abu Amr)', () {
    for (final (a, w) in [(10, 15), (66, 10), (67, 7)]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'rawh',
          surah: 33,
          ayah: a,
          word: w,
          count: 1,
          text: 'ٱلظُّنُونَ',
          kind: VariantKind.farsh,
          description: 'بحذف الألف وصلاً ووقفًا',
        ),
        'ٱلظُّنُونَا۠',
        33,
        surahs,
      );
      expect(r.poem, Poem.shatibiyya, reason: '33:$a');
      expect(r.mention, {969}, reason: '33:$a');
    }
  });

  test('Yaqub يصدقني (28:34) cites «وَيُصَدِّقْ فِه»', () {
    for (final id in ['ruways', 'rawh']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 28,
          ayah: 34,
          word: 9,
          count: 1,
          text: 'يُصَدِّقۡنِي',
          kind: VariantKind.farsh,
          description: 'بإسكان القاف',
        ),
        'يُصَدِّقُنِيٓۖ',
        28,
        surahs,
      );
      expect(r.mention, {176}, reason: id);
    }
  });

  test('Ibn Amir قل رب, لؤلؤ and سواء cite their verses', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs, verse) in [
        (21, 4, 'قُل رَّبِّي', 'قَالَ رَبِّي', 887),
        (21, 112, 'قُل رَّبِّ', 'قَٰلَ رَبِّ', 887),
        (22, 23, 'وَلُؤۡلُؤٖاْ', 'وَلُؤۡلُؤٗاۖ', 895),
        (35, 33, 'وَلُؤۡلُؤٖ', 'وَلُؤۡلُؤٗاۖ', 895),
        (22, 25, 'سَوَآءٌ', 'سَوَآءً', 895),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, {verse}, reason: '$id $surah:$ayah');
      }
    }
  });

  test('Ibn Amir أشدد وأشركه cite «وَشَامٍ قَطْعُ أَشْدُدْ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (ayah, text, hafs, description) in [
        (31, 'أَشۡدُدۡ', 'ٱشۡدُدۡ', 'بهمزة قطع مفتوحة'),
        (32, 'وَأُشۡرِكۡهُ', 'وَأَشۡرِكۡهُ', 'بضم الهمزة'),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 20,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: description,
          ),
          hafs,
          20,
          surahs,
        );
        expect(r.mention, {873}, reason: '$id $text');
      }
    }
  });

  test('Ibn Amir وأحل cites «وَضَمٌّ وَكَسْرٌ فِي أَحَلَّ صِحَابُهُ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 4,
          ayah: 24,
          word: 10,
          count: 1,
          text: 'وَأَحَلَّ',
          kind: VariantKind.farsh,
          description: 'بفتح الهمزة والحاء',
        ),
        'وَأُحِلَّ',
        4,
        surahs,
      );
      expect(r.mention, {597});
    }
  });

  test('Ibn Amir فتيلا انظر cites «وَضَمُّكَ أُولَى السَّاكِنَيْنِ»', () {
    Set<int> mention(String id, int ayah, int word, String hafs) => manzumat
        .referenceOf(
          Variant(
            riwayaId: id,
            surah: 4,
            ayah: ayah,
            word: word,
            count: 1,
            text: '',
            kind: VariantKind.farsh,
            description: 'بضم نون التنوين لالتقاء الساكنين',
          ),
          hafs,
          4,
          surahs,
        )
        .mention;
    expect(mention('hisham', 49, 13, 'فَتِيلًا'), {495, 496});
    expect(mention('hisham', 50, 0, 'ٱنظُرۡ'), {495, 496});
    expect(mention('ibn_dhakwan', 49, 13, 'فَتِيلًا'), {495, 497, 498});
    // «قَدِ اسْتُهْزِئَ» is named in the verse, with damma for both.
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 6,
          ayah: 10,
          word: 0,
          count: 1,
          text: 'وَلَقَدُ',
          kind: VariantKind.farsh,
          description: 'بضم الدال لالتقاء الساكنين',
        ),
        'وَلَقَدِ',
        6,
        surahs,
      );
      expect(r.mention, {495, 496}, reason: id);
    }
  });

  test(
    'Ibn Amir هزؤا cites «وَهُزْؤاً وَكُفْؤاً في السَّوَاكِنِ فُصِّلَا»',
    () {
      for (final (surah, ayah, word) in [
        (2, 67, 12),
        (5, 57, 8),
        (45, 35, 5),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: 'hisham',
            surah: surah,
            ayah: ayah,
            word: word,
            count: 1,
            text: 'هُزُؤٗا',
            kind: VariantKind.farsh,
            description: 'بإبدال الواو همزة',
          ),
          'هُزُوٗا',
          surah,
          surahs,
        );
        expect(r.mention, {460, 461}, reason: '$surah:$ayah');
      }
    },
  );

  test('Hisham أئنكم: two ways and «وَقَبْلَ الْكَسْرِ خُلْفٌ لَهُ»', () {
    Set<int> mention(int surah, int ayah, List<String> ways) => manzumat
        .referenceOf(
          Variant(
            riwayaId: 'hisham',
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: 'أَٰئِنَّكُمۡ',
            kind: VariantKind.usul,
            description: ways.join('؛ '),
            rule: 'tasheel_word',
            usulText: 'أَئِنَّكُمۡ',
            usulWays: ways,
          ),
          'أَئِنَّكُمۡ',
          surah,
          surahs,
        )
        .mention;
    expect(
      mention(6, 19, [
        'تحقيق الهمزة الثانية مع الإدخال',
        'تحقيق الهمزة الثانية دون إدخال',
      ]),
      {196},
    );
    expect(mention(26, 41, ['تحقيق الهمزة الثانية مع الإدخال']), {
      196,
      197,
      198,
    });
  });

  test('Ibn Amir يس والقرآن cites «وَيَاسِيْنَ أَظْهِرْ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 36,
          ayah: 1,
          word: 0,
          count: 1,
          text: '',
          kind: VariantKind.usul,
          description: 'بإدغام النون من «يسٓ» في واو «وَٱلۡقُرۡءَانِ» بغنة',
          rule: 'idgham_saghir',
        ),
        'يسٓ',
        36,
        surahs,
      );
      expect(r.mention, {281}, reason: id);
    }
  });

  test(
    'ishmam cites «وَقِيلَ وَغِيضَ» or «وَحِيلَ… وَسِيءَ» in every surah',
    () {
      Set<int> mention(String id, int surah, int ayah, String hafs, String d) =>
          manzumat
              .referenceOf(
                Variant(
                  riwayaId: id,
                  surah: surah,
                  ayah: ayah,
                  word: 0,
                  count: 1,
                  text: '',
                  kind: VariantKind.usul,
                  description: d,
                  rule: 'ishmam',
                ),
                hafs,
                surah,
                surahs,
              )
              .mention;
      const qaf = 'بإشمام كسرة القاف ضمًّا', sin = 'بإشمام كسرة السين ضمًّا';
      expect(mention('hisham', 2, 11, 'قِيلَ', qaf), {447});
      expect(mention('hisham', 4, 61, 'قِيلَ', qaf), {447});
      expect(mention('hisham', 11, 44, 'وَغِيضَ', 'بإشمام كسرة الغين ضمًّا'), {
        447,
      });
      expect(mention('ibn_dhakwan', 39, 71, 'وَسِيقَ', sin), {448});
      expect(mention('ibn_dhakwan', 11, 77, 'سِيٓءَ', sin), {448});
    },
  );

  test('Ibn Amir أخذتم cites «فَازَ اتَخَذْتُمْ أَخَذْتُمْ»', () {
    for (final (id, s, a, text) in [
      ('hisham', 2, 51, 'ٱتَّخَذتُّمُ'),
      ('ibn_dhakwan', 3, 81, 'وَأَخَذتُّمۡ'),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: 0,
          count: 1,
          text: text,
          kind: VariantKind.usul,
          description: 'بإدغام الذال في التاء',
          rule: 'idgham_saghir',
        ),
        text,
        s,
        surahs,
      );
      expect(r.mention, {283}, reason: id);
    }
  });

  test('Ibn Amir لي and معي cite «مَا كَانَ لِيْ اثْنَيْنِ مَعْ مَعِيْ»', () {
    for (final (s, a, text) in [
      (14, 22, 'لِى'),
      (38, 23, 'وَلِى'),
      (7, 105, 'مَعِى'),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'hisham',
          surah: s,
          ayah: a,
          word: 0,
          count: 1,
          text: text,
          kind: VariantKind.farsh,
          description: 'بإسكان الياء',
        ),
        text,
        s,
        surahs,
      );
      expect(r.mention, {417}, reason: '$s:$a');
    }
  });

  test('every جاء and شاء of Ibn Dhakwan, on its own word, cites bayt 319', () {
    final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync());
    final words = {
      for (final a in quran['ayahs'] as List)
        '${a[0]}:${a[1]}': (a[4] as String).split(' '),
    };
    final data = jsonDecode(
      File('assets/data/qiraat/ibn_dhakwan.json').readAsStringSync(),
    );
    var checked = 0;
    for (final v in data['variants'] as List) {
      final hafs = words['${v[0]}:${v[1]}']![v[2] as int];
      final bare = hafs.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '');
      if (!RegExp('^[وفل]?[شج][اآ]ء').hasMatch(bare)) continue;
      final reading = Variant(
        riwayaId: 'ibn_dhakwan',
        surah: v[0] as int,
        ayah: v[1] as int,
        word: v[2] as int,
        count: v[3] as int,
        text: v[4] as String,
        kind: VariantKind.fromCode(v[5] as String),
        description: v[6] as String,
      );
      if (!reading.isImala) continue;
      expect(reading.count, 1, reason: '${v[0]}:${v[1]}:${v[2]}');
      expect(
        manzumat.referenceOf(reading, hafs, reading.surah, surahs).mention,
        {319},
        reason: '${v[0]}:${v[1]}:${v[2]} $hafs',
      );
      checked++;
    }
    expect(checked, greaterThan(200));
  });

  test('Hisham\'s أؤنبئكم cites «وَفي آلِ عِمْرَانَ رَووْا لِهِشَامِهِمْ»', () {
    final r = manzumat.referenceOf(
      Variant(
        riwayaId: 'hisham',
        surah: 3,
        ayah: 15,
        word: 1,
        count: 1,
        text: 'أَٰؤُنَبِّئُكُم',
        kind: VariantKind.usul,
        description:
            'بوجهين: تحقيق الهمزة الثانية مع الإدخال؛ أو تحقيقها دون إدخال',
        rule: 'tasheel_word',
        usulText: 'أَؤُنَبِّئُكُم',
      ),
      'أَؤُنَبِّئُكُم',
      3,
      surahs,
    );
    expect(r.mention, {200, 201});
  });

  Variant reading({
    String rule = 'naql',
    int ayah = 4,
    int word = 9,
    VariantKind kind = VariantKind.usul,
  }) => Variant(
    riwayaId: 'warsh',
    surah: 2,
    ayah: ayah,
    word: word,
    count: 1,
    text: '',
    kind: kind,
    rule: rule,
  );

  test('book citations take priority and stay within the selected rule', () {
    final v = reading();
    final r = manzumat.referenceOf(
      v,
      'بالآخرة',
      2,
      surahs,
      entries: book.at(2, 4, 9),
    );
    expect(r.fromBook, isTrue);
    expect(r.mention, {226});
    expect(r.bookExplanation[226], contains('بنقل حركة الهمزة'));
    // The same note quotes madd al-badal and Hamzah's sakt as well.
    // They belong to the other rules, rather than this naql selection.
    final badal = manzumat.referenceOf(
      reading(rule: 'badal'),
      'بالآخرة',
      2,
      surahs,
      entries: book.at(2, 4, 9),
    );
    expect(badal.mention, {171, 172});
    expect(badal.fromBook, isTrue);
  });

  test('quotations spanning bayts retain both and exclude the other poem', () {
    expect(
      manzumat.quotedVerses(
        Poem.shatibiyya,
        'وما بعد همز ثابت أو مغير، فقصر وقد يروى لورش مطولا، '
        'ووسطه قوم كآمن هؤلاء، ءآلهة آتى للإيمان مثلا',
      ),
      {171, 172},
    );
    expect(manzumat.quotedVerses(Poem.shatibiyya, 'يخدعون اعلم حجى'), isEmpty);
    expect(manzumat.quotedVerses(Poem.durrah, 'يخدعون اعلم حجى'), contains(62));
    expect(manzumat.quotedVerses(Poem.shatibiyya, 'الله'), isEmpty);
  });

  test(
    'two-word hamza rules select that chapter rather than one-word hamzas',
    () {
      for (final rule in ['tasheel_pair', 'ibdal_waw', 'ibdal_ya']) {
        final r = ref(
          'warsh',
          2,
          'السفهاء ألا',
          rule: rule,
          kind: VariantKind.usul,
        );
        expect(skeleton(r.chapter), contains(skeleton('كلمتين')));
        expect(r.mention, isNotEmpty);
        expect(r.mention.every((n) => n >= 202 && n <= 213), isTrue);
      }
      expect(
        ref(
          'warsh',
          2,
          'ءأنذرتهم',
          rule: 'tasheel_word',
          kind: VariantKind.usul,
        ).mention,
        {183, 184},
      );
    },
  );

  test('unknown words and common prose are never a whole-chapter proof', () {
    expect(ref('warsh', 2, 'كلمةغيرموجودة').mention, isEmpty);
    expect(ref('warsh', 2, 'الله الذين').mention, isEmpty);
  });

  test(
    'every Shatibiyya bayt has sourced commentary, including shared passages',
    () {
      for (final b in manzumat.verses(Poem.shatibiyya)) {
        final e = manzumat.explanation(Poem.shatibiyya, b.n);
        expect(e, isNotNull, reason: 'Bayt ${b.n}');
        expect(e!.text.length, greaterThan(20));
        expect(e.source, contains('أبو شامة'));
        expect(e.url, startsWith('https://'));
        expect(e.group, contains(b.n));
      }
      expect(
        manzumat.explanation(Poem.shatibiyya, 183)!.text,
        isNot(manzumat.explanation(Poem.shatibiyya, 226)!.text),
      );
      // The Durrah's bayts have a sharh of their own, not Abu Shama's.
      expect(
        manzumat.explanation(Poem.durrah, 183)?.source,
        isNot(contains('أبو شامة')),
      );
    },
  );
}
