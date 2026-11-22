import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:qiraat_mushaf/data/waqf_hamza.dart';

import '../tool/build_ashab_usul.dart';

void main() {
  late Map quran, book;
  late AshabSources sources;
  Map load(String id) =>
      jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync()) as Map;
  setUpAll(() {
    quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    book =
        jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
    sources = AshabSources.load(
      (id) => File('assets/data/qiraat/$id.json').readAsStringSync(),
    );
  });

  test('al-Ashab files are what tool/build_ashab_usul.dart builds', () {
    for (final id in ashabRiwayat) {
      final data = load(id);
      final saved = jsonEncode(data['variants']);
      buildAshabUsul(quran, data, id, sources, raw: ashabRaw(id), book: book);
      expect(jsonEncode(data['variants']), saved, reason: id);
    }
  });

  List<List> at(String id, int s, int a, int w) => [
    for (final v in (load(id)['variants'] as List).cast<List>())
      if (v[0] == s && v[1] == a && v[2] == w) v,
  ];

  test("Hisham's stop on a hamza after a waw or ya of the root: the naql too", () {
    // «سُوٓءَ ٱلۡعَذَابِ» (البقرة ٤٩) moved onto as well as merged, as Hamza's
    // (التوثيق للتسهيل; the user, 2026-11-20); «بَرِيٓءٞ» merged alone.
    final suu = at(
      'hisham',
      2,
      49,
      6,
    ).singleWhere((v) => v[7] == 'hisham_waqf');
    expect((suu[8] as Map)['ways'], [
      'إبدالها من جنس ما قبلها وإدغامه فيه مع السكون المحض',
      'نقل حركتها إلى الساكن قبلها مع السكون المحض',
    ]);
    final bari = at(
      'hisham',
      6,
      19,
      34,
    ).singleWhere((v) => v[7] == 'hisham_waqf');
    expect(
      ((bari[8] as Map)['ways'] as List).any((w) => '$w'.contains('نقل')),
      isFalse,
    );
  });

  test("the book's «وعلى كل» told once after the two faces of «شيء»", () {
    // «بِكُلِّ شَيۡءٍ» (البقرة ٢٣١): the naql and the merging, then the sukun
    // and the rawm once, no ishmam with the kasra (the user, 2026-11-20).
    List faces(String at) => [
      for (final f
          in ((book['entries'] as List).firstWhere(
                (e) => '${e[0]}:${e[1]}:${e[2]}' == at,
              ) as List)[5]
              as List)
        if (f[4] == true) f[3],
    ];
    expect(faces('2:231:43'), [
      'النقل ـ نقل حركة الهمزة إلى الساكن قبلها مع حذف الهمزة، ثم تسكن الياء للوقف',
      'الإدغام ـ إبدال الهمزة ياء وإدغام ما قبلها فيها',
      'وعلى كلٍّ: السكون المحض والرَّوم',
    ]);
    // شَيۡءٞ with the damma: the ishmam too; شَيۡـٔٗا: none after the alif.
    expect(
      faces('2:178:19').last,
      'وعلى كلٍّ: السكون المحض، والرَّوم، والإشمام',
    );
    expect(faces('2:216:9').any((h) => '$h'.contains('وعلى كل')), isFalse);
    // «وَزَادَهُۥ» and «وَزَادَكُمۡ»: Ibn Dhakwan's dispute told by him first,
    // and «بخلف» beside his word in the usul, under the imala, not in the
    // hamesh (the user, 2026-11-20, 2026-11-21).
    for (final (key, s, a, w) in [
      ('2:247:30', 2, 247, 30),
      ('7:69:18', 7, 69, 18),
      ('3:173:10', 3, 173, 10),
      ('72:6:9', 72, 6, 9),
    ]) {
      final r =
          ((book['entries'] as List).firstWhere(
                (e) => '${e[0]}:${e[1]}:${e[2]}' == key && e[4] == 'mumal',
              ) as List)[5]
              as List;
      expect(r.last, [
        '',
        [],
        ['ibn_dhakwan'],
        'بالإمالة والفتح، والراجح الإمالة',
        false,
        false,
        [],
      ]);
      final rows = at('ibn_dhakwan', s, a, w);
      expect(rows.map((v) => v[6]), [
        'بإمالة الألف بخلف عنه، والإمالة هي المقدّمة',
      ]);
      expect(
        (rows.single[8] as Map)['bandNote'],
        'بخلف عنه، والإمالة هي المقدّمة أداءً',
      );
    }
    // The ishmam with the damma alone, never with the kasra (لِشَاْيۡءٍ).
    expect(faces('18:23:2').last, 'وعلى كلٍّ: السكون المحض والرَّوم');
    // «عمران» and «المحراب» of Ibn Dhakwan in the usul, each by its own
    // word: the fath first in «عمران», the imala in the nasb «المحراب», the
    // imala alone in the jarr (the user, 2026-11-20).
    List entry(String key, String section) => ((book['entries'] as List).where(
      (e) => '${e[0]}:${e[1]}:${e[2]}' == key && e[4] == section,
    )).toList();
    String hamesh(int s, int a, int w) =>
        (at('ibn_dhakwan', s, a, w).single[8] as Map)['bandNote'];
    expect(hamesh(3, 33, 8), 'بخلف عنه، والفتح هو المقدّم أداءً');
    expect(hamesh(3, 37, 13), 'بخلف عنه، والإمالة هي المقدّمة أداءً');
    // «حِمَارِكَ» (البقرة ٢٥٩) and every disputed imala of his alike: «بخلف
    // عنه» in the usul, both faces in the book's note (the user, 2026-11-21).
    // The face preferred told there too, as the book (the user, 2026-11-21).
    expect(hamesh(2, 259, 44), 'بخلف عنه، والإمالة هي المقدّمة أداءً');
    expect(
      (entry('2:259:44', 'mumal').single[5] as List).singleWhere(
        (f) => (f[2] as List).contains('ibn_dhakwan'),
      )[3],
      'بالإمالة والفتح، والراجح الإمالة',
    );
    expect(
      (entry('3:33:8', 'mumal').single[5] as List).singleWhere(
        (f) => (f[2] as List).contains('ibn_dhakwan'),
      )[3],
      'بالإمالة والفتح، والراجح الفتح',
    );
    expect(hamesh(3, 39, 6), 'بالإمالة قولًا واحدًا');
    expect(hamesh(19, 11, 4), 'بالإمالة قولًا واحدًا');
    expect(
      (entry('3:37:13', 'mumal').single[5] as List).single[3],
      'بالإمالة والفتح، والراجح الإمالة',
    );
    // «في المحراب إنّ الله» (آل عمران ٣٩): three lines, no «الممال».
    expect(entry('3:39:6', 'mumal'), isEmpty);
    // What Hafs reads alike untold: «تُكۡفَرُوهُ» (آل عمران ١١٥) «بالتاء» without
    // the ha's shortness, «يَحۡسَبَنَّ» (١٨٨) «بالياء» without the sin's fatha
    // (the user, 2026-11-20).
    for (final id in const ['hisham', 'ibn_dhakwan']) {
      expect(at(id, 3, 115, 5).single[6], 'بالتاء');
      expect(at(id, 3, 188, 1).single[6], 'بالياء');
    }
    expect(
      [for (final g in entry('3:39:5', 'farsh').single[5] as List) g[3]],
      ['', '(بالإمالة في «المحراب» قولًا واحدًا)', ''],
    );
  });

  test('the chapters of the guide, each for its readers', () {
    // «الصراط» for Khalaf everywhere, for Khallad in al-Fatiha alone.
    expect(
      at('khalaf_hamzah', 1, 7, 0).map((v) => v[7]),
      contains('ishmam_sad'),
    );
    expect(
      at('khallad', 1, 7, 0).map((v) => v[7]),
      isNot(contains('ishmam_sad')),
    );
    // «عليهم» with its ha joined to Hamza, not to al-Kisa'i.
    expect(at('khallad', 1, 7, 3).map((v) => v[7]), contains('ha_damir'));
    expect(
      at('abul_harith', 1, 7, 3).map((v) => v[7]),
      isNot(contains('ha_damir')),
    );
    // «يفعل ذلك» merged by Abu al-Harith alone.
    final yaf = at('abul_harith', 2, 231, 15).map((v) => v[6]);
    expect(yaf, contains('بإدغام اللام في الذال'));
    expect(
      at('duri_kisai', 2, 231, 15).map((v) => v[6]),
      isNot(contains('بإدغام اللام في الذال')),
    );
    // al-Kisa'i's feminine ha when stopping (غِشَٰوَةٞ).
    expect(
      at('duri_kisai', 2, 7, 8).map((v) => v[6]),
      contains('بإمالة هاء التأنيث وما قبلها وقفًا قولًا واحدًا'),
    );
    // Hamza's stop on «يؤمنون»; none for al-Kisa'i.
    expect(
      at('khalaf_hamzah', 2, 3, 1).map((v) => v[7]),
      contains('hisham_waqf'),
    );
    expect(
      at('abul_harith', 2, 3, 1).map((v) => v[7]),
      isNot(contains('hisham_waqf')),
    );
    // Khalaf's sakt on a quiet letter before the round sukun of its alif
    // (خَلَوۡاْ إِلَىٰ); none for Khallad.
    expect(
      at(
        'khalaf_hamzah',
        2,
        14,
        7,
      ).where((v) => v[7] == 'sakt').map((v) => v[4]),
      contains('خَلَوۡۜاْ'),
    );
    expect(at('khallad', 2, 14, 7).map((v) => v[7]), isNot(contains('sakt')));
    // Hamza's farsh the book tells with its stop: «فَأَزَٰلَهُمَا» and
    // «وَٱلۡأَرۡحَامِ», with the sakt by his kasra; not al-Kisa'i's.
    for (final id in ['khalaf_hamzah', 'khallad']) {
      expect(at(id, 2, 36, 0).where((v) => v[5] == 'f').map((v) => v[4]), [
        'فَأَزَٰلَهُمَا',
      ]);
      expect(at(id, 4, 1, 22).where((v) => v[5] == 'f').map((v) => v[4]), [
        'وَٱلۡأَرۡحَامِۚ',
      ]);
      expect(at(id, 4, 1, 22).where((v) => v[7] == 'sakt').map((v) => v[4]), [
        'وَٱلۡۜأَرۡحَامِۚ',
      ]);
    }
    expect(at('abul_harith', 2, 36, 0).where((v) => v[5] == 'f'), isEmpty);
    // «أَسۡرَىٰ» told without its ya, read as Hafs's.
    expect(
      at('khalaf_hamzah', 2, 85, 16).where((v) => v[5] == 'f').map((v) => v[6]),
      ['بفتح الهمزة وإسكان السين وحذف الألف'],
    );
    // Every word vowelled: no «ولاخوفٌ عليهُم» (read as Hafs's but the ha),
    // «تَرَوۡنَ» with the ta for «أو لا ترون», the wasl alif of «ٱلسَّلَمَ».
    for (final id in ['khalaf_hamzah', 'khallad']) {
      expect(at(id, 2, 62, 18).where((v) => v[5] == 'f'), isEmpty);
      expect(at(id, 9, 126, 0).where((v) => v[5] == 'f'), isEmpty);
      expect(at(id, 9, 126, 1).where((v) => v[5] == 'f').map((v) => v[4]), [
        'تَرَوۡنَ',
      ]);
    }
    for (final id in ['khalaf_hamzah', 'khallad', 'ishaq']) {
      expect(at(id, 4, 94, 14).where((v) => v[5] == 'f').map((v) => v[4]), [
        startsWith('ٱلس'),
      ]);
    }
    // Khalaf's sakt at an ayah's end before the next one's hamza (قَدِيرٌۜ ۝
    // أَلَمۡ); none for Khallad.
    expect(
      at('khalaf_hamzah', 2, 106, 18).where((v) => v[7] == 'sakt'),
      isNotEmpty,
    );
    expect(at('khallad', 2, 106, 18).where((v) => v[7] == 'sakt'), isEmpty);
    // Khalaf's idgham into a word his farsh starts with a ya (مَن يَطَّوَّعۡ
    // for «تطوع»), its letter doubled once (صَٰلِحٗا يُّؤۡتِهَا).
    String letters(Object t) => '$t'.replaceAll(RegExp('[ً-ْٰۡ]'), '');
    final tatawwa = at(
      'khalaf_hamzah',
      2,
      158,
      17,
    ).where((v) => v[7] == 'idgham_bila_ghunna').map((v) => '${v[4]}');
    expect(tatawwa.map(letters), ['ومن يطوع']);
    expect(tatawwa.single.split(' ').last, startsWith('يّ'));
    final yutiha = at(
      'khalaf_hamzah',
      33,
      31,
      6,
    ).where((v) => v[7] == 'idgham_bila_ghunna').map((v) => '${v[4]}');
    expect(yutiha.single.split(' ').last.split('ّ'), hasLength(2));
    // Khalaf's idgham after his farsh's word: «هُزۡؤٗا وَّٱذۡكُرُواْ», the hamza
    // on the waw as the farsh and Khalaf al-'Ashir write it.
    for (final (a, w) in const [(231, 24)]) {
      final row = at(
        'khalaf_hamzah',
        2,
        a,
        w,
      ).where((v) => v[7] == 'idgham_bila_ghunna').single;
      expect('${row[4]}', startsWith('هُزۡؤ'));
    }
    // «قَالَ كَمۡ لَبِثۡتَۖ» (البقرة ٢٥٩), the first of three, merged as the
    // others; the ya made quiet before the wasl alif bare (رَبِّي ٱلَّذِي).
    for (final id in ['khalaf_hamzah', 'khallad', 'duri_kisai']) {
      expect(
        at(id, 2, 259, 24).where((v) => v[7] == 'idgham_saghir'),
        hasLength(1),
        reason: id,
      );
    }
    expect(at('ishaq', 2, 259, 24), isEmpty);
    // «ٱلرِّبَوٰاْ» leaned in all its places of البقرة ٢٧٥, its stop signs aside.
    for (final id in ['khalaf_hamzah', 'duri_kisai']) {
      for (final w in [2, 19, 24]) {
        expect(
          at(id, 2, 275, w).where((v) => '${v[6]}' == 'بإمالة الألف'),
          hasLength(1),
          reason: '$id $w',
        );
      }
    }
    // The stop on the hamza against «نهج حمزة», juz 3 to 30: one word of each
    // pattern, for both narrators.
    for (final id in ['khalaf_hamzah', 'khallad']) {
      List ways(int s, int a, int w) => [
        for (final v in at(id, s, a, w))
          if (v[7] == 'hisham_waqf' &&
              (v[8] as Map)['kind'] != 'الوقف على الساكن المفصول')
            ...((v[8] as Map)['ways'] as List),
      ];
      // مِاْئَةَ: the silent alif aside, the ya of the kasra.
      expect(ways(2, 259, 18), ['إبدالها ياءً مفتوحة'], reason: id);
      // هَنِيٓـٔٗا، جُزۡءٗا، خَطَـٔٗا: middle at the stop.
      expect(ways(4, 4, 12), ['إبدالها من جنس ما قبلها وإدغامه فيه']);
      expect(ways(2, 260, 29), ['نقل حركتها إلى الساكن قبلها']);
      expect(ways(4, 92, 7), ['تسهيلها بين بين']);
      // جَزَآءَۢ: after an alif with the nasb, as «بِنَآءٗ».
      expect(ways(5, 38, 4), [
        'تسهيلها بين بين مع المد',
        'تسهيلها بين بين مع القصر',
      ]);
      // يُنَبِّئُكُم: al-Akhfash's ya for both.
      expect(ways(9, 94, 26), contains('إبدالها ياءً مضمومة'), reason: id);
      // سَأَصۡرِفُ: the future's sin added; not «سَأَلۡتَهُمۡ».
      expect(ways(7, 146, 0), ['التحقيق', 'تسهيلها بين بين']);
      expect(ways(9, 65, 1), ['تسهيلها بين بين']);
      // رَءَا: its fatha before the read alif, middle.
      expect(ways(6, 76, 4), ['تسهيلها بين بين']);
      // أَئِمَّةٗ: of the root, eased alone.
      expect(ways(9, 12, 10), ['تسهيلها بين بين']);
      // ٱمۡرُؤٌاْ: the waw of the rasm with the ishmam and the rawm.
      expect(ways(4, 176, 7), contains('إبدالها واوًا على الرسم مع الإشمام'));
      // تَبُوٓأَ: the waw of the root, moved onto too.
      expect(
        ways(5, 29, 3),
        contains('نقل حركتها إلى الساكن قبلها مع السكون المحض'),
      );
      // Hamza's own reading: دَكَّآءَ، سَوَآءٌ (الحج ٢٥) against «سَوَآءٗ»
      // (الجاثية ٢١)، وَجَبۡرَئِيلُ، وَطۡـٔٗا with Hisham's «وِطَآءً» no more.
      expect(ways(7, 143, 28), hasLength(3));
      expect(ways(22, 25, 12), hasLength(5));
      expect(ways(45, 21, 11), hasLength(2));
      expect(ways(66, 4, 14), ['تسهيلها بين بين']);
      expect(ways(73, 6, 5), ['نقل حركتها إلى الساكن قبلها']);
      // يَبۡلُغَآنِّ: no hamza of his.
      expect(ways(17, 23, 9), isEmpty);
    }
    // «فَنَعِمَّا» and «وَكِتَٰبِهِۦ»: one description with every reader.
    for (final id in ['khalaf_hamzah', 'duri_kisai', 'ishaq']) {
      expect(
        at(id, 2, 271, 3).where((v) => v[5] == 'f').single[6],
        'بفتح النون',
      );
      expect(
        at(id, 2, 285, 12).where((v) => v[5] == 'f').single[6],
        'بكسر الكاف وفتح التاء وإثبات الألف (على الإفراد)',
      );
    }
    // «فَـَٔاذِنُواْ» (البقرة ٢٧٩): the fa kept, as Shu'ba's.
    for (final id in ['khalaf_hamzah', 'khallad']) {
      expect(
        at(id, 2, 279, 3).where((v) => v[5] != 'u').single[6],
        'بفتح الهمزة وإثبات الألف وكسر الذال',
        reason: id,
      );
    }
    // «قَالَ ٱعۡلَمۡ أَنَّ» by Hamza's farsh: Khalaf's sakt on its mim, the stop
    // on the separated sakin's hamza for both.
    expect(
      at('khalaf_hamzah', 2, 259, 60).where((v) => v[7] == 'sakt').single[4],
      'ٱعۡلَمۡۜ',
    );
    for (final id in ['khalaf_hamzah', 'khallad']) {
      expect(
        at(id, 2, 259, 61).where(
          (v) =>
              v[7] == 'hisham_waqf' &&
              (v[8] as Map)['kind'] == 'الوقف على الساكن المفصول',
        ),
        hasLength(1),
        reason: id,
      );
    }
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final rabbi = at(id, 2, 258, 15).where((v) => v[5] == 'f').single;
      expect('${rabbi[4]}', endsWith('ي'), reason: id);
    }
    // «فَمَن تَطَوَّعَ خَيۡرٗا فَهُوَ» (١٨٤) as Hafs's for al-Ashab: no farsh,
    // no idgham.
    for (final id in [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'abul_harith',
      'ishaq',
      'idris',
    ]) {
      expect(at(id, 2, 184, 19), isEmpty, reason: id);
      expect(at(id, 2, 184, 20), isEmpty, reason: id);
    }
    // Juz 2 against «نهج حمزة»: al-Akhfash's ya in «وَلِأُتِمَّ»; the hamza
    // dropped as the rasm in «تَبَرَّءُواْ», «رُءُوسَكُمۡ», not «رَءُوفٞ».
    for (final id in ['khalaf_hamzah', 'khallad']) {
      List ways(int a, int w) => at(id, 2, a, w)
          .where((v) => v[7] == 'hisham_waqf')
          .expand((v) => (v[8] as Map)['ways'] as List)
          .toList();
      expect(ways(150, 26), contains('إبدالها ياءً مضمومة'));
      expect(ways(167, 10), contains('حذفها على الرسم'));
      expect(ways(196, 12), contains('حذفها على الرسم'));
      expect(ways(143, 43), isNot(contains('حذفها على الرسم')));
    }
    // al-Kisa'i's repeated question: the statement in the second.
    expect(
      at('abul_harith', 13, 5, 7).map((v) => v[6]),
      contains('بالإخبار بهمزة واحدة مكسورة'),
    );
  });
  test('Hamza'
      's stop on the hamza, divided by the guide'
      's kinds', () {
    Map waqf(String id, int s, int a, int w, String kind) =>
        at(id, s, a, w).firstWhere(
              (v) => v[7] == 'hisham_waqf' && (v[8] as Map)['kind'] == kind,
            )[8]
            as Map;
    // The naql and the sakt for both narrators, as «نهج حمزة في الوقف على كل
    // همزة», with who takes which.
    for (final (id, a, w) in const [
      ('khallad', 11, 6),
      ('khalaf_hamzah', 25, 11),
    ]) {
      expect(waqf(id, 2, a, w, 'الوقف على لام التعريف')['ways'], [
        'النقل',
        'السكت (من سكت فله السكت والنقل، ومن لم يسكت فله النقل)',
      ]);
    }
    // The hamzas of Hamza's reading alone: سُئِلَ, the rasm's dropping, the
    // added prefix, and جَبۡرَئِيلَ.
    expect(waqf('khallad', 2, 108, 6, 'الهمز المتحرك بعد متحرك')['ways'], [
      'تسهيلها بين بين',
      'إبدالها واوًا مكسورة',
    ]);
    expect(waqf('khalaf_hamzah', 2, 62, 6, 'الهمز المتحرك بعد متحرك')['ways'], [
      'تسهيلها بين بين',
      'حذفها على الرسم',
    ]);
    expect(waqf('khallad', 2, 124, 5, 'الهمز المتوسط بحرف زائد')['ways'], [
      'التحقيق',
      'تسهيلها بين بين',
    ]);
    expect(
      waqf('khalaf_hamzah', 2, 97, 4, 'الهمز المتحرك بعد متحرك')['context'],
      contains('جَبۡرَئِيلَ'),
    );
    expect(waqf('khallad', 2, 67, 12, 'الهمز المتحرك بعد ساكن صحيح')['ways'], [
      'نقل حركتها إلى الساكن قبلها',
      'إبدالها واوًا على الرسم',
    ]);
    expect(waqf('khallad', 2, 31, 7, 'الهمز المتوسط بعد ألف'), isNotEmpty);
    expect(waqf('khallad', 2, 31, 10, 'الهمز المتوسط بحرف زائد'), isNotEmpty);
    expect(waqf('khallad', 2, 31, 9, 'الهمز المتحرك بعد متحرك'), isNotEmpty);
    // «شيء» and «شَيۡـًٔا»: one faces for both narrators, neither first.
    for (final id in const ['khalaf_hamzah', 'khallad']) {
      expect(waqf(id, 2, 48, 7, 'الهمز بعد واو أو ياء ساكنتين')['ways'], [
        'نقل حركتها إلى الساكن قبلها',
        'إبدالها من جنس ما قبلها وإدغامه فيه',
      ]);
    }
    // زَكَرِيَّا، تُرۡجِي: Hisham''s hamza, not Hamza''s.
    expect(
      at('khallad', 3, 37, 8).where((v) => v[7] == 'hisham_waqf'),
      isEmpty,
    );
    expect(
      at('khallad', 33, 51, 0).where((v) => v[7] == 'hisham_waqf'),
      isEmpty,
    );
    for (final id in const ['khalaf_hamzah', 'khallad']) {
      for (final v in (load(id)['variants'] as List).cast<List>()) {
        if (v[7] == 'hisham_waqf') expect((v[8] as Map)['kind'], isNotNull);
      }
    }
  });
  test('one division for Hamza and Hisham, his final hamza with Hamza'
      's', () {
    expect(waqfHamzaKindOfFinal('سُوٓءَ'), 'الهمز بعد واو أو ياء ساكنتين');
    expect(waqfHamzaKindOfFinal('ٱلسَّمَآءِ'), 'الهمز المتطرف بعد ألف');
    expect(waqfHamzaKindOfFinal('زَكَرِيَآءُ'), 'الهمز المتطرف بعد ألف');
    expect(waqfHamzaKindOfFinal('يَسۡتَهۡزِئُ'), 'الهمز الساكن');
    expect(waqfHamzaKindOfFinal('ٱلۡمَرۡءِ'), 'الهمز المتحرك بعد ساكن صحيح');
    expect(waqfHamzaKindOfFinal('سَبَإِۭ'), 'الهمز الساكن');
    // للإيمان، للآخرة: the article without its alif.
    expect(waqfHamzaKindAt('لِلۡإِيمَٰنِ', 2), 'الوقف على لام التعريف');
    expect(waqfHamzaKindAt('لَبِإِمَامٖ', 2), 'الهمز المتوسط بحرف زائد');
    // أسألكم of the root, not a question''s hamza.
    expect(waqfHamzaKindAt('أَسۡـَٔلُكُمۡ', 2), 'الهمز المتحرك بعد ساكن صحيح');
  });
  test(
    'al-Kisa\'i\'s feminine ha by the letter before it, the two schools',
    () {
      String? how(int s, int a, int w) => at(
        'duri_kisai',
        s,
        a,
        w,
      ).where((v) => v[7] == 'imala_ha').map((v) => '${v[6]}').firstOrNull;
      const one = 'بإمالة هاء التأنيث وما قبلها وقفًا قولًا واحدًا';
      const khulf = 'بإمالة هاء التأنيث وما قبلها وقفًا بخلف عنه';
      expect(how(2, 31, 7), one); // ٱلۡمَلَٰٓئِكَةِ: a kasra before the kaf
      expect(how(2, 148, 1), one); // وِجۡهَةٌ: a quiet letter after a kasra
      expect(how(2, 25, 30), khulf); // مُّطَهَّرَةٞ: a fatha before the ra
      expect(how(2, 195, 8), khulf); // ٱلتَّهۡلُكَةِ
      expect(how(2, 26, 8), khulf); // بَعُوضَةٗ: after a «حق ضغاط عص خظا»
      expect(how(2, 3, 4), isNull); // ٱلصَّلَوٰةَ: after an alif
      // رَحۡمَتَ, its ta stopped on as a ha: as a feminine ha.
      expect(how(2, 218, 11), one);
      expect(how(2, 35, 14), khulf); // ٱلشَّجَرَةَ
      expect(how(36, 80, 4), isNull); // ٱلشَّجَرِ: no ha
    },
  );

  test('«فإن قاتلوكم» البقرة ١٩١: «قتلوكم» for Hamza, al-Kisai and Khalaf', () {
    // The book's run of ten words: Hafs's dagger alif in «قَٰتَلُوكُمۡ» is
    // the full alif of the other reading (قَاتَلُوكُم), a difference.
    for (final id in [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      final words = {
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[0] == 2 && v[1] == 191 && v[5] == 'f') v[2]: v[4],
      };
      expect(words, {
        12: 'تَقۡتُلُوهُمۡ',
        17: 'يَقۡتُلُوكُمۡ',
        20: 'قَتَلُوكُمۡ',
      }, reason: id);
    }
  });

  test('the farsh the user set: تماسوهن، ويبصط، يتسنه، اعلم', () {
    Map<int, String> farsh(String id, int s, int a) => {
      for (final v in (load(id)['variants'] as List).cast<List>())
        if (v[0] == s && v[1] == a && v[5] == 'f')
          v[2] as int: '${v[4]}|${v[6]}',
    };
    const all = [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ];
    for (final id in all) {
      // The madd over the dagger alif.
      for (final (s, a, w) in [(2, 236, 8), (2, 237, 5), (33, 49, 11)]) {
        expect(
          farsh(id, s, a)[w],
          'تُمَٰٓسُّوهُنَّ|بضم التاء وتشديد السين مع المد المشبع',
          reason: '$id $s:$a',
        );
      }
      // The oval of «أنا» on the ha, gone joined: told in the usul, as
      // Ya'qub's (the user, 2026-11-14).
      expect(
        [
          for (final v in (load(id)['variants'] as List).cast<List>())
            if (v[0] == 2 && v[1] == 259 && v[2] == 41 && v[7] == 'ha_sakt')
              '${v[4]}|${v[6]}',
        ],
        ['يَتَسَنَّه۠ۖ|بحذف هاء السكت وصلاً وإثباتها وقفًا'],
        reason: id,
      );
      final kisai = id == 'abul_harith' || id == 'duri_kisai';
      expect(
        farsh(id, 2, 245)[13],
        kisai
            ? 'وَيَبۡصُطُ|بالصاد'
            : id == 'khallad'
            ? 'وَيَبۡصُۣطُ|بالصاد والسين، والصاد هو المقدّم'
            : isNull,
        reason: id,
      );
      // «بَصۡطَةٗ» الأعراف ٦٩ with the sad for al-Kisa'i (the user, 2026-11-14).
      if (kisai) {
        expect(farsh(id, 7, 69)[21], 'بَصۡطَةٗۖ|بالصاد', reason: id);
      }
      // «ولا يحسبن الذين يبخلون»: the verb alone, not the book's entry of
      // ١٧٨ («الذين كفروا») misplaced over three words.
      expect(farsh(id, 3, 180).keys.toSet(), {1}, reason: id);
      // Hafs's word, its ya a ta, the dagger alif kept.
      expect(farsh(id, 3, 154)[8], 'تَغۡشَىٰ|بالتاء', reason: id);
      // Khalaf's idgham without ghunna only before a ya or waw he reads:
      // none before the ta or nun of his farsh.
      if (id == 'khalaf_hamzah') {
        for (final (s, a, w) in [
          (3, 154, 7),
          (6, 145, 12),
          (13, 4, 11),
          (24, 35, 15),
          (25, 8, 7),
          (75, 37, 4),
        ]) {
          expect(
            (load(id)['variants'] as List).cast<List>().where(
              (v) =>
                  v[0] == s &&
                  v[1] == a &&
                  v[2] == w &&
                  v[7] == 'idgham_bila_ghunna',
            ),
            isEmpty,
            reason: '$s:$a',
          );
        }
      }
      // Hafs's ta's tooth without its dots, the dagger alif on it.
      expect(farsh(id, 3, 39)[0], 'فَنَادَىٰهُ|بالألف', reason: id);
      // In the usul now, as Ya'qub's (the user, 2026-11-14).
      expect(farsh(id, 6, 90)[5], isNull, reason: id);
      expect(
        [
          for (final v in (load(id)['variants'] as List).cast<List>())
            if (v[0] == 6 && v[1] == 90 && v[2] == 5 && v[7] == 'ha_sakt')
              '${v[4]}|${v[6]}',
        ],
        ['ٱقۡتَدِه۠ۗ|بحذف هاء السكت وصلاً وإثباتها وقفًا'],
        reason: id,
      );
      expect(
        farsh(id, 3, 195)[24],
        'وَقُتِلُواْ|بضم القاف وحذف الألف وكسر التاء',
        reason: id,
      );
      expect(
        farsh(id, 3, 195)[25],
        'وَقَٰتَلُواْ|بفتح القاف وإثبات الألف وفتح التاء',
        reason: id,
      );
      final hamzaOrKisai = !id.startsWith('i');
      expect(
        farsh(id, 2, 259)[60],
        hamzaOrKisai
            ? 'ٱعۡلَمۡ|بإبدال همزة القطع همزة وصل وإسكان الميم'
            : isNull,
        reason: id,
      );
    }
  });

  test(
    '«التوراة»: al-Kisai and Khalaf al-Ashir lean it, Hamza reduces it, all 18',
    () {
      final quran =
          jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
      final places = <String>{
        for (final a in (quran['ayahs'] as List).cast<List>())
          for (final (i, w) in '${a[4]}'.split(' ').indexed)
            if (w.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '').contains('تورىة'))
              '${a[0]}:${a[1]}:$i',
      };
      expect(places, hasLength(18));
      for (final (id, how) in [
        ('abul_harith', 'بالإمالة'),
        ('duri_kisai', 'بالإمالة'),
        ('ishaq', 'بالإمالة'),
        ('idris', 'بالإمالة'),
        ('khalaf_hamzah', 'بالتقليل'),
        ('khallad', 'بالتقليل'),
      ]) {
        final told = {
          for (final v in (load(id)['variants'] as List).cast<List>())
            if (places.contains('${v[0]}:${v[1]}:${v[2]}'))
              '${v[0]}:${v[1]}:${v[2]}': v[6],
        };
        expect(told.keys.toSet(), places, reason: id);
        expect(told.values.toSet(), {how}, reason: id);
      }
    },
  );

  // «يُؤَدِّهۡ» (آل عمران ٧٥) the farsh alike for Khalaf and Khallad, one row
  // in the hamesh; Khalaf's sakt on its own row, the stop on «إِلَيۡكَ» for
  // both (the user, 2026-11-18).
  test('yu\'addih quiet alike for Hamza\'s narrators, the sakt apart', () {
    List<List> at(String id, int w) => [
      for (final v in (load(id)['variants'] as List).cast<List>())
        if (v[0] == 3 && v[1] == 75 && v[2] == w) v,
    ];
    for (final w in [7, 15]) {
      for (final id in ['khalaf_hamzah', 'khallad']) {
        final farsh = at(id, w).where((v) => v[5] == 'f').single;
        expect(
          farsh[4],
          at('khallad', w).where((v) => v[5] == 'f').single[4],
          reason: '$id $w',
        );
        expect('${farsh[4]}', endsWith('هۡ'), reason: '$id $w');
        expect(farsh[6], 'بإسكان الهاء', reason: '$id $w');
        expect(
          at(id, w + 1).where((v) => v[7] == 'hisham_waqf'),
          hasLength(1),
          reason: '$id $w',
        );
      }
      expect(
        at('khalaf_hamzah', w).where((v) => v[7] == 'sakt').single[4],
        '${at('khallad', w).where((v) => v[5] == 'f').single[4]}ۜ',
      );
    }
  });

  // «وَمَن يُّرِد ثَّوَابَ» (آل عمران ١٤٥): Khalaf's idgham without ghunna into
  // «يُرِد», its dal bare, merged into the tha, as Khallad's (the user,
  // 2026-11-18).
  test('man yurid thawab: the dal bare in the chain of Khalaf', () {
    for (final w in [10, 16]) {
      final row = [
        for (final v
            in (load('khalaf_hamzah')['variants'] as List).cast<List>())
          if (v[0] == 3 &&
              v[1] == 145 &&
              v[2] == w &&
              v[7] == 'idgham_bila_ghunna')
            v,
      ].single;
      expect(
        '${row[4]}'.replaceAll(RegExp('[ً-ْۡ]'), ''),
        endsWith('يرد'),
        reason: '$w',
      );
      expect('${row[4]}', isNot(endsWith('ۡ')), reason: '$w');
    }
  });

  // «فِيهِمۡ ... وَيُزَكِّيهِمۡ» (آل عمران ١٦٤) as Hafs's for Hamza, Ya'qub's
  // alone; «عَلَيۡهُمۡ» between them his (the user, 2026-11-18).
  test('fihim and yuzakkihim as Hafs for Hamza, alayhum his', () {
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final rows = [
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[0] == 3 && v[1] == 164 && v[3] == 1 && '${v[4]}'.isNotEmpty) v,
      ];
      expect(rows.where((v) => v[2] == 7 || v[2] == 14), isEmpty, reason: id);
      expect(
        rows.where((v) => v[2] == 12 && v[7] == 'ha_damir'),
        hasLength(1),
        reason: id,
      );
    }
  });

  // «سَيُكۡتَبُ» (آل عمران ١٨١) its ya with the damma (the user, 2026-11-18).
  test('sayuktabu told with its ya and its damma', () {
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final row = [
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[0] == 3 && v[1] == 181 && v[2] == 11 && v[5] == 'f') v,
      ].single;
      expect(row[6], 'بالياء وضمها وفتح التاء', reason: id);
    }
  });

  // «يَحۡسِبُهُمُ» (البقرة ٢٧٣) of Khalaf al-'Ashir and al-Kisa'i: the farsh
  // alone, no plural's mim where the ha is Hafs's (the user, 2026-11-18).
  test('yahsibuhum the farsh alone, no mim of the plural', () {
    for (final id in ['ishaq', 'idris', 'duri_kisai', 'abul_harith']) {
      final rows = [
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[0] == 2 && v[1] == 273 && v[2] == 11) v,
      ];
      expect(rows.where((v) => v[7] == 'mim_jam'), isEmpty, reason: id);
      expect(
        rows.where((v) => v[5] == 'f').single[4],
        contains('حۡسِ'),
        reason: id,
      );
    }
  });

  // «يُوصِي» (النساء ١٢): «بكسر الصاد وإسكان الياء», no alif told, for every
  // reader who reads it so (the user, 2026-11-18).
  test('yusi told without the alif for every reader', () {
    final dir = Directory('assets/data/qiraat');
    var seen = 0;
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final data = jsonDecode(f.readAsStringSync()) as Map;
      for (final v in (data['variants'] as List).cast<List>()) {
        if (v[0] == 4 && v[1] == 12 && v[2] == 76 && v[5] == 'f') {
          expect(v[6], 'بكسر الصاد وإسكان الياء', reason: f.path);
          seen++;
        }
      }
    }
    expect(seen, 14);
  });

  // The alif maqsura before a sakin leaned at the stop alone (يَتَٰمَى
  // ٱلنِّسَآءِ، يَغۡشَى ٱلنَّاسَ، بِعِيسَى ٱبۡنِ), «رَءَا ٱلۡقَمَرَ» and «جَآءَهَا»
  // not; «مَأۡوَىٰ» leaned in all its places (the user, 2026-11-18).
  // «بِبَاسِطٖ يَدِيَ إِلَيۡكَ» (المائدة ٢٨): Khalaf's idgham into the ya of the
  // idafa he reads quiet, written as Khallad's (the user, 2026-11-19).
  test('Khalaf idgham into his ya of the idafa takes its rasm', () {
    List at(String id, int s, int a, int w, String rule) => [
      for (final v in (load(id)['variants'] as List).cast<List>())
        if (v[0] == s && v[1] == a && v[2] == w && v[7] == rule) v,
    ].single;
    final yadi = at('khallad', 5, 28, 8, 'ya_idafa')[4] as String;
    expect(yadi, 'يَدِيٓ');
    final row = at('khalaf_hamzah', 5, 28, 7, 'idgham_bila_ghunna');
    final second = (row[4] as String).split(' ').last;
    expect(second, endsWith(yadi.substring(2)));
    expect(second, contains('ّ'));
    // «وَلِي نَعۡجَةٞ» (ص ٢٣) quiet so.
    expect(
      (at('khalaf_hamzah', 38, 23, 6, 'idgham_bila_ghunna')[4] as String)
          .endsWith('لِي'),
      isTrue,
    );
  });

  // «هُزۡؤٗا»: «بإسكان الزاي وبالهمز» for all who read it so (the user,
  // 2026-11-19).
  test('huzuwan told with its zay quiet and with the hamza', () {
    for (final id in ['khalaf_hamzah', 'khallad', 'ishaq', 'idris']) {
      final rows = [
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[5] == 'f' && '${v[4]}'.contains('زۡؤ')) v,
      ];
      expect(rows.length, 11, reason: id);
      for (final v in rows) {
        expect(v[6], 'بإسكان الزاي وبالهمز', reason: '$id ${v[0]}:${v[1]}');
      }
    }
  });

  // «تَوَفَّٰ۪هُ، ٱسۡتَهۡوَٰ۪هُ» (الأنعام ٦١، ٧١) of Hamza: the dagger alif, the
  // imala sign, told «بإبدال التاء ألفًا مدية مع الإمالة», and leaned among
  // the usul (the user, 2026-11-19).
  test('tawaffahu and istahwahu with the dagger alif and leaned', () {
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final variants = (load(id)['variants'] as List).cast<List>();
      for (final (s, a, w, text) in const [
        (6, 61, 12, 'تَوَفَّٰ۪هُ'),
        (6, 71, 18, 'ٱسۡتَهۡوَٰ۪هُ'),
      ]) {
        final rows = [
          for (final v in variants)
            if (v[0] == s && v[1] == a && v[2] == w) v,
        ];
        final farsh = rows.singleWhere((v) => v[5] == 'f');
        expect(farsh[4], text, reason: '$id $s:$a');
        expect(farsh[6], 'بإبدال التاء ألفًا مدية مع الإمالة');
        expect(
          rows.where((v) => v[5] == 'u' && v[6] == 'بإمالة الألف'),
          hasLength(1),
          reason: '$id $s:$a',
        );
      }
    }
  });

  // «رَءَا كَوۡكَبٗا، رَءَا ٱلۡقَمَرَ، رَءَا ٱلشَّمۡسَ» (الأنعام ٧٦-٧٨) in the usul
  // below the page with the word after them (the user, 2026-11-19): a row
  // of their own there, none in the hamesh.
  test('raa of al-An\'am told below the page', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'abul_harith',
      'ishaq',
      'idris',
    ]) {
      final rows = (load(id)['variants'] as List).cast<List>();
      List note(int a, int w) => rows.singleWhere(
        (v) =>
            v[0] == 6 &&
            v[1] == a &&
            v[2] == w &&
            v.length > 8 &&
            (v[8] as Map)['bandOnly'] == true,
      );
      expect(
        rows.where(
          (v) =>
              v[0] == 6 &&
              (v[1] as int) >= 76 &&
              (v[1] as int) <= 78 &&
              v.length > 8 &&
              (v[8] as Map)['hamesh'] == true,
        ),
        isEmpty,
        reason: id,
      );
      expect(note(76, 4)[4], 'رَ۪ءَ۪ا كَوۡكَبٗاۖ', reason: id);
      expect(note(76, 4)[6], 'بإمالة الهمزة والراء وقفًا ووصلًا');
      // Told beside the words in the band (the user, 2026-11-21).
      expect((note(76, 4)[8] as Map)['bandNote'], note(76, 4)[6]);
      final kisai = id.contains('kisai') || id == 'abul_harith';
      for (final (a, next) in [(77, 'ٱلۡقَمَرَ'), (78, 'ٱلشَّمۡسَ')]) {
        expect(note(a, 1)[4], endsWith(next), reason: '$id $a');
        expect(
          note(a, 1)[6],
          kisai
              ? 'بإمالة الراء والهمزة وقفًا'
              : 'بإمالة الهمزة والراء وقفًا، وإمالة الراء فقط وصلًا',
          reason: '$id $a',
        );
      }
    }
  });

  // «رِسَالَٰتِهِۦ» (الأنعام ١٢٤) as Ruways's, its ha with the kasra; «وَإِنَّ»
  // (١٥٣) without the book's faces of «صِرَٰطِي» (the user, 2026-11-19).
  test('risalatihi as Ruways and wa-inna told alone', () {
    for (final id in ['khalaf_hamzah', 'khallad', 'duri_kisai', 'ishaq']) {
      final rows = (load(id)['variants'] as List).cast<List>();
      List farsh(int a, int w) => rows.singleWhere(
        (v) => v[0] == 6 && v[1] == a && v[2] == w && v[5] == 'f',
      );
      expect(farsh(124, 17)[4], 'رِسَالَٰتِهِۦ', reason: id);
      expect((farsh(153, 0)[8] as Map)['ownWays'], isTrue, reason: id);
      // «يَأۡتِيَهُمُ» (١٥٨) as al-Nahl's: «بالياء», its second ya opened.
      expect(farsh(158, 4)[4], 'يَأۡتِيَهُمُ', reason: id);
      expect(farsh(158, 4)[6], 'بالياء', reason: id);
    }
    // Khalaf's idgham into it takes its ya's fatha; his sakt of «يُؤَدِّهۡۜ» kept.
    final khalaf = (load('khalaf_hamzah')['variants'] as List).cast<List>();
    String idgham(int s, int a, int w) => khalaf.singleWhere(
      (v) =>
          v[0] == s && v[1] == a && v[2] == w && v[7] == 'idgham_bila_ghunna',
    )[4];
    expect(idgham(6, 158, 3), endsWith('أۡتِيَهُمُ'));
    expect(idgham(3, 75, 6), endsWith('ۜ'));
  });

  // Hamza's «ءَاتَىٰنِي ٱلۡكِتَٰبَ» (مريم ٣٠) in the rasm, its ya quiet (the user,
  // 2026-11-20).
  test('atani of Maryam in the rasm', () {
    for (final id in ['khalaf_hamzah', 'khallad']) {
      final row = (load(id)['variants'] as List).cast<List>().singleWhere(
        (v) => v[0] == 19 && v[1] == 30 && v[2] == 4 && v[5] == 'f',
      );
      expect(row[4], 'ءَاتَىٰنِي', reason: id);
      expect(row[6], 'بإسكان الياء', reason: id);
      expect((row[8] as Map).containsKey('vocalizationSource'), isFalse);
    }
  });

  // «وَقَالَتۡ أُولَىٰهُمۡ» (الأعراف ٣٩) leaned as «لِأُولَىٰهُمۡ» of ٣٨; Warsh's
  // taqlil of both with its other face (the user, 2026-11-20).
  test('ulahum of al-A\'raf 39 leaned for al-Ashab, Warsh with his khulf', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'abul_harith',
      'ishaq',
      'idris',
    ]) {
      for (final (a, w) in const [(38, 25), (39, 1)]) {
        expect(
          (load(id)['variants'] as List).cast<List>().where(
            (v) =>
                v[0] == 7 &&
                v[1] == a &&
                v[2] == w &&
                v[5] == 'u' &&
                v[6] == 'بإمالة الألف',
          ),
          hasLength(1),
          reason: '$id 7:$a',
        );
      }
    }
    for (final (a, w) in const [(38, 25), (39, 1)]) {
      expect(
        (load('warsh')['variants'] as List).cast<List>().where(
          (v) =>
              v[0] == 7 &&
              v[1] == a &&
              v[2] == w &&
              '${v[6]}'.endsWith('بالتقليل بخلف'),
        ),
        hasLength(1),
        reason: 'warsh 7:$a',
      );
    }
  });

  // «بَصۜۡطَةٗ» (الأعراف ٦٩): al-Kisa'i's sad drawn alike for all who read
  // it; Ibn Dhakwan's and Khallad's khulf in the hamesh, Hafs's word with
  // the small sin (the user, 2026-11-20).
  test('bastatan of al-A\'raf 69', () {
    List row(String id) =>
        (load(id)['variants'] as List).cast<List>().singleWhere(
          (v) => v[0] == 7 && v[1] == 69 && v[2] == 21 && v[5] == 'f',
        );
    for (final id in [
      'qalun',
      'warsh',
      'bazzi',
      'shubah',
      'duri_kisai',
      'abul_harith',
      'rawh',
      'ibn_wardan',
      'ibn_jammaz',
    ]) {
      expect(row(id)[4], 'بَصۡطَةٗۖ', reason: id);
      expect(row(id)[6], 'بالصاد', reason: id);
    }
    for (final id in ['ibn_dhakwan', 'khallad']) {
      expect(row(id)[4], 'بَصۜۡطَةٗۖ', reason: id);
      expect(row(id)[6], 'بخلف عنه، بالوجهين: السين والصاد', reason: id);
      expect((row(id)[8] as Map)['hamesh'], isTrue, reason: id);
      expect((row(id)[8] as Map)['ways'], ['السين', 'الصاد'], reason: id);
    }
  });

  // The question's second hamza where Hafs tells (الأعراف ٨١، ١١٣، العنكبوت
  // ٢٨): on its nabra for every reader, as Rawh's and Ruways's «أَئِنَّكُمۡ»;
  // the eased one its dot, the idkhal the dagger alif (the user, 2026-11-20).
  test('the question\'s second hamza on its nabra', () {
    String text(String id, int s, int a, int w) =>
        (load(id)['variants'] as List).cast<List>().singleWhere(
          (v) => v[0] == s && v[1] == a && v[2] == w && v[5] != 'u',
        )[4];
    // Built from code points, the marks in the order the data keeps them.
    String of(List<int> codes) => String.fromCharCodes(codes);
    final hamzas = of([0x623, 0x64e, 0x626, 0x650]);
    final kum =
        '$hamzas${of([0x646, 0x651, 0x64e, 0x643, 0x64f, 0x645, 0x6e1])}';
    final inna = '$hamzas${of([0x646, 0x651, 0x64e])}';
    String idkhal(String s) => s.replaceFirst(of([0x64e]), of([0x64e, 0x670]));
    String eased(String s) => s.replaceFirst(of([0x650]), of([0x650, 0x6ec]));
    const ashab = [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'abul_harith',
      'ishaq',
      'idris',
    ];
    for (final (s, a, w, base, readers) in [
      (7, 113, 4, inna, [...ashab, 'shubah', 'ibn_dhakwan', 'rawh']),
      (7, 81, 0, kum, [...ashab, 'shubah', 'ibn_dhakwan', 'rawh', 'ruways']),
      (29, 28, 4, kum, [...ashab, 'shubah']),
    ]) {
      for (final id in readers) {
        expect(text(id, s, a, w), base, reason: '$id $s:$a');
      }
      for (final id in ['duri_abuamr', 'susi']) {
        expect(text(id, s, a, w), eased(idkhal(base)), reason: '$id $s:$a');
      }
    }
    expect(text('hisham', 7, 113, 4), idkhal(inna));
    expect(text('hisham', 7, 81, 0), idkhal(kum));
    // Ruways's tasheel told by its own row, as in ٨١.
    expect(text('ruways', 7, 113, 4), inna);
    for (final id in ['bazzi', 'qunbul']) {
      expect(
        text(id, 7, 81, 0),
        eased(kum).replaceFirst(
          RegExp('${of([0x645, 0x6e1])}\$'),
          of([0x645, 0x64f, 0x6e5]),
        ),
        reason: id,
      );
    }
  });

  // «دَكَّآءَ» (الأعراف ١٤٣): one description for all who read it so; no
  // tanween, so none of Khalaf's idgham into «وَخَرَّ» (the user, 2026-11-20).
  test('dakkaa of al-A\'raf 143', () {
    for (final id in const [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'abul_harith',
      'ishaq',
      'idris',
    ]) {
      final rows = (load(id)['variants'] as List).cast<List>().where(
        (v) => v[0] == 7 && v[1] == 143 && v[2] == 28,
      );
      final farsh = rows.singleWhere((v) => v[5] == 'f');
      expect(farsh[4], 'دَكَّآءَ', reason: id);
      expect(farsh[6], 'بفتح الكاف دون التنوين مع زيادة الهمزة', reason: id);
      expect(
        rows.where((v) => v[7] == 'idgham_bila_ghunna'),
        isEmpty,
        reason: id,
      );
    }
  });

  test('imala before a sakin at the stop alone; mawa everywhere', () {
    const ashab = [
      'khalaf_hamzah',
      'khallad',
      'duri_kisai',
      'abul_harith',
      'ishaq',
      'idris',
    ];
    for (final id in ashab) {
      List<List> at(int s, int a, int w) => [
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[0] == s &&
              v[1] == a &&
              v[2] == w &&
              '${v[6]}'.contains('إمالة'))
            v,
      ];
      for (final (s, a, w) in [(4, 127, 13), (44, 11, 0), (57, 27, 6)]) {
        final row = at(s, a, w).single;
        expect(row[6], 'بإمالة الألف وقفًا', reason: '$id $s:$a');
        expect((row[8] as Map)['stopOnly'], isTrue, reason: '$id $s:$a');
      }
      // «وَمَأۡوَىٰهُ»، and «وَءَاتَىٰكُم» (المائدة ٢٠، إبراهيم ٣٤; the user,
      // 2026-11-19).
      for (final (s, a, w) in [
        (5, 72, 27),
        (8, 16, 16),
        (3, 162, 9),
        (5, 20, 15),
        (14, 34, 0),
        (11, 28, 9),
        (11, 63, 9),
        (19, 30, 4),
        (27, 36, 7),
      ]) {
        expect(at(s, a, w).single[6], 'بإمالة الألف', reason: '$id $s:$a');
      }
      for (final (s, a, w) in [(36, 13, 6), (7, 43, 21)]) {
        expect(
          at(s, a, w).where((v) => (v[8] as Map)['stopOnly'] == true),
          isEmpty,
          reason: '$id $s:$a',
        );
      }
      final awwalin = [
        for (final v in (load(id)['variants'] as List).cast<List>())
          if (v[0] == 5 && v[1] == 107 && v[2] == 13 && v[5] == 'f') v,
      ];
      for (final v in awwalin) {
        expect('${v[6]}', isNot(contains('سكت')), reason: id);
      }
    }
  });
}
