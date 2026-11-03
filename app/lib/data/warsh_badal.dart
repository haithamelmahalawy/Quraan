import 'arabic.dart';

/// Test the word actually read by Warsh, including any lexical additions
/// or deletions. A naql spelling needs its underlying hamza restored first.
bool hasWarshBadal(String word, String location) {
  // تَرَٰٓءَا (الشعراء 61): no badal, its alif is told on stopping as taqlil.
  // وَرَآيِٕ (الشورى 51): a muttasil, the source's ya after its hamza no madd.
  if (const ['10:51', '10:91', '26:61', '42:51'].contains(location)) {
    return false;
  }
  final bare = skeleton(word);
  // ءَا۬عۡجَمِيّٞ (فصلت 44): its alif is the second hamza, eased or changed.
  if (location == '41:44' && bare.contains('عجمي')) return false;
  if (bare.contains('سريل') ||
      RegExp(r'^[وف]?[يتن]خذ').hasMatch(bare) ||
      RegExp(r'^[وف]?لصب(ين|ون)$').hasMatch(bare)) {
    return false;
  }
  final letters = lettersOf(word);
  for (var i = 0; i < letters.length; i++) {
    final h = letters[i];
    final alifMadd = h.startsWith('آ') || h.startsWith('أ') && h.contains('ٓ');
    if (!'ءأإؤئ'.contains(h[0]) && !RegExp('[ٕٔ]').hasMatch(h) && !alifMadd) {
      continue;
    }
    if (i > 0 && RegExp('[ْۡ]').hasMatch(letters[i - 1])) {
      final lamOfAl =
          letters[i - 1].startsWith('ل') &&
          i >= 2 &&
          'ٱل'.contains(letters[i - 2][0]);
      final lin = 'وي'.contains(letters[i - 1][0]);
      if (!lamOfAl && !lin) continue;
    }
    final open = h.contains('َ') || h.contains('۪') || h.contains('ٜ');
    if (h.contains('ِ') && (h.contains('ۧ') || h.contains('ۦ'))) return true;
    if (alifMadd || open && h.contains('ٰ')) return true;
    if (i + 1 >= letters.length) continue;
    final next = letters[i + 1];
    if (RegExp('[ًٌٍَُِْٖۡٗٞٓ]').hasMatch(next)) continue;
    if (open && next.startsWith('ا') ||
        h.contains('ُ') && next.startsWith('و') ||
        h.contains('ِ') && 'يى'.contains(next[0])) {
      return true;
    }
  }
  return false;
}
