import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      contains('بإمالة هاء التأنيث وما قبلها وقفًا'),
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
}
