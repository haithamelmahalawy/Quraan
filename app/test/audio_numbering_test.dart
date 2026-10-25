import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/audio_numbering.dart';
import 'package:qiraat_mushaf/data/recitations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AudioNumbering map;
  setUpAll(() async => map = await AudioNumbering.load());

  test('all counting profiles map every displayed verse and native clip', () {
    const totals = {
      'kufi': 6236,
      'madani-last': 6214,
      'madani-first': 6214,
      'makki': 6219,
      'makki-6220': 6220,
      'basri': 6204,
      'dimashqi': 6226,
    };
    for (final system in map.systems) {
      var total = 0;
      for (var s = 1; s <= 114; s++) {
        final count = map.nativeCount(system, s);
        total += count;
        for (var h = 1; h <= map.hafsCounts[s - 1]; h++) {
          final clips = map.clips(system, s, h);
          expect(clips, isNotEmpty);
          for (final n in clips) {
            expect(n, inInclusiveRange(s == 1 ? 0 : 1, count));
            expect(map.displayedVerses(system, s, n), contains(h));
          }
          if (system == 'kufi') expect(clips, [h]);
        }
        for (var n = 1; n <= count; n++) {
          expect(map.displayedVerses(system, s, n), isNotEmpty);
        }
      }
      expect(total, totals[system], reason: system);
    }
  });

  test('Warsh selection and Fatiha basmala use native clip numbers', () {
    expect(map.clips('madani-last', 2, 1), [1]);
    expect(map.clips('madani-last', 2, 2), [1]);
    expect(map.clips('madani-last', 2, 5), [4]);
    expect(map.displayedVerses('madani-last', 2, 1), [1, 2]);
    expect(map.clips('madani-last', 1, 1), [0]);
    expect(map.clips('madani-last', 1, 7), [6, 7]);
    expect(map.nativeCount('basri', 2), 287);
    expect(map.nativeCount('dimashqi', 2), 285);
  });

  test('native verse spans cover every word once in all counting systems', () {
    for (final system in map.systems) {
      for (var s = 1; s <= 114; s++) {
        var n = s == 1 && system != 'kufi' && !system.startsWith('makki')
            ? 0
            : 1;
        for (var a = 1; a <= map.hafsCounts[s - 1]; a++) {
          for (var w = 0; w < map.wordCounts[s - 1][a - 1]; w++) {
            expect(map.verseAt(system, s, a, w), n, reason: '$system $s:$a:$w');
            final end = map.markerAt(system, s, a, w);
            if (end != null) {
              expect(end, n);
              final range = map.span(system, s, n);
              expect(range.last, (ayah: a, word: w));
              expect(
                map.verseAt(system, s, range.first.ayah, range.first.word),
                n,
              );
              n++;
            } else if (s == 1 &&
                a == 1 &&
                w == map.wordCounts[0][0] - 1 &&
                n == 0) {
              n++;
            }
          }
        }
        expect(n - 1, map.nativeCount(system, s), reason: '$system $s');
      }
    }
  });

  test('Fatiha split and Baqarah merge have real word boundaries', () {
    expect(map.markerAt('madani-last', 1, 1, 3), isNull);
    expect(map.markerAt('madani-last', 1, 7, 3), 6);
    expect(map.span('madani-last', 1, 7).first, (ayah: 7, word: 4));
    expect(map.span('madani-last', 2, 1).first, (ayah: 1, word: 0));
    expect(map.span('madani-last', 2, 1).last.ayah, 2);
    expect(map.clipsForSpan('kufi', 2, map.span('madani-last', 2, 1)), [1, 2]);
    expect(map.clipsForSpan('madani-last', 1, map.span('kufi', 1, 7)), [6, 7]);
  });

  test(
    'Bazzi recording and display retain their extra Naba boundary',
    () async {
      expect(map.nativeCount('makki', 78), 40);
      expect(map.nativeCount('makki-6220', 78), 41);
      expect(AudioNumbering.displaySystemFor('bazzi'), 'makki-6220');
      expect(AudioNumbering.displaySystemFor('qunbul'), 'makki');
      final recitations = await Recitations.load();
      expect(recitations.of('bazzi').single.numbering, 'makki-6220');
      expect(recitations.of('qunbul').single.numbering, 'makki');
      expect(map.clipsForSpan('makki-6220', 78, map.span('makki', 78, 40)), [
        40,
        41,
      ]);
    },
  );

  test(
    'cross-system selections always cover the same first and last words',
    () {
      for (final from in map.systems) {
        for (final to in map.systems) {
          for (var s = 1; s <= 114; s++) {
            for (var n = 1; n <= map.nativeCount(from, s); n++) {
              final selected = map.span(from, s, n);
              final clips = map.clipsForSpan(to, s, selected);
              expect(
                clips.first,
                map.verseAt(to, s, selected.first.ayah, selected.first.word),
              );
              expect(
                clips.last,
                map.verseAt(to, s, selected.last.ayah, selected.last.word),
              );
              if (from == to) expect(clips, [n]);
            }
          }
        }
      }
    },
  );

  test('all twenty narrations select the recording counting system', () async {
    final recitations = await Recitations.load();
    const expected = {
      'hafs': 'kufi',
      'shubah': 'kufi',
      'warsh': 'madani-last',
      'qalun': 'madani-last',
      'bazzi': 'makki-6220',
      'qunbul': 'makki',
      'duri_abuamr': 'basri',
      'susi': 'basri',
      'hisham': 'dimashqi',
      'ibn_dhakwan': 'dimashqi',
      'khalaf_hamzah': 'kufi',
      'khallad': 'kufi',
      'abul_harith': 'kufi',
      'duri_kisai': 'kufi',
      'ibn_wardan': 'madani-first',
      'ibn_jammaz': 'madani-first',
      'ruways': 'basri',
      'rawh': 'basri',
      'ishaq': 'kufi',
      'idris': 'kufi',
    };
    for (final entry in expected.entries) {
      expect(recitations.of(entry.key), isNotEmpty, reason: entry.key);
      for (final reciter in recitations.of(entry.key)) {
        expect(
          reciter.numbering,
          entry.value,
          reason: '${entry.key}/${reciter.id}',
        );
      }
    }
  });
}
