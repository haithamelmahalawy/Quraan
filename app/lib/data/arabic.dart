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
/// Shu'bah text becomes the Madinah imala sign ۪.
String madinahScript(String text) =>
    text.replaceAll('ے', 'ى').replaceAll('يٰ', 'ىٰ').replaceAll('ٜ', '۪');

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
