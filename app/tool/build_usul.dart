// Adds the readings of recitation rules (usul) that the riwayat texts do not
// spell, by applying the rules to the Hafs text, and drops "differences"
// that are written exactly as Hafs.
//
//   dart run tool/build_usul.dart
//
// Run after build_data.dart and build_quranpedia.dart; it can be run again
// (its own readings, tagged with their rule, are replaced).
//
// Warsh ('an Nafi', by al-Azraq, as in the Shatibiyya):
//   badal    madd al-badal: a hamza followed by a madd letter (ءَامَنُواْ,
//            ءَالَ, أُوتُواْ, إِيمَٰن, ٱلۡأٓخِرَة), except after a sakin in the
//            word (ٱلۡقُرۡءَان, مَسۡـُٔولٗا), إسرائيل, يؤاخذ, ءالآن, عادًا الأولى
//   tarqiq   tarqiq of a ra with fatha or damma after a kasra (كَٰفِرُونَ),
//            a ya sakina (خَيۡرٞ, بَصِيرٌ) or a kasra and a sakin that is not
//            a letter of isti'la (ذِكۡرٗا), unless a letter of isti'la follows
//            in the word (صِرَٰط, فِرَاق), the ra is repeated (فِرَارٗا), or in
//            إبراهيم, عمران, إسرائيل
//   taghliz  taghliz of a lam with fatha after ص, ط or ظ with fatha or sukun
//            (ٱلصَّلَوٰة, ظَلَمُواْ, أَظۡلَمُ, ٱلطَّلَٰق, مَطۡلَعِ)
// Khalaf 'an Hamzah:
//   sakt     on the lam of ال before a hamza (ٱلۡأَرۡض), on شيء, and on a
//            sakin (or tanween) ending a word before a hamza (مَنۡ ءَامَنَ)
//
// These are rules, not a text: the rare words with their own ruling (a
// Shatibiyya khilaf) may be missing or extra.
import 'dart:convert';
import 'dart:io';

/// A letter and its marks.
typedef Cluster = ({int base, List<int> marks});

const hamzas = {0x0621, 0x0623, 0x0625, 0x0624, 0x0626};
const sukun = 0x06E1, fatha = 0x064E, damma = 0x064F, kasra = 0x0650;
const shadda = 0x0651, dagger = 0x0670, maddah = 0x0653, smallSeen = 0x06DC;
const tanween = {0x064B, 0x064C, 0x064D, 0x0656, 0x0657, 0x065E, 0x08F0, 0x08F1, 0x08F2};
const isti3la = {0x0635, 0x0636, 0x0637, 0x0638, 0x0642, 0x063A}; // ص ض ط ظ ق غ
const vowels = {fatha, damma, kasra, sukun, 0x0652, ...tanween};

bool isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) || c == dagger || (c >= 0x06D6 && c <= 0x06ED);

List<Cluster> clusters(String word) {
  final out = <Cluster>[];
  for (final c in word.runes) {
    if (isMark(c) && out.isNotEmpty) {
      out.last.marks.add(c);
    } else {
      out.add((base: c, marks: <int>[]));
    }
  }
  return out;
}

String join(List<Cluster> cs) =>
    String.fromCharCodes([for (final c in cs) ...[c.base, ...c.marks]]);

bool isHamza(Cluster c) =>
    hamzas.contains(c.base) || (c.base == 0x0640 && c.marks.contains(0x0654));

/// The Hafs word without its vowels and alefs (as lib/data/arabic.dart).
String bare(String w) => String.fromCharCodes(w.runes.where(
    (c) => c >= 0x0621 && c <= 0x064A && c != 0x0640 && !'ءئأإآاؤ'.runes.contains(c)));

// ---------------------------------------------------------------- Warsh

