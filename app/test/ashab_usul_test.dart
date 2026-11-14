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
    // «ولخلاد في الوقف النقل في لام التعريف» (ص3): no sakt for him.
    expect(waqf('khallad', 2, 11, 6, 'الوقف على لام التعريف')['ways'], [
      'النقل',
    ]);
    expect(waqf('khalaf_hamzah', 2, 25, 11, 'الوقف على لام التعريف')['ways'], [
      'النقل',
      'السكت',
    ]);
    expect(waqf('khallad', 2, 31, 7, 'الهمز المتوسط بعد ألف'), isNotEmpty);
    expect(waqf('khallad', 2, 31, 10, 'الهمز المتوسط بحرف زائد'), isNotEmpty);
    expect(waqf('khallad', 2, 31, 9, 'الهمز المتحرك بعد متحرك'), isNotEmpty);
    // «شيء» and «شَيۡـًٔا»: one faces for both narrators, neither first.
    for (final id in const ['khalaf_hamzah', 'khallad']) {
      expect(waqf(id, 2, 48, 7, 'الوقف على «شيء» و«شيئًا»')['ways'], [
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
}
