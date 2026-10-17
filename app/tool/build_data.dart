// Builds the app's data assets from the KFGQPC riwayat texts.
//
//   dart run tool/build_data.dart [sourceDir]
//
// sourceDir defaults to ../tools/source and must contain the KFGQPC JSON
// files (hafsData_v18.json, warshData_v10.json, ...).
//
// Output:
//   assets/data/quran.json            Hafs base text (pages, surahs, ayahs, words)
//   assets/data/qiraat/<riwaya>.json  word-level differences against Hafs
//
// The riwayat texts use different ayah numbering (Madani/Basri/Makki/Kufi)
// and different spelling conventions, so they are aligned against Hafs word by
// word per surah and compared on a normalised form that ignores pure
// orthography (sukun shapes, wasl alef, waqf signs, tanween placement, ...).
import 'dart:convert';
import 'dart:io';

/// riwaya id -> source file name.
const sources = {
  'warsh': 'warshData_v10.json',
  'qalun': 'QaloonData_v10.json',
  'bazzi': 'BazziData_v07.json',
  'qunbul': 'QumbulData_v07.json',
  'duri_abuamr': 'DooriData_v09.json',
  'susi': 'SoosiData09.json',
  'shubah': 'ShoubaData08.json',
};

const fontOf = {
  'warsh': 'Warsh',
  'qalun': 'Qaloon',
  'bazzi': 'Bazzi',
  'qunbul': 'Qumbul',
  'duri_abuamr': 'Doori',
  'susi': 'Soosi',
  'shubah': 'Shouba',
};

void main(List<String> args) {
  final srcDir = args.isNotEmpty ? args[0] : '../tools/source';
  final hafs = _load('$srcDir/hafsData_v18.json');
  final base = _buildBase(hafs);
  File('assets/data/quran.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(base.toJson()));
  stdout.writeln('quran.json: ${base.ayahs.length} ayahs');

  for (final MapEntry(key: id, value: file) in sources.entries) {
    final rows = _load('$srcDir/$file');
    final variants = <List<Object>>[];
    final counts = <String, int>{};
    for (var s = 1; s <= 114; s++) {
      final h = base.surahWords(s);
      final r = rows
          .where((x) => x['sura_no'] == s)
          .expand((x) => _words(x['aya_text'] as String))
          .toList();
      // Riwayat that do not count the basmala as an ayah of Al-Fatiha still
      // recite it; their text simply starts at ٱلۡحَمۡدُ.
      if (s == 1 && norm(r.first).loose != norm(h.first.text).loose) {
        r.insertAll(0, h.takeWhile((w) => w.ayah == 1).map((w) => w.text));
      }
      for (final v in _diffSurah(s, h, r)) {
        variants.add(v);
        counts[v[5] as String] = (counts[v[5]] ?? 0) + 1;
      }
    }
    File('assets/data/qiraat/$id.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'riwaya': id,
        'font': fontOf[id],
        'source': 'KFGQPC $file',
        'variants': variants,
      }));
    stdout.writeln('$id: ${variants.length} variants $counts');
  }
}

List<Map<String, dynamic>> _load(String path) {
  final text = File(path).readAsStringSync().replaceFirst('﻿', '');
  return (jsonDecode(text) as List).cast<Map<String, dynamic>>();
}

final _ayahNumber = RegExp(r'^[٠-٩]+$');

/// Splits an ayah into words, dropping the ayah-number token and stand-alone
/// symbols (rub' al-hizb, sajda).
List<String> _words(String text) => text
    .split(RegExp(r'[  ]+'))
    .map((w) => w.trim())
    .where((w) =>
        w.isNotEmpty &&
        !_ayahNumber.hasMatch(w) &&
        w != '۞' &&
        w != '۩')
    .toList();

// ---------------------------------------------------------------------------
// Base text

class HafsWord {
  HafsWord(this.surah, this.ayah, this.index, this.text);
  final int surah, ayah, index;
  final String text;
}

class Base {
  final ayahs = <Map<String, Object>>[];
  final surahs = <Map<String, Object>>[];
  final _words = <int, List<HafsWord>>{};

  List<HafsWord> surahWords(int s) => _words[s]!;

  Map<String, Object> toJson() => {
        'source': 'KFGQPC Hafs v18 (Madinah mushaf, 604 pages)',
        'surahs': surahs,
        // [surah, ayah, page, juz, "word word ..."]
        'ayahs': ayahs
            .map((a) => [a['s']!, a['a']!, a['p']!, a['j']!, a['t']!])
            .toList(),
      };
}

