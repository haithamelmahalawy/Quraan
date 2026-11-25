import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/ui/usul_labels.dart';

/// «أَتُمِدُّونَنِ» (النمل ٣٦) of Hamza and Ya'qub: told under the idgham alone
/// (the user, 2026-11-24).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ukhfi();
  ghurfat();
  tanawush();
  luluFatir();
  fawatih();
  waliNaja();
  liMin();
  amman();
  List rows(String id) =>
      ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List)
          .where((r) => r[0] == 27 && r[1] == 36 && r[2] == 4)
          .toList();

  test('one row, the nuns merged, the ya small, no big idgham', () {
    for (final id in ['khalaf_hamzah', 'khallad', 'ruways', 'rawh']) {
      final r = rows(id);
      expect(r, hasLength(1), reason: id);
      expect(r.single[4], 'أَتُمِدُّوٓننِّۦ');
      expect(r.single[6], 'بإدغام النون مع المد المشبع');
      expect(r.single[7], '');
      expect((r.single[8] as Map)['bandNote'], 'بإدغام النون مع المد المشبع');
    }
  });

  test('told under the idgham, not the madd', () {
    final v = Variant(
      riwayaId: 'khallad',
      surah: 27,
      ayah: 36,
      word: 4,
      count: 1,
      text: 'أَتُمِدُّوٓننِّۦ',
      kind: VariantKind.usul,
      description: 'بإدغام النون مع المد المشبع',
    );
    expect(usulOf(v), ['الإدغام']);
  });

  test('Hamza cites 937، 421، 426', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final r = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 27,
          ayah: 36,
          word: 4,
          count: 1,
          text: 'أَتُمِدُّوٓننِّۦ',
          kind: VariantKind.usul,
          description: 'بإدغام النون مع المد المشبع',
        ),
        'أَتُمِدُّونَنِ',
        27,
        names,
      );
      expect(r.mention, {937, 421, 426}, reason: id);
    }
  });

  test('«ءَاتِيكَ» leaned cites 329، 330', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final (id, d) in [
      ('khalaf_hamzah', 'بإمالة الألف'),
      ('khallad', 'بإمالة الألف بخلف عنه'),
      ('ishaq', 'بإمالة الألف'),
    ]) {
      for (final (a, w) in [(39, 5), (40, 7)]) {
        final r = m.referenceOf(
          Variant(
            riwayaId: id,
            surah: 27,
            ayah: a,
            word: w,
            count: 1,
            text: 'ءَ۪اتِيكَ',
            kind: VariantKind.usul,
            description: d,
          ),
          'ءَاتِيكَ',
          27,
          names,
        );
        expect(r.mention, {329, 330}, reason: '$id $a');
      }
    }
  });

  test('«ءَايَتٞ» (العنكبوت ٥٠) cites 954 for every reader of it', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final id in [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'shubah',
      'ishaq',
    ]) {
      final r = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 29,
          ayah: 50,
          word: 4,
          count: 1,
          text: 'ءَايَتٞ',
          kind: VariantKind.farsh,
          description: 'بحذف الألف',
        ),
        'ءَايَٰتٞ',
        29,
        names,
      );
      expect(r.mention, {954}, reason: id);
    }
  });
}

/// «أُخۡفِي» (السجدة ١٧), its ya quiet: Hamza 963, Ya'qub the Durrah's 181
/// (the user, 2026-11-24).
void ukhfi() {
  test('«أُخۡفِي» cites 963 for Hamza, 181 for Ya\'qub', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final (id, verses) in [
      ('khalaf_hamzah', {963}),
      ('khallad', {963}),
      ('ruways', {181}),
      ('rawh', {181}),
    ]) {
      final r = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 32,
          ayah: 17,
          word: 4,
          count: 1,
          text: 'أُخۡفِي',
          kind: VariantKind.usul,
          rule: 'ya_idafa',
          description: 'بإسكان ياء الإضافة',
        ),
        'أُخۡفِيَ',
        32,
        names,
      );
      expect(r.mention, verses, reason: id);
    }
  });
}

/// «ٱلۡغُرۡفَتِ» (سبأ ٣٧) of Hamza: the singular, its ta open (the user,
/// 2026-11-25).
void ghurfat() {
  test('«ٱلۡغُرۡفَتِ» for Hamza', () {
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final r =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .singleWhere((r) => r[0] == 34 && r[1] == 37 && r[2] == 21);
      expect(r[4], 'ٱلۡغُرۡفَتِ', reason: id);
      expect(r[6], 'بحذف الألف (على الإفراد)', reason: id);
    }
  });
}

/// «ٱلتَّنَآؤُشُ» (سبأ ٥٢): one note, 982 for every reader of it (the user,
/// 2026-11-25).
void tanawush() {
  test('«ٱلتَّنَآؤُشُ» told alike, cites 982', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final id in [
      'duri_abuamr',
      'susi',
      'shubah',
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      final r =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .singleWhere(
                (r) => r[0] == 34 && r[1] == 52 && r[2] == 5 && r[5] == 'h',
              );
      expect(r[6], 'بالهمز مع المد المتصل', reason: id);
      final ref = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 34,
          ayah: 52,
          word: 5,
          count: 1,
          text: r[4] as String,
          kind: VariantKind.hamza,
          description: r[6] as String,
        ),
        'ٱلتَّنَاوُشُ',
        34,
        names,
      );
      expect(ref.mention, {982}, reason: id);
    }
  });
}

