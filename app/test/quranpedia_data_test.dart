import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';

/// Variants of [riwaya] in an ayah, as [word, count, text, kind, ...].
List<List<Object?>> variants(String riwaya, int surah, int ayah) => [
  for (final v
      in (jsonDecode(File('assets/data/qiraat/$riwaya.json').readAsStringSync())
              as Map)['variants']
          as List)
    if (v[0] == surah && v[1] == ayah) (v as List).sublist(2),
];

void main() {
  test('every riwaya has an offline file', () {
    for (final q in qiraat) {
      for (final r in q.riwayat) {
        if (r.id == hafsId) continue;
        expect(
          File('assets/data/qiraat/${r.id}.json').existsSync(),
          isTrue,
          reason: r.id,
        );
      }
    }
  });

  test('readings of the twelve Quranpedia riwayat', () {
    // مَلِكِ (1:4) — filed by Quranpedia under 1:3 as «الرحيم ملك» — for Ibn
    // 'Amir, Hamzah and Abu Ja'far; al-Kisa'i, Ya'qub and Khalaf read مَٰلِكِ.
    for (final id in [
      'hisham',
      'ibn_dhakwan',
      'khalaf_hamzah',
      'khallad',
      'ibn_wardan',
      'ibn_jammaz',
    ]) {
      expect(variants(id, 1, 4).single.sublist(0, 4), [
        0,
        1,
        'مَلِكِ',
        'f',
      ], reason: id);
      expect(variants(id, 1, 3), isEmpty, reason: id);
    }
    for (final id in [
      'abul_harith',
      'duri_kisai',
      'ruways',
      'rawh',
      'ishaq',
      'idris',
    ]) {
      expect(variants(id, 1, 4), isEmpty, reason: id);
    }
    // يُكَذِّبُونَ (2:10) for Ibn 'Amir, Abu Ja'far and Ya'qub only.
    for (final id in [
      'hisham',
      'ibn_dhakwan',
      'ibn_wardan',
      'ibn_jammaz',
      'ruways',
      'rawh',
    ]) {
      expect(
        variants(id, 2, 10).where((v) => v[0] == 11 && v[3] == 'f'),
        hasLength(1),
        reason: id,
      );
    }
    for (final id in [
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      expect(
        variants(id, 2, 10).where((v) => v[3] == 'f'),
        isEmpty,
        reason: id,
      );
    }
    // مَرْفِقًا ends 18:16; Quranpedia files it under 18:17 with وَتَرَى.
    // (Besides Hisham's stop on a last hamza, a rule of its own.)
    expect(
      variants('hisham', 18, 16)
          .where((v) => v.length < 6 || v[5] != 'hisham_waqf')
          .single
          .sublist(0, 3),
      [18, 1, 'مَرْفِقٗا'],
    );
  });
}
