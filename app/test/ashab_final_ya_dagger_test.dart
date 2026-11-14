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
    // Every riwaya's, not al-Ashab's alone (Hisham's «وَأَوْصَىٰ», Abu Ja'far's
    // «أُسَٰرَىٰ» without the madd, Warsh's «ٱهۡتَدَىٰ») (the user, 2026-11-14).
    for (final id in [
      for (final f in Directory('assets/data/qiraat').listSync())
        if (f.path.endsWith('.json'))
          f.uri.pathSegments.last.replaceFirst('.json', ''),
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

  // Hamza's «إِلَيۡهُمۡ» النساء ٦: no farsh of the book's broken quotation, the
  // ha's damma in the usul (the user, 2026-11-14); Abu Ja'far's «أُسَٰرَىٰ»
  // without the madd, as he reads it short.
  test('Hamza has no broken farsh on ilayhim; Abu Jafar no madd', () {
    List<List> rows(String id) =>
        ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                    as Map)['variants']
                as List)
            .cast<List>();
    for (final id in const ['khalaf_hamzah', 'khallad']) {
      for (final w in const [11, 30]) {
        final at = rows(id).where((v) => v[0] == 4 && v[1] == 6 && v[2] == w);
        expect(at.where((v) => v[5] == 'f'), isEmpty, reason: '$id $w');
        expect(at.any((v) => v[7] == 'ha_damir'), isTrue, reason: '$id $w');
      }
    }
    for (final id in const ['ibn_wardan', 'ibn_jammaz']) {
      final text = rows(id)
          .where((v) => v[0] == 8 && v[1] == 70 && v[2] == 7)
          .single[4];
      expect(text, 'ٱلۡأُسَٰرَىٰ', reason: id);
    }
  });

  // A ya of idafa read quiet before a hamza (يَدِيٓ إِلَيۡكَ، المائدة ٢٨): the
  // separated madd over it, al-Ashab reading it long (the user, 2026-11-14).
  test('al-Ashab put the separated madd over a quiet ya before a hamza', () {
    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final words = <String, String>{
      for (final x in quran['ayahs'] as List)
        for (final (i, w) in (x[4] as String).split(' ').indexed)
          '${x[0]}:${x[1]}:$i': w,
    };
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
      final quiet = [
        for (final v in rows)
          if (v[7] == 'ya_idafa' &&
              v[3] == 1 &&
              RegExp(
                '^[أإءآ]',
              ).hasMatch(words['${v[0]}:${v[1]}:${(v[2] as int) + 1}'] ?? '') &&
              RegExp(r'ي[ٓ]?$').hasMatch('${v[4]}'))
            v,
      ];
      expect(quiet, isNotEmpty, reason: id);
      for (final v in quiet) {
        expect('${v[4]}', endsWith('يٓ'), reason: '$id ${v[0]}:${v[1]}');
      }
      expect(
        quiet.where((v) => v[0] == 5 && v[1] == 28).single[4],
        'يَدِيٓ',
        reason: id,
      );
    }
  });

  // A word the book's section names once and that comes again in the ayah
  // (هُدٗى ... وَهُدٗى، المائدة ٤٦): leaned again as the first; not where it is
  // leaned already (أَوۡلَىٰ لَكَ فَأَوۡلَىٰ، القيامة ٣٤) (the user, 2026-11-14).
  test('al-Ashab lean a word again where it comes again in the ayah', () {
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
      List<String> at(int s, int a, int w) => [
        for (final v in rows)
          if (v[0] == s && v[1] == a && v[2] == w && '${v[6]}'.contains('مال'))
            '${v[6]}',
      ];
      expect(at(5, 46, 15), ['بإمالة الألف وقفًا'], reason: id);
      expect(at(5, 46, 23), ['بإمالة الألف وقفًا'], reason: id);
      expect(at(75, 34, 0), hasLength(1), reason: id);
      expect(at(75, 34, 2), hasLength(1), reason: id);
    }
  });

  // «ٱلۡأَوَّلِينَ» (المائدة ١٠٧) its ya quiet, not opened, for Khalaf
  // al-'Ashir, Hamza and Ya'qub; Hamza's sakt on its article over his own
  // word (the user, 2026-11-14).
  test('al-awwalin with its ya quiet, the sakt on its own word', () {
    List<List> at(String id) => [
      for (final v
          in ((jsonDecode(
                    File('assets/data/qiraat/$id.json').readAsStringSync(),
                  ) as Map)['variants']
                  as List)
              .cast<List>())
        if (v[0] == 5 && v[1] == 107 && v[2] == 13) v,
    ];
    for (final id in const [
      'ishaq',
      'idris',
      'khalaf_hamzah',
      'khallad',
      'ruways',
      'rawh',
    ]) {
      final farsh = at(id).where((v) => v[5] == 'f').single;
      // Its ya quiet: no fatha over it.
      expect('${farsh[4]}', endsWith('ينَ'), reason: id);
      expect('${farsh[4]}', isNot(contains('يَ')), reason: id);
    }
    for (final id in const ['khalaf_hamzah', 'khallad']) {
      final sakt = at(id).where((v) => '${v[4]}'.contains('ۜ')).single;
      expect('${sakt[4]}', startsWith('ٱلۡۜأَ'), reason: id);
      expect('${sakt[4]}', endsWith('ينَ'), reason: id);
      expect('${sakt[4]}', isNot(contains('يَ')), reason: id);
    }
  });

  // al-Kisa'i's «وَهۡوَ، فَهۡوَ» its ha quiet in all the places, as Qalun's
  // (الأنعام ١٧، ١٨ were left out) (the user, 2026-11-14).
  test('al-Kisai reads every wahwa and fahwa with the ha quiet', () {
    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final places = [
      for (final x in quran['ayahs'] as List)
        for (final (i, w) in (x[4] as String).split(' ').indexed)
          if (RegExp(r'^[وفل]ه[وي]$')
                  .hasMatch(w.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')) &&
              // «لَهۡوٞ» the noun, not the pronoun.
              !w.contains('ۡ'))
            '${x[0]}:${x[1]}:$i',
    ];
    for (final id in const ['abul_harith', 'duri_kisai']) {
      final quiet = {
        for (final v
            in ((jsonDecode(
                      File('assets/data/qiraat/$id.json').readAsStringSync(),
                    ) as Map)['variants']
                    as List)
                .cast<List>())
          if ('${v[6]}'.contains('إسكان الهاء')) '${v[0]}:${v[1]}:${v[2]}',
      };
      expect(places.where((p) => !quiet.contains(p)), isEmpty, reason: id);
      expect(quiet, containsAll(['6:17:12', '6:18:0', '6:18:4']), reason: id);
    }
  });

  // al-Kisa'i's «أَرَيۡتُمۡ، أَرَيۡتَكُمۡ، أَفَرَيۡتَ» in every place, the second
  // hamza gone (the user, 2026-11-14).
  test("al-Kisai drops the second hamza of every ara'aytum", () {
    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final places = {
      for (final x in quran['ayahs'] as List)
        for (final (i, w) in (x[4] as String).split(' ').indexed)
          if (RegExp('^أَ(?:فَ)?رَءَيۡت').hasMatch(w))
            '${x[0]}:${x[1]}:$i': w.replaceFirst('رَءَ', 'رَ'),
    };
    expect(places, hasLength(34));
    for (final id in const ['abul_harith', 'duri_kisai']) {
      final farsh = {
        for (final v
            in ((jsonDecode(
                      File('assets/data/qiraat/$id.json').readAsStringSync(),
                    ) as Map)['variants']
                    as List)
                .cast<List>())
          if (v[5] == 'f') '${v[0]}:${v[1]}:${v[2]}': v,
      };
      for (final MapEntry(:key, :value) in places.entries) {
        expect(farsh[key]?[4], value, reason: '$id $key');
        expect(farsh[key]?[6], 'بحذف الهمزة الثانية', reason: '$id $key');
      }
    }
  });

  // «إِلَى ٱلۡهُدَى ٱئۡتِنَا»: before a quiescent leaned at the stop alone, the
  // plain row gone; «أَهۡدَىٰ مِنۡهُمۡ» leaned in both (the user, 2026-11-14).
  test('a leaned alif before a quiescent is leaned at the stop alone', () {
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
      List<String> at(String k) => [
        for (final v in rows)
          if ('${v[0]}:${v[1]}:${v[2]}' == k && '${v[6]}'.contains('إمالة'))
            '${v[6]}',
      ];
      expect(at('6:71:27'), ['بإمالة الألف وقفًا'], reason: id);
      expect(at('28:44:7'), ['بإمالة الألف وقفًا'], reason: id);
      expect(at('6:157:8'), ['بإمالة الألف'], reason: id);
    }
  });

  // «رَءَا» before a quiescent: Hamza and Khalaf al-'Ashir lean its ra in
  // joining, al-Kisa'i not; at the stop all the ra and the hamza (the user,
  // 2026-11-14).
  test(
    "ra'a before a quiescent: its ra leaned in joining by Hamza and Khalaf",
    () {
      const places = [
        '6:77:1',
        '6:78:1',
        '16:85:1',
        '16:86:1',
        '18:53:0',
        '26:61:1',
        '33:22:1',
      ];
      for (final id in const [
        'khalaf_hamzah',
        'khallad',
        'ishaq',
        'idris',
        'abul_harith',
        'duri_kisai',
      ]) {
        final rows =
            ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                        as Map)['variants']
                    as List)
                .cast<List>();
        final wasl = {
          for (final v in rows)
            if (v[6] == 'بإمالة الراء وصلًا')
              '${v[0]}:${v[1]}:${v[2]}': '${v[4]}',
        };
        if (id.contains('kisai') || id == 'abul_harith') {
          expect(wasl, isEmpty, reason: id);
        } else {
          expect(wasl.keys, places, reason: id);
          expect(wasl['6:78:1'], 'رَ۪ءَا', reason: id);
        }
        expect(
          rows.any(
            (v) =>
                '${v[0]}:${v[1]}:${v[2]}' == '6:78:1' &&
                v[6] == 'بإمالة الراء والهمزة وقفًا',
          ),
          isTrue,
          reason: id,
        );
      }
    },
  );

  // «وَٱلَّيۡسَعَ» (الأنعام ٨٦، ص ٤٨): its lam doubled, its ya quiet (the user,
  // 2026-11-14).
  test("al-laysa' with the lam doubled and the ya quiet", () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'ishaq',
      'idris',
      'abul_harith',
      'duri_kisai',
    ]) {
      final rows =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .cast<List>();
      for (final k in const ['6:86:1', '38:48:2']) {
        final v = rows
            .where((v) => '${v[0]}:${v[1]}:${v[2]}' == k && v[5] == 'f')
            .single;
        expect(v[4], 'وَٱلَّيۡسَعَ', reason: '$id $k');
        expect(v[6], 'بتشديد اللام وإسكان الياء', reason: '$id $k');
      }
    }
  });

  // The ha of silence in the usul, as Ya'qub's (the user, 2026-11-14).
  test('the ha of silence of al-Ashab told in the usul as Ya\'qub\'s', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'ishaq',
      'idris',
      'abul_harith',
      'duri_kisai',
    ]) {
      final rows =
          ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                      as Map)['variants']
                  as List)
              .cast<List>();
      final ha = {
        for (final v in rows)
          if (v[7] == 'ha_sakt') '${v[0]}:${v[1]}:${v[2]}': v,
      };
      final hamza = id == 'khalaf_hamzah' || id == 'khallad';
      expect(ha.keys, [
        '2:259:41',
        '6:90:5',
        if (hamza) ...['69:28:3', '69:29:2', '101:10:3'],
      ], reason: id);
      for (final v in ha.values) {
        expect(v[5], 'u', reason: id);
        expect(v[6], 'بحذف هاء السكت وصلاً وإثباتها وقفًا', reason: id);
      }
      expect(
        rows.where(
          (v) => v[5] == 'f' && '${v[6]}'.contains('الهاء وصلًا وإثباتها'),
        ),
        isEmpty,
        reason: id,
      );
    }
  });

  // «مُوسَىٰ ثَلَٰثِينَ، مُوسَىٰ لِمِيقَٰتِنَا»: no quiescent after the alif, leaned
  // joined too; «هُدٗى» and «ٱلۡأَعۡلَى / ٱلَّذِي» at the stop alone (the user,
  // 2026-11-14).
  test('an alif before a moving letter is leaned joined too', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'ishaq',
      'idris',
      'abul_harith',
      'duri_kisai',
    ]) {
      final rows = ((jsonDecode(
                File('assets/data/qiraat/$id.json').readAsStringSync(),
              ) as Map)['variants']
              as List)
          .cast<List>();
      List<String> at(String k) => [
        for (final v in rows)
          if ('${v[0]}:${v[1]}:${v[2]}' == k &&
              '${v[6]}'.startsWith('بإمالة الألف'))
            '${v[6]}',
      ];
      for (final k in ['7:142:1', '7:143:2', '2:260:12', '75:31:3']) {
        expect(at(k), ['بإمالة الألف'], reason: '$id $k');
      }
      for (final k in ['87:1:3', '6:71:27']) {
        expect(at(k), ['بإمالة الألف وقفًا'], reason: '$id $k');
      }
      expect(at('6:157:8'), ['بإمالة الألف'], reason: id);
    }
  });
}
