import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/apply_dagger_alif.dart';

void main() {
  test('an alif any reader adds to Hafs\'s rasm is the dagger one', () {
    expect(daggerAlifWord('خطيئَاتُهُ', 'خَطِيٓـَٔتُهُۥ'), 'خطيئَٰتُهُ');
    expect(daggerAlifWord('دِفَاعُ', 'دَفۡعُ'), 'دِفَٰعُ');
    expect(
      daggerAlifWord('تُمَآسُّوهُنَّ', 'تَمَسُّوهُنَّ'),
      'تُمَٰٓسُّوهُنَّ',
    );
    // Where Hafs writes it, the wasl's, a seat's and a tanween's: kept.
    expect(
      daggerAlifWord('وَالنَّبِيٓـِٕـۧنَ', 'وَٱلنَّبِيِّـۧنَ'),
      'وَالنَّبِيٓـِٕـۧنَ',
    );
    expect(daggerAlifWord('هُزُؤًا', 'هُزُوٗا'), 'هُزُؤًا');
    expect(daggerAlifWord('قَلِيلٗا', 'قَلِيلٞ'), 'قَلِيلٗا');

    final quran =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    for (final f in Directory(
      'assets/data/qiraat',
    ).listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final rows =
          (jsonDecode(f.readAsStringSync()) as Map)['variants'] as List;
      final copy = jsonDecode(jsonEncode(rows)) as List;
      // Applied already: nothing left to change.
      expect(applyDaggerAlif(quran, copy), 0, reason: f.path);
    }
  });
}
