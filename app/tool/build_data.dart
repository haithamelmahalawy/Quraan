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

import 'package:qiraat_mushaf/data/reading_normalization.dart';
export 'package:qiraat_mushaf/data/reading_normalization.dart'
    show Unit, Norm, norm, units;

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
    currentRiwaya = id;
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
      ..writeAsStringSync(
        jsonEncode({
          'riwaya': id,
          'font': fontOf[id],
          'source': 'KFGQPC $file',
          'variants': variants,
        }),
      );
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
    .where(
      (w) => w.isNotEmpty && !_ayahNumber.hasMatch(w) && w != '۞' && w != '۩',
    )
    .toList();

// ---------------------------------------------------------------------------
// Base text

/// The source's words without verse-number and standalone ornament tokens.
List<String> sourceWords(String text) => _words(text);

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

const _fatha = 0x064E, _damma = 0x064F, _kasra = 0x0650;

// ---------------------------------------------------------------------------
// Arabic description of a difference ("بالتاء", "بضم الهاء", ...)

const _letterNames = {
  'ا': 'الألف',
  'ب': 'الباء',
  'ت': 'التاء',
  'ث': 'الثاء',
  'ج': 'الجيم',
  'ح': 'الحاء',
  'خ': 'الخاء',
  'د': 'الدال',
  'ذ': 'الذال',
  'ر': 'الراء',
  'ز': 'الزاي',
  'س': 'السين',
  'ش': 'الشين',
  'ص': 'الصاد',
  'ض': 'الضاد',
  'ط': 'الطاء',
  'ظ': 'الظاء',
  'ع': 'العين',
  'غ': 'الغين',
  'ف': 'الفاء',
  'ق': 'القاف',
  'ك': 'الكاف',
  'ل': 'اللام',
  'م': 'الميم',
  'ن': 'النون',
  'ه': 'الهاء',
  'و': 'الواو',
  'ي': 'الياء',
  'ة': 'التاء',
  'ء': 'الهمزة',
};

String _name(Unit u) => _letterNames[u.letter] ?? u.letter;

/// Riwaya being processed; the same imala sign means taqlil in Nafi's texts.
var currentRiwaya = '';

String _imalaName(int mark) => switch (mark) {
  0x06ED => 'التقليل',
  0x06EA when currentRiwaya == 'warsh' || currentRiwaya == 'qalun' => 'التقليل',
  _ => 'الإمالة',
};

