import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 604 book margins have valid source transcriptions', () {
    final source = Directory('../tools/source/books/kharouf');
    final files = source
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'[/\\]\d{3}\.json$').hasMatch(f.path))
        .toList();
    final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync());
    final ayahs = {for (final a in quran['ayahs'] as List) '${a[0]}:${a[1]}'};
    expect(files, hasLength(604));
    final pages = <int>{};
    for (final file in files) {
      final page = jsonDecode(file.readAsStringSync()) as Map;
      final number = page['bookPage'] as int;
      expect(pages.add(number), isTrue, reason: file.path);
      expect(page['mushafPage'], number - 14, reason: file.path);
      expect(page['text'], isA<String>(), reason: file.path);
      expect((page['text'] as String).trim(), isNotEmpty, reason: file.path);
      expect(page['entries'], isA<List>(), reason: file.path);
      for (final entry in page['entries'] as List) {
        expect(entry['word'], isA<String>(), reason: file.path);
        expect(entry['raw'], isA<String>(), reason: file.path);
        expect(entry['verses'], isA<List>(), reason: file.path);
        expect(entry['readings'], isA<List>(), reason: file.path);
        for (final ayah in entry['ayahs'] as List) {
          expect(
            ayahs,
            contains('${entry['surah']}:$ayah'),
            reason: '${file.path}: ${entry['word']}',
          );
        }
        for (final reading in entry['readings'] as List) {
          expect(reading['text'], anyOf(isNull, isA<String>()));
          expect(reading['readers'], isA<List>());
          expect(reading['how'], isA<String>());
        }
      }
    }
    expect(pages, unorderedEquals(List.generate(604, (i) => i + 15)));
  });

  test(
    'the last book page is included with continuous and stopping readings',
    () async {
      final book = await Kharouf.load();
      final kufuwan = book
          .at(112, 4, 3)
          .where((e) => e.section == 'farsh')
          .single;
      expect(kufuwan.readings.firstWhere((r) => r.readsAsHafs).riwayat, [
        'hafs',
      ]);
      expect(
        kufuwan.readings.where(
          (r) => r.stopOnly && r.riwayat.contains('khalaf_hamzah'),
        ),
        hasLength(2),
      );
      for (final (ayah, word) in [(1, 3), (2, 1), (3, 1), (5, 4), (6, 2)]) {
        expect(
          book
              .at(114, ayah, word)
              .where((e) => e.section == 'mumal')
              .expand((e) => e.readings.expand((r) => r.riwayat)),
          contains('duri_abuamr'),
          reason: '114:$ayah',
        );
      }
    },
  );
}
