import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/quran_search.dart';

void main() {
  final quran = QuranRepository.parse(
    File('assets/data/quran.json').readAsStringSync(),
  );
  final search = QuranSearch(quran);

  String at(SearchHit h) => '${h.ayah.surah}:${h.ayah.number}';

  test('a phrase typed without diacritics', () {
    final hits = search.search('خذ الكتاب بقوة');
    expect(hits.map(at), ['19:12']);
    expect(hits.single.page, 306);
    expect(
      hits.single.ayah.words.sublist(hits.single.from, hits.single.to),
      hasLength(3),
    );
  });

  test('Uthmani spellings: dagger alef, waw for alef', () {
    expect(search.search('الرحمن').map(at), contains('1:3'));
    final salah = search.search('الصلاة').map(at);
    expect(salah, contains('2:3'));
    expect(salah.length, greaterThan(50));
  });

  test('nothing for an empty or unknown query', () {
    expect(search.search('  '), isEmpty);
    expect(search.search('كمبيوتر'), isEmpty);
  });
  test('the text as typed, its hamzas aside: no other word of the root', () {
    final shufaa = search.search('شفعاؤ');
    expect(shufaa, isNotEmpty);
    for (final h in shufaa) {
      final w = h.ayah.words.sublist(h.from, h.to).join(' ');
      expect(w, contains('شُفَعَ'), reason: w);
    }
    expect(
      search.search('اشركوا').map(at).toSet(),
      search.search('أشركوا').map(at).toSet(),
    );
    expect(search.search('الحياة').map(at), contains('2:85'));
    // اشركوا is not شُرَكَآؤُكُمۡ, its alif a letter.
    for (final h in search.search('اشركوا')) {
      expect(h.ayah.words[h.from], contains('أَشۡرَكُو'));
    }
    expect(search.search('الرحمان').map(at), contains('1:3'));
  });
}