/// Describes how [other] differs from the Hafs word [hafs], e.g. "بالتاء",
/// "بحذف الألف", "بضم الهاء وصلة الميم". Empty when it cannot be put
/// briefly.
String describe(String hafs, String other) {
  if (other.isEmpty) return '';
  if (_muqattaat.hasMatch(hafs)) {
    final m = other.runes.where(
      (c) => c == 0x06EA || c == 0x06ED || c == 0x065C,
    );
    return m.isEmpty ? '' : 'ب${_imalaName(m.first)}';
  }
  final phrases = <String>[];
  var a = hafs, b = other;
  if (_hasSilah(a) != _hasSilah(b)) {
    final last = units(_dropSilah(_hasSilah(b) ? b : a)).last;
    final which = last.letter == 'م'
        ? 'ميم الجمع'
        : last.letter == 'ه'
        ? 'الهاء'
        : 'الياء الزائدة';
    // A ha read with sukun (يُؤَدِّهۡ) is told by the letters below
    // (إسكان الهاء), not as a silah left out.
    final sukun =
        !_hasSilah(b) &&
        which == 'الهاء' &&
        units(_stripWaqf(b)).last.vowel == null;
    // Replacing the pronoun in نِعَمَهُۥ → نِعْمَةً is not a sakin ha
    // or simply an omitted silah; the lexical replacement is described below.
    if (units(_dropSilah(a)).last.letter == units(_dropSilah(b)).last.letter) {
      phrases.add(
        which == 'الياء الزائدة'
            ? (_hasSilah(b) ? 'إثبات الياء الزائدة' : 'حذف الياء الزائدة')
            : sukun
            ? 'إسكان الهاء'
            : _hasSilah(b)
            ? 'صلة $which'
            : 'ترك صلة $which',
      );
    }
    a = _dropSilah(a);
    b = _dropSilah(b);
  }
  final ua = units(a), ub = units(b);

  // Align the letters (LCS on unit keys; hamza seats ignored so a hamza that
  // becomes its seat shows as a substitution).
  final n = ua.length, m = ub.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = ua[i].letter == ub[j].letter
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final removed = <Unit>[], added = <Unit>[];
  var removedAt = 0;
  void flushEdits() {
    for (var k = 0; k < removed.length || k < added.length; k++) {
      final x = k < removed.length ? removed[k] : null;
      final y = k < added.length ? added[k] : null;
      if (x != null && y != null) {
        if (x.letter == 'ء' && 'اوي'.contains(y.letter)) {
          final afterArticle =
              removedAt + k >= 2 &&
              ua[removedAt + k - 1].letter == 'ل' &&
              ua[removedAt + k - 2].letter == 'ا';
          phrases.add(
            afterArticle
                ? 'نقل حركة الهمزة إلى اللام'
                : y.letter == 'ا' && removedAt + k <= 3
                ? 'تخفيف الهمزة'
                : 'إبدال الهمزة ${const {'ا': 'ألفًا', 'و': 'واوًا', 'ي': 'ياءً'}[y.letter]}',
          );
        } else if (x.letter == 'ه' && y.letter == 'ة') {
          final ending = switch (y.tanween) {
            'an' => ' منونة بالفتح',
            'un' => ' منونة بالضم',
            'in' => ' منونة بالكسر',
            _ => '',
          };
          phrases.add('إبدال الهاء تاء مربوطة$ending');
        } else if (x.letter == 'ي' && y.letter == 'ء' && y.vowel == _damma) {
          phrases.add('إبدال الياء همزة مضمومة');
        } else if (y.letter == 'ء') {
          phrases.add('الهمز');
        } else {
          phrases.add(_name(y));
        }
      } else if (x != null) {
        phrases.add(x.letter == 'ء' ? 'حذف الهمزة' : 'حذف ${_name(x)}');
      } else if (y != null) {
        phrases.add(y.letter == 'ا' ? 'إثبات الألف' : 'زيادة ${_name(y)}');
      }
    }
    removed.clear();
    added.clear();
  }

  var mutedMadd = 0;
  var i = 0, j = 0;
  while (i < n || j < m) {
    if (i < n && j < m && ua[i].letter == ub[j].letter) {
      flushEdits();
      // A madd on a letter whose vowel changes goes with it (إِنِّيٓ → إِنِّيَ).
      if (_compareUnit(ua[i], ub[j], i, phrases, i > 0 ? ua[i - 1] : null)) {
        mutedMadd += _madd(ua[i]);
      }
      i++;
      j++;
    } else if (j < m && (i == n || dp[i][j + 1] >= dp[i + 1][j])) {
      added.add(ub[j++]);
    } else {
      if (removed.isEmpty) removedAt = i;
      removed.add(ua[i++]);
    }
  }
  flushEdits();

  final maddA = ua.fold(0, (s, u) => s + _madd(u)) - mutedMadd;
  final maddB = ub.fold(0, (s, u) => s + _madd(u));
  if (maddB < maddA) phrases.add('القصر');
  if (maddB > maddA) phrases.add('المد');

  if (_addsInterrogative(hafs, other)) {
    phrases.remove('فتح الهمزة');
    phrases.remove('زيادة الهمزة');
    phrases.insert(0, 'زيادة همزة استفهام');
  }
  final unique = phrases.toSet().toList();
  if (unique.isEmpty || unique.length > 4) return '';
  return 'ب${unique.join(' و')}';
}

int _madd(Unit u) => u.marks.where((k) => k == 0x0653 || k == 0x06E4).length;