Base _buildBase(List<Map<String, dynamic>> rows) {
  final b = Base();
  for (final r in rows) {
    final s = r['sora'] as int, a = r['aya_no'] as int;
    final words = _words(r['aya_text'] as String);
    b.ayahs.add({
      's': s,
      'a': a,
      'p': r['page'] as int,
      'j': r['jozz'] as int,
      't': words.join(' '),
    });
    final list = b._words.putIfAbsent(s, () => []);
    for (var i = 0; i < words.length; i++) {
      list.add(HafsWord(s, a, i, words[i]));
    }
    if (a == 1) {
      b.surahs.add({
        'n': s,
        'ar': (r['sora_name_ar'] as String).trim(),
        'en': (r['sora_name_en'] as String).trim(),
        'page': r['page'] as int,
      });
    }
  }
  for (final s in b.surahs) {
    s['ayahs'] = rows.where((r) => r['sora'] == s['n']).length;
  }
  return b;
}

// ---------------------------------------------------------------------------
// Normalisation

const _fatha = 0x064E, _damma = 0x064F, _kasra = 0x0650, _shadda = 0x0651;
const _dagger = 0x0670;

/// Marks dropped entirely: sukun shapes, silent-letter zeros, waqf signs,
/// tatweel, iqlab meem, joiners.
const _ignored = {
  0x0652, 0x06E1, 0x06DF, 0x06E0, 0x06E2, //
  0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DD, 0x06DE,
  0x06E9, 0x0640, 0x200C, 0x200D, 0x200E, 0x200F,
};

/// Tanween shapes -> canonical tanween (placement differs between texts).
const _tanween = {
  0x064B: 'an', 0x0657: 'an', 0x064C: 'un', 0x065E: 'un', //
  0x064D: 'in', 0x0656: 'in',
};

/// Recitation marks: madd, imala/taqlil, tasheel/ishmam.
const _recitationMarks = {0x0653, 0x06E4, 0x06EA, 0x065C, 0x06ED, 0x06EC};

/// Small letters that are pronounced (silah, small noon).
const _smallLetters = {0x06E5: 'و', 0x06E6: 'ي', 0x06E7: 'ي', 0x06E8: 'ن'};

bool _isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) ||
    c == _dagger ||
    (c >= 0x06D6 && c <= 0x06ED && !(c >= 0x06E5 && c <= 0x06E6)) ||
    c == 0x0640 ||
    (c >= 0x200C && c <= 0x200F);

class Norm {
  Norm(this.loose, this.letters, this.noHamza, this.vowels, this.marks);

  /// Alignment key: letters without alef or hamza.
  final String loose;

  /// Letters (hamza seats kept), wasl alef as plain alef.
  final String letters;

  /// [letters] with hamza removed / seats reduced to their carrier letter.
  final String noHamza;

  /// Vowels, shadda and pronounced small letters, per letter + tanween.
  final String vowels;

  /// Madd / imala / tasheel marks (order-insensitive).
  final String marks;
}

final _normCache = <String, Norm>{};

Norm norm(String word) => _normCache.putIfAbsent(word, () => _norm(word));

