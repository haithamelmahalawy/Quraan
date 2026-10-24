import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build_ibn_amir_usul.dart';

void main() {
  late Map quran;
  late Map<String, Map> built;
  setUpAll(() {
    quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    built = {
      for (final id in ['hisham', 'ibn_dhakwan']) id: {'variants': <List>[]},
    };
    for (final entry in built.entries) {
      final counts = buildIbnAmirUsul(quran, entry.value, entry.key);
      // Counts are diagnostic; the tests below assert transmitted examples.
      // ignore: avoid_print
      print('${entry.key}: $counts');
    }
  });
  List rows(String id, int s, int a, String rule) =>
      (built[id]!['variants'] as List)
          .where((v) => v[0] == s && v[1] == a && v[7] == rule)
          .toList();

  test('only the two Ibn Amir narrators are accepted', () {
    expect(
      () => buildIbnAmirUsul(quran, {'variants': []}, 'warsh'),
      throwsArgumentError,
    );
  });
  test(
    'general shared madd and basmala are a profile, not false differences',
    () {
      for (final data in built.values) {
        expect(data['usulProfile']['madd']['muttasil'], [4]);
        expect(data['usulProfile']['basmala']['ways'], hasLength(5));
        expect(
          (data['variants'] as List).where((v) => '${v[7]}'.startsWith('madd')),
          isEmpty,
        );
      }
    },
  );
  test('passive ishmam is restricted by narrator and excludes nouns', () {
    expect(rows('hisham', 2, 11, 'ishmam'), hasLength(1));
    expect(rows('ibn_dhakwan', 2, 11, 'ishmam'), isEmpty);
    expect(rows('hisham', 11, 44, 'ishmam'), hasLength(3));
    expect(rows('ibn_dhakwan', 34, 54, 'ishmam'), hasLength(1));
    expect(rows('ibn_dhakwan', 67, 27, 'ishmam'), hasLength(1));
    expect(rows('hisham', 4, 122, 'ishmam'), isEmpty);
  });
  test('restricted imala and corrected possessive ya examples are indexed', () {
    for (final place in [
      (33, 53),
      (88, 5),
      (36, 73),
      (109, 3),
      (109, 4),
      (109, 5),
    ]) {
      expect(
        rows('hisham', place.$1, place.$2, 'imala'),
        isNotEmpty,
        reason: '${place.$1}:${place.$2}',
      );
    }
    for (final place in [(58, 21), (71, 6), (12, 38), (12, 86), (11, 88)]) {
      for (final id in built.keys) {
        expect(
          rows(id, place.$1, place.$2, 'ya_idafa'),
          isNotEmpty,
          reason: '$id ${place.$1}:${place.$2}',
        );
      }
    }
  });
  test('ha faces preserve vowel and do not mistake no-silah for sukun', () {
    for (final id in built.keys) {
      final row = rows(id, 25, 69, 'ha_kinaya').single;
      expect(row[4], contains('هِ'));
      expect(row[4], isNot(contains('هۡ')));
    }
    expect(rows('hisham', 39, 7, 'ha_kinaya').single[8]['ways'], hasLength(2));
    expect(rows('ibn_dhakwan', 24, 52, 'ha_kinaya').single[4], contains('قِ'));
  });
  test('Hisham keeps both verification faces on aounabbiukum', () {
    final row = rows('hisham', 3, 15, 'tasheel_word').single;
    expect(row[8]['ways'], [
      'تحقيق الهمزتين دون إدخال',
      'تحقيق الهمزتين مع إدخال ألف الفصل',
    ]);
  });
  test(
    'terminal hamza includes fathatan and retains its compensation alif',
    () {
      final shayan = rows('hisham', 2, 48, 'hisham_waqf').single;
      expect(shayan[8]['stopText'], 'شَيَا');
      final juzan = rows(
        'hisham',
        2,
        260,
        'hisham_waqf',
      ).singleWhere((v) => (v[8]['stopText'] as String).startsWith('جُز'));
      expect(juzan[8]['stopText'], 'جُزَا');
      final hanian = rows('hisham', 4, 4, 'hisham_waqf');
      expect(hanian.map((v) => v[8]['stopText']), contains('هَنِيَّا'));
      expect(hanian.map((v) => v[8]['stopText']), contains('مَّرِيَّا'));
      final duaan = rows('hisham', 2, 171, 'hisham_waqf');
      expect(duaan.map((v) => v[8]['stopText']), contains('دُعَآ'));
    },
  );
  test('internal idgham keeps the canonical shared Shubah spelling', () {
    for (final id in built.keys) {
      expect(rows(id, 2, 51, 'idgham_saghir').single[4], 'ٱتَّخَذتُّمُ');
    }
  });
  test(
    'all stop rules preserve continuous text and carry their own source',
    () {
      for (final id in built.keys) {
        final variants = built[id]!['variants'] as List;
        for (final row in variants) {
          expect(row[8]['source'], ibnAmirUsulSource);
          expect(row[8]['sourcePage'], inInclusiveRange(8, 45));
          if (row[8]['stopOnly'] == true) {
            expect(row[4], isEmpty);
            expect(row[8]['stopText'], isNotEmpty);
          }
        }
        expect(
          variants.where((v) => v[7] == 'hisham_waqf').isNotEmpty,
          id == 'hisham',
        );
        // Generic ta marbuta / open-ta conversion from the book is rejected.
        expect(rows(id, 2, 218, 'waqf_rasm'), isEmpty);
      }
    },
  );
  test('rebuilding is deterministic and preserves approved farsh', () {
    for (final id in built.keys) {
      final data = built[id]!;
      final preserved = [
        1,
        1,
        3,
        1,
        'مَلِكِ',
        'f',
        'بحذف الألف',
        'reviewed_farsh',
      ];
      (data['variants'] as List).add(preserved);
      buildIbnAmirUsul(quran, data, id);
      final first = jsonEncode(data);
      buildIbnAmirUsul(quran, data, id);
      expect(jsonEncode(data), first);
      expect(
        (data['variants'] as List).map(jsonEncode),
        contains(jsonEncode(preserved)),
      );
    }
  });
}
