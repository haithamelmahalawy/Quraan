import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/apply_word_span.dart' show sameAsHafs;

/// A text whatever the order of its marks on a letter.
String canon(Object? text) {
  final out = StringBuffer();
  var marks = <String>[];
  void flush() {
    out.writeAll(marks..sort());
    marks = [];
  }

  for (final c in '$text'.replaceAll('ْ', 'ۡ').split('')) {
    if (RegExp('[ً-ْ]').hasMatch(c)) {
      marks.add(c);
    } else {
      flush();
      out.write(c);
    }
  }
  flush();
  return '$out';
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final words = <String, String>{
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        '${x[0]}:${x[1]}:$i': w,
  };
  List<List> rowsOf(String id) =>
      ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List)
          .cast<List>();

  group('sameAsHafs', () {
    test('tells a word read as Hafs from one read otherwise', () {
      expect(sameAsHafs('قُلْ', 'قُلۡ'), isTrue);
      expect(sameAsHafs('إِلآَّ', 'إِلَّآ'), isTrue);
      expect(sameAsHafs('لَكُمُ', 'لَكُمۡ'), isTrue);
      expect(sameAsHafs('هْوَ', 'هُوَ'), isFalse);
      expect(sameAsHafs('صَدَقَ', 'صَدَّقَ'), isFalse);
      expect(sameAsHafs('يَشَا', 'يَشَأۡ'), isFalse);
    });
  });

  for (final id in const ['ibn_wardan', 'ibn_jammaz']) {
    group(id, () {
      final rows = rowsOf(id);
      List<List> at(int s, int a, int w) => [
        for (final v in rows)
          if (v[0] == s && v[1] == a && v[2] == w) v,
      ];

      test('no row covers a word at its edge that reads as Hafs', () {
        final wrong = <String>[];
        for (final v in rows) {
          final count = (v[3] as num).toInt();
          final own = '${v[4]}'.split(' ');
          if (count < 2 || own.length != count) continue;
          if (v.length > 7 && v[7] == 'idgham_saghir') continue;
          final first = words['${v[0]}:${v[1]}:${v[2]}'] ?? '';
          final last =
              words['${v[0]}:${v[1]}:${(v[2] as int) + count - 1}'] ?? '';
          // The izhar: Hafs's idgham doubles the next word's first letter, the
          // reading leaves it single (يَلۡهَثۡ ذَٰلِكَ for يَلۡهَثۚ ذَّٰلِكَ).
          bool doubledFirst(String w) => RegExp(r'^[ء-ي][ً-ِ]*ّ').hasMatch(w);
          if (doubledFirst(last) && !doubledFirst(own.last)) continue;
          // The idgham: the reading doubles the next word's first letter, Hafs
          // leaves it single (قُل رَّبِّي for قَٰلَ رَبِّي).
          if (doubledFirst(own.last) && !doubledFirst(last)) continue;
          // Its madd drawn where Hafs has none, made lazim by the reading's
          // sukun after it (ٱثۡنَآ عۡشَرَ for ٱثۡنَا عَشَرَ).
          if (own.first.contains('ٓ') && !first.contains('ٓ')) continue;
          if (sameAsHafs(own.first, first) || sameAsHafs(own.last, last)) {
            wrong.add('${v[0]}:${v[1]}:${v[2]}+$count ${v[4]}');
          }
        }
        expect(wrong, isEmpty);
      });

      test('«يؤاخذكم» is its hamza changed, not a farsh', () {
        final v = at(2, 225, 1).firstWhere((v) => v[4] != '');
        expect(v[5], 'h');
        expect(v[6], 'بإبدال الهمزة واوًا');
      });

      test('no letter carries two vowels', () {
        // The small ya of the zawaid a letter of its own, opened on its own
        // (تَتَّبِعَنِۦَ).
        final letter = RegExp('[^ً-ٟۖ-ۥۧ-ۭ]([ً-ٟۖ-ۥۧ-ۭ]*)');
        final vowel = RegExp('[ً-ِٖٗٞ]');
        final wrong = [
          for (final v in rows)
            if (letter
                .allMatches('${v[4]}')
                .any((m) => vowel.allMatches(m[1]!).length > 1))
              '${v[0]}:${v[1]}:${v[2]} ${v[4]}',
        ];
        expect(wrong, isEmpty);
      });

      test('«مائة» is Hafs\'s word with a ya for its hamza, not a farsh', () {
        final v = at(2, 259, 18).firstWhere((v) => v[6] != 'بالقصر');
        expect(canon(v[4]), canon('مِاْيَةَ'));
        expect(v[5], 'h');
      });

      test('«بربوة» alone, not «أصابها»', () {
        expect(at(2, 265, 13), isEmpty);
        expect(at(2, 265, 12).single[5], 'f');
      });

      test('«لبثت»: the tha bare, the ta shaddaed', () {
        expect(canon(at(2, 259, 26).single[4]), canon('لَبِثتُّ'));
        expect(canon(at(2, 259, 33).single[4]), canon('لَّبِثتَّ'));
      });

      test('«ٱيتُمِنَ»: a ya for its hamza, after the wasl', () {
        final v = at(2, 283, 15).firstWhere((v) => v[7] == 'ibdal_single');
        expect(canon(v[4]), canon('ٱيتُمِنَ'));
        expect(v[6], 'بإبدال الهمزة ياءً');
      });

      test('«رياء» is its hamza a ya, not a farsh', () {
        for (final (a, w) in const [(264, 11)]) {
          final v = at(2, a, w).firstWhere((v) => v[5] == 'h');
          expect(canon(v[4]), canon('رِيَآءَ'));
          expect(v[6], 'بإبدال الهمزة ياءً');
        }
        expect(at(2, 264, 11).where((v) => v[5] == 'f'), isEmpty);
      });

      test('«فنعما» with one face, the sukun', () {
        final v = at(2, 271, 3).single;
        expect(canon(v[4]), canon('فَنِعۡمَّا'));
        expect(v[6], 'بإسكان العين');
      });

      test('«جاءته» has no row: its ha is short as Hafs\'s', () {
        expect(at(2, 211, 15), isEmpty);
      });

      test('«قل أرأيتم» is on the word of its two hamzas, as Qalun', () {
        expect(at(46, 4, 0), isEmpty);
        expect(at(67, 28, 0), isEmpty);
        expect(canon(at(67, 28, 1).single[4]), canon('أَرَٰ۬يْتُمُۥ'));
      });

      test('the separated madd is short: no sign before a hamza', () {
        final signed = RegExp('ٓ[ۖ-ۜ]*\$');
        final words0 = (quran['ayahs'] as List)
            .expand(
              (x) => (x[4] as String)
                  .split(' ')
                  .indexed
                  .map((e) => (x[0], x[1], e.$1, e.$2)),
            )
            .toList();
        final written = {
          for (final v in rows)
            if ('${v[4]}'.isNotEmpty)
              for (var d = 0; d < (v[3] as num).toInt(); d++)
                '${v[0]}:${v[1]}:${(v[2] as int) + d}',
        };
        for (var i = 0; i + 1 < words0.length; i++) {
          final w = words0[i], n = words0[i + 1];
          if (w.$1 != n.$1 || !signed.hasMatch(w.$4)) continue;
          if (!RegExp('^[ءأإآ]').hasMatch(n.$4)) continue;
          if (w.$1 == 3 && w.$2 == 1) continue; // «الٓمٓ» before «ٱللَّهُ».
          if (w.$4.startsWith('ال') && w.$3 == 0) continue; // Its letters.
          expect(
            written,
            contains('${w.$1}:${w.$2}:${w.$3}'),
            reason: '${w.$1}:${w.$2}:${w.$3} ${w.$4}',
          );
        }
      });

      test('«فاذكروني» has no note, and is written without the madd', () {
        final v = at(2, 152, 0).single;
        expect(canon(v[4]), canon('فَٱذۡكُرُونِي'));
        expect(v[5], 'u');
        expect(v[6], 'بالقصر');
      });

      test('«إن القوة» and «وإن الله» with the hamza broken', () {
        expect(at(2, 165, 23).single.sublist(4, 7), [
          'إِنَّ',
          'f',
          'بكسر الهمزة',
        ]);
        expect(at(2, 165, 27).single.sublist(4, 7), [
          'وَإِنَّ',
          'f',
          'بكسر الهمزة',
        ]);
      });

      test('«ٱلۡمَيِّتَةَ» takes its «ٱلۡ» from Hafs', () {
        expect(canon(at(2, 173, 3).single[4]), canon('ٱلۡمَيِّتَةَ'));
      });

      test('«ليس البر» is on «البر» alone, read once', () {
        expect(at(2, 177, 0), isEmpty);
        expect(canon(at(2, 177, 1).single[4]), canon('ٱلۡبِرُّ'));
      });

      test('«تأكلوا أموالكم» has no madd of a separated madd', () {
        final text = at(2, 188, 1).map((v) => v[4]).join();
        expect(text, isNot(contains('ٓ')));
      });

      test('«يقاتلوكم» is no farsh, only its silah, as Qalun', () {
        expect(at(2, 191, 17).single.sublist(4, 7), [
          'يُقَٰتِلُوكُمُۥ',
          'u',
          'بصلة ميم الجمع',
        ]);
      });

      test('its ya of the zawaid is written after the word', () {
        expect(canon(at(2, 186, 8).single[4]), canon('ٱلدَّاعِۦ'));
        expect(canon(at(2, 186, 10).single[4]), canon('دَعَانِۦ'));
      });

      test(
        'a word told farsh takes Hafs\'s vowels, keeping the difference',
        () {
          expect(canon(at(4, 73, 8).single[4]), canon('يَكُنۢ'));
          // Ibn Wardan's alone: Ibn Jammaz reads it with the shadda.
          if (id == 'ibn_wardan') {
            expect(canon(at(36, 32, 2).single[4]), canon('لَمَا'));
          }
        },
      );
    });
  }

  test('al-Bazzi\'s «لأعنتكم»: eased first, or not', () {
    final v = rowsOf(
      'bazzi',
    ).firstWhere((v) => v[0] == 2 && v[1] == 220 && v[2] == 21 && v[5] == 'h');
    expect(v[6], contains('تسهيل الهمزة، وهو المقدم'));
    expect((v[8] as Map)['ways'], hasLength(2));
  });

  test('Qalun\'s «فنعما»: the sukun first, or the kasra stolen', () {
    final v = rowsOf('qalun')
        .firstWhere((v) => v[0] == 2 && v[1] == 271 && v[2] == 3);
    expect(canon(v[4]), canon('فَنِعۡمَّا'));
    expect(v[6], contains('اختلاس'));
  });

  test('Ibn Kathir\'s «يعذب»: shown alone, its ba with qalqala', () {
    for (final id in const ['bazzi', 'qunbul']) {
      final v = rowsOf(id)
          .firstWhere((v) => v[0] == 2 && v[1] == 284 && v[2] == 20);
      expect(v[5], 'f');
      expect(v[6], 'بإسكان الباء مع الإظهار والقلقلة');
    }
  });

  test('Qalun\'s «فاذكروني» is written without the madd', () {
    final v = rowsOf('qalun')
        .firstWhere((v) => v[0] == 2 && v[1] == 152 && v[2] == 0);
    expect(canon(v[4]), canon('فَٱذۡكُرُونِي'));
  });

  group('opening letters, Tawrah and a-unabbi ukum', () {
    List<List> rowsOf(String id) =>
        ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                    as Map)['variants']
                as List)
            .cast<List>();
    List<List> where(String id, int s, int a, int w) => [
      for (final v in rowsOf(id))
        if (v[0] == s && v[1] == a && v[2] == w) v,
    ];

    test('Abu Ja\'far\'s sakt on each letter, on the opening itself', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final fawatih = rowsOf(id)
            .where((v) => v.length > 7 && v[7] == 'fawatih');
        expect(fawatih.where((v) => v[0] == 3 && v[1] == 2), isEmpty);
        final imran = fawatih.singleWhere((v) => v[0] == 3 && v[1] == 1);
        expect(imran[2], 0);
        expect(imran[4], 'اۜلٓــۜـمٓۜ');
        expect(fawatih.where((v) => v[0] == 42 && v[1] == 1), hasLength(1));
        expect(fawatih.where((v) => v[0] == 42 && v[1] == 2), hasLength(1));
        for (final v in fawatih) {
          expect('${v[4]}', contains('ۜ'), reason: '${v[0]}:${v[1]}');
        }
      }
    });

    test('the ya of the zawaid beside the word, in its chapter', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [(3, 20, 7), (14, 22, 36), (20, 93, 1)]) {
          final v = where(id, s, a, w).single;
          expect('${v[4]}', contains('ۦ'), reason: '$s:$a');
          expect('${v[4]}', isNot(contains('ى')), reason: '$s:$a');
          expect(v[5], 'u', reason: '$s:$a');
          expect(v[7], 'ya_zaida', reason: '$s:$a');
        }
        for (final (s, a, w) in [(12, 66, 5), (18, 40, 3)]) {
          for (final v in where(id, s, a, w)) {
            expect('${v[4]}', contains('ۦ'), reason: '$s:$a');
          }
        }
      }
    });

    test('Zakariyya in the added hamza, with the madd, in all seven', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [
          (3, 37, 8),
          (3, 37, 12),
          (3, 38, 2),
          (6, 85, 0),
          (19, 2, 4),
          (19, 7, 0),
          (21, 89, 0),
        ]) {
          final v = where(id, s, a, w).single;
          final qalun = where('qalun', s, a, w).single;
          expect(v[3], 1, reason: '$s:$a');
          expect(v[4], qalun[4], reason: '$s:$a');
          expect(v[5], 'h', reason: '$s:$a');
          expect(v[6], qalun[6], reason: '$s:$a');
        }
      }
    });

    test('kahayyah in the ibdal, and the added alifs dagger ones', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [(3, 49, 15), (5, 110, 30)]) {
          final v = where(id, s, a, w).single;
          expect(v[4], 'كَهَيَّةِ');
          expect(v[5], 'h');
          expect(v[7], 'ibdal_single');
        }
        expect(where(id, 3, 49, 16).single[4], 'ٱلطَّٰٓئِرِ');
        expect(where(id, 3, 49, 20).single[4], 'طَٰٓئِرَۢا');
        for (final v in rowsOf(id)) {
          expect(
            '${v[4]}',
            isNot(matches(RegExp('^أَ[اآ][ءئ]'))),
            reason: '${v[0]}:${v[1]}',
          );
        }
      }
    });

    test('ha antum: each by his face, Qalun and Abu Ja\'far told alike', () {
      for (final (s, a) in [(3, 66), (3, 119), (4, 109), (47, 38)]) {
        String told(String id) {
          final rows = where(
            id,
            s,
            a,
            0,
          ).where((v) => v.length > 7 && v[7] == 'ha_antum').toList();
          expect(rows, hasLength(1), reason: '$id $s:$a');
          return '${rows.single[6]}';
        }

        for (final id in ['qalun', 'ibn_wardan', 'ibn_jammaz']) {
          expect(told(id), 'بإثبات الألف وهمزة مسهلة');
        }
        expect(told('bazzi'), 'بإثبات الألف وهمزة محققة بعدها');
        expect(told('qunbul'), 'بحذف الألف مع تحقيق الهمزة');
      }
    });

    test('Ibn Kathir\'s an yuta, with the moved hamza, not the farsh', () {
      for (final id in ['bazzi', 'qunbul']) {
        final v = where(id, 3, 73, 11).single;
        expect(v[4], isNotEmpty);
        expect(v[5], 'h');
        expect(v[6], 'بهمزتين مع تسهيل الثانية');
        expect(v[7], 'ha_antum');
      }
    });

    test('Atainakum as Qalun\'s, in his writing and wording', () {
      final qalun = where('qalun', 3, 81, 6).firstWhere((v) => v[5] == 'f');
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 3, 81, 6).firstWhere((v) => v[5] == 'f');
        expect(v[4], qalun[4]);
        expect(v[6], qalun[6]);
        expect('${v[4]}', contains('ٰ'));
      }
    });

    test('Qalun\'s Nabiyyun: its ya sakin and its added hamza', () {
      for (final (s, a, w) in [(2, 136, 20), (3, 84, 18), (5, 44, 8)]) {
        final v = where('qalun', s, a, w).single;
        expect(v[6], 'بإسكان الياء وزيادة الهمزة', reason: '$s:$a');
        expect(v[7], 'hamza_zaida', reason: '$s:$a');
      }
    });

    test('Israil eased in all its places, milu in the naql', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [
          (3, 93, 9),
          (10, 90, 2),
          (26, 17, 4),
          (32, 23, 13),
        ]) {
          final v = where(id, s, a, w).firstWhere((v) => v[5] == 'h');
          expect('${v[4]}', contains('۬'), reason: '$s:$a');
          expect(v[6], contains('بتسهيل الهمزة الثانية'), reason: '$s:$a');
        }
      }
      final v = where('ibn_wardan', 3, 91, 10).single;
      expect(v[6], 'بضم اللام وحذف الهمزة');
      expect(v[7], 'naql');
    });

    test('al-Anbiya is as Hafs for Abu Ja\'far', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [(3, 112, 27), (3, 181, 15), (4, 155, 7)]) {
          expect(where(id, s, a, w), isEmpty, reason: '$s:$a');
        }
      }
    });

    test('mudaafah and its like as Ibn Kathir\'s, without a dagger', () {
      for (final (s, a, w) in [
        (2, 245, 7),
        (2, 261, 18),
        (3, 130, 7),
        (25, 69, 0),
        (57, 11, 7),
        (64, 17, 5),
      ]) {
        final kathir = where('bazzi', s, a, w).firstWhere((v) => v[5] == 'f');
        for (final id in ['ibn_wardan', 'ibn_jammaz']) {
          final v = where(id, s, a, w).firstWhere((v) => v[5] == 'f');
          expect(v[4], kathir[4], reason: '$s:$a');
          expect('${v[4]}', isNot(contains('ٰ')), reason: '$s:$a');
          expect(
            '${v[6]}',
            contains('بحذف الألف وتشديد العين'),
            reason: '$s:$a',
          );
        }
      }
    });

    test('al-anamil is as Hafs for Ibn Wardan', () {
      expect(where('ibn_wardan', 3, 119, 16), isEmpty);
    });

    test('al-Bazzi\'s tamannawn and tafakkahun with their two faces', () {
      for (final (s, a, w) in [(3, 143, 2), (56, 65, 5)]) {
        final v = where('bazzi', s, a, w).single;
        expect(v[4], '');
        expect(v[7], 'bazzi_ta');
        expect((v[8] as Map)['ways'], hasLength(2));
        expect(where('qunbul', s, a, w), isEmpty);
      }
    });

    test('nutih: Qalun\'s kasra, Abu Ja\'far\'s sakin in both places', () {
      for (final w in [14, 20]) {
        expect(where('qalun', 3, 145, w).single[6], 'بكسر الهاء');
        for (final id in ['ibn_wardan', 'ibn_jammaz']) {
          final v = where(id, 3, 145, w).firstWhere((v) => v[5] != 'u');
          expect('${v[4]}', isNot(contains('ۦ')));
          expect(v[6], 'بإبدال الهمزة واوًا وإسكان الهاء');
          expect(v[7], 'ibdal_single');
        }
      }
    });

    test('kaayin: the hamza eased in all seven', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a) in [
          (3, 146),
          (12, 105),
          (22, 45),
          (22, 48),
          (29, 60),
          (47, 13),
          (65, 8),
        ]) {
          final v = where(id, s, a, 0).firstWhere((v) => '${v[4]}'.isNotEmpty);
          expect('${v[4]}', contains('۬'), reason: '$s:$a');
          expect('${v[6]}', contains('مسهلة'), reason: '$s:$a');
        }
      }
    });

    test('fawahidatun with its tanween', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 4, 3, 19).single;
        expect('${v[4]}', endsWith('ةٌ'));
        expect(v[6], 'بتنوين الضم');
      }
    });

    test('tasawwa as Qalun\'s, the dagger over its ya', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        expect(
          where(id, 4, 42, 7).single[4],
          where('qalun', 4, 42, 7).single[4],
        );
      }
    });

    test('Qalun has nothing of his own in layyan', () {
      expect(where('qalun', 4, 46, 14), isEmpty);
    });

    test('muminan: a row for each of Abu Ja\'far\'s two', () {
      final wardan = where('ibn_wardan', 4, 94, 16).single;
      final jammaz = where('ibn_jammaz', 4, 94, 16).single;
      expect(wardan[6], 'بإبدال الهمزة واوًا وفتح الميم');
      expect(jammaz[6], 'بإبدال الهمزة واوًا وكسر الميم');
      expect('${wardan[4]}', contains('مَن'));
      expect('${jammaz[4]}', contains('مِن'));
      expect(wardan[7], 'ibdal_single');
      expect(jammaz[7], 'ibdal_single');
    });

    test('amani: the ya bare, without a sign', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [(2, 111, 11), (4, 123, 1), (4, 123, 3)]) {
          final v = where(id, s, a, w).firstWhere((v) => v[5] == 'f');
          expect(v[6], 'بإسكان الياء', reason: '$s:$a');
          expect('${v[4]}', contains('نِي'), reason: '$s:$a');
          expect(
            '${v[4]}',
            isNot(matches(RegExp('نِي[ّْۡ]'))),
            reason: '$s:$a',
          );
        }
        final hadid = where(id, 57, 14, 12).firstWhere((v) => v[5] == 'f');
        expect(hadid[6], 'بإسكان الياء وتخفيفها');
        expect('${hadid[4]}', isNot(contains('\u0651')));
        // البقرة ٧٨ with its fatha, as it is.
        expect(where(id, 2, 78, 6).single[6], 'بتخفيف الياء');
      }
    });

    test('ta3dduu: Qalun two faces as farsh, its alif with the sign', () {
      final q = where('qalun', 4, 154, 12).single;
      expect(q[5], 'f');
      expect(q[6], 'بوجهين: إسكان العين وتشديد الدال؛ أو اختلاس فتحة العين');
      expect('${q[4]}', endsWith('اْ'));
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 4, 154, 12).single;
        expect('${v[4]}', endsWith('اْ'));
        expect(v[6], 'بإسكان العين وتشديد الدال');
      }
    });

    test('min ajli with a wasl alif before the jim', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 5, 32, 0).single;
        expect(v[3], 2);
        expect('${v[4]}', startsWith('مِنِ '));
        expect('${v[4]}', contains('ٱجۡ'));
        expect(v[5], 'h');
        expect(v[6], 'بكسر الهمزة ونقل حركتها إلى النون');
        expect(v[7], 'naql');
      }
    });

    test('istuhiqqa on its own word for all but Hafs, istahaqqa as Hafs', () {
      for (final id in [
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
        'warsh',
        'hisham',
        'ibn_dhakwan',
        'shubah',
        'susi',
        'duri_abuamr',
        'abul_harith',
        'duri_kisai',
        'khalaf_hamzah',
        'khallad',
        'idris',
        'ishaq',
        'ruways',
        'rawh',
      ]) {
        final v = where(id, 5, 107, 11).firstWhere((v) => v[5] == 'f');
        expect(v[6], 'بضم التاء وكسر الحاء', reason: id);
      }
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        expect(where(id, 5, 107, 4).where((v) => v[5] == 'f'), isEmpty);
      }
    });

    test('the tanween before a ba is no farsh of Qalun, a real one stays', () {
      expect(where('qalun', 5, 95, 23), isEmpty);
      expect(where('qalun', 2, 95, 2), isEmpty);
      expect(where('qalun', 7, 57, 4), isNotEmpty);
    });

    test('fa-inniya u3adhdhibuhu as Qalun for Abu Ja\'far', () {
      final q = where('qalun', 5, 115, 9).single;
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 5, 115, 9).single;
        expect(v[4], q[4]);
        expect(v[6], q[6]);
        expect(v[7], 'ya_idafa');
      }
    });

    test(
      'two hamzas of a word: Ibn Kathir eased, Abu Ja\'far with the idkhal',
      () {
        final words = [
          (6, 19, 18),
          (13, 5, 4),
          (17, 49, 5),
          (27, 60, 20),
          (32, 10, 1),
          (37, 52, 1),
          (79, 11, 0),
        ];
        for (final id in ['bazzi', 'qunbul']) {
          for (final (s, a, w) in words) {
            final v = where(id, s, a, w).firstWhere((v) => v[5] == 'h');
            expect(v[7], 'tasheel_word', reason: '$id $s:$a');
            expect('${v[6]}', contains('بلا إدخال'), reason: '$id $s:$a');
            expect('${v[4]}', isNot(contains('ٮ')), reason: '$id $s:$a');
          }
          for (final (s, a, w) in [(6, 19, 18), (27, 55, 0), (9, 12, 10)]) {
            final text = '${where(id, s, a, w).first[4]}';
            expect(text, startsWith('أَئِ۬'), reason: '$id $s:$a');
          }
          final silah = where(id, 6, 19, 18).single;
          expect('${silah[6]}', contains('بصلة ميم الجمع'));
        }
        for (final id in ['ibn_wardan', 'ibn_jammaz']) {
          for (final (s, a, w) in [
            (6, 19, 18),
            (17, 49, 5),
            (27, 67, 7),
            (28, 5, 9),
            (32, 10, 5),
            (36, 19, 3),
            (37, 86, 0),
          ]) {
            final text = '${where(id, s, a, w).first[4]}';
            expect(text, startsWith('أَٰ'), reason: '$s:$a');
            expect(text, contains('۬'), reason: '$s:$a');
          }
          expect(where(id, 27, 61, 14).single[7], 'tasheel_word');
        }
      },
    );

    test('araaytum of Ibn Kathir: both hamzas kept, in their chapter', () {
      for (final id in ['bazzi', 'qunbul']) {
        for (final (s, a, w) in [
          (6, 40, 1),
          (6, 46, 1),
          (18, 63, 1),
          (25, 43, 0),
        ]) {
          final v = where(id, s, a, w).firstWhere((v) => v[5] == 'h');
          expect(v[6], 'بتحقيق الهمزتين', reason: '$id $s:$a');
          expect(v[7], 'tasheel_word', reason: '$id $s:$a');
        }
      }
    });

    test('fa-innahu of الأنعام for all of Ashab al-Silah', () {
      final q = where('qalun', 6, 54, 24).single;
      for (final id in ['bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 6, 54, 24).single;
        expect(v[4], q[4], reason: id);
        expect(v[6], 'بكسر الهمزة', reason: id);
      }
      // Its first, «أَنَّهُۥ», opened by Qalun and Abu Ja'far as Hafs.
      expect(where('qalun', 6, 54, 13), isEmpty);
      expect(where('ibn_wardan', 6, 54, 13), isEmpty);
    });

    test('anjaytana: one writing and one wording for Ashab al-Silah', () {
      final bazzi = where('bazzi', 6, 63, 11).single;
      for (final id in ['ibn_wardan', 'ibn_jammaz', 'qunbul']) {
        expect(where(id, 6, 63, 11).single[4], bazzi[4], reason: id);
      }
      for (final id in [
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      ]) {
        expect(
          where(id, 6, 63, 11).single[6],
          'بإبدال الألف ياءً ثم تاء مفتوحة',
          reason: id,
        );
      }
    });

    test('jaail al-layl of الأنعام ٩٦: one writing and wording', () {
      for (final w in [2, 3]) {
        final bazzi = where('bazzi', 6, 96, w).single;
        for (final id in ['qalun', 'qunbul', 'ibn_wardan', 'ibn_jammaz']) {
          final row = where(id, 6, 96, w).single;
          expect(row[4], bazzi[4], reason: '$id $w');
          expect(row[5], bazzi[5], reason: '$id $w');
          expect(row[6], bazzi[6], reason: '$id $w');
        }
      }
    });

    test('kharraqu of الأنعام ١٠٠ as Qalun, the sukun on its alif', () {
      final qalun = where('qalun', 6, 100, 5).single;
      expect('${qalun[4]}', endsWith('اْ'));
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        expect(where(id, 6, 100, 5).single[4], qalun[4], reason: id);
      }
    });

    test('mayyitatun of الأنعام ١٣٩: shadda on the mim and on the ya', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        expect(
          where(id, 6, 139, 13).single[4],
          '\u0645\u0651\u064E\u064A\u0651\u0650\u062A\u064E\u0629\u065E',
          reason: id,
        );
      }
    });

    test('qatalu of الأنعام ١٤٠ just as Qalun', () {
      final qalun = where('qalun', 6, 140, 3).single;
      expect('${qalun[4]}', endsWith('اْ'));
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final row = where(id, 6, 140, 3).single;
        expect(row.sublist(4, 7), qalun.sublist(4, 7), reason: id);
      }
    });

    test('mahyay of الأنعام ١٦٢: Abu Jafar just as Qalun', () {
      final qalun = where('qalun', 6, 162, 4).single;
      expect(qalun[5], 'f');
      expect(qalun[6], 'بإسكان الياء مع المد المشبع');
      expect('${qalun[4]}', contains('آ'));
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final row = where(id, 6, 162, 4).single;
        expect(row.sublist(4, 7), qalun.sublist(4, 7), reason: id);
      }
    });

    test('Qalun reads faliq of الأنعام ٩٥ as Hafs', () {
      expect(where('qalun', 6, 95, 2), isEmpty);
      expect(where('warsh', 6, 95, 2), isEmpty);
    });

    test('la-atiyannahum of الأعراف ١٧: Ibn Kathir as Qalun, no madda', () {
      final q = where('qalun', 7, 17, 1).single;
      expect('${q[4]}', isNot(contains('ٓ')));
      for (final id in ['bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz']) {
        final rows = where(id, 7, 17, 1);
        expect(rows.where((v) => v[5] == 'f'), isEmpty, reason: id);
        expect(rows.single[4], q[4], reason: id);
      }
    });

    test(
      'the munfasil inside haa\'ulaa and the call is short, as Qalun\'s',
      () {
        for (final id in ['ibn_wardan', 'ibn_jammaz']) {
          for (final (s, a, w) in [(7, 38, 27), (2, 21, 0), (2, 85, 2)]) {
            final v = where(id, s, a, w).single;
            final q = where('qalun', s, a, w).single;
            expect(v[4], q[4], reason: '$id $s:$a:$w');
            expect(v[6], 'بالقصر');
          }
          for (final v in where(id, 12, 4, 4)) {
            expect('${v[4]}', isNot(contains('ٓ')));
            expect('${v[4]}', isNot(contains(' ')));
          }
        }
      },
    );

    test('Ibn Wardan\'s la yukhriju of الأعراف ٥٨: two faces, vowelled', () {
      final v = where('ibn_wardan', 7, 58, 9).single;
      expect(v[6], startsWith('بخلف: '));
      expect(v[6], contains('(يُخۡرِجُ)'));
      expect(v[6], contains('(يَخۡرُجُ)، وهو الأرجح'));
      expect((v[8] as Map)['ways'], hasLength(2));
      expect(where('ibn_jammaz', 7, 58, 9), isEmpty);
    });

    test('a word told short is Hafs\'s word, its munfasil madda dropped', () {
      // الأعراف ٧٤-٨٠, ص ١٦٠: Hafs's wasl, shadda and sukun, not Warsh's.
      final alladhi = '${where('qalun', 7, 76, 4).single[4]}';
      expect(alladhi, startsWith('بِٱل'));
      expect(alladhi, contains('ّ'));
      expect(alladhi, isNot(contains('ٓ')));
      expect(where('qalun', 7, 74, 0).single[4], 'وَٱذۡكُرُواْ');
      expect(where('qalun', 7, 74, 17).single[4], 'فَٱذۡكُرُواْ');
      expect(where('qalun', 7, 74, 16).single[4], 'بِيُوتٗاۖ');
      // «وَإِن وَجَدۡنَآ» (الأعراف ١٠٢، ص ١٦٣): no shadda on the waw, as Hafs.
      for (final id in ['qalun', 'bazzi', 'ibn_wardan']) {
        final v = where(id, 7, 102, 6).firstWhere((v) => '${v[4]}' != '');
        expect('${v[4]}', isNot(contains('ّ')), reason: id);
      }
      for (final id in [
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      ]) {
        for (final v in rowsOf(id)) {
          expect('${v[4]}', isNot(matches(RegExp('ا[ًٗ]'))), reason: '$id $v');
          if (v[5] == 'u' && v[6] == 'بالقصر') {
            expect('${v[4]}', isNot(contains('ے')), reason: '$id $v');
          }
        }
      }
    });

    test(
      'arjih: Ibn Jammaz\'s silah in farsh and usul, Ibn Wardan\'s farsh',
      () {
        for (final (s, a) in [(7, 111), (26, 36)]) {
          final j = where('ibn_jammaz', s, a, 1);
          expect(j.map((v) => v[5]).toSet(), {'f', 'u'}, reason: '$s:$a');
          for (final v in j) {
            expect(v[4], 'أَرۡجِهِۦ');
          }
          expect(j.firstWhere((v) => v[5] == 'u')[7], 'ha_kinaya');
          final w = where('ibn_wardan', s, a, 1).single;
          expect(w[5], 'f');
          expect('${w[4]}', isNot(contains('ۦ')));
        }
      },
    );

    test(
      'a-amantum: the small alif on the eased one, no kashida, as Warsh\'s',
      () {
        for (final id in ['qalun', 'bazzi', 'ibn_wardan', 'ibn_jammaz']) {
          for (final (s, a, w) in [(7, 123, 2), (20, 71, 1), (26, 49, 1)]) {
            final v = where(
              id,
              s,
              a,
              w,
            ).firstWhere((v) => v[7] == 'tasheel_word');
            expect('${v[4]}', startsWith('ءَا۬ ٰ'), reason: '$id $s:$a');
          }
        }
        final aaraf = where(
          'qunbul',
          7,
          123,
          2,
        ).firstWhere((v) => '${v[4]}' != '');
        expect('${aaraf[4]}', startsWith('وَا۬ ٰ'));
        expect(aaraf[6], contains('واوًا وصلاً'));
        // Taha's read with one hamza and a madd, as Hafs: told in «مد الفرق».
        final taha = where(
          'qunbul',
          20,
          71,
          1,
        ).singleWhere((v) => '${v[4]}' != '');
        expect('${taha[4]}', isNot(contains('۬')));
        expect(taha[6], 'بتحقيق الهمزة الأولى ثم مد');
      },
    );

    test(
      'Warsh\'s rows left in Qalun\'s: shay\', al-shafa\'a, mali, al-la\'i',
      () {
        for (final (s, a, w) in [
          (18, 76, 4),
          (46, 25, 2),
          (67, 19, 13),
          (34, 23, 2),
        ]) {
          expect(where('qalun', s, a, w), isEmpty, reason: '$s:$a:$w');
        }
        final mali = where('qalun', 27, 20, 3).single;
        expect(mali[4], 'مَالِي');
        expect(mali[7], 'ya_idafa');
        for (final (s, a, w) in [
          (33, 4, 11),
          (58, 2, 11),
          (65, 4, 0),
          (65, 4, 11),
        ]) {
          final v = where('qalun', s, a, w).single;
          expect('${v[4]}', endsWith('ٱلَّٰٓءِ'), reason: '$s:$a:$w');
          expect('${v[4]}'.startsWith('وَ'), s == 65, reason: '$s:$a:$w');
        }
      },
    );

    test('Warsh\'s rows left in Qalun\'s, after الأعراف', () {
      for (final (s, a, w) in [
        (10, 27, 4),
        (30, 8, 19),
        (30, 16, 5),
        (37, 11, 11),
        (72, 16, 0),
      ]) {
        expect(where('qalun', s, a, w), isEmpty, reason: '$s:$a:$w');
      }
      for (final (s, a, w, how) in [
        (20, 77, 4, 'بكسر النون وإبدال همزة القطع بهمزة وصل'),
        (26, 52, 3, 'بوصل الهمزة، ويلزم منه كسر النون وصلاً'),
        (37, 17, 0, 'بإسكان الواو'),
        (56, 48, 0, 'بإسكان الواو'),
        (75, 27, 1, 'بالإدغام دون سكت'),
        (83, 14, 1, 'بالإدغام دون سكت'),
      ]) {
        expect(where('qalun', s, a, w).single[6], how, reason: '$s:$a:$w');
      }
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a) in [(37, 17), (56, 48)]) {
          expect(where(id, s, a, 0).single[6], 'بإسكان الواو', reason: id);
        }
      }
    });

    test('yalhath dhalika of الأعراف ١٧٦: the izhar, Qalun\'s two faces', () {
      List rowsOf(String id) =>
          (jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List;
      for (final id in [
        'qalun',
        'warsh',
        'bazzi',
        'qunbul',
        'hisham',
        'ibn_wardan',
        'ibn_jammaz',
      ]) {
        final at = [
          for (final v in rowsOf(id))
            if (v[0] == 7 && v[1] == 176 && (v[2] == 19 || v[2] == 20)) v,
        ];
        expect(at, hasLength(1), reason: id);
        final v = at.single;
        expect([v[2], v[3], v[5]], [19, 2, 'f'], reason: id);
        // The tha quiet, the dhal open, not doubled.
        expect('${v[4]}', contains('ثۡ ذَ'), reason: id);
        expect('${v[4]}', isNot(contains('ّ')), reason: id);
        expect(
          v[6],
          id == 'qalun' ? 'بخلف: الإظهار والإدغام' : 'بالإظهار',
          reason: id,
        );
      }
    });

    test('yumiddunahum of الأعراف ٢٠٢: the dal doubled with its damma', () {
      final q = where('qalun', 7, 202, 1).firstWhere((v) => v[5] == 'f');
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 7, 202, 1).firstWhere((v) => v[5] == 'f');
        expect(v[4], q[4], reason: id);
      }
    });

    test('yabtushuna: Abu Ja\'far\'s ta with the damma, wherever it comes', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [(7, 195, 7), (28, 19, 4), (44, 16, 1)]) {
          final v = where(id, s, a, w).single;
          expect('${v[4]}', contains('طُ'), reason: '$id $s:$a');
          expect(v[6], 'بضم الطاء', reason: '$id $s:$a');
        }
      }
    });

    test('shirkan of الأعراف ١٩٠: Abu Ja\'far\'s as Qalun\'s, one wording', () {
      final q = where('qalun', 7, 190, 5).single;
      expect(q[6], 'بكسر الشين وتسكين الراء وتنوين الكاف بالفتح');
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 7, 190, 5).single;
        expect(v[4], q[4], reason: id);
        expect(v[6], q[6], reason: id);
      }
    });

    test('tughfar and bi\'is of الأعراف told as Abu Ja\'far tells them', () {
      for (final (s, a, w) in [(7, 161, 15), (7, 165, 14)]) {
        final aj = where('ibn_wardan', s, a, w).single;
        expect(where('qalun', s, a, w).single[6], aj[6], reason: '$s:$a:$w');
      }
    });

    test('the iqlab\'s small mim under a kasra, as Hafs writes it', () {
      // «بِعَذَابِۭ بِيسِۭ» (الأعراف ١٦٥): under the sin, as Abu Ja'far's.
      expect('${where('qalun', 7, 165, 14).single[4]}', endsWith('ِۭ'));
      for (final id in [
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      ]) {
        for (final v in rowsOf(id)) {
          expect('${v[4]}', isNot(contains('ِۢ')), reason: '$id $v');
        }
      }
    });

    test('wa-s\'alhum of الأعراف ١٦٣: the hamza on its tooth, as Qalun\'s', () {
      final q = where('qalun', 7, 163, 0).firstWhere((v) => '${v[4]}' != '');
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final v in where(id, 7, 163, 0)) {
          if ('${v[4]}'.isEmpty) continue;
          expect(v[4], q[4], reason: id);
          expect('${v[4]}', isNot(contains('أ')), reason: id);
        }
      }
    });

    test('bi-risalati of الأعراف ١٤٤: the singular, as Ibn Kathir\'s', () {
      final bazzi = where('bazzi', 7, 144, 6).single;
      for (final id in ['qalun', 'ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 7, 144, 6).single;
        expect(v[4], bazzi[4], reason: id);
        expect(v[6], bazzi[6], reason: id);
        // The first alif the dagger one, the second gone.
        expect('${v[4]}'.split('ٰ').length, 2, reason: id);
      }
    });

    test('Qalun reads yasta\'khiruna of الأعراف ٣٤ as Hafs', () {
      expect(where('qalun', 7, 34, 7), isEmpty);
    });

    test('atuhajjunni and hadani of الأنعام ٨٠', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        final hajj = where(id, 6, 80, 3).firstWhere((v) => v[5] == 'f');
        expect('${hajj[4]}', isNot(contains('وٓ')));
        expect(hajj[6], 'بتخفيف النون');
        final hadani = where(id, 6, 80, 7).single;
        expect('${hadani[4]}', contains('ىٰ'));
        expect('${hadani[4]}', contains('ۦ'));
        expect(hadani[7], 'ya_zaida');
      }
    });

    test('the answers on the open words', () {
      for (final id in ['bazzi', 'qunbul']) {
        for (final (s, a) in [(38, 8), (54, 25)]) {
          final v = where(id, s, a, 0).single;
          expect(v[6], 'بتسهيل الهمزة الثانية بلا إدخال');
          expect(v[7], 'tasheel_word');
        }
      }
      final nisa = where('qalun', 4, 58, 17).single;
      expect('${nisa[6]}', startsWith('بوجهين: إسكان العين'));
      expect('${nisa[4]}', isNot(contains('۪')));
      final inna = where('qalun', 27, 55, 0).firstWhere((v) => v[5] == 'h');
      expect('${inna[4]}', contains('۬'));
      expect(inna[7], 'tasheel_word');
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        expect(where(id, 4, 58, 17).single[6], 'بإسكان العين');
        expect(
          where(id, 4, 40, 9).single[4],
          where('bazzi', 4, 40, 9).single[4],
        );
        expect(where(id, 42, 20, 14).single[7], 'ibdal_single');
        expect(where(id, 15, 48, 7), isEmpty);
        expect(where(id, 18, 2, 0), isEmpty);
        expect(
          where(id, 67, 27, 3).single[4],
          where('qalun', 67, 27, 3).single[4],
        );
        for (final (s, a, w) in [(7, 123, 2), (20, 71, 1), (26, 49, 1)]) {
          final v = where(id, s, a, w).firstWhere((v) => v[5] == 'h');
          final q = where('qalun', s, a, w).firstWhere((v) => v[5] == 'h');
          expect(v[4], q[4], reason: '$s:$a');
          expect(v[6], q[6], reason: '$s:$a');
        }
        final dagger = where(id, 9, 44, 1).firstWhere((v) => v[5] == 'h');
        expect('${dagger[4]}', contains('ٰ'));
        expect('${dagger[4]}', isNot(contains('تَا')));
      }
    });

    test('yuaddih, the hamza after a damma, in the ibdal', () {
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        for (final (s, a, w) in [
          (3, 75, 7),
          (3, 75, 15),
          (4, 58, 4),
          (16, 61, 11),
          (35, 45, 1),
        ]) {
          final v = where(id, s, a, w).firstWhere((v) => v[5] != 'u');
          expect(v[5], 'h', reason: '$s:$a');
          expect(v[7], 'ibdal_single', reason: '$s:$a');
          expect('${v[6]}', contains('واو'), reason: '$s:$a');
        }
      }
    });

    test('Qalun\'s Tawrah: both faces, no sign, wherever it comes', () {
      final rows = rowsOf('qalun').where((v) {
        return v.length > 7 && v[7] == 'fath_taqlil';
      }).toList();
      expect(rows, hasLength(18));
      for (final v in rows) {
        expect(v[4], '');
        expect(v[6], 'بالفتح والتقليل، والراجح الفتح');
      }
    });

    test('a-unabbi\'ukum: the dagger between for those who put it', () {
      for (final id in ['qalun', 'ibn_wardan', 'ibn_jammaz']) {
        final v = where(id, 3, 15, 1).single;
        expect(v[4], 'أَٰؤُ۬نَبِّئُكُمُۥ');
        expect(v[7], 'tasheel_word');
      }
      for (final id in ['bazzi', 'qunbul']) {
        final v = where(id, 3, 15, 1).firstWhere((v) => v[5] == 'h');
        expect(v[4], 'أَؤُ۬نَبِّئُكُمُۥ');
        expect(v[6], contains('بلا إدخال'));
        expect(v[7], 'tasheel_word');
      }
    });
  });
}
