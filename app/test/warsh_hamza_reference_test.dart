import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';

// Regression cases from the user's eight hamza charts (22 October 2026),
// checked against the transcribed book and aligned to the Hafs ayah numbers.
// Source numbering differs at e.g. شهداء إذ (6:144), هؤلاء إلا (38:15),
// الدعاء إذا (30:52), and يشاء إنه (42:27,51).
// The exact faces follow al-Wafi, باب الهمزتين من كلمتين:
// https://www.islamweb.net/ar/library/content/245/16/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VariantRepository repository;
  setUpAll(() async {
    repository = await VariantRepository.discover();
    await repository.ensureLoaded(['warsh']);
  });
  Variant rule((int, int, int) site, String id) => repository
      .at(['warsh'], site.$1, site.$2, site.$3)
      .singleWhere((v) => v.rule == id);

  void cases(String name, String id, int count, List<(int, int, int)> sites) {
    test(name, () {
      for (final site in sites) {
        final v = rule(site, id);
        expect(v.usulWays, hasLength(count), reason: '$site: ${v.usulText}');
        expect(v.isUsul, isTrue);
        expect(v.inHamesh, isFalse);
        expect(ReadingColors.of(v), ReadingColors.hamza);
        expect(v.usulText.split(' '), hasLength(2));
        expect(v.usulWays.every((w) => w.contains('وصلاً')), isTrue);
      }
    });
  }

  cases(
    'damma/fatha replaces the second hamza with pure waw only',
    'ibdal_waw',
    1,
    [
      (2, 13, 12),
      (7, 100, 11),
      (7, 155, 33),
      (9, 37, 25),
      (11, 44, 5),
      (12, 43, 17),
      (27, 32, 3),
      (27, 38, 3),
      (33, 6, 1),
      (33, 50, 36),
      (41, 28, 2),
      (60, 4, 27),
    ],
  );
  cases('damma/kasra keeps both pure waw and tasheel', 'ibdal_waw', 2, [
    (2, 142, 18),
    (2, 213, 46),
    (2, 282, 74),
    (3, 13, 23),
    (3, 47, 15),
    (6, 83, 10),
    (7, 188, 21),
    (10, 25, 8),
    (11, 87, 16),
    (12, 100, 42),
    (19, 7, 1),
    (22, 5, 31),
    (24, 6, 7),
    (24, 46, 8),
    (27, 29, 3),
    (33, 45, 2),
    (33, 50, 2),
    (35, 15, 4),
    (35, 28, 13),
    (35, 43, 9),
    (42, 27, 13),
    (42, 49, 10),
    (42, 51, 19),
    (60, 12, 2),
    (65, 1, 2),
    (66, 3, 3),
  ]);
  cases(
    'kasra/fatha replaces the second hamza with pure ya only',
    'ibdal_ya',
    1,
    [
      (2, 235, 9),
      (2, 282, 65),
      (4, 51, 15),
      (7, 28, 16),
      (7, 38, 28),
      (7, 50, 10),
      (8, 32, 15),
      (12, 76, 4),
      (12, 76, 9),
      (21, 99, 3),
      (25, 17, 12),
      (25, 40, 8),
      (26, 4, 6),
      (33, 55, 14),
      (67, 16, 4),
      (67, 17, 5),
    ],
  );
  cases('fatha/kasra or damma facilitates without ibdal', 'tasheel_pair', 1, [
    (2, 133, 3),
    (5, 14, 16),
    (5, 64, 30),
    (5, 101, 7),
    (6, 144, 19),
    (9, 23, 8),
    (9, 28, 23),
    (10, 66, 17),
    (12, 24, 15),
    (12, 58, 1),
    (18, 102, 9),
    (19, 3, 0),
    (21, 45, 8),
    (21, 89, 1),
    (23, 44, 7),
    (26, 69, 3),
    (27, 80, 8),
    (30, 52, 8),
    (49, 9, 17),
  ]);

  test('same vowels distinguish a moving following letter from a sakin', () {
    for (final site in [
      (32, 5, 4),
      (43, 84, 4),
      (23, 99, 3),
      (63, 11, 6),
      (46, 32, 14),
    ]) {
      final v = rule(site, 'tasheel_pair');
      expect(v.usulWays, hasLength(2));
      expect(v.usulWays.last, contains('القصر (حركتان)'));
      expect(v.usulWays.join(), isNot(contains('المشبع')));
    }
    for (final site in [
      (38, 15, 3),
      (33, 53, 7),
      (33, 55, 11),
      (15, 67, 1),
      (22, 65, 16),
      (25, 57, 9),
      (33, 24, 8),
      (47, 18, 9),
      (80, 22, 3),
    ]) {
      final v = rule(site, 'tasheel_pair');
      expect(v.usulWays, hasLength(2));
      expect(v.usulWays.last, contains('المد المشبع (٦ حركات)'));
      expect(v.usulWays.join(), isNot(contains('القصر')));
    }
  });

  test('arid movement retains qasr and ishba with their reasons', () {
    for (final site in [(33, 32, 6), (33, 50, 33), (24, 33, 32)]) {
      final ways = rule(site, 'tasheel_pair').usulWays;
      expect(ways, contains(contains('بالسكون الأصلي')));
      expect(ways, contains(contains('بالحركة العارضة')));
      expect(ways, contains(contains('القصر (حركتان)')));
      expect(ways, contains(contains('المد المشبع (٦ حركات)')));
    }
    expect(rule((2, 31, 12), 'tasheel_pair').usulWays, hasLength(3));
    expect(rule((24, 33, 32), 'tasheel_pair').usulWays, hasLength(4));
    for (final site in [(2, 31, 12), (24, 33, 32)]) {
      expect(
        rule(site, 'tasheel_pair').usulWays.last,
        contains('ياءً مكسورة خالصة'),
      );
    }
  });

  test('jaa aal has five valid faces without a Cartesian product', () {
    for (final site in [(15, 61, 2), (54, 41, 2)]) {
      final ways = rule(site, 'tasheel_pair').usulWays;
      expect(ways, hasLength(5));
      expect(ways.where((s) => s.contains('تسهيل')), hasLength(3));
      expect(ways.where((s) => s.contains('إبدال')), hasLength(2));
      expect(
        ways.where((s) => s.contains('إبدال')).join(),
        isNot(contains('٤ حركات')),
      );
    }
  });

  test('a pure ya replacement retains the following changed badal alif', () {
    for (final (site, text) in [
      ((21, 99, 3), 'ءَالِهَة'),
      ((26, 4, 6), 'ءَايَة'),
    ]) {
      expect(rule(site, 'ibdal_ya').text, startsWith(text));
      expect(
        repository
            .at(['warsh'], site.$1, site.$2, site.$3)
            .any((v) => v.isBadal),
        isTrue,
      );
    }
  });

  test('single-hamza ibdal does not change the iwaa exception', () {
    final q =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    var checked = 0;
    for (final a in q['ayahs'] as List) {
      final words = (a[4] as String).split(' ');
      for (var w = 0; w < words.length; w++) {
        if (!words[w].contains('مَأۡوَى')) continue;
        checked++;
        expect(
          repository
              .at(['warsh'], a[0] as int, a[1] as int, w)
              .where((v) => v.rule == 'ibdal_single'),
          isEmpty,
        );
      }
    }
    expect(checked, greaterThan(0));
  });

  test('Warsh-specific final hamzas survive classification of the second', () {
    for (final (site, id, context) in [
      ((33, 6, 1), 'ibdal_waw', 'ٱلنَّبِىٓءُ'),
      ((33, 53, 7), 'tasheel_pair', 'ٱلنَّبِىٓءِ'),
      ((19, 7, 1), 'ibdal_waw', 'زَكَرِيَّآءُ'),
      ((19, 3, 0), 'tasheel_pair', 'زَكَرِيَّآءَ'),
    ]) {
      expect(rule(site, id).usulText, contains(context));
    }
    expect(
      repository.at(['warsh'], 33, 6, 0).any((v) => v.text.contains('ءُ')),
      isTrue,
    );
  });

  test(
    'one-word faces respect the following letter and three-hamza exception',
    () {
      for (final site in [(11, 72, 2), (67, 16, 0)]) {
        expect(
          rule(site, 'tasheel_word').usulWays.last,
          contains('القصر (حركتان)'),
        );
      }
      expect(
        rule((2, 6, 5), 'tasheel_word').usulWays.last,
        contains('٦ حركات'),
      );
      for (final site in [
        (7, 123, 2),
        (20, 71, 1),
        (26, 49, 1),
        (43, 58, 1),
        (9, 12, 10),
      ]) {
        final v = rule(site, 'tasheel_word');
        expect(v.usulWays, hasLength(1));
        expect(v.usulWays.single, contains('تسهيل'));
        expect(v.inHamesh, isFalse);
        expect(v.isImala, isFalse);
        expect(ReadingColors.of(v), ReadingColors.hamza);
      }
      // In the repeated interrogation Warsh reads إنا by ikhbar.
      expect(
        repository
            .at(['warsh'], 13, 5, 7)
            .where((v) => v.rule == 'tasheel_word'),
        isEmpty,
      );
      expect(
        repository
            .at(['warsh'], 13, 5, 7)
            .any((v) => v.inHamesh && v.description == 'بالإخبار بهمزة واحدة'),
        isTrue,
      );
    },
  );

  test('ha antum and interrogative followed by wasl are explicit usul', () {
    for (final site in [(3, 66, 0), (3, 119, 0), (4, 109, 0), (47, 38, 0)]) {
      final v = rule(site, 'ha_antum');
      expect(v.usulWays, hasLength(2));
      expect(v.description, contains('حذف الألف بعد الهاء'));
      expect(v.inHamesh, isFalse);
    }
    for (final site in [
      (6, 143, 9),
      (6, 144, 7),
      (10, 59, 13),
      (10, 51, 6),
      (10, 91, 0),
    ]) {
      expect(rule(site, 'hamza_wasl').usulWays, hasLength(2));
    }
    expect(rule((10, 91, 0), 'hamza_wasl').description, contains('نقل'));
  });

  test('the book note on the first word does not become false farsh', () {
    for (final site in [(54, 41, 1), (2, 31, 11), (33, 32, 5), (20, 71, 0)]) {
      expect(
        repository
            .at(['warsh'], site.$1, site.$2, site.$3)
            .where(
              (v) =>
                  v.inHamesh && RegExp('تسهيل|إبدال').hasMatch(v.description),
            ),
        isEmpty,
        reason: '$site',
      );
    }
  });

  test('tanween and wasl do not become a two-qat-hamza rule', () {
    final data = jsonDecode(
      File('assets/data/qiraat/warsh.json').readAsStringSync(),
    ) as Map;
    final rows = data['variants'] as List;
    for (final (s, a, w) in [(3, 28, 16), (42, 24, 8)]) {
      expect(
        rows.where(
          (v) =>
              v[0] == s &&
              v[1] == a &&
              v[2] == w &&
              v.length > 7 &&
              ['tasheel_pair', 'ibdal_waw', 'ibdal_ya'].contains(v[7]),
        ),
        isEmpty,
      );
    }
  });
}
