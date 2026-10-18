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
    } else if (c >= 0x0621 && c <= 0x064A && c != 0x0640 && // not tatweel
        !'ءئأإآا'.contains(ch)) {
      b.write(ch);
    }
  }
  return b.toString();
}
