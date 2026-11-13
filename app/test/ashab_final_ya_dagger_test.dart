import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// al-Ashab's words keep the small alif over a final ya where Hafs writes
/// it (تَسَوَّىٰ، سَكۡرَىٰ، يَخۡفَىٰ), the book's quotation without it (the
/// user, 2026-11-14).
void main() {
  test('al-Ashab keep the small alif over a final ya as Hafs', () {
    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final words = <String, String>{
      for (final x in quran['ayahs'] as List)
        for (final (i, w) in (x[4] as String).split(' ').indexed)
          '${x[0]}:${x[1]}:$i': w,
    };
    final finalYa = RegExp(r'ى([ً-ٰٟۖ-ۭ]*)$');
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      final rows =
          (jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List;
      final missing = [
        for (final v in rows.cast<List>())
          if (v[5] != 'u' && v[3] == 1)
            if (finalYa.firstMatch('${v[4]}') case final m?)
              if (finalYa.firstMatch(words['${v[0]}:${v[1]}:${v[2]}'] ?? '')
                  case final h?)
                if (h[1]!.contains('ٰ') && !m[1]!.contains('ٰ'))
                  '${v[0]}:${v[1]}:${v[2]} ${v[4]}',
      ];
      expect(missing, isEmpty, reason: id);
    }
    // تسوى in the four riwayat of al-Kisa'i and Khalaf al-'Ashir: its ta
    // opened and its waw leaned, no more (the user, 2026-11-14).
    for (final id in const ['abul_harith', 'duri_kisai', 'ishaq', 'idris']) {
      expect(
        File('assets/data/qiraat/$id.json').readAsStringSync(),
        contains('[4,42,7,1,"تَسَوَّىٰ","f","بفتح التاء وبإمالة الواو"'),
      );
    }
  });

  // «لَمَسۡتُمُ» النساء ٤٣ and المائدة ٦: al-Kisa'i's as Khalaf al-'Ashir's,
  // in letters and hamesh (the user, 2026-11-14).
  test('al-Kisai reads lamastum as Khalaf al-Ashir in both places', () {
    List<List> at(String id, int s, int a, int w) => [
      for (final v
          in ((jsonDecode(
                    File('assets/data/qiraat/$id.json').readAsStringSync(),
                  ) as Map)['variants']
                  as List)
              .cast<List>())
        if (v[0] == s && v[1] == a && v[2] == w && v[5] == 'f') v,
    ];
    for (final (s, a, w) in const [(4, 43, 32), (5, 6, 34)]) {
      final his = at('ishaq', s, a, w).single;
      for (final id in const ['abul_harith', 'duri_kisai']) {
        final mine = at(id, s, a, w).single;
        expect(mine[4], his[4], reason: '$id $s:$a');
        expect(mine[6], his[6], reason: '$id $s:$a');
      }
    }
  });

  // «كَفَىٰ» leaned in all its places, where the book's section leaves it out
  // too (النساء ٤٥، ٥٠، الإسراء ١٤); at the stop alone where its alif falls
  // joined (الأحزاب ٢٥) (the user, 2026-11-14).
  test('al-Ashab lean kafa in all its places', () {
    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final places = [
      for (final x in quran['ayahs'] as List)
        for (final (i, w) in (x[4] as String).split(' ').indexed)
          if (RegExp(r'^[وف]?كفى$')
              .hasMatch(w.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')))
            '${x[0]}:${x[1]}:$i',
    ];
    expect(places, hasLength(27));
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      final rows =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .cast<List>();
      final imala = {
        for (final v in rows)
          if (v[5] == 'u' && '${v[6]}'.startsWith('بإمالة الألف'))
            '${v[0]}:${v[1]}:${v[2]}': '${v[6]}',
      };
      for (final p in places) {
        expect(imala[p], isNotNull, reason: '$id $p');
      }
      expect(imala['4:45:3'], 'بإمالة الألف', reason: id);
      expect(imala['33:25:8'], 'بإمالة الألف وقفًا', reason: id);
    }
  });

  // «فَتَثَبَّتُواْ» for «فَتَبَيَّنُواْ» in its three places, Hamza's, al-Kisa'i's
  // and Khalaf al-'Ashir's, as the user words it (2026-11-14).
  test('al-Ashab read fatathabbatu in its three places', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      final rows =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .cast<List>();
      for (final (s, a, w) in const [(4, 94, 8), (4, 94, 32), (49, 6, 7)]) {
        final row = rows
            .where((v) => v[0] == s && v[1] == a && v[2] == w && v[5] == 'f')
            .single;
        expect('${row[4]}', contains('تَثَبَّتُو'), reason: '$id $s:$a');
        expect(
          row[6],
          'بفاء ثم تاء ثم ثاء ثم باء مفتوحة ثم تاء مضمومة ثم واو',
          reason: '$id $s:$a',
        );
      }
    }
  });

  // al-Duri's «ٱلۡكَٰفِرِينَ» leaned in all its 93 places, the second of
  // النساء ١٤١ too; Abu al-Harith's and Khalaf al-'Ashir's not (the user,
  // 2026-11-14).
  test('al-Duri leans al-kafirin in all its places', () {
    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final places = [
      for (final x in quran['ayahs'] as List)
        for (final (i, w) in (x[4] as String).split(' ').indexed)
          if (RegExp(r'^[وفبل]*([اٱ]ل)?كفرين$')
              .hasMatch(w.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')))
            '${x[0]}:${x[1]}:$i',
    ];
    expect(places, hasLength(93));
    Set<String> leaned(String id) => {
      for (final v
          in ((jsonDecode(
                    File('assets/data/qiraat/$id.json').readAsStringSync(),
                  ) as Map)['variants']
                  as List)
              .cast<List>())
        if ('${v[6]}'.contains('مال')) '${v[0]}:${v[1]}:${v[2]}',
    };
    final duri = leaned('duri_kisai');
    expect(places.where((p) => !duri.contains(p)), isEmpty);
    expect(duri, contains('4:141:32'));
    for (final id in const ['abul_harith', 'ishaq', 'idris']) {
      expect(places.where(leaned(id).contains), isEmpty, reason: id);
    }
  });

  // «نُؤۡتِيهِمۡ» النساء ١٥٢ with the nun for Hamza as for al-Kisa'i, his sakt
  // drawn on it with the nun too (2026-11-14).
  test('Hamza reads nu-tihim with the nun', () {
    for (final id in const ['khalaf_hamzah', 'khallad']) {
      final rows = [
        for (final v
            in ((jsonDecode(
                      File('assets/data/qiraat/$id.json').readAsStringSync(),
                    ) as Map)['variants']
                    as List)
                .cast<List>())
          if (v[0] == 4 && v[1] == 152 && v[2] == 11) v,
      ];
      final farsh = rows.where((v) => v[5] == 'f').single;
      expect(farsh[4], 'نُؤۡتِيهِمۡ', reason: id);
      expect(farsh[6], 'بالنون', reason: id);
      for (final v in rows) {
        expect('${v[4]}', isNot(contains('يُؤۡتِيهِمۡ')), reason: id);
      }
    }
  });

  // «وَقَتۡلِهُمُ ٱلۡأَنۢبِيَآءَ» النساء ١٥٥: the ha's damma on «وَقَتۡلِهُمُ» in
  // the usul; «ٱلۡأَنۢبِيَآءَ» no farsh of its own (the user, 2026-11-14).
  test('al-Ashab read waqatlihumu with the damma, al-anbiya as Hafs', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      final rows =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .cast<List>();
      bool at(int w, bool Function(List) test) =>
          rows.any((v) => v[0] == 4 && v[1] == 155 && v[2] == w && test(v));
      expect(
        at(6, (v) => v[7] == 'ha_damir' && v[4] == 'وَقَتۡلِهُمُ'),
        isTrue,
        reason: id,
      );
      expect(at(7, (v) => v[5] == 'f'), isFalse, reason: id);
    }
  });
}