Norm _norm(String word) {
  // Group into base letter + its marks.
  final groups = <(String, List<int>)>[];
  for (final c in word.runes) {
    if (_smallLetters.containsKey(c)) {
      groups.add((_smallLetters[c]!, []));
    } else if (_isMark(c) || c == 0x0654 || c == 0x0655) {
      if (groups.isEmpty) groups.add(('', []));
      groups.last.$2.add(c);
    } else {
      groups.add((String.fromCharCode(c), []));
    }
  }

  // Index of the lam whose marks are pure spelling: the article lam after a
  // wasl alef, and the doubled lam of لِلَّهِ / لِلَّذِينَ.
  final bare = groups.map((g) => g.$1).join();
  final prefix = RegExp('^[وفبك]?').firstMatch(bare)![0]!.length;
  int? spellingLam;
  if (bare.startsWith('لل', prefix)) spellingLam = prefix + 1;

  final letters = StringBuffer();
  final vowels = StringBuffer();
  final tanween = <String>[];
  final marks = <int>[];
  var wasl = false;
  for (var i = 0; i < groups.length; i++) {
    var (ch, ms) = groups[i];
    ms = ms.where((m) => !_ignored.contains(m)).toList();
    switch (ch) {
      case 'ے' || 'ى':
        ch = 'ي';
    }
    // Hamzat al-wasl: ٱ in eastern texts; a plain alef (often with the
    // starting vowel and a marker) in the Maghribi-style texts.
    final isWasl = ch == 'ٱ' ||
        (ch == 'ا' &&
            (i == prefix ||
                ms.contains(0x06EC) ||
                ms.contains(0x06DF)));
    if (isWasl) {
      ch = 'ا';
      ms = [];
    }
    if (ch == 'ل' && (wasl || i == spellingLam)) ms = [];
    wasl = isWasl;

    // Small high seen: on sad it means "read as seen", elsewhere it is saktah.
    if (ms.contains(0x06DC)) {
      ms = ms.where((m) => m != 0x06DC).toList();
      if (ch == 'ص') {
        ch = 'س';
      } else {
        marks.add(0x06DC);
      }
    }
    if (ms.contains(_dagger) && !ms.contains(_fatha)) ms.add(_fatha);
    if (ms.any((m) => m == 0x06EA || m == 0x06ED || m == 0x065C) &&
        !ms.any((m) => m == _fatha || m == _damma || m == _kasra)) {
      ms.add(_fatha); // imala / taqlil replaces the written fatha
    }

    for (final m in ms) {
      if (m == 0x0654 || m == 0x0655) ch = '$chء';
    }
    letters.write(ch);
    final v = <int>[];
    for (final m in ms) {
      if (_tanween.containsKey(m)) {
        tanween.add(_tanween[m]!);
      } else if (_recitationMarks.contains(m)) {
        marks.add(m);
      } else if (m == _shadda && i == 0) {
        marks.add(m); // idgham with the previous word
      } else if (m == _fatha || m == _damma || m == _kasra || m == _shadda) {
        v.add(m);
      }
    }
    v.sort();
    vowels
      ..write(ch)
      ..write(String.fromCharCodes(v));
    if (ms.contains(_dagger)) {
      letters.write('ا');
      vowels.write('ا');
    }
  }
  tanween.sort();
  marks.sort();
  final l = letters.toString();
  final noHamza = l
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ء', '');
  final loose = noHamza.replaceAll('ا', '').replaceAll('ى', 'ي');
  return Norm(loose, l, noHamza, '$vowels|${tanween.join()}',
      String.fromCharCodes(marks));
}

/// 'f' letters/vowels, 'h' hamza only, 'u' madd/imala/tasheel marks only,
/// null when the words read the same.
String? classify(String hafs, String other) {
  // Muqatta'at (الٓمٓ, حمٓ, ...) are spelled differently in each text but read
  // alike; only imala / taqlil marks distinguish the riwayat.
  if (_muqattaat.hasMatch(hafs)) {
    String imala(String w) => w.runes
        .where((c) => c == 0x06EA || c == 0x06ED || c == 0x065C)
        .length
        .toString();
    return imala(hafs) == imala(other) ? null : 'u';
  }
  final a = norm(hafs), b = norm(other);
  if (a.letters == b.letters && a.vowels == b.vowels) {
    return a.marks == b.marks ? null : 'u';
  }
  if (a.letters != b.letters && a.noHamza == b.noHamza) return 'h';
  // Silat mim al-jam' / ha' al-kinaya (لَهُمۡ ↔ لَهُمُۥ) is an usul rule.
  if (_hasSilah(hafs) != _hasSilah(other)) {
    final x = norm(_dropSilah(hafs)), y = norm(_dropSilah(other));
    if (x.letters == y.letters && x.vowels == y.vowels) return 'u';
  }
  return 'f';
}

/// [classify] plus two cross-word rules that only show at the word's end:
/// naql (the vowel of a dropped hamza moves onto this word) and idgham
/// kabir (this word's last vowel is dropped into the next word).
String? _classifyInContext(List<HafsWord> h, List<String> r, int i, int j) {
  final c = classify(h[i].text, r[j]);
  if (c != 'f') return c;
  final a = _stripWaqf(h[i].text), b = _stripWaqf(r[j]);
  final ea = _finalVowel.firstMatch(a)?[0] ?? '';
  final eb = _finalVowel.firstMatch(b)?[0] ?? '';
  if (classify(a.substring(0, a.length - ea.length),
          b.substring(0, b.length - eb.length)) !=
      null) {
    return c;
  }
  final vowelA = ea.contains(RegExp('[َُِ]'));
  final vowelB = eb.contains(RegExp('[َُِ]'));
  if (vowelA && eb.isEmpty) return 'u';
  if (!vowelA && vowelB && i + 1 < h.length && j + 1 < r.length) {
    final hamzaInHafs = RegExp('^[وف]?[أإآء]').hasMatch(h[i + 1].text);
    if (hamzaInHafs && norm(r[j + 1]).letters == norm(r[j + 1]).noHamza) {
      return 'h';
    }
  }
  return c;
}

