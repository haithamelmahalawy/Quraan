// Shared spelling-aware normalization for data generation and comparisons.
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

/// One pronounced letter of a word after normalisation.
class Unit {
  Unit(this.letter);

  /// Base letter; hamza on any seat is 'ء' + its seat in [seat].
  String letter;
  String seat = '';

  /// fatha / damma / kasra, or null for sukun / no vowel.
  int? vowel;
  bool shadda = false;

  /// True when a quotation supplies a vowel/sukun rather than leaving it out.
  bool vocalized = false;

  /// Written as alef maqsura (ى, ے), read as a ya.
  bool maqsura = false;
  String? tanween;
  bool iqlab = false;

  /// Madd, imala / taqlil, tasheel / ishmam, saktah.
  final marks = <int>[];

  String get key => letter + seat;
}

/// Splits [word] into normalised letter units, ignoring spelling
/// conventions that do not change the reading.
List<Unit> units(String word) =>
    _unitCache.putIfAbsent(word, () => _units(word));

final _unitCache = <String, List<Unit>>{};

List<Unit> _units(String word) {
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

  final out = <Unit>[];
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
    // A word-initial alef with a vowel but no marker is a hamza dropped
    // after naql (اِلَّا), not a wasl.
    final isWasl =
        ch == 'ٱ' ||
        (ch == 'ا' &&
            ((i == prefix &&
                    (i > 0 ||
                        !ms.any(
                          (m) => m == _fatha || m == _damma || m == _kasra,
                        ))) ||
                groups[i].$2.any(
                  (m) => m == 0x06EC || m == 0x06DF || m == 0x06EA,
                )));
    if (isWasl) {
      ch = 'ا';
      ms = [];
    }
    if (ch == 'ل' && (wasl || i == spellingLam)) ms = [];
    wasl = isWasl;

    final u = Unit(ch)
      ..maqsura = groups[i].$1 == 'ى' || groups[i].$1 == 'ے'
      ..vocalized = groups[i].$2.any(
        (m) =>
            m >= 0x064B && m <= 0x0652 ||
            const {
              0x0656,
              0x0657,
              0x065E,
              0x0670,
              0x06E1,
              0x06EA,
              0x06ED,
            }.contains(m),
      );
    // Small high seen: on sad it means "read as seen", elsewhere it is saktah.
    if (ms.contains(0x06DC)) {
      ms = ms.where((m) => m != 0x06DC).toList();
      ch == 'ص' ? u.letter = 'س' : u.marks.add(0x06DC);
    }
    if (ms.contains(_dagger) && !ms.contains(_fatha)) ms.add(_fatha);
    if (ms.any((m) => m == 0x06EA || m == 0x06ED || m == 0x065C) &&
        !ms.any((m) => m == _fatha || m == _damma || m == _kasra)) {
      ms.add(_fatha); // imala / taqlil replaces the written fatha
    }
    switch (u.letter) {
      case 'أ' || 'إ' || 'آ':
        u
          ..letter = 'ء'
          ..seat = 'ا';
      case 'ؤ':
        u
          ..letter = 'ء'
          ..seat = 'و';
      case 'ئ':
        u
          ..letter = 'ء'
          ..seat = 'ي';
    }
    if (ms.contains(0x0654) || ms.contains(0x0655)) {
      u
        ..seat = u.letter
        ..letter = 'ء';
    }
    for (final m in ms) {
      if (_tanween.containsKey(m)) {
        u.tanween = _tanween[m];
      } else if (_recitationMarks.contains(m)) {
        u.marks.add(m);
      } else if (m == _shadda) {
        u.shadda = true;
      } else if (m == _fatha || m == _damma || m == _kasra) {
        u.vowel = m;
      }
    }
    // Tanween before ba (iqlab) is the vowel with a small mim: تُۢ, تِۭ.
    final raw = groups[i].$2;
    // (Without a written vowel, the small low mim is Abu 'Amr's taqlil: مُوسۭيٰ.)
    if (u.tanween == null &&
        raw.any((m) => m == _fatha || m == _damma || m == _kasra) &&
        (raw.contains(0x06E2) || raw.contains(0x06ED))) {
      u.tanween = const {_fatha: 'an', _damma: 'un', _kasra: 'in'}[u.vowel];
      u.vowel = null;
      u.marks.remove(0x06ED);
    }
    u.iqlab =
        u.tanween != null && (raw.contains(0x06E2) || raw.contains(0x06ED));
    out.add(u);
    if (ms.contains(_dagger)) out.add(Unit('ا'));
  }
  // The tanween of fath written on the alef (or final alef maqsura) after
  // the letter (اِثْماٗ، سِوىٗ), as in Hafs on the letter (إِثۡمٗا، سُوٗى).
  for (var k = 1; k < out.length; k++) {
    if ((out[k].letter == 'ا' || (out[k].maqsura && k == out.length - 1)) &&
        out[k].tanween != null &&
        out[k - 1].tanween == null) {
      out[k - 1].tanween = out[k].tanween;
      out[k].tanween = null;
    }
  }
  return out;
}

class Norm {
  Norm(this.loose, this.letters, this.noHamza, this.vowels, this.marks);

  /// Alignment key: letters without alef or hamza.
  final String loose;

  /// Letters (hamza seats kept), wasl alef as plain alef.
  final String letters;

  /// [letters] with hamza removed / seats reduced to their carrier letter.
  final String noHamza;

  /// Vowels and shadda per letter + tanween.
  final String vowels;

  /// Madd / imala / tasheel marks (order-insensitive). A shadda on the first
  /// letter (idgham with the previous word) is left out: the texts differ in
  /// writing it, not in reading it.
  final String marks;
}

final _normCache = <String, Norm>{};

Norm norm(String word) => _normCache.putIfAbsent(word, () => _norm(word));

Norm _norm(String word) {
  final us = units(word);
  final letters = StringBuffer(), noHamza = StringBuffer();
  final vowels = StringBuffer();
  final tanween = <String>[], marks = <int>[];
  for (var i = 0; i < us.length; i++) {
    final u = us[i];
    letters.write(u.key);
    if (u.letter != 'ء') noHamza.write(u.letter);
    if (u.letter == 'ء' && u.seat != '') noHamza.write(u.seat);
    vowels
      ..write(u.key)
      ..write(u.vowel == null ? '' : String.fromCharCode(u.vowel!))
      ..write(u.shadda && i > 0 ? 'ّ' : '');
    if (u.tanween != null) tanween.add(u.tanween!);
    marks.addAll(u.marks);
  }
  tanween.sort();
  marks.sort();
  final nh = noHamza.toString();
  final loose = nh.replaceAll('ا', '');
  return Norm(
    loose,
    letters.toString(),
    nh,
    '$vowels|${tanween.join()}',
    String.fromCharCodes(marks),
  );
}
