/// Bare letters of an Arabic word, to compare words written with different
/// diacritics, spellings or fonts (Uthmani script, plain text, OCR output).
///
/// Vowels and marks are dropped; alef (full or dagger) and hamza seats are
/// left out entirely, since texts spell them differently; ى and the small
/// ya become ي, ؤ and the small waw become و, ة becomes ه.
String skeleton(String word) {
  final b = StringBuffer();
  for (final c in word.runes) {
    final ch = String.fromCharCode(c);
    if (ch == 'ى' || c == 0x06E6 || c == 0x06CC) {
      b.write('ي');
    } else if (ch == 'ؤ' || c == 0x06E5) {
      b.write('و');
    } else if (ch == 'ة') {
      b.write('ه');
    } else if (c == 0x06A9) {
      b.write('ك'); // keheh, sometimes produced by OCR
    } else if (c >= 0x0621 &&
        c <= 0x064A &&
        c != 0x0640 && // not tatweel
        !'ءئأإآا'.contains(ch)) {
      b.write(ch);
    }
  }
  return b.toString();
}

/// A riwaya's text in the script of the Madinah (Hafs) mushaf, so it reads
/// like the page around it: the Maghribi yeh barree ے of the KFGQPC Warsh
/// and Qalun texts becomes ى, ya before a dagger alef (أَر۪يٰكُمْ) becomes
/// ى as in Hafs (أَرَىٰكُمۡ), and the dot below that marks imala in the
/// Shu'bah text becomes the Madinah imala sign ۪. The Maghribi marks on the
/// first alef of a word, which the Hafs font draws as big circles, go: the
/// sifr on the alef whose hamza gave its vowel to the word before by naql
/// (قَرِيبٌ ا۟جِيبُ), and the dot of the alef of wasl (اَ۬لدَّاعِ), written ٱ as
/// in Hafs.
String madinahScript(String text) => text
    .replaceAll('ے', 'ى')
    .replaceAll('يٰ', 'ىٰ')
    .replaceAll('ٜ', '۪')
    .replaceAllMapped(_naqlAlef, (m) => '${m[1]}ا')
    .replaceAllMapped(_waslAlef, (m) => '${m[1]}ٱ');

final _naqlAlef = RegExp(r'(^|\s)ا۟');
// The dot above (after a fatha or damma) or below (after a kasra: اِ۪تَّخَذتُّمُ).
final _waslAlef = RegExp(r'(^|\s)ا[َُِ]?[۪۬]');

/// The imala sign of the Madinah mushaf, a dot below the letter.
const imalaSign = '۪';

bool _isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED);

/// [word] with the imala sign under the letter read with imala: the one
/// before ى (هُدَى → هُدَ۪ى), before an alef followed by ra (ٱلنَّارِ →
/// ٱلنَّ۪ارِ) or carrying a dagger alef (ٱلۡأَبۡرَٰرِ), before the ta marbuta
/// (رَحۡمَة, al-Kisa'i's imala of the feminine ha), or else before the last
/// alef. Unchanged when it has the sign already or no such letter.
String withImalaSign(String word) {
  if (word.contains(imalaSign)) return word;
  // Letters with their marks.
  final clusters = <List<int>>[];
  for (final c in word.runes) {
    if (_isMark(c) && clusters.isNotEmpty) {
      clusters.last.add(c);
    } else {
      clusters.add([c]);
    }
  }
  int? target;
  bool base(int i, int c) =>
      i >= 0 && i < clusters.length && clusters[i][0] == c;
  bool dagger(int i) => clusters[i].contains(0x0670);
  for (var i = clusters.length - 1; i > 0 && target == null; i--) {
    if (base(i, 0x0649)) target = i - 1;
  }
  for (var i = clusters.length - 2; i >= 0 && target == null; i--) {
    if (base(i + 1, 0x0631) && (base(i, 0x0627) || dagger(i))) {
      target = dagger(i) ? i : i - 1;
    }
  }
  if (target == null &&
      clusters.length > 1 &&
      base(clusters.length - 1, 0x0629)) {
    target = clusters.length - 2;
  }
  for (var i = clusters.length - 1; i >= 0 && target == null; i--) {
    if (base(i, 0x0627) && i > 0) target = i - 1;
    if (target == null && dagger(i)) target = i;
  }
  if (target == null || target < 0) return word;
  clusters[target].add(imalaSign.codeUnitAt(0));
  return String.fromCharCodes(clusters.expand((c) => c));
}

/// [word] as its letters, each with its marks.
List<String> lettersOf(String word) {
  final out = <String>[];
  for (final c in word.runes) {
    final s = String.fromCharCode(c);
    if (_isMark(c) && out.isNotEmpty) {
      out.last += s;
    } else {
      out.add(s);
    }
  }
  return out;
}

