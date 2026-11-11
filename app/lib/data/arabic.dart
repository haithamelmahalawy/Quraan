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

/// A ya of the zawaid, added to Hafs's rasm: the small one beside the word, not
/// a letter in its body, as agreed for every reader (ٱتَّبَعَنِۦ، يَٰعِبَادِۦ،
/// يُرِدۡنِۦَ with its fatha, دُعَآءِۦ with Hafs's hamza).
String withSmallYa(String text) => text
    .replaceFirst(RegExp('آئ(?=ِ[يىےۦ])'), 'آء')
    .replaceFirstMapped(
      RegExp('ِ[يىے](َ?)([ۖ-ۜ]*)\$'),
      (m) => 'ِۦ${m[1]}${m[2]}',
    );

/// A riwaya's text in the script of the Madinah (Hafs) mushaf, so it reads
/// like the page around it: the Maghribi yeh barree ے of the KFGQPC Warsh
/// and Qalun texts becomes ى, ya before a dagger alef (أَر۪يٰكُمْ) becomes
/// ى as in Hafs (أَرَىٰكُمۡ), and the dot below that marks imala in the
/// Shu'bah text becomes the Madinah imala sign ۪. The Maghribi marks on the
/// first alef of a word, which the Hafs font draws as big circles, go: the
/// sifr on the alef whose hamza gave its vowel to the word before by naql
/// (قَرِيبٌ ا۟جِيبُ), and the dot of the alef of wasl (اَ۬لدَّاعِ), written ٱ as
/// in Hafs.
String madinahScript(String text, {String? followingWord}) {
  var shown = text
      .replaceAll('ے', 'ى')
      .replaceAll('يٰ', 'ىٰ')
      .replaceAll('ٜ', '۪')
      .replaceAll(_iqlabOnAlif, 'َۢا')
      // The Maghribi export attaches the following hamza to a sakin ya
      // in شَئْا. The Hafs font would compose it as ئ, hiding the ya.
      // Give the hamza its own joining carrier, as in شَيۡـٔٗا.
      .replaceAllMapped(_linHamzaCarrier, (m) => '${m[1]}ـٔ')
      // This Maghribi replacement dot is not part of the substituted
      // waw/ya in the Madinah font. Retain the vowel (يُوَاخِذُكُم).
      .replaceAllMapped(_replacementDot, (m) => m[1]!)
      .replaceAllMapped(_waslSifrAlef, (m) => '${m[1]}ٱ')
      .replaceAllMapped(_naqlAlef, (m) => '${m[1]}ا')
      .replaceAllMapped(_waslAlef, (m) => '${m[1]}ٱ')
      .replaceAllMapped(_prefixedArticle, (m) => '${m[1]}ٱ')
      .replaceAllMapped(_prefixedWasl, (m) => '${m[1]}ٱ')
      // The lam doubled, as Hafs writes it: «لِلَّهِ»، «ٱلَّذِي»، «ٱلَّتِي».
      .replaceAllMapped(_nameLam, (m) => '${m[1]}لَّ')
      .replaceAllMapped(_relativeLam, (m) => '${m[1]}ٱلَّ')
      // The tanween before its alif, as Hafs's «نَارٗا».
      .replaceAllMapped(_tanweenAfterAlif, (m) => '${m[1]}ا')
      .replaceAllMapped(_nunBeforeIdgham, (m) => 'ن${m[1]}');
  if (followingWord != null && _idghamStart.hasMatch(followingWord)) {
    shown = shown.replaceFirstMapped(_nunEnd, (m) => 'ن${m[1]}');
  }
  // Initial ya here is a prefix, not an intrinsically doubled letter.
  // Keep the Madinah spelling when the source marks the boundary ghunna.
  return _madaniSukun(shown.replaceAllMapped(_yartadid, (m) => '${m[1]}يَ'));
}