/// Adds the differences between two aligned letters; returns true when the
/// vowel changed.
bool _compareUnit(Unit a, Unit b, int index, List<String> out, [Unit? before]) {
  final name = _name(a);
  if (index == 0 && b.shadda && !a.shadda) out.add('الإدغام');
  if (index > 0 && a.shadda && !b.shadda && b.vowel == null) {
    out.add('إسكان $name مخففة');
    return true;
  }
  // A sakin letter merged into this one (ٱتَّخَذۡتُمُ ↔ ٱتَّخَذتُّمُ): idgham.
  if (index > 0 &&
      b.shadda &&
      !a.shadda &&
      before != null &&
      before.vowel == null &&
      before.letter != a.letter &&
      'ذثدتطظضبلنرقك'.contains(before.letter)) {
    out.add('إدغام ${_name(before)} في $name');
    return false;
  }
  if (index > 0 && b.shadda != a.shadda) {
    out.add(b.shadda ? 'تشديد $name' : 'تخفيف $name');
  }
  var changed = false;
  if (a.tanween != b.tanween) {
    // مُوهِنُ ↔ مُوهِنٌ, ثَمُودَاْ ↔ ثَمُودًا, مُسَخَّرَٰتُ ↔ مُسَخَّرَٰتٍ.
    changed = true;
    out.add(switch (b.tanween) {
      'an' => 'تنوين $name بالفتح',
      'un' => 'تنوين $name بالضم',
      'in' => 'تنوين $name بالكسر',
      _ => switch (b.vowel) {
        _fatha => 'فتح $name دون تنوين',
        _damma => 'ضم $name دون تنوين',
        _kasra => 'كسر $name دون تنوين',
        _ => 'ترك تنوين $name',
      },
    });
    if (b.iqlab) out.add('الإقلاب');
  } else if (a.letter == 'ء' && a.seat != b.seat && a.vowel == b.vowel) {
    // Same hamza on another seat: spelling only.
  } else if (a.vowel != b.vowel && !(a.letter == 'ا' && b.vowel == null)) {
    changed = true;
    out.add(switch (b.vowel) {
      _fatha => 'فتح $name',
      _damma => 'ضم $name',
      _kasra => 'كسر $name',
      _ => 'إسكان $name',
    });
  }
  for (final mark in b.marks) {
    if (a.marks.contains(mark)) continue;
    // The small mim of iqlab under a tanween (ـِۭ), not an imala sign.
    if (mark == 0x06ED && b.tanween != null) continue;
    switch (mark) {
      case 0x06EA || 0x06ED || 0x065C:
        out.add(_imalaName(mark));
      case 0x06EC:
        out.add(a.letter == 'ء' || a.letter == 'ا' ? 'التسهيل' : 'الإشمام');
    }
  }
  return changed;
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
  // An interrogative hamza changes the word: farsh, rather than the
  // handling of a hamza already present (tasheel, ibdal, ...).
  if (_addsInterrogative(hafs, other) || _addsInterrogative(other, hafs)) {
    return 'f';
  }
  // تُرْجِي → تُرْجِئُ is lexical farsh, rather than applying a general
  // rule to a hamza already present in the Hafs word.
  if (a.noHamza == 'ترجي' && b.noHamza == 'ترجي' && a.letters != b.letters) {
    return 'f';
  }
  if (a.letters != b.letters && a.noHamza == b.noHamza) return 'h';
  // Silat mim al-jam' / ha' al-kinaya (لَهُمۡ ↔ لَهُمُۥ) is an usul rule.
  if (_hasSilah(hafs) != _hasSilah(other)) {
    final x = norm(_dropSilah(hafs)), y = norm(_dropSilah(other));
    if (x.letters == y.letters && x.vowels == y.vowels) return 'u';
  }
  return 'f';
}

bool _addsInterrogative(String original, String reading) {
  final a = units(original), b = units(reading);
  return a.isNotEmpty &&
      b.length == a.length + 1 &&
      a.first.letter == 'ء' &&
      b.first.letter == 'ء' &&
      b[1].letter == 'ء' &&
      a.map((u) => u.letter).join() == b.skip(1).map((u) => u.letter).join();
}

/// [classify] and [describe] plus two cross-word rules that only show at the
/// word's end: naql (the vowel of a dropped hamza moves onto this word) and
/// idgham kabir (this word's last vowel is dropped into the next word).
(String, String)? _classifyInContext(
  List<HafsWord> h,
  List<String> r,
  int i,
  int j,
) {
  final c = _plain(h[i].text, r[j]);
  if (c?.$1 != 'f') return c;
  final a = _stripWaqf(h[i].text), b = _stripWaqf(r[j]);
  final ea = _finalVowel.firstMatch(a)?[0] ?? '';
  final eb = _finalVowel.firstMatch(b)?[0] ?? '';
  if (classify(
        a.substring(0, a.length - ea.length),
        b.substring(0, b.length - eb.length),
      ) !=
      null) {
    return c;
  }
  final vowelA = ea.contains(RegExp('[َُِ]'));
  final vowelB = eb.contains(RegExp('[َُِ]'));
  if (vowelA && eb.isEmpty) {
    // Ya' al-idafa read with sukun (بَيۡتِيَ ↔ بَيۡتِيۡ, مَعِيَ ↔ مَعِيۡ): farsh,
    // not a vowel dropped into the next word.
    if (ea.startsWith('َ') &&
        a.substring(0, a.length - ea.length).endsWith('ي')) {
      return ('f', 'بإسكان الياء');
    }
    return ('u', 'بالإدغام فيما بعدها');
  }
  if (!vowelA && vowelB && i + 1 < h.length && j + 1 < r.length) {
    final hamzaInHafs = RegExp('^[وف]?[أإآء]').hasMatch(h[i + 1].text);
    if (hamzaInHafs && norm(r[j + 1]).letters == norm(r[j + 1]).noHamza) {
      return ('h', 'بنقل حركة الهمزة إليها');
    }
  }
  return c;
}