/// «وَلُؤۡلُؤٖ» (فاطر ٣٣): one note, 895 alone for every reader of it (the
/// user, 2026-11-25).
void luluFatir() {
  test('«وَلُؤۡلُؤٖ» (فاطر ٣٣) told alike, cites 895', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final id in [
      'bazzi',
      'qunbul',
      'duri_abuamr',
      'hisham',
      'ibn_dhakwan',
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ruways',
      'rawh',
      'ishaq',
      'idris',
    ]) {
      final r =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .singleWhere(
                (r) => r[0] == 35 && r[1] == 33 && r[2] == 9 && r[5] == 'f',
              );
      expect(r[6], 'بتنوين الهمزة بالكسر', reason: id);
      final ref = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 35,
          ayah: 33,
          word: 9,
          count: 1,
          text: r[4] as String,
          kind: VariantKind.farsh,
          description: r[6] as String,
        ),
        'وَلُؤۡلُؤٗاۖ',
        35,
        names,
      );
      expect(ref.mention, {895}, reason: id);
    }
  });
}

/// The leaned fawatih cite 738, the ha of «طه» 739 (the user, 2026-11-25);
/// «وَلُؤۡلُؤٖ» (الحج ٢٣) 895 alone.
void fawatih() {
  test('the leaned fawatih cite 738', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    final seen = <String>[];
    for (final id in [
      'khallad',
      'khalaf_hamzah',
      'duri_kisai',
      'shubah',
      'duri_abuamr',
      'ibn_dhakwan',
      'ishaq',
    ]) {
      final rows =
          (jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List;
      for (final r in rows) {
        if (!const {
              10,
              11,
              12,
              13,
              14,
              15,
              20,
              26,
              27,
              28,
              36,
            }.contains(r[0]) ||
            r[1] != 1 ||
            r[2] != 0 ||
            !'${r[6]}'.contains('إمالة')) {
          continue;
        }
        final ref = m.referenceOf(
          Variant(
            riwayaId: id,
            surah: r[0] as int,
            ayah: 1,
            word: 0,
            count: 1,
            text: r[4] as String,
            kind: VariantKind.usul,
            description: r[6] as String,
          ),
          q.ayah(r[0] as int, 1).words.first,
          r[0] as int,
          names,
        );
        final want = r[0] == 20
            ? {
                if ('${r[6]}'.contains('الطاء')) 738,
                if ('${r[6]}'.contains('الهاء')) 739,
              }
            : {738};
        expect(ref.mention, want, reason: '$id ${r[0]}');
        seen.add('$id ${r[0]}');
      }
    }
    expect(seen.length, greaterThan(50));
  });

  test('«وَلُؤۡلُؤٖ» (الحج ٢٣) cites 895 alone', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final id in ['khallad', 'bazzi', 'duri_abuamr', 'hisham', 'ishaq']) {
      final ref = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 22,
          ayah: 23,
          word: 18,
          count: 1,
          text: 'وَلُؤۡلُؤٖاْ',
          kind: VariantKind.farsh,
          description: 'بتنوين الهمزة بالكسر',
        ),
        'وَلُؤۡلُؤٗاۚ',
        22,
        names,
      );
      expect(ref.mention, {895}, reason: id);
    }
  });
}

/// «وَلِي نَعۡجَةٞ» (ص ٢٣) quiet cites 417 (the user, 2026-11-25).
void waliNaja() {
  test('«وَلِي» (ص ٢٣) cites 417', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final (id, kind) in [
      ('khallad', VariantKind.usul),
      ('khalaf_hamzah', VariantKind.usul),
      ('susi', VariantKind.farsh),
      ('shubah', VariantKind.farsh),
      ('ruways', VariantKind.farsh),
      ('ishaq', VariantKind.usul),
    ]) {
      final ref = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 38,
          ayah: 23,
          word: 7,
          count: 1,
          text: 'وَلِي',
          kind: kind,
          rule: kind == VariantKind.usul ? 'ya_idafa' : '',
          description: 'بإسكان الياء',
        ),
        'وَلِيَ',
        38,
        names,
      );
      expect(ref.mention, {417}, reason: id);
    }
  });
}

/// «لِي مِنۡ عِلۡمِۭ» (ص ٦٩) quiet cites 417 (the user, 2026-11-25).
void liMin() {
  test('«لِي» (ص ٦٩) cites 417', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final (id, kind) in [
      ('khallad', VariantKind.usul),
      ('duri_kisai', VariantKind.usul),
      ('susi', VariantKind.farsh),
      ('shubah', VariantKind.farsh),
      ('hisham', VariantKind.farsh),
      ('ruways', VariantKind.farsh),
      ('ishaq', VariantKind.usul),
    ]) {
      final ref = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 38,
          ayah: 69,
          word: 2,
          count: 1,
          text: 'لِي',
          kind: kind,
          rule: kind == VariantKind.usul ? 'ya_idafa' : '',
          description: 'بإسكان ياء الإضافة',
        ),
        'لِيَ',
        38,
        names,
      );
      expect(ref.mention, {417}, reason: id);
    }
  });
}

/// «أَمَنۡ» (الزمر ٩) lightened cites 1005 (the user, 2026-11-25).
void amman() {
  test('«أَمَنۡ» (الزمر ٩) cites 1005', () async {
    final m = await Manzumat.load();
    final q = await QuranRepository.load();
    final names = [for (final s in q.surahs) s.nameAr];
    for (final id in ['khallad', 'khalaf_hamzah', 'qalun', 'warsh', 'bazzi']) {
      final ref = m.referenceOf(
        Variant(
          riwayaId: id,
          surah: 39,
          ayah: 9,
          word: 0,
          count: 1,
          text: 'أَمَنۡ',
          kind: VariantKind.farsh,
          description: 'بتخفيف الميم',
        ),
        'أَمَّنۡ',
        39,
        names,
      );
      expect(ref.mention, {1005}, reason: id);
    }
  });
}
