import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';

import '../tool/build_yaqub_usul.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  Map load(String id) =>
      jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync()) as Map;
  List<List> rules(Map d, String rule, int s, int a) => (d['variants'] as List)
      .cast<List>()
      .where((v) => v.length > 7 && v[7] == rule && v[0] == s && v[1] == a)
      .toList();
  test('Yaqub source builder is deterministic for both narrators', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      buildYaqubUsul(quran, d, id);
      final once = jsonEncode(d);
      buildYaqubUsul(quran, d, id);
      expect(jsonEncode(d), once, reason: id);
    }
  });
  test('ishmam belongs to Ruways and carries no Warsh badal', () {
    final rw = load('ruways'), rh = load('rawh');
    final v = rules(rw, 'ishmam', 2, 11).single;
    expect(v[3], 1);
    expect(v[6], isNot(contains('البدل')));
    expect(rules(rh, 'ishmam', 2, 11), isEmpty);
    expect(rules(rw, 'badal', 2, 13), isEmpty);
  });
  test('source imala is restricted to its narrator and first aama', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      expect(rules(d, 'imala', 17, 72), hasLength(1));
      expect(rules(d, 'imala', 27, 43), hasLength(1));
      expect(rules(d, 'imala', 11, 41), isEmpty);
      expect(rules(d, 'imala', 2, 19), isEmpty);
    }
    expect(rules(load('rawh'), 'imala', 36, 1), hasLength(1));
    expect(rules(load('ruways'), 'imala', 36, 1), isEmpty);
  });
  test('hamza boundary rules preserve first hamza and their context', () {
    final d = load('ruways');
    final v = rules(d, 'ibdal_waw', 2, 13).single;
    expect(v[3], 1);
    expect((v[8] as Map)['context'], contains('ٱلسُّفَهَآءُ'));
    expect(v[4], startsWith('وَ'));
    expect(rules(load('rawh'), 'ibdal_waw', 2, 13), isEmpty);
    final source = rules(d, 'naql_source', 55, 54).single;
    expect(source[4], endsWith('نِ'));
    expect(rules(load('rawh'), 'naql_source', 55, 54), isEmpty);
    expect(rules(d, 'naql', 53, 50).single[4], contains('لُّ'));
  });
  test('stop annotations do not replace continuous text', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      for (final v in (d['variants'] as List).cast<List>()) {
        if (v.length < 9 ||
            v[8] is! Map ||
            (v[8] as Map)['source'] != yaqubSource) {
          continue;
        }
        expect((v[8] as Map)['sourcePage'], inInclusiveRange(7, 39));
        if ((v[8] as Map)['stopOnly'] == true) {
          expect(v[4], isEmpty);
          expect((v[8] as Map)['stopText'], isNotEmpty);
        }
      }
      expect(
        rules(d, 'ha_sakt', 2, 2),
        isEmpty,
        reason: 'negative lam is not interrogative lim',
      );
      expect(rules(d, 'ha_silah', 25, 69).single[6], contains('بلا صلة'));
      expect(rules(d, 'ha_damir', 1, 7), isNotEmpty);
    }
  });
  test('unsupported narrator is refused before any mutation', () {
    final d = load('ruways'), before = jsonEncode(load('ruways'));
    expect(() => buildYaqubUsul(quran, d, 'warsh'), throwsArgumentError);
    expect(jsonEncode(d), before);
  });
  test('ha sakt excludes lexical doubled ya and retains first-person ya', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      final hs = (d['variants'] as List)
          .cast<List>()
          .where(
            (v) =>
                v.length > 8 && v[7] == 'ha_sakt' && v[8]['stopOnly'] == true,
          )
          .toList();
      for (final v in hs) {
        final a = (quran['ayahs'] as List).firstWhere(
          (a) => a[0] == v[0] && a[1] == v[1],
        );
        final hf = (a[4] as String).split(' ')[v[2] as int];
        expect(hf.contains('نَّبِيّ'), isFalse, reason: '$id $hf');
        expect(hf.contains('ٱلۡحَيّ'), isFalse, reason: '$id $hf');
        expect(hf.contains('بُنَيّ'), isFalse, reason: '$id $hf');
      }
      expect(rules(d, 'ha_sakt', 3, 68), isEmpty); // النبي
      expect(
        rules(
          d,
          'ha_sakt',
          31,
          13,
        ).any((v) => (v[8]['stopText'] as String).contains('بُنَيّ')),
        isFalse,
      );
      expect(
        rules(
          d,
          'ha_sakt',
          14,
          22,
        ).any((v) => (v[8]['stopText'] as String).contains('مُصرِخِيَّ')),
        isTrue,
      );
      expect(
        rules(
          d,
          'ha_sakt',
          50,
          23,
        ).any((v) => (v[8]['stopText'] as String).startsWith('لَدَيَّ')),
        isTrue,
      );
      expect(
        rules(
          d,
          'ha_sakt',
          2,
          132,
        ).any((v) => (v[8]['stopText'] as String).contains('بَنِيَّ')),
        isTrue,
      );
    }
  });
  test(
    'checked extra ya catalogue covers all 86 verse endings and exclusions',
    () {
      final lengths = {
        for (final a in quran['ayahs'] as List)
          '${a[0]}:${a[1]}': (a[4] as String).split(' ').length,
      };
      for (final id in ['ruways', 'rawh']) {
        final d = load(id);
        final ys = (d['variants'] as List)
            .cast<List>()
            .where((v) => v.length > 8 && v[7] == 'ya_zaida')
            .toList();
        final continuousEnd = ys
            .where(
              (v) =>
                  (v[8] as Map)['stopOnly'] != true &&
                  v[2] == lengths['${v[0]}:${v[1]}']! - 1,
            )
            .toList();
        expect(continuousEnd, hasLength(86), reason: id);
        expect(rules(d, 'ya_zaida', 2, 186), hasLength(2));
        expect(rules(d, 'ya_zaida', 3, 175), hasLength(1));
        expect(
          rules(d, 'ya_zaida', 12, 90),
          isEmpty,
          reason: 'يتق is excluded',
        );
        expect(
          rules(d, 'ya_zaida', 12, 12),
          isEmpty,
          reason: 'نرتع is not a Yaqub extra ya',
        );
        expect(
          rules(d, 'ya_zaida', 39, 10),
          isEmpty,
          reason: 'vocative يا عباد الذين is deleted by agreement',
        );
        final stopped = ys
            .where((v) => (v[8] as Map)['stopOnly'] == true)
            .toList();
        expect(stopped, hasLength(id == 'rawh' ? 19 : 18));
        expect(
          (rules(d, 'ya_zaida', 6, 57).single[8] as Map)['stopText'],
          'يَقْضِي',
        );
        final atan = rules(d, 'ya_zaida', 27, 36).singleWhere((v) => v[2] == 7);
        expect((atan[8] as Map)['stopOnly'] == true, id == 'rawh');
        expect(
          rules(d, 'ya_zaida', 39, 16).any((v) => v[2] == 14),
          id == 'ruways',
        );
      }
    },
  );
  test('reviewed assets do not revive stale book usul at runtime', () async {
    final repo = await VariantRepository.discover();
    await repo.ensureLoaded(['ruways', 'rawh']);
    final q = await QuranRepository.load();
    for (final id in ['ruways', 'rawh']) {
      for (final w in [2, 19, 24]) {
        // Legacy data asserted false imala in words on early Baqara pages.
        final rows = repo.at(
          [id],
          2,
          w,
          w == 2
              ? 0
              : w == 19
              ? 18
              : 12,
        );
        expect(rows.any((v) => v.isImala), isFalse, reason: '$id 2:$w');
      }
      final own = repo.at([id], 2, 11, 1);
      expect(own.any((v) => v.rule == 'ishmam'), id == 'ruways');
      final compared = compareReadings(
        repository: repo,
        ayah: q.ayah(2, 11),
        word: 1,
        displayed: null,
        selected: [id],
      );
      expect(compared.any((v) => v.rule == 'badal'), isFalse);
    }
    expect(
      repo.at(['ruways'], 19, 4, 3).any((v) => v.rule == 'ha_sakt'),
      isFalse,
      reason: 'وهن is a verb, not the feminine plural pronoun',
    );
  });
}