bool hasBadal(String word, String where) {
  if (const ['10:51', '10:91'].contains(where)) return false; // ءالآن
  final b = bare(word);
  // إسرائيل; يؤاخذ (its ؤ dropped: يخذ, تخذ, نخذ).
  if (b.contains('سريل') || RegExp('^[وف]?[يتن]خذ').hasMatch(b)) return false;
  final cs = clusters(word);
  for (var i = 0; i < cs.length; i++) {
    final h = cs[i];
    final alefMadd = h.base == 0x0623 && h.marks.contains(maddah); // أٓ
    if (!isHamza(h) && !alefMadd) continue;
    // After a sakin in the word (ٱلۡقُرۡءَان), except the lam of ال.
    if (i > 0 && cs[i - 1].marks.contains(sukun)) {
      final lamOfAl = cs[i - 1].base == 0x0644 &&
          i >= 2 &&
          (cs[i - 2].base == 0x0671 || cs[i - 2].base == 0x0644);
      final lin = cs[i - 1].base == 0x0648 || cs[i - 1].base == 0x064A;
      if (!lamOfAl && !lin) continue;
    }
    if (alefMadd) return true;
    if (h.marks.contains(fatha) && h.marks.contains(dagger)) return true;
    if (i + 1 >= cs.length) continue;
    final next = cs[i + 1];
    final plain = !next.marks.any(vowels.contains) && !next.marks.contains(maddah);
    if (!plain) continue;
    if (h.marks.contains(fatha) && next.base == 0x0627) return true;
    if (h.marks.contains(damma) && next.base == 0x0648) return true;
    if (h.marks.contains(kasra) && (next.base == 0x064A || next.base == 0x0649)) {
      return true;
    }
  }
  return false;
}

bool hasTarqiq(String word) {
  final b = bare(word);
  if (b.contains('برهيم') || b.contains('عمرن') || b.contains('سريل')) {
    return false;
  }
  final cs = clusters(word);
  for (var r = 1; r < cs.length; r++) {
    final ra = cs[r];
    if (ra.base != 0x0631) continue;
    final open = ra.marks.contains(fatha) ||
        ra.marks.contains(damma) ||
        ra.marks.any(tanween.contains);
    if (!open || ra.marks.contains(kasra)) continue;
    // A letter of isti'la after it, or a repeated ra (فِرَارٗا).
    if (cs.skip(r + 1).any((c) => isti3la.contains(c.base))) continue;
    if (r + 2 < cs.length && cs[r + 1].base == 0x0627 && cs[r + 2].base == 0x0631) {
      continue;
    }
    final p = cs[r - 1];
    // A kasra just before, but not on a prefix letter (بِرَبِّ).
    if (p.marks.contains(kasra) &&
        !(r == 1 && const {0x0628, 0x0644}.contains(p.base))) {
      return true;
    }
    // A ya sakina or a madd ya before it (خَيۡرٞ, بَصِيرٌ).
    if (p.base == 0x064A && !p.marks.any((m) => m == fatha || m == damma || m == kasra)) {
      return true;
    }
    // A kasra, then a sakin that is not a letter of isti'la (ذِكۡرٗا).
    if (r >= 2 &&
        p.marks.contains(sukun) &&
        !isti3la.contains(p.base) &&
        cs[r - 2].marks.contains(kasra)) {
      return true;
    }
  }
  return false;
}

bool hasTaghliz(String word) {
  final cs = clusters(word);
  for (var l = 1; l < cs.length; l++) {
    final lam = cs[l];
    if (lam.base != 0x0644) continue;
    if (!(lam.marks.contains(fatha) || lam.marks.contains(0x064B) || lam.marks.contains(0x0657))) {
      continue;
    }
    final p = cs[l - 1];
    if (!const {0x0635, 0x0637, 0x0638}.contains(p.base)) continue;
    if (p.marks.contains(fatha) || p.marks.contains(sukun)) return true;
  }
  return false;
}

// ---------------------------------------------------------------- Khalaf

/// Where Khalaf pauses (sakt) in [word], followed by [next] in the ayah:
/// the word with the sakt sign, or null.
String? sakt(String word, String? next) {
  final cs = clusters(word);
  // ال before a hamza: ٱلۡأَرۡض.
  for (var i = 1; i + 1 < cs.length; i++) {
    if (cs[i].base == 0x0644 &&
        cs[i].marks.contains(sukun) &&
        cs[i - 1].base == 0x0671 &&
        (isHamza(cs[i + 1]) || cs[i + 1].base == 0x0623)) {
      cs[i].marks.add(smallSeen);
      return join(cs);
    }
  }
  // شيء: شَيۡءٖ, شَيۡـًٔا.
  for (var i = 1; i + 1 < cs.length; i++) {
    if (cs[i - 1].base == 0x0634 &&
        cs[i].base == 0x064A &&
        cs[i].marks.contains(sukun) &&
        isHamza(cs[i + 1])) {
      cs[i].marks.add(smallSeen);
      return join(cs);
    }
  }
  // A sakin ending the word before a hamza starting the next: مَنۡ ءَامَنَ.
  if (next == null) return null;
  final first = clusters(next).first;
  if (!const {0x0621, 0x0623, 0x0625, 0x0622}.contains(first.base)) return null;
  // The last letter that is read (not a silent alef, not a waqf sign).
  var last = cs.length - 1;
  while (last > 0 && cs[last].base == 0x0627 && !cs[last].marks.any(vowels.contains)) {
    last--;
  }
  final c = cs[last];
  final madd = const {0x0627, 0x0648, 0x064A, 0x0649}.contains(c.base);
  final silentSukun = c.marks.contains(sukun) || c.marks.contains(0x0652);
  final bareNun = c.base == 0x0646 && !c.marks.any(vowels.contains); // مَن
  final sakin = (silentSukun && !madd) || bareNun || c.marks.any(tanween.contains);
  if (!sakin) return null;
  c.marks.add(smallSeen);
  return join(cs);
}