/// The Hafs font distinguishes jazm (head of kha) from the round zero on
/// unpronounced letters. Maghribi text uses the round Unicode sukun also
/// for pronounced consonants; do not confuse it with its silent carriers.
String _madaniSukun(String text) {
  final cs = lettersOf(text);
  for (var i = 0; i < cs.length; i++) {
    final c = cs[i];
    if (!c.contains('ْ')) continue;
    final before = i > 0 ? cs[i - 1] : '';
    final silent =
        c.startsWith('ا') ||
        // Abu Ja'far's «لِإْيلَٰفِ»: the alif of a hamza not read.
        c.startsWith('إ') && !RegExp('[ً-ِ]').hasMatch(c) ||
        c.startsWith('و') && before.startsWith('أ') && before.contains('ُ') ||
        c.startsWith('ي') && before.startsWith('إ') && before.contains('ِ') ||
        // بِأَيۡيْدٖ, as Hafs's second ya.
        c.startsWith('ي') && before.startsWith('ي') && before.contains('ۡ') ||
        // Hafs's seat of the hamza after one eased (أَٰاَ۬يْن for أَئِن).
        c.startsWith('ي') && before.startsWith('ا') && before.contains('۬');
    if (silent) continue;
    final madd =
        c.startsWith('و') && before.contains('ُ') ||
        (c.startsWith('ي') || c.startsWith('ى')) && before.contains('ِ');
    cs[i] = c.replaceAll('ْ', madd ? '' : 'ۡ');
  }
  return cs.join();
}

// In Madinah notation a nun assimilated into the next word is bare.
// Require the source's explicit shadda; do not erase sukun at izhar,
// before an unassimilated letter, or inside words such as الدنيا.
final _idghamStart = RegExp(r'^[يرملون][َُِ]*ّ');
final _nunEnd = RegExp(r'ن[ْۡ]([ۖ-ۭ]*)$');
final _nunBeforeIdgham = RegExp(r'ن[ْۡ]([ۖ-ۭ]*)(?=\s+[يرملون][َُِ]*ّ)');

final _naqlAlef = RegExp(r'(^|\s)ا۟');
final _yartadid = RegExp(r'(^|\s)ي[َّ]+(?=ر[ْۡ]تَدِد)');
// Some exports place the iqlab fatha and mim on the silent final alif.
// Return them to the preceding letter, matching the Madinah script.
final _iqlabOnAlif = RegExp(r'اَۢ(?=[ۖ-ۭ]*(?:\s|$))');
final _linHamzaCarrier = RegExp('(َ[ويى][ْۡ])ٔ');
final _replacementDot = RegExp('([وي])۬(?=[َُِ])');
// A vowel + sifr marks a joined hamzat al-wasl in the Maghribi export
// (اُ۟عْبُدُواْ / اِ۟سْجُدُواْ); a bare ا۟ instead belongs to naql. Before an
// open letter it is the eased hamza after a naql (اَ۟لَٰهٞ، اَ۟ذَا): no wasl.
// So too where the second hamza had a damma (اَ۟نزِلَ، اَ۟لْقِيَ، اَ۟شْهِدُواْ).
final _waslSifrAlef = RegExp(
  r'(^|\s|[وفبك]َ|لِ)ا(?:[ُِ]۟|َ۟(?![^ً-ْ]َ|نزِلَ|ل[ْۡ]قِيَ|ش[ْۡ]هِدُوا))',
);
// The dot above (after a fatha or damma) or below (after a kasra: اِ۪تَّخَذتُّمُ).
final _waslAlef = RegExp(r'(^|\s)ا[َُِ]?[۪۬]');
// The Name after the lam of jarr, its second lam bare in the Maghribi export
// (لِلهِ، وَلِلهِ).
final _nameLam = RegExp(r'((?:^|\s|[وفأ]َ)لِ)ل(?=هِ)');
// «ٱلذِى، ٱلذِينَ، ٱلتِى» with a bare lam.
final _relativeLam = RegExp(
  r'((?:^|\s)(?:[وفبكل][َُِ]?)?)ٱل(?=(?:ذِ[ىي]|ذِينَ|تِ[ىي])[ۖ-ۭ]*(?:\s|$))',
);
// «نَاراٗ»: the tanween on the alif at the word's end.
final _tanweenAfterAlif = RegExp(r'ا([ًٗ])(?=[ۖ-ۭ]*(?:\s|$))');
// After a waw or fa, the article's alif of wasl (وَاَ۬للَّهُ), not an eased
// hamza, which the export writes on its seat.
final _prefixedArticle = RegExp(r'((?:^|\s)[وف]َ)ا[َُِ]?[۪۬](?=ل)');
// And bare, after a waw, fa, ba or kaf: the article before a bare lam or a
// doubled letter (وَالنَّبِيٓءِ، بِالذِى), the verb's before a doubled or
// quiet letter (وَاتَّخَذُواْ). Never a long alif: it is followed by a vowel.
final _prefixedWasl = RegExp(
  // ... the article's lam with the vowel the naql gave it (وَالَارۡضِ), and a
  // bare nun before its hiding (فَانفَجَرَتۡ).
  r'((?:^|\s)[وفبك][َُِ])ا(?=ل[ء-ي]|[ء-ي][َُِ]?[ّْۡ]|ل[َُِ][اٰ]|ل۪|ن[ء-يۢ])',
);

