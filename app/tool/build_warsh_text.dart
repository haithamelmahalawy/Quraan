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
            withHafsYaAlif(
              withHafsMuqattaat(
                withHafsStops(
                  withHafsForms(
                    withSmallNunApart(
                      withLowIqlab(
                        withNaqisIdgham(
                          withEasedAlifDagger(
                            withYaDaggerApart(
                              withNaqlDamma(
                                withKafMaddApart(
                                  withHafsHamzaAbove(
                                    withHafsFullAlif(
                                      withHafsLamShadda(
                                        withSakinHamzaAlif(
                                          withHafsDaggerAlif(
                                            slots[i],
                                            anchors[i].text,
                                          ),
                                          anchors[i].text,
                                        ),
                                        anchors[i].text,
                                      ),
                                      anchors[i].text,
                                    ),
                                    anchors[i].text,
                                  ),
                                ),
                                anchors[i].text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    anchors[i].text,
                  ),
                  anchors[i].text,
                ),
                anchors[i].text,
              ),
              anchors[i].text,
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

/// Where the source writes a dagger alif and Hafs's rasm a full one in the
/// same word (ٱلۡعِظَٰمَ for ٱلۡعِظَامَ), the full alif is written, with the
/// marks the dagger alif carried (its madd): a dagger alif only stands for
/// an alif Hafs's rasm has as one, or adds to it.
String withHafsFullAlif(String warsh, String hafs) {
  if (!warsh.contains('ٰ')) return warsh;
  // The source's letters, a dagger alif after its letter counted apart.
  final w = <String>[];
  for (final c in _clusters(warsh)) {
    final at = c.indexOf('ٰ');
    if (at > 0 && c[0] != 'ا' && c[0] != 'ـ') {
      w
        ..add(c.substring(0, at))
        ..add(c.substring(at));
    } else {
      w.add(c);
    }
  }
  final h = _clusters(hafs);
  String base(String c) => c[0].replaceAll(RegExp('[ٱأإآ]'), 'ا');
  bool same(String a, String b) =>
      base(a) == base(b) ||
      RegExp('[يى]').hasMatch(a[0]) && RegExp('[يى]').hasMatch(b[0]);
  // In step with Hafs's letters; a dagger alif opposite none of his is
  // one he does not write (the second alif of رِسَٰلَٰتِهِۦ): it stays.
  final full = <int>{};
  var j = 0;
  for (var i = 0; i < w.length; i++) {
    if (w[i].startsWith('ٰ')) {
      if (j < h.length && h[j][0] == 'ا' && !h[j].contains('ٰ')) {
        full.add(i);
        j++;
      }
      continue;
    }
    if (j >= h.length || !same(h[j], w[i])) return warsh;
    j++;
  }
  if (j != h.length) return warsh;
  if (full.isEmpty) return warsh;
  return [
    for (var i = 0; i < w.length; i++)
      full.contains(i) ? 'ا${w[i].substring(1)}' : w[i],
  ].join();
}

/// The source writes the hamza on a kashida below it, with the kasra
/// (خَٰسِـِٕينَ، أَفْـِٕدَةٗ); where Hafs's rasm writes it above (خَٰسِـِٔينَ) it is
/// written above, the kasra under the kashida as usual.
String withHafsHamzaAbove(String warsh, String hafs) =>
    hafs.contains('ـِٔ') || hafs.contains('ـِٔ')
    ? warsh.replaceAll('ـِٕ', 'ـِٔ')
    : warsh;

/// The alif of a hamza with damma whose vowel goes to the word before
/// (فَإِنُ اُحْصِرْتُمْ): the source marks it unread (ا۟), but the alif takes
/// the damma, as it takes the fatha and kasra (قَدَ اَفْلَحَ، قُلِ اِنَّ).
String withNaqlDamma(String warsh, String hafs) =>
    RegExp('^[أإ]').hasMatch(hafs) && RegExp('^ا۟(?![ً-ْ])').hasMatch(warsh)
    ? 'اُ${warsh.substring(2)}'
    : warsh;

/// The stop signs of the Madinah mushaf, Hafs's at this word (يَسْمَعُونَۘ):
/// the source has one sign for every stop of the Maghribi print (ۖ), at
/// each ayah's end too.
/// The sakin hamza after a fatha read as an alif, where Hafs seats it on an
/// alif (يَسۡتَأۡخِرُونَ read يَسْتَاخِرُونَ): a full alif in the word, where the
/// source writes a dagger one on the letter before. Seated on a kashida
/// (يَسۡتَـٔۡخِرُونَ) Hafs's rasm has no alif, and the dagger one stays.
String withSakinHamzaAlif(String warsh, String hafs) {
  final m = RegExp(r'(\S)َأۡ').firstMatch(hafs);
  // Not where the source writes that alif in full already, and the dagger
  // alif is Hafs's own (يَاتِيَٰنِهَا).
  if (m == null || warsh.contains('${m[1]}َا')) return warsh;
  return warsh.replaceFirst('${m[1]}َٰ', '${m[1]}َا');
}

/// The lam of the article written once for two (ٱلَّذِينَ، ٱلَّيۡلِ): the
/// Madinah rasm marks it with the shadda and its fatha, where the Maghribi
/// source writes it bare (اَ۬لذِينَ).
String withHafsLamShadda(String warsh, String hafs) {
  final h = _clusters(hafs), w = _clusters(warsh);
  int? lamAfterAlif(List<String> cs, String alif) {
    for (var i = 1; i < cs.length && i < 4; i++) {
      if (cs[i].startsWith('ل') && cs[i - 1].startsWith(alif)) return i;
    }
    return null;
  }

  final hi = lamAfterAlif(h, 'ٱ'), wi = lamAfterAlif(w, 'ا');
  if (hi == null ||
      wi == null ||
      !h[hi].contains('ّ') ||
      w[wi].contains('ّ') ||
      hi + 1 >= h.length ||
      wi + 1 >= w.length ||
      h[hi + 1][0] != w[wi + 1][0]) {
    return warsh;
  }
  w[wi] = h[hi];
  return w.join();
}

/// The question's two hamzas with the alif after them (ءَآمَنتُمۡ): the
/// second eased, marked as the Madinah mushaf marks it (ءَا۬), and the
/// alif after it a dagger alif before the mim, not on the eased alif.
String withEasedAlifDagger(String warsh) => warsh.replaceAll('ءَاٰ۬', 'ءَا۬ـٰ');

String withHafsStops(String warsh, String hafs) {
  final stops = RegExp('[ۖ-ۛ]');
  return warsh.replaceAll(stops, '') +
      stops.allMatches(hafs).map((m) => m[0]).join();
}

/// Words read as Hafs reads them, written as his rasm writes them: the
/// small ya after the doubled one (وَلِـِّۧيَ for the source's وَلِيِّيَ), and
/// the alif of أَنَا۠ not read in wasl with its rectangular zero, where the
/// source writes it bare (أَنَا before إِلَّا); read with the madd before a
/// hamza (أَنَآ), it stays.
String withHafsForms(String warsh, String hafs) {
  // The small ya counted as the letter it is, before the marks go.
  String bare(String s) => s
      .replaceAll('\u06E7', 'ي')
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '');
  // With the same doubling: not where the source marks an idgham Hafs's
  // word does not (مَن يُّحْيِ).
  int shaddas(String s) => '\u0651'.allMatches(s).length;
  if (hafs.contains('\u06E7') &&
      bare(warsh) == bare(hafs) &&
      shaddas(warsh) == shaddas(hafs)) {
    return hafs.replaceAll(RegExp('[ۖ-ۛ]'), '');
  }
  if (hafs.contains('نَا۠') && warsh.endsWith('نَا')) {
    return '$warsh۠';
  }
  // The ya Warsh adds to حَيَّ (حَيِيَ) small on its tooth, as Hafs writes
  // يُحۡـِۧيَ: حَـِۧيَ.
  if (warsh == 'حَيِيَ') return 'حَـِۧيَ';
  // تِلۡقَآيِٕ (يونس 15), read as Hafs reads it: written as he writes it, not
  // the source's تِلْقَآءِےْ with its seat ya after the hamza.
  if (hafs.startsWith('تِلۡقَآيٕ')) {
    return hafs.replaceAll(RegExp('[ۖ-ۛ]'), '');
  }
  // So too وَإِيتَآيِٕ، وَرَآيِٕ، ءَانَآيِٕ: the hamza on Hafs's ya, not the
  // source's ya after it, which reads as an added ya.
  const seat = '\u0627\u0653\u064a\u0655\u0650';
  const after = '\u0627\u0653\u0621\u0650\u06d2\u0652';
  if (hafs.endsWith(seat) && warsh.endsWith(after)) {
    return warsh.substring(0, warsh.length - after.length) + seat;
  }
  // لِيَسُـۥٓـُٔواْ (الإسراء 7): after the sin the small waw of the madd with
  // its madd sign, then the hamza on the kashida between the sin and the
  // waw, near the waw; the source follows Hafs's لِيَسُـُٔواْ.
  if (warsh ==
      '\u0644\u0650\u064a\u064e\u0633\u064f\u0640\u0654\u064f\u0648\u0627\u0652') {
    return '\u0644\u0650\u064a\u064e\u0633\u064f\u0640\u06e5\u0653\u0640\u0640\u0654\u064f'
        '\u0648\u0627\u0652';
  }
  // ٱلشَّفَٰعَةَ (مريم 87، طه 109، سبأ 23): the sun letter doubled as Hafs
  // writes it; the source leaves the shin bare (اَ۬لشَفَٰعَةَ).
  if (hafs.contains('\u0644\u0634\u0651\u064e\u0641\u064e\u0670\u0639') &&
      warsh.contains('\u0644\u0634\u064e\u0641\u064e\u0670\u0639')) {
    return warsh.replaceFirst('\u0644\u0634\u064e', '\u0644\u0634\u0651\u064e');
  }
  // يَصْل۪يٰهَا (الإسراء 18) with the taqlil the hamesh tells beside the
  // source's taghliz (يَصْلَيٰهَا): either face may be read.
  if (warsh ==
      '\u064a\u064e\u0635\u0652\u0644\u064e\u064a\u0670\u0647\u064e\u0627') {
    return '\u064a\u064e\u0635\u0652\u0644\u06ea\u064a\u0670\u0647\u064e\u0627';
  }
  // The hamza over a lam-alif (لِأَبَآئِهِمۡ، لَأَيَةٗ) with its fatha, without
  // the source's madd, as Hafs's word is written.
  if (warsh.contains('أٓ') && hafs.contains('أَ')) {
    return warsh.replaceFirst('أٓ', 'أَ');
  }
  // The eased hamza of أَئِمَّةَ on its tooth, the easing dot in place of
  // the ya's two dots and the kasra under it: أَىِ۪مَّةَ.
  if (warsh == 'أَي۪مَّةَ') {
    return 'أَىِ۪مَّةَ';
  }
  // And the words the source writes with the hamza (أَئِمَّةٗ، أَئِنَّ، اَئِنَّكُمْ):
  // the same tooth and dot.
  final eased = RegExp('^[أا]َئِ').firstMatch(warsh);
  if (eased != null) {
    return '${warsh.substring(0, 2)}ىِ۪${warsh.substring(4)}';
  }
  return warsh;
}

/// The iqlab mim of a tanween with kasra under its letter (بِيسِۭ بِمَا), as
/// the Madinah rasm writes it; the source writes it above (ۢ).
String withLowIqlab(String warsh) => warsh.replaceAll('ِۢ', 'ِۭ');

/// The ta merged into after a ta' or za' keeping its emphasis (بَسَطتَ،
/// أَحَطتُ), written as the Madinah rasm writes it: the ta' without sukun,
/// the ta with its vowel only, not the source's shadda (بَسَطْتَّ).
String withNaqisIdgham(String warsh) => warsh.replaceAllMapped(
  RegExp('([طظ])[ْۡ]ت([ًٌٍَُِ]?)ّ([ًٌٍَُِ]?)'),
  (m) => '${m[1]}ت${m[2]}${m[3]}',
);

/// The dagger alif after a ya read with imala, on a kashida between it and
/// the next letter (دِي۪ـٰرِهِمْ): over the ya's own stroke the font stands it
/// on the ya, where Hafs's fatha (دِيَٰرِهِمۡ) moves it beside.
String withYaDaggerApart(String warsh) =>
    warsh.replaceAll(RegExp('يٰ۪(?=[ء-ي])'), 'ي۪ـٰ');

/// The dagger alif with its madd on a kashida after the kaf of مِيكَٰٓئِلَ:
/// over the kaf's own stroke the madd stood apart from the alif.
String withKafMaddApart(String warsh) => warsh.replaceAll('كَٰٓ', 'كَـٰٓ');

/// The small nun after a nun with damma (فَنُۨجِے), on a kashida beside the
/// damma as the Madinah rasm writes it (نُـۨجِي); the font sets it over the
/// damma.
String withSmallNunApart(String warsh) => warsh.replaceAll('نُۨ', 'نُـۨ');

/// The letters «الٓر» and «الٓمٓر» as the Madinah rasm writes them, with the
/// taqlil sign under the ra alone; the source writes them vowelled
/// (أَلَٓمِّٓر۪ۚ).
String withHafsMuqattaat(String warsh, String hafs) {
  if (RegExp(r'^الٓ(?:مٓ)?رۚ$').hasMatch(hafs) && warsh.contains('ر۪')) {
    return hafs.replaceFirst('ر', 'ر۪');
  }
  // The letters read as Hafs reads them (الٓمٓ، طسٓمٓ، يسٓ، صٓ): as he writes
  // them, without the source's vowels.
  final letters = hafs.replaceAll(RegExp('[\u06d6-\u06db]'), '');
  return RegExp(
        '^[\u0627\u0644\u0645\u0637\u0633\u064a\u0635\u0639\u0642\u0653]+\$',
      ).hasMatch(letters)
      ? hafs
      : warsh;
}

/// The ya with the alif after it as Hafs writes it (بِأَيَّىٰمِ), the source
/// writing two ya's (بِأَييَّٰمِ): the same reading.
String withHafsYaAlif(String warsh, String hafs) =>
    warsh.replaceAll(
          '\u064a\u064a\u0651\u064e\u0670',
          '\u064a\u0651\u064e\u0649\u0670',
        ) ==
        hafs
    ? hafs
    : warsh;
