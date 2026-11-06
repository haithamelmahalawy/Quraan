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
    // And the complete texts, as Warsh's «وَهَٰمَٰنَ» (القصص ٦).
    final hafs = {
      for (final a in quran['ayahs'] as List)
        '${a[0]}:${a[1]}': (a[4] as String).split(' '),
    };
    expect(daggerAlifWord('وَهَامَٰنَ', 'وَهَٰمَٰنَ'), 'وَهَٰمَٰنَ');
    for (final f in Directory(
      'assets/data/reading_texts',
    ).listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final ayahs = (jsonDecode(f.readAsStringSync()) as Map)['ayahs'] as List;
      for (final a in ayahs) {
        for (final (i, w) in (a[2] as List).cast<String>().indexed) {
          if (w.isEmpty) continue;
          final h = hafs['${a[0]}:${a[1]}']![i];
          expect(
            daggerAlifWord(w, h),
            w,
            reason: '${f.path} ${a[0]}:${a[1]}:$i',
          );
        }
      }
    }
  });
}