/// The imala sign of the Madinah mushaf, a dot below the letter.
const imalaSign = '۪';

bool _isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED);

/// [word] with the imala sign under the letter read with imala: the one
/// before ى (هُدَى → هُدَ۪ى), before an alef followed by ra (ٱلنَّارِ →
/// ٱلنَّ۪ارِ) or carrying a dagger alef (ٱلۡأَبۡرَٰرِ), before the ta marbuta
/// (رَحۡمَة, al-Kisa'i's imala of the feminine ha), or else before the last
/// alef. Unchanged when it has the sign already or no such letter.
String withImalaSign(String word, [String? reading]) {
  if (reading != null) {
    final marked = _imalaAsIn(word, reading);
    if (marked != null) return marked;
  }
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

final _imalaRaBeforeHamza = RegExp(
  '(ر[ً-ْۡ]*۪[ً-ْۡ]*)'
  '(?=ء[ً-ْۡ]*۪)',
);

/// For drawing only: a thin space between a ra and a hamza both read with
/// imala (رَ۪ءَ۪اكَ). The ra's tail runs under the hamza, so its sign falls
/// under the hamza and the hamza's sign on the tail: one dot is seen.
String spacedImalaSigns(String text) => text.replaceAllMapped(
  _imalaRaBeforeHamza,
  (m) => '${m[1]}${String.fromCharCode(0x2009)}',
);

/// For drawing only: «أَوَءَابَآؤُنَا» (37:17، 56:48), one word of the text,
/// shown as the two it is read as, «أَوَ ءَابَآؤُنَا», as the riwayat with
/// «أَوۡ» write it beside it.
String spacedAwa(String word) =>
    word.replaceFirst(RegExp('^أَوَءَ'), 'أَوَ ءَ');

final _tanween = RegExp('[ًٌٍٖٗٞ]');

/// The tanween of each word of [text] written as the Madinah mushaf writes
/// it before the word after it ([next] after the last one; unchanged when
/// none is known): stacked (ً ٌ ٍ) before a throat letter or hamzat al-wasl,
/// where it is shown; the iqlab mim (َۢ ُۢ ِۭ) before the ba; offset (ٗ ٞ ٖ)
/// before the other letters, hidden in them or merged.
String tanweenBefore(String text, String? next) {
  final words = text.split(' ');
  for (var i = 0; i < words.length; i++) {
    final after = i + 1 < words.length ? words[i + 1] : next;
    // Written after the alef or alef maqsura (قِيَماً): put on the letter
    // before it, as the Madinah text does (قِيَمٗا).
    words[i] = words[i].replaceAllMapped(
      RegExp('([اى])([ًٗ])'),
      (m) => '${m[2]}${m[1]}',
    );
    final mark = _tanween.allMatches(words[i]).lastOrNull;
    final letter = after == null
        ? null
        : RegExp('[ء-يٱ]').firstMatch(after)?[0];
    // Already written with the iqlab mim (نُشۡرَۢا).
    if (mark == null || letter == null || RegExp('[ۭۢ]').hasMatch(words[i])) {
      continue;
    }
    final kind = switch (mark[0]) {
      'ً' || 'ٗ' => 0,
      'ٌ' || 'ٞ' => 1,
      _ => 2,
    };
    // The naql into the lam before a bare alif (عَادٗا ٱلُّاولَىٰ): the tanween
    // merges into the lam (not ٱلَّذِينَ, whose wasla takes the tanween).
    final merged =
        after != null && RegExp('^ٱل(?:ّ[ً-ِ]?|[ً-ِ]ّ)ا').hasMatch(after);
    final form = !merged && 'ءأإآؤئعحغخهاٱ'.contains(letter)
        ? const ['ً', 'ٌ', 'ٍ'][kind]
        : letter == 'ب'
        ? const ['َۢ', 'ُۢ', 'ِۭ'][kind]
        : const ['ٗ', 'ٞ', 'ٖ'][kind];
    words[i] = words[i].replaceRange(mark.start, mark.end, form);
  }
  return words.join(' ');
}

/// [word] with the imala sign under the letters [reading] marks with it
/// (رٜءٜا: the ra and the hamza, Shu'bah's رَءَا كَوۡكَبٗا); null when the
/// reading marks none or its letters are not the word's.
String? _imalaAsIn(String word, String reading) {
  List<List<int>> clustersOf(String s) {
    final out = <List<int>>[];
    for (final c in s.runes) {
      if (_isMark(c) && out.isNotEmpty) {
        out.last.add(c);
      } else {
        out.add([c]);
      }
    }
    return out;
  }

  const signs = [0x06EA, 0x065C]; // ۪ and ٜ
  final r = clustersOf(reading);
  final w = clustersOf(word);
  if (!r.any((c) => c.skip(1).any(signs.contains))) return null;
  if (r.length != w.length ||
      [for (var i = 0; i < r.length; i++) r[i][0] == w[i][0]].contains(false)) {
    return null;
  }
  for (var i = 0; i < r.length; i++) {
    if (r[i].skip(1).any(signs.contains) && !w[i].contains(0x06EA)) {
      w[i].add(0x06EA);
    }
  }
  return String.fromCharCodes(w.expand((c) => c));
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

const _hamzas = 'ءأإؤئٕٔ';
const _alefs = 'اٱ';

/// The letter that receives the vowel of the hamza by naql, among [letters]
/// of a word: the lam of al before its hamza (وَبِالَاخِرَةِ), or with
/// [last], the last letter of a word followed by the hamza (وَلَقَدَ ءَاتَيۡنَا).
int? naqlLetter(List<String> letters, {bool last = false}) {
  if (last) {
    // In naql after tanween the pronounced nun belongs to the tanween,
    // not to the silent final alif of a word such as مريضًا.
    final tanween = letters.lastIndexWhere(
      (l) => RegExp('[ًٌٍٖٗٞ]').hasMatch(l),
    );
    return tanween >= 0
        ? tanween
        : (letters.isEmpty ? null : letters.length - 1);
  }
  for (var i = 1; i + 1 < letters.length; i++) {
    if (letters[i].startsWith('ل') &&
        (_alefs.contains(letters[i - 1][0]) ||
            letters[i - 1].startsWith('ل')) &&
        (letters[i].contains('ٰ') ||
            _alefs.contains(letters[i + 1][0]) ||
            _hamzas.contains(letters[i + 1][0]) ||
            RegExp('[ٕٔ]').hasMatch(letters[i + 1]))) {
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
  // With no vowel of its own (not the waw of أَوَءَابَآؤُنَا).
  bool madd(int i) =>
      i < letters.length &&
      'اوىي'.contains(letters[i][0]) &&
      !RegExp('[َُِ]').hasMatch(letters[i]);
  for (var i = 0; i < letters.length; i++) {
    final l = letters[i];
    if (_hamzas.contains(l[0]) ||
        RegExp('[ٕٔ]').hasMatch(l) ||
        l.startsWith('آ')) {
      if (l.startsWith('آ') ||
          l.contains('ٓ') ||
          l.contains('ٰ') ||
          l.contains('ۧ')) {
        return i;
      }
      if (madd(i + 1)) return i + 1;
      // The hamza over a lam-alif, the madd alif after it unwritten
      // (ٱلۡأَخِرَةِ، لِأَبَآئِهِمۡ): the hamza carries the madd.
      if (l.startsWith('أ') &&
          l.contains('َ') &&
          i > 0 &&
          letters[i - 1].startsWith('ل') &&
          i + 1 < letters.length &&
          RegExp('[ًٌٍَُِ]').hasMatch(letters[i + 1])) {
        return i;
      }
    }
  }
  final naql = naqlLetter(letters);
  if (naql != null) {
    if (letters[naql].contains('ٰ')) return naql;
    // The hamza's seat left bare before the madd ya or waw (بِالِايمَٰنِ):
    // the madd is that letter, not the seat.
    final seat = naql + 1;
    if (seat + 1 < letters.length &&
        letters[seat] == 'ا' &&
        'يو'.contains(letters[seat + 1][0]) &&
        !RegExp('[ً-ْۡ]').hasMatch(letters[seat + 1])) {
      return seat + 1;
    }
    return seat;
  }
  if (letters.isNotEmpty && _alefs.contains(letters.first[0])) return 0;
  return null;
}

/// A fatha/damma ra, including their tanween encodings. Kasra and kasratan
/// are shared natural tarqiq and cannot identify a Warsh difference.
bool isOpenRa(String cluster) =>
    cluster.startsWith('ر') &&
    !RegExp('[ٍࣲِٖ]').hasMatch(cluster) &&
    RegExp('[ًࣰٌࣱَُٗٞ]').hasMatch(cluster);

/// The ra read with tarqiq among [letters]: the last ra with a fatha, damma
/// or their tanween (وَبِالَاخِرَةِ, خَيۡرٞ).
int? raLetter(List<String> letters) {
  for (var i = letters.length - 1; i > 0; i--) {
    final l = letters[i];
    // Maghribi exports can attach fathatan to the silent final alif,
    // e.g. خَيْراٗ. The vowel still belongs to the preceding ra.
    final finalFathatan =
        i + 1 == letters.length - 1 &&
        RegExp(r'^ا[ًࣰٗ][ۖ-ۭ]*$').hasMatch(letters[i + 1]);
    if (isOpenRa(finalFathatan ? '$l${letters[i + 1]}' : l)) {
      return i;
    }
  }
  return null;
}

/// Warsh's automatic tarqiq, evaluated on the word after lexical changes.
bool hasWarshTarqiq(String word) {
  final bare = String.fromCharCodes(
    word.runes.where(
      (c) =>
          c >= 0x0621 &&
          c <= 0x064A &&
          c != 0x0640 &&
          !'ءئأإآاؤ'.runes.contains(c),
    ),
  );
  if (RegExp('برهي?م').hasMatch(bare) ||
      bare.contains('عمرن') ||
      bare.contains('سريل')) {
    return false;
  }
  final cs = lettersOf(word);
  const high = 'صضطظقغ';
  for (var r = 1; r < cs.length; r++) {
    final tailTanween =
        r + 1 == cs.length - 1 && RegExp(r'^ا[ًࣰٗ][ۖ-ۭ]*$').hasMatch(cs[r + 1]);
    if (!isOpenRa(tailTanween ? '${cs[r]}${cs[r + 1]}' : cs[r])) continue;
    if (cs.skip(r + 1).any((c) => high.contains(c[0]))) continue;
    if (r + 2 < cs.length &&
        cs[r + 1].startsWith('ا') &&
        cs[r + 2].startsWith('ر')) {
      continue;
    }
    final p = cs[r - 1];
    if (p.contains('ِ') && !(r == 1 && 'بل'.contains(p[0]))) return true;
    if (p.startsWith('ي') && !RegExp('[َُِ]').hasMatch(p)) return true;
    if (r >= 2 &&
        RegExp('[ْۡ]').hasMatch(p) &&
        !high.contains(p[0]) &&
        cs[r - 2].contains('ِ')) {
      return true;
    }
  }
  return false;
}

/// The lam read with taghliz among [letters]: a lam with a fatha after a
/// ص, ط or ظ (ٱلصَّلَوٰة, ظَلَمُواْ).
int? lamLetter(List<String> letters, {bool anyVowel = false}) {
  for (var i = 1; i < letters.length; i++) {
    // Right after the letter, or after an alif after it (طَالَ، فِصَالًا).
    final before = letters[i - 1][0] == 'ا' && i > 1
        ? letters[i - 2][0]
        : letters[i - 1][0];
    if (letters[i].startsWith('ل') &&
        'صطظ'.contains(before) &&
        (anyVowel || RegExp('[\u064E\u064B\u0657]').hasMatch(letters[i]))) {
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
    final i = full < slots.length ? slots[full] : slots[k % slots.length];
    // A hamza on a kashida after a bare one (لِيَسُـۥٓـــُٔواْ) stays by
    // the letter after it: drawn out before it.
    out[i] =
        i > 0 &&
            out[i].startsWith(tatweel) &&
            out[i].contains('ٔ') &&
            RegExp('^$tatweel+\$').hasMatch(letters[i - 1])
        ? '$tatweel${out[i]}'
        : '${out[i]}$tatweel';
  }
  return out;
}

/// A reading whose first hamza was dropped by naql, its alef written bare
/// (ا۟خَرَ, after [madinahScript]: اخَرَ), with the hamza's vowel of the Hafs
/// word on the alef, as the print writes it (مِنۡ أَيَّامٍ اُخَرَ).
String withNaqlVowel(String text, String hafs) {
  final letters = lettersOf(text);
  final from = lettersOf(hafs);
  if (letters.length < 2 ||
      letters[0] != 'ا' ||
      from.isEmpty ||
      !'أإ'.contains(from[0][0])) {
    return text;
  }
  final vowel = from[0].replaceAll(RegExp('[^َُِ]'), '');
  return vowel.isEmpty ? text : 'ا$vowel${letters.skip(1).join()}';
}

/// Completes a partial quotation from the unchanged letters of its aligned
/// source. Explicit vowels (including a changed case ending) always win.
/// New letters and recitation signs are never inferred from another reading.
String completeReadingVowels(String text, String baseline) {
  final ownWords = text.split(RegExp(r'\s+'));
  final sourceWords = baseline.split(RegExp(r'\s+'));
  if (ownWords.length != sourceWords.length) return text;
  final explicit = RegExp('[ً-ِْٖۡٗٞ]');
  final marks = RegExp('[ً-ْٖۡٗٞۢ]');
  String key(String cluster) =>
      cluster[0].replaceAll('ٱ', 'ا').replaceAll('ى', 'ي').replaceAll('ے', 'ي');
  return [
    for (var w = 0; w < ownWords.length; w++)
      (() {
        final own = lettersOf(ownWords[w]), source = lettersOf(sourceWords[w]);
        final lengths = List.generate(
          own.length + 1,
          (_) => List.filled(source.length + 1, 0),
        );
        for (var i = own.length - 1; i >= 0; i--) {
          for (var j = source.length - 1; j >= 0; j--) {
            lengths[i][j] = key(own[i]) == key(source[j])
                ? 1 + lengths[i + 1][j + 1]
                : (lengths[i + 1][j] > lengths[i][j + 1]
                      ? lengths[i + 1][j]
                      : lengths[i][j + 1]);
          }
        }
        var i = 0, j = 0;
        while (i < own.length && j < source.length) {
          if (key(own[i]) == key(source[j])) {
            final followingDoubled = i + 1 < own.length
                ? own[i + 1].contains('ّ')
                : w + 1 < ownWords.length &&
                      lettersOf(ownWords[w + 1]).first.contains('ّ');
            final assimilated =
                followingDoubled && RegExp('[ْۡ]').hasMatch(source[j]);
            // A bare nun before a letter of ikhfa is the nun sakina of the
            // Uthmani script (يُنزِلَ، يَغُرَّنكَ): it takes no vowel.
            final next = i + 1 < own.length
                ? own[i + 1]
                : w + 1 < ownWords.length
                ? lettersOf(ownWords[w + 1]).first
                : '';
            final hidden =
                own[i] == 'ن' &&
                next.isNotEmpty &&
                'تثجدذزسشصضطظفقك'.contains(next[0]);
            // A bare last ya after a kasra is the madd ya, the ya of idafa
            // read sakin (لِي، بَيۡتِي): not Hafs's fatha (لِيَ).
            final maddYa =
                i == own.length - 1 &&
                i > 0 &&
                'يى'.contains(own[i][0]) &&
                own[i - 1].contains('ِ');
            // The lam of ٱل before a doubled (sun) letter is silent
            // (ٱللَّهُ for Hafs's لِلَّهِ): not Hafs's kasra.
            final sunLam =
                own[i] == 'ل' &&
                i > 0 &&
                own[i - 1][0] == 'ٱ' &&
                next.contains('ّ');
            // A bare waw after a damma before the last (silent) alif is the
            // waw of the plural (لِتُرۡبُواْ): not the fatha of Hafs's singular
            // (لِّيَرۡبُوَاْ).
            final pluralWaw =
                own[i] == 'و' &&
                i > 0 &&
                i + 2 == own.length &&
                own[i - 1].contains('ُ') &&
                own[i + 1][0] == 'ا';
            // A kashida (ٱلَّـٰٓيِٕ) carries no vowel of its own.
            // A bare waw after a damma is the madd waw (فَرُوحٞ for Hafs's
            // فَرَوۡحٞ): it takes no sukun from Hafs (still his fatha: هُوَ).
            final maddWaw =
                own[i] == 'و' &&
                i > 0 &&
                own[i - 1].contains('ُ') &&
                RegExp('^[ْۡ]+\$').hasMatch(source[j].substring(1));
            if (own[i][0] != 'ـ' &&
                !maddWaw &&
                !explicit.hasMatch(own[i]) &&
                !assimilated &&
                !hidden &&
                !maddYa &&
                !sunLam &&
                !pluralWaw) {
              for (final m in marks.allMatches(source[j])) {
                if (!own[i].contains(m[0]!)) own[i] += m[0]!;
              }
            }
            i++;
            j++;
          } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
            i++;
          } else {
            j++;
          }
        }
        return own.join();
      })(),
  ].join(' ');
}