/// A word of letter names: maddah but no vowel at all (الٓمٓ, حمٓ, كٓهيعٓصٓ).
final _muqattaat = RegExp(
    '^(?=.*ٓ)[^ً-ِْٖٗٞۡ]+\$');

final _silah = RegExp('[ۥۦۧ][ٓۤ]?\$');
final _finalVowel = RegExp('[َُِْۡ]+\$');

bool _hasSilah(String w) => _silah.hasMatch(_stripWaqf(w));

String _dropSilah(String w) =>
    _stripWaqf(w).replaceFirst(_silah, '').replaceFirst(_finalVowel, '');

String _stripWaqf(String w) =>
    w.replaceAll(RegExp('[ۖ-ۜٓ]+\$'), '');

// ---------------------------------------------------------------------------
// Alignment

/// Returns variants as [surah, ayah, wordIndex, wordCount, text, category].
List<List<Object>> _diffSurah(int surah, List<HafsWord> h, List<String> r) {
  final a = h.map((w) => norm(w.text).loose).toList();
  final b = r.map((w) => norm(w).loose).toList();
  final out = <List<Object>>[];

  void emit(int hi, int hj, int ri, int rj) {
    // Hafs span [hi, hj) is read as riwaya span [ri, rj).
    if (hj - hi == rj - ri) {
      for (var k = 0; k < hj - hi; k++) {
        final c = _classifyInContext(h, r, hi + k, ri + k);
        if (c != null) {
          final w = h[hi + k];
          out.add([w.surah, w.ayah, w.index, 1, r[ri + k], c]);
        }
      }
      return;
    }
    // Same words, only split differently (أَوَلَمۡ / أَوَ لَمۡ).
    if (hi < hj &&
        ri < rj &&
        h[hi].ayah == h[hj - 1].ayah &&
        classify(h.sublist(hi, hj).map((w) => w.text).join(),
                r.sublist(ri, rj).join()) ==
            null) {
      return;
    }
    if (hi == hj) {
      // Pure insertion: attach to the preceding Hafs word (or the next one at
      // the start of a surah).
      if (hi > 0) {
        final w = h[hi - 1];
        out.add([
          w.surah, w.ayah, w.index, 1, //
          [r[ri - 1], ...r.sublist(ri, rj)].join(' '), 'f'
        ]);
      } else {
        final w = h[0];
        out.add([
          w.surah, w.ayah, 0, 1, //
          [...r.sublist(ri, rj), r[rj]].join(' '), 'f'
        ]);
      }
      return;
    }
    // Unequal spans: one variant per ayah; the first carries the whole
    // riwaya text, the following ones are read as part of it.
    var start = hi;
    while (start < hj) {
      var end = start;
      while (end < hj && h[end].ayah == h[start].ayah) {
        end++;
      }
      final text = start == hi ? r.sublist(ri, rj).join(' ') : '';
      final w = h[start];
      out.add([w.surah, w.ayah, w.index, end - start, text, 'f']);
      start = end;
    }
  }

  var hi = 0, ri = 0;
  for (final (i, j) in _lcs(a, b)) {
    if (i > hi || j > ri) emit(hi, i, ri, j);
    emit(i, i + 1, j, j + 1);
    hi = i + 1;
    ri = j + 1;
  }
  if (hi < h.length || ri < r.length) emit(hi, h.length, ri, r.length);
  return out;
}

/// Myers O(ND) diff; returns matched index pairs in order.
List<(int, int)> _lcs(List<String> a, List<String> b) {
  final n = a.length, m = b.length, max = n + m;
  final v = List<int>.filled(2 * max + 2, 0);
  final trace = <List<int>>[];
  outer:
  for (var d = 0; d <= max; d++) {
    trace.add(List.of(v));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[max + k - 1] < v[max + k + 1]))
          ? v[max + k + 1]
          : v[max + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && a[x] == b[y]) {
        x++;
        y++;
      }
      v[max + k] = x;
      if (x >= n && y >= m) break outer;
    }
  }
  final pairs = <(int, int)>[];
  var x = n, y = m;
  for (var d = trace.length - 1; d >= 0; d--) {
    final vv = trace[d];
    final k = x - y;
    final prevK = (k == -d || (k != d && vv[max + k - 1] < vv[max + k + 1]))
        ? k + 1
        : k - 1;
    final prevX = d == 0 ? 0 : vv[max + prevK];
    final prevY = prevX - prevK;
    while (x > prevX && y > prevY) {
      x--;
      y--;
      pairs.add((x, y));
    }
    if (d > 0) {
      x = prevX;
      y = prevY;
    }
  }
  return pairs.reversed.toList();
}