const _hamzas = 'ءأإؤئٔ';
const _alefs = 'اٱ';

/// The letter that receives the vowel of the hamza by naql, among [letters]
/// of a word: the lam of al before its hamza (وَبِالَاخِرَةِ), or with
/// [last], the last letter of a word followed by the hamza (وَلَقَدَ ءَاتَيۡنَا).
int? naqlLetter(List<String> letters, {bool last = false}) {
  if (last) return letters.isEmpty ? null : letters.length - 1;
  for (var i = 1; i + 1 < letters.length; i++) {
    if (letters[i].startsWith('ل') &&
        _alefs.contains(letters[i - 1][0]) &&
        (_alefs.contains(letters[i + 1][0]) ||
            _hamzas.contains(letters[i + 1][0]))) {
      return i;
    }
  }
  return null;
}

/// The letter of madd al-badal among [letters]: the madd after the hamza
/// (ءَامَنُواْ, إِيمَٰن, أُوتُواْ), the hamza itself when it carries the madd
/// (ٱلۡأٓخِرَةِ, ءَٰدَم), or, the hamza dropped by naql, the alef after the
/// lam (وَبِالَاخِرَةِ) or at the start of the word (اٰتَيْنَا).
int? badalLetter(List<String> letters) {
  bool madd(int i) => i < letters.length && 'اوىي'.contains(letters[i][0]);
  for (var i = 0; i < letters.length; i++) {
    final l = letters[i];
    if (_hamzas.contains(l[0]) || l.contains('ٔ') || l.startsWith('آ')) {
      if (l.startsWith('آ') || l.contains('ٓ') || l.contains('ٰ')) return i;
      if (madd(i + 1)) return i + 1;
    }
  }
  final naql = naqlLetter(letters);
  if (naql != null) return naql + 1;
  if (letters.isNotEmpty && _alefs.contains(letters.first[0])) return 0;
  return null;
}

/// The ra read with tarqiq among [letters]: the last ra with a fatha, damma
/// or tanween (وَبِالَاخِرَةِ, خَيۡرٞ).
int? raLetter(List<String> letters) {
  for (var i = letters.length - 1; i > 0; i--) {
    final l = letters[i];
    if (l.startsWith('ر') && RegExp('[\u064B-\u064F\u08F0-\u08F2]').hasMatch(l)) {
      return i;
    }
  }
  return null;
}

/// The lam read with taghliz among [letters]: a lam with a fatha after a
/// ص, ط or ظ (ٱلصَّلَوٰة, ظَلَمُواْ).
int? lamLetter(List<String> letters) {
  for (var i = 1; i < letters.length; i++) {
    if (letters[i].startsWith('ل') &&
        'صطظ'.contains(letters[i - 1][0]) &&
        RegExp('[\u064E\u064B\u0657]').hasMatch(letters[i])) {
      return i;
    }
  }
  return null;
}

/// The tatweel that draws a letter's join out (kashida).
const tatweel = 'ـ';

/// Letters that join only to the letter before them: no kashida after.
const _rightJoining = 'اأإآٱٲٳدذرزوؤةءى';

/// Where a kashida can stretch [letters] of a word: after each letter that
/// joins to the next, last first (the print stretches the end of the word,
/// خَالِصَةً). Not inside lam-alef, nor before the last letter's marks only.
List<int> kashidaSlots(List<String> letters) {
  bool isLetter(String l) {
    final c = l.codeUnitAt(0);
    return (c >= 0x0621 && c <= 0x064A) || c == 0x0671 || c == 0x0640;
  }

  return [
    for (var i = letters.length - 2; i >= 0; i--)
      if (isLetter(letters[i]) &&
          isLetter(letters[i + 1]) &&
          !_rightJoining.contains(letters[i][0]) &&
          letters[i + 1][0] != 'ء' &&
          // Lam-alef is one shape.
          !(letters[i][0] == 'ل' && 'اأإآٱ'.contains(letters[i + 1][0])))
        i,
  ];
}

/// Kashidas one join takes before the next join of the word is drawn out.
const kashidaPerJoin = 2;

/// [letters] with [count] kashidas on its [kashidaSlots], each added to the
/// letter it draws out: the last join first, as far as [kashidaPerJoin].
List<String> withKashida(List<String> letters, int count) {
  final slots = kashidaSlots(letters);
  if (count <= 0 || slots.isEmpty) return letters;
  final out = [...letters];
  for (var k = 0; k < count; k++) {
    final full = k ~/ kashidaPerJoin;
    final i = full < slots.length
        ? slots[full]
        : slots[k % slots.length];
    out[i] = '${out[i]}$tatweel';
  }
  return out;
}