// ---------------------------------------------------------------- files

/// Readings written exactly as Hafs, with no description: nothing differs
/// (e.g. only the shape of the iqlab sign, كَافِرِۭ / كَافِرِۢ).
String same(String s) => s
    .replaceAll(RegExp('[ۡ۟]'), 'ْ')
    .replaceAll('ࣰ', 'ً')
    .replaceAll('ࣱ', 'ٌ')
    .replaceAll('ࣲ', 'ٍ')
    .replaceAll('ۭ', 'ۢ')
    .replaceAll('ے', 'ى')
    .replaceAll(RegExp('[ـۖ-ۛ۞۩‏\\s]'), '');

void main() {
  final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final ayahs = [
    for (final a in quran['ayahs'] as List)
      (surah: a[0] as int, ayah: a[1] as int, words: (a[4] as String).split(' ')),
  ];
  final words = {for (final a in ayahs) '${a.surah}:${a.ayah}': a.words};

  for (final file in Directory('assets/data/qiraat').listSync().whereType<File>()) {
    final id = file.uri.pathSegments.last.replaceAll('.json', '');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final variants = [
      for (final v in json['variants'] as List)
        if ((v as List).length < 8) v, // not one of ours
    ];
    final before = variants.length;
    variants.removeWhere((v) {
      final text = v[4] as String;
      final hafs = words['${v[0]}:${v[1]}']!.sublist(v[2] as int, (v[2] as int) + (v[3] as int)).join(' ');
      final described = v.length > 6 && (v[6] as String).isNotEmpty;
      return text.isNotEmpty && !described && same(text) == same(hafs);
    });
    final dropped = before - variants.length;

    final added = <String, int>{};
    void add(int s, int a, int w, String text, String description, String rule) {
      variants.add([s, a, w, 1, text, 'u', description, rule]);
      added[rule] = (added[rule] ?? 0) + 1;
    }

    if (id == 'warsh') {
      for (final a in ayahs) {
        for (final (w, word) in a.words.indexed) {
          final where = '${a.surah}:${a.ayah}';
          // عَادًا ٱلۡأُولَىٰ (53:50) has a ruling of its own.
          if (hasBadal(word, where) && !(where == '53:50' && w == 3)) {
            add(a.surah, a.ayah, w, '', 'مد البدل: بالقصر والتوسط والإشباع', 'badal');
          }
          if (hasTarqiq(word)) add(a.surah, a.ayah, w, '', 'بترقيق الراء', 'tarqiq');
          if (hasTaghliz(word)) add(a.surah, a.ayah, w, '', 'بتغليظ اللام', 'taghliz');
        }
      }
    }
    if (id == 'khalaf_hamzah') {
      // Not where the riwaya's own readings already speak of the sakt.
      final told = {
        for (final v in variants)
          if (v.length > 6 && (v[6] as String).contains('سكت'))
            for (var k = v[2] as int; k < (v[2] as int) + (v[3] as int); k++)
              '${v[0]}:${v[1]}:$k',
      };
      for (final a in ayahs) {
        for (final (w, word) in a.words.indexed) {
          if (told.contains('${a.surah}:${a.ayah}:$w')) continue;
          final next = w + 1 < a.words.length ? a.words[w + 1] : null;
          final text = sakt(word, next);
          if (text != null) {
            add(a.surah, a.ayah, w, text, 'بالسكت على الساكن قبل الهمز', 'sakt');
          }
        }
      }
    }

    variants.sort((x, y) {
      for (var i = 0; i < 3; i++) {
        final c = (x[i] as int).compareTo(y[i] as int);
        if (c != 0) return c;
      }
      return 0;
    });
    json['variants'] = variants;
    file.writeAsStringSync(jsonEncode(json));
    stdout.writeln('$id: dropped $dropped written as Hafs'
        '${added.isEmpty ? '' : ', added ${added.entries.map((e) => '${e.value} ${e.key}').join(', ')}'}');
  }
}
