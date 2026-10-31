// Complete Warsh text, aligned onto the existing Hafs pages and word anchors.
// It is deliberately independent of the book's margin/annotation data.
import 'dart:convert';
import 'dart:io';

import 'build_data.dart' show HafsWord, sourceWords, alignSourceWords;

Map<String, Object> buildWarshText(Map base, List<Map> source) {
  final ayahs = base['ayahs'] as List;
  final out = <List<Object>>[];
  for (var s = 1; s <= 114; s++) {
    final sourceText = source
        .where((a) => a['sura_no'] == s)
        // The source export joins نأى and بجانبه at Fussilat 41:51.
        // Restore that word boundary without changing a letter or vowel.
        .expand(
          (a) => sourceWords(
            (a['aya_text'] as String).replaceAll(
              'ابِجَانِبِهِ',
              'ا بِجَانِبِهِ',
            ),
          ),
        )
        .toList();
    final anchors = <HafsWord>[
      for (final a in ayahs.where((a) => a[0] == s))
        for (final (w, text) in (a[4] as String).split(' ').indexed)
          HafsWord(s, a[1] as int, w, text),
    ];
    // Warsh's Madani verse numbering does not count the Fatiha basmala.
    if (s == 1) {
      sourceText.insertAll(
        0,
        anchors.takeWhile((w) => w.ayah == 1).map((w) => w.text),
      );
    }
    final slots = alignSourceWords(anchors, sourceText);
    if (slots.where((w) => w.isNotEmpty).join(' ') != sourceText.join(' ')) {
      throw StateError('Source text changed while aligning surah $s');
    }
    var start = 0;
    while (start < anchors.length) {
      var end = start + 1;
      while (end < anchors.length && anchors[end].ayah == anchors[start].ayah) {
        end++;
      }
      out.add([
        s,
        anchors[start].ayah,
        [
          for (var i = start; i < end; i++)
            withKafMaddApart(
              withHafsHamzaAbove(
                withHafsDaggerAlif(slots[i], anchors[i].text),
                anchors[i].text,
              ),
            ),
        ],
      ]);
      start = end;
    }
  }
  return {
    'riwaya': 'warsh',
    'source': 'KFGQPC warshData_v10.json; complete source text aligned to Hafs anchors',
    'ayahs': out,
  };
}

void main() {
  final base =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final source = (jsonDecode(
    File('../tools/source/warshData_v10.json')
        .readAsStringSync()
        .replaceFirst('\uFEFF', ''),
  ) as List).cast<Map>();
  final data = buildWarshText(base, source);
  File('assets/data/reading_texts/warsh.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(data));
  stdout.writeln(
    'Complete Warsh text: ${(data['ayahs'] as List).length} Hafs-anchored ayahs; all 114 surahs round-trip exactly.',
  );
}

final _mark = RegExp('[ً-ٰٟۖ-ۭـ]');

List<String> _clusters(String s) {
  final out = <String>[];
  for (final c in s.split('')) {
    if (_mark.hasMatch(c) && out.isNotEmpty) {
      out[out.length - 1] += c;
    } else if (!_mark.hasMatch(c)) {
      out.add(c);
    }
  }
  return out;
}

/// Where Hafs's rasm writes a dagger alif (إِسۡرَٰٓءِيلَ، فَأَحۡيَٰكُمۡ، قَٰلَ) and
/// the source a full one in the same word, the dagger alif is written, with
/// the alif's own marks (its madd) after it.
String withHafsDaggerAlif(String warsh, String hafs) {
  if (!hafs.contains('ٰ') || warsh.isEmpty) return warsh;
  // Hafs's letters, a dagger alif counted as the alif it stands for.
  final h = <String>[];
  for (final c in _clusters(hafs)) {
    if (c.contains('ٰ') && c[0] != 'ا') {
      h
        ..add(c.replaceAll('ٰ', ''))
        ..add('ٰ');
    } else {
      h.add(c);
    }
  }
  final w = _clusters(warsh);
  if (w.length != h.length) return warsh;
  String base(String c) => c[0].replaceAll(RegExp('[ٱأإآ]'), 'ا');
  final dagger = <int>{};
  for (var i = 0; i < h.length; i++) {
    if (h[i] == 'ٰ' && w[i][0] == 'ا' && i > 0) {
      dagger.add(i);
    } else if (base(h[i]) != base(w[i]) &&
        !(RegExp('[يى]').hasMatch(h[i][0]) &&
            RegExp('[يى]').hasMatch(w[i][0]))) {
      return warsh;
    }
  }
  if (dagger.isEmpty) return warsh;
  final out = <String>[];
  for (var i = 0; i < w.length; i++) {
    if (dagger.contains(i)) {
      out[out.length - 1] += 'ٰ${w[i].substring(1)}';
    } else {
      out.add(w[i]);
    }
  }
  return out.join();
}

/// The source writes the hamza on a kashida below it, with the kasra
/// (خَٰسِـِٕينَ، أَفْـِٕدَةٗ); where Hafs's rasm writes it above (خَٰسِـِٔينَ) it is
/// written above, the kasra under the kashida as usual.
String withHafsHamzaAbove(String warsh, String hafs) =>
    hafs.contains('ـِٔ') || hafs.contains('ـِٔ')
    ? warsh.replaceAll('ـِٕ', 'ـِٔ')
    : warsh;

/// The dagger alif with its madd on a kashida after the kaf of مِيكَٰٓئِلَ:
/// over the kaf's own stroke the madd stood apart from the alif.
String withKafMaddApart(String warsh) => warsh.replaceAll('كَٰٓ', 'كَـٰٓ');
