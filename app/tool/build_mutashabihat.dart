// Builds the mutashabihat (verbally similar ayahs) data.
//
//   dart run tool/build_mutashabihat.dart [dataJson]
//
// Source: Quran Mutashabihat Data by Waqar144 (CC0), based on the work of
// Qari Idrees Al-Asim: https://github.com/Waqar144/Quran_Mutashabihat_Data
// (default ../tools/source/mutashabihat/data.json). Ayahs there are 0-based
// indexes over the whole Quran.
//
// Output: assets/data/mutashabihat.json
//   {"groups": [[occurrence, ...], ...]}
//   occurrence = [[surah, ayah, [shared word indexes]], ...] (one part per
//   ayah; a few entries span two or three ayahs)
// Shared words are the runs of two or more words an occurrence has in common
// with another occurrence of the group; they become tappable in the app.
import 'dart:convert';
import 'dart:io';

typedef Part = (int surah, int ayah);

void main(List<String> args) {
  final path =
      args.isNotEmpty ? args[0] : '../tools/source/mutashabihat/data.json';
  final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync())
      as Map<String, dynamic>;
  final ayahs = [
    for (final a in quran['ayahs'] as List)
      (surah: a[0] as int, ayah: a[1] as int, words: (a[4] as String).split(' ')),
  ];

  final data = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  List<int> indexes(Object ayah) => ayah is List ? ayah.cast<int>() : [ayah as int];

  // Each entry: a source and its similar ayahs. Entries appear in both
  // directions, so identical groups are kept once.
  final seen = <String>{};
  final groups = <List<List<int>>>[];
  for (final entries in data.values) {
    for (final e in entries as List) {
      final occurrences = [
        indexes(e['src']['ayah']),
        for (final m in e['muts'] as List) indexes(m['ayah']),
      ];
      final key = (occurrences.map((o) => o.join('+')).toList()..sort()).join('|');
      if (seen.add(key)) groups.add(occurrences);
    }
  }

  final out = <List<Object>>[];
  for (final group in groups) {
    final texts = [
      for (final o in group) [for (final i in o) for (final w in ayahs[i].words) _skeleton(w)],
    ];
    final shared = [for (final t in texts) List<bool>.filled(t.length, false)];
    for (var x = 0; x < texts.length; x++) {
      for (var y = 0; y < texts.length; y++) {
        if (x != y) _markCommonRuns(texts[x], texts[y], shared[x]);
      }
    }
    final occurrences = <Object>[];
    for (var k = 0; k < group.length; k++) {
      var offset = 0;
      final parts = <Object>[];
      for (final i in group[k]) {
        final a = ayahs[i];
        parts.add([
          a.surah,
          a.ayah,
          [
            for (var w = 0; w < a.words.length; w++)
              if (shared[k][offset + w]) w,
          ],
        ]);
        offset += a.words.length;
      }
      occurrences.add(parts);
    }
    out.add(occurrences);
  }

  File('assets/data/mutashabihat.json').writeAsStringSync(jsonEncode({
    'source': 'Quran Mutashabihat Data (Waqar144, CC0), after Qari Idrees '
        'Al-Asim — https://github.com/Waqar144/Quran_Mutashabihat_Data',
    'groups': out,
  }));
  final places = out.fold<int>(0, (n, g) => n + g.length);
  stdout.writeln('mutashabihat.json: ${out.length} groups, $places places');
}

/// Marks in [mark] the words of [a] that belong to a run of at least two
/// consecutive words also found, in the same order, in [b] (via LCS).
void _markCommonRuns(List<String> a, List<String> b, List<bool> mark) {
  final n = a.length, m = b.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final matched = List<bool>.filled(n, false);
  final pairedWith = List<int>.filled(n, -1);
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      matched[i] = true;
      pairedWith[i] = j;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  // Keep runs: consecutive in a and in b.
  for (var k = 0; k < n; k++) {
    if (!matched[k]) continue;
    final prev = k > 0 && matched[k - 1] && pairedWith[k - 1] == pairedWith[k] - 1;
    final next =
        k + 1 < n && matched[k + 1] && pairedWith[k + 1] == pairedWith[k] + 1;
    if (prev || next) mark[k] = true;
  }
}

/// Letters only, with hamza seats, alef forms and final ya / ta marbuta
/// unified, so spelling and vowel marks do not hide a shared word.
String _skeleton(String word) {
  final b = StringBuffer();
  for (final c in word.runes) {
    final ch = String.fromCharCode(c);
    if (c == 0x0671 || ch == 'أ' || ch == 'إ' || ch == 'آ') {
      b.write('ا');
    } else if (ch == 'ى' || ch == 'ئ') {
      b.write('ي');
    } else if (ch == 'ؤ') {
      b.write('و');
    } else if (ch == 'ة') {
      b.write('ه');
    } else if (c >= 0x0621 && c <= 0x064A && ch != 'ء') {
      b.write(ch);
    }
  }
  return b.toString();
}