(String, String)? _plain(String hafs, String other) {
  final c = classify(hafs, other);
  return c == null ? null : (c, describe(hafs, other));
}

/// A word of letter names: maddah but no vowel at all (الٓمٓ, حمٓ, كٓهيعٓصٓ).
final _muqattaat = RegExp('^(?=.*ٓ)[^ً-ِْٖٗٞۡ]+\$');

final _silah = RegExp('[ۥۦۧ][ٓۤ]?\$');
final _finalVowel = RegExp('[َُِْۡ]+\$');

bool _hasSilah(String w) => _silah.hasMatch(_stripWaqf(w));

String _dropSilah(String w) =>
    _stripWaqf(w).replaceFirst(_silah, '').replaceFirst(_finalVowel, '');

String _stripWaqf(String w) => w.replaceAll(RegExp('[ۖ-ۜٓ]+\$'), '');

// ---------------------------------------------------------------------------
// Alignment

/// Maps the COMPLETE reading onto Hafs word anchors without discarding equal
/// words, vowels or spellings. Empty slots are source omissions/continuations,
/// never annotation-only notes. The joined slots must reproduce the source.
List<String> alignSourceWords(List<HafsWord> hafs, List<String> reading) {
  final slots = List.filled(hafs.length, '');
  var hi = 0, ri = 0;
  final prefix = <String>[];
  void gap(int endH, int endR) {
    final text = reading.sublist(ri, endR);
    if (endH == hi) {
      if (text.isNotEmpty) {
        if (hi > 0) {
          slots[hi - 1] = [
            slots[hi - 1],
            ...text,
          ].where((w) => w.isNotEmpty).join(' ');
        } else {
          prefix.addAll(text);
        }
      }
    } else if (endH - hi == endR - ri) {
      for (var k = 0; k < text.length; k++) {
        slots[hi + k] = text[k];
      }
    } else {
      slots[hi] = text.join(' ');
    }
  }

  for (final (h, r) in _lcs(
    // Silah letters change pronunciation, not the word anchor. Including them
    // in the key can shift repeated words (أحسنتم أحسنتم at 17:7).
    hafs
        .map((w) => norm(w.text.replaceAll(RegExp('[ۥۦۧۨ]'), '')).loose)
        .toList(),
    reading.map((w) => norm(w.replaceAll(RegExp('[ۥۦۧۨ]'), '')).loose).toList(),
  )) {
    gap(h, r);
    slots[h] = [...prefix, reading[r]].join(' ');
    prefix.clear();
    hi = h + 1;
    ri = r + 1;
  }
  gap(hafs.length, reading.length);
  if (prefix.isNotEmpty && slots.isNotEmpty) {
    slots[0] = [...prefix, slots[0]].where((w) => w.isNotEmpty).join(' ');
  }
  return slots;
}

/// Returns variants as
/// [surah, ayah, wordIndex, wordCount, text, category, description].
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
          out.add([w.surah, w.ayah, w.index, 1, r[ri + k], c.$1, c.$2]);
        }
      }
      return;
    }
    // Same words, only split differently (أَوَلَمۡ / أَوَ لَمۡ).
    if (hi < hj &&
        ri < rj &&
        h[hi].ayah == h[hj - 1].ayah &&
        classify(
              h.sublist(hi, hj).map((w) => w.text).join(),
              r.sublist(ri, rj).join(),
            ) ==
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
          [r[ri - 1], ...r.sublist(ri, rj)].join(' '), 'f',
          'بزيادة ${r.sublist(ri, rj).join(' ')}',
        ]);
      } else {
        final w = h[0];
        out.add([
          w.surah, w.ayah, 0, 1, //
          [...r.sublist(ri, rj), r[rj]].join(' '), 'f',
          'بزيادة ${r.sublist(ri, rj).join(' ')}',
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
      out.add([w.surah, w.ayah, w.index, end - start, text, 'f', '']);
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
