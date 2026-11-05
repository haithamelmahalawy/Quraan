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
        final letter = RegExp('[^ً-ٟۖ-ۭ]([ً-ٟۖ-ۭ]*)');
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
