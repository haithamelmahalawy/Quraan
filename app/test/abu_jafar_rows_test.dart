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
      final v = rowsOf(
        id,
      ).firstWhere((v) => v[0] == 2 && v[1] == 284 && v[2] == 20);
      expect(v[5], 'f');
      expect(v[6], 'بإسكان الباء مع الإظهار والقلقلة');
    }
  });

  test('Qalun\'s «فاذكروني» is written without the madd', () {
    final v = rowsOf('qalun')
        .firstWhere((v) => v[0] == 2 && v[1] == 152 && v[2] == 0);
    expect(canon(v[4]), canon('فَٱذۡكُرُونِي'));
  });
}
