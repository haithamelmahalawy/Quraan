// A row covers the Hafs words its text reads: the page replaces every word a
// row counts, so a source's row told with the word next to it (يَامُرُكُمُ over
// «يَأۡمُرُكُمۡ أَن») would lose that word. The text is matched to Hafs's words by
// its letters, and the row put on those alone. What is really read as one word
// (مَالِيَ for «مَا لِيٓ», وَأَن for «أَوۡ أَن») keeps both.
// Run from app/: dart run tool/apply_word_span.dart [--dry]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

String _key(String t) => t
    .replaceAll(RegExp('[ً-ٰٟۖ-ۭـٕٔ]'), '')
    .replaceAll(RegExp('[اأإآٱءئؤ]'), '')
    .replaceAll(RegExp('[ىے]'), 'ي')
    .replaceAll('ة', 'ت');

/// The share of letters two keys have in order.
double _alike(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var row = List.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    final next = List.filled(b.length + 1, 0);
    for (var j = 0; j < b.length; j++) {
      next[j + 1] = a[i] == b[j] ? row[j] + 1 : math.max(row[j + 1], next[j]);
    }
    row = next;
  }
  return row[b.length] / math.max(a.length, b.length);
}

/// Puts each row of [rows] on the words its text reads; the number changed.
int applyWordSpan(Map quran, List rows) {
  final words = <String, List<String>>{
    for (final x in quran['ayahs'] as List)
      '${x[0]}:${x[1]}': (x[4] as String).split(' '),
  };
  var changed = 0;
  final added = <List>[];
  for (final v in rows.cast<List>()) {
    final text = '${v[4]}'.trim();
    final count = (v[3] as num).toInt();
    if (text.isEmpty || text.contains('[')) continue;
    final own = text.split(RegExp(r'\s+'));
    if (own.length >= count) continue;
    // The word left out is what it tells (ٱلۡغَنِيُّ ٱلۡحَمِيدُ «بحذف هو»).
    if ('${v.length > 6 ? v[6] : ''}'.startsWith('بحذف هو')) continue;
    final ayah = words['${v[0]}:${v[1]}'];
    final from = v[2] as int;
    if (ayah == null || from + count > ayah.length) continue;
    final hafs = ayah.sublist(from, from + count).map(_key).toList();
    final keys = own.map(_key).toList();
    // The best place for its words, each to one word...
    var at = 0;
    var best = -1.0;
    var worst = 0.0;
    for (var o = 0; o + keys.length <= count; o++) {
      final scores = [
        for (var i = 0; i < keys.length; i++) _alike(keys[i], hafs[o + i]),
      ];
      final sum = scores.reduce((a, b) => a + b);
      if (sum > best) {
        best = sum;
        at = o;
        worst = scores.reduce(math.min);
      }
    }
    // ...or its last word two of Hafs's read as one.
    var merged = -1;
    final n = keys.length;
    for (var o = 0; o + n < count; o++) {
      final head = [
        for (var i = 0; i < n - 1; i++) _alike(keys[i], hafs[o + i]),
      ];
      final last = _alike(keys[n - 1], hafs[o + n - 1] + hafs[o + n]);
      final single = _alike(keys[n - 1], hafs[o + n - 1]);
      final other = _alike(keys[n - 1], hafs[o + n]);
      if (last > math.max(single, other) + .1 &&
          last >= .7 &&
          head.every((s) => s >= .5)) {
        merged = o;
        break;
      }
    }
    final int word, span;
    if (merged >= 0) {
      word = from + merged;
      span = n + 1;
    } else if (worst >= .6) {
      word = from + at;
      span = n;
    } else {
      continue;
    }
    if (word == from && span == count) continue;
    // One word told for two places (كَرۡهٗا «في الكلمتين»): each its own row.
    if (n == 1 && merged < 0) {
      for (var i = 0; i < count; i++) {
        if (from + i != word && hafs[i] == hafs[at] && hafs[i].isNotEmpty) {
          added.add(
            [...v]
              ..[2] = from + i
              ..[3] = 1,
          );
        }
      }
    }
    v[2] = word;
    v[3] = span;
    changed++;
  }
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final v in added) {
    final next = rows.indexWhere((o) => order(o as List) > order(v));
    rows.insert(next < 0 ? rows.length : next, v);
  }
  return changed;
}

/// A word as letters, each with the marks that tell how it is read: signs of
/// pause, sukun and madd aside, every hamza one letter.
List<(String, Set<String>)> _reading(String word) {
  final t = word
      .replaceAll(RegExp('\u0640?\u0654'), '\u0621')
      .replaceAll('\u0649\u0670', '\u064A')
      .replaceAll('\u0622', '\u0627')
      .replaceAll(RegExp('[\u0623\u0625\u0624\u0626]'), '\u0621')
      .replaceAll('\u0671', '\u0627')
      .replaceAll('\u0670', '\u0627')
      .replaceAll(RegExp('[\u0649\u06CC\u06D2]'), '\u064A')
      .replaceAll('\u0657', '\u064B')
      .replaceAll('\u0656', '\u064D')
      .replaceAll('\u065E', '\u064C')
      .replaceAll('\u0627\u064B', '\u064B\u0627')
      .replaceAll('\u06E1', '\u0652')
      .replaceAll(RegExp('[\u06D6-\u06E0\u06E2-\u06EB\u06ED\u0653\u0640]'), '');
  final out = <(String, Set<String>)>[];
  for (final c in t.split('')) {
    if (RegExp('[\u064B-\u0652\u06EC]').hasMatch(c)) {
      if (out.isNotEmpty) out.last.$2.add(c);
    } else {
      out.add((c, <String>{}));
    }
  }
  // A mark on the alif is its letter's before it (لاَّ for لَّا).
  for (var i = 1; i < out.length; i++) {
    if (out[i].$1 == '\u0627' && out[i].$2.isNotEmpty) {
      final tanwin = out[i].$2.remove('\u064B');
      out[i - 1].$2.addAll(out[i].$2);
      if (tanwin) out[i - 1].$2.add('\u064B');
      out[i].$2.clear();
    }
  }
  // The shadda of the word before's idgham (مِّن، لَّمۡ) is not the word's own.
  if (out.isNotEmpty) out.first.$2.remove('\u0651');
  return out;
}

/// Whether a source's [text] reads what Hafs's [hafs] reads: its letters, and
/// no mark against Hafs's. The damma of a plural mim is its silah, told in its
/// own row.
bool sameAsHafs(String text, String hafs) {
  const sukun = '\u0652', shadda = '\u0651';
  final a = _reading(text), b = _reading(hafs);
  if (a.length != b.length) return false;
  bool vowel(String m) => m != sukun && m != shadda;
  for (var i = 0; i < a.length; i++) {
    if (a[i].$1 != b[i].$1) return false;
    // هْوَ for هُوَ; صَدَقَ for صَدَّقَ.
    if (a[i].$2.contains(sukun) && b[i].$2.any(vowel)) return false;
    if (a[i].$2.any(vowel) &&
        b[i].$2.contains(shadda) &&
        !a[i].$2.contains(shadda)) {
      return false;
    }
    final extra = a[i].$2.difference(b[i].$2)..remove(sukun);
    if (extra.isEmpty) continue;
    final silah =
        i == a.length - 1 &&
        a[i].$1 == '\u0645' &&
        extra.length == 1 &&
        extra.first == '\u064F' &&
        !b[i].$2.any(vowel);
    if (!silah) return false;
  }
  return true;
}

/// What the source's text cannot tell, by the row's place: the word it is on
/// (from the row's first), how many, its text and wording; `null` where the row
/// has nothing to tell: it reads as Hafs, or is a sakin hamza the usul tells.
const Map<String, (int, int, String?, String?)?> _placed = {
  '2:254:8+3': null,
  '4:133:0+2': null,
  '6:158:3+2': null,
  '7:27:14+2': null,
  '7:123:6+3': null,
  '7:179:22+2': null,
  '7:199:1+2': null,
  '9:61:13+2': null,
  '9:109:7+2': null,
  '10:16:7+2': null,
  '10:61:32+6': null,
  '11:70:1+2': null,
  '12:80:27+2': null,
  '14:31:13+3': null,
  '15:65:12+2': null,
  '17:54:7+2': null,
  '17:90:2+2': null,
  '17:93:11+2': null,
  '17:104:10+2': null,
  '20:47:11+2': null,
  '20:75:0+2': null,
  '21:48:5+2': null,
  '26:61:1+2': null,
  '26:111:1+2': null,
  '30:43:7+2': null,
  '33:49:5+2': null,
  '34:33:9+2': null,
  '35:16:0+2': null,
  '42:47:5+2': null,
  '48:5:2+2': null,
  '49:11:27+2': null,
  '49:12:20+2': null,
  '49:13:9+3': null,
  '57:12:1+2': null,
  '67:21:3+3': null,
  '69:3:0+2': null,
  '2:259:25+2': (1, 1, 'لَبِتُّ', null),
  '2:265:12+2': (0, 1, null, 'بضم الراء'),
  '3:13:13+2': (1, 1, 'تَرَوۡنَهُم', 'بالتاء'),
  '3:37:12+2': (0, 1, null, 'بهمزة مضمومة بعد الألف'),
  '3:161:2+3': (2, 1, 'يُغَلَّ', 'بضم الياء وفتح الغين'),
  '4:3:19+2': (0, 1, null, 'بالرفع'),
  '8:48:17+2': (0, 1, 'ٱلۡفِيَتَانِ', null),
  '11:61:10+4': (1, 1, 'غَيۡرِهِۦ', 'بكسر الراء والهاء'),
  '11:66:11+3': (1, 1, null, 'بفتح الميم'),
  '11:76:5+4': (2, 1, 'اَ۬مْرُ', null),
  '11:84:11+2': (1, 1, 'غَيۡرِهِۦ', 'بكسر الراء والهاء'),
  '12:12:3+2': (0, 1, 'يَرۡتَعِ', 'بالياء وكسر العين'),
  '13:4:7+4': (0, 4, 'وَزَرۡعٖ وَنَخِيلٖ صِنۡوَانٖ وَغَيۡرِ', null),
  '14:22:12+3': (2, 1, 'لِيْ', null),
  '23:23:12+3': (1, 1, 'غَيۡرِهِۦٓ', 'بكسر الراء والهاء'),
  '23:32:10+3': (1, 1, 'غَيۡرِهِۦٓ', 'بكسر الراء والهاء'),
  '23:52:0+2': (0, 1, 'وَأَنَّ', null),
  '24:35:15+2': (1, 1, null, 'بفتح التاء والواو وتشديد القاف وفتح الدال'),
  '26:86:0+3': (1, 1, 'لِأَبِيَ', null),
  '27:29:2+3': (
    1,
    1,
    'اِ۪نِّيَ',
    'بتسهيل الهمزة الثانية أو إبدالها واوًا مكسورة وفتح ياء الإضافة',
  ),
  '27:32:2+2': (1, 1, 'وَفۡتُونِي', null),
  '27:38:2+2': (1, 1, 'وَيُّكُمۡ', null),
  '33:26:10+2': (1, 1, null, 'بضم العين'),
  '33:30:6+4': (1, 1, null, 'بحذف الألف وتشديد العين'),
  '35:28:12+2': (1, 1, 'اِ۪نَّ', null),
  '35:43:4+2': (5, 1, 'اِ۪لَّا', null),
  '37:25:2+2': (1, 1, 'تَّنَاصَرُونَ', null),
  '38:1:0+2': (0, 1, null, null),
  '38:23:6+2': (1, 1, 'وَلِيْ', null),
  '40:26:11+3': (1, 2, 'وَأَن', null),
  '41:39:11+2': (0, 1, null, 'بهمزة مفتوحة بعد الباء'),
  '43:15:4+2': (0, 1, null, 'بتشديد الزاي وتنوينها بالفتح'),
  '45:21:10+2': (1, 1, 'سَوَآءٌ', 'برفع الهمزة'),
  '47:18:7+3': (2, 1, 'اَ۬شْرَاطُهَا', null),
  '50:1:0+2': (0, 1, null, null),
  '52:21:2+2': (1, 1, null, 'بفتح التاء'),
  '54:41:0+3': (2, 1, 'ءَالَ', null),
  '59:2:30+2': (1, 1, null, 'بضم العين'),
  '61:14:12+2': (1, 1, 'أَنصَارِيَ', null),
  '65:3:13+2': (0, 2, 'بَٰلِغٌ أَمْرَهُۥ', null),
  '67:16:3+2': (1, 1, 'أَن', 'بإبدال الهمزة الثانية ياءً خالصة وصلاً'),
  '68:1:0+2': (0, 1, null, null),
  '69:16:2+2': (0, 1, 'فَهْيَ', 'بإسكان الهاء'),
  '71:4:14+2': (0, 1, 'يُوَخَّرُ', 'بإبدال الهمزة واوًا مفتوحة'),
  '76:21:2+4': (2, 1, null, 'بكسر القاف'),
  '77:6:0+3': (2, 1, null, 'بضم الذال'),
  '78:25:1+2': (1, 1, 'وَغَسَاقٗا', 'بتخفيف السين'),
  '94:5:0+4': (2, 2, null, 'بضم السين في الكلمتين'),
  '94:6:0+4': (2, 2, null, 'بضم السين في الكلمتين'),
  // «قُلۡ أَرَءَيۡتُمۡ»: on the word of its two hamzas, written as Qalun's.
  '3:15:0+2': (1, 1, '', null),
  '28:71:0+3': (1, 1, '', null),
  '28:72:0+3': (1, 1, '', null),
  '35:40:0+2': (1, 1, '', null),
  '39:38:8+2': (1, 1, '', null),
  '41:52:0+2': (1, 1, '', null),
  '46:4:0+2': (1, 1, '', null),
  '46:10:0+2': (1, 1, '', null),
  '67:28:0+3': (1, 1, '', null),
  '67:30:0+3': (1, 1, '', null),
  // «ءَآعۡجَمِيّٞ»: its hamza eased with the alif between, unlike Hafs's.
  '41:44:8+2': (0, 1, 'ءَٰا۬عْجَمِيّٞ', null),
  // Each of «يَأۡجُوجَ وَمَأۡجُوجَ» has its sakin hamza told in the usul.
  '43:5:3+2': (1, 1, 'إِن', 'بكسر الهمزة'),
  '2:269:4+2': null,
  '18:94:4+2': null,
  '21:96:3+2': null,
};

/// Abu Ja'far's words as written, where his source's letters leave their vowels
/// to be guessed or are mistaken: «تُووِي» (الأحزاب ٥١) and «تُووِيهِ» (المعارج
/// ١٣) with the waw for the hamza; his two hamzas and «هَٰٓأَنتُم» as Qalun's.
const _writtenAs = {
  '33:51:4': 'وَتُووِي',
  '70:13:2': 'تُووِيهِ',
  '3:66:0': 'هَٰا۬نتُمُۥ',
  '3:119:0': 'هَٰا۬نتُمُۥ',
  '4:109:0': 'هَٰا۬نتُمُۥ',
  '47:38:0': 'هَٰا۬نتُمُۥ',
  '6:19:18': 'أَٰئِنَّكُمُۥ',
  '36:19:3': 'أَٰئِن',
  '37:86:0': 'أَٰئِفْكًا',
  '3:49:20': 'طَآئِرَۢا',
  '5:110:36': 'طَآئِرَۢا',
  '12:43:22': 'لِلرُّيَّا',
  '78:37:5': 'ٱلرَّحۡمَٰنُ',
  '83:14:1': 'بَلۡ رَّانَ',
};

/// Told twice on one word: its sakin hamza is told in the usul.
const _toldTwice = {'2:269:5', '2:279:3'};

String text0(List v) => '${v[4]}';

/// One letter of a word, and the marks after it.
class _Letter {
  _Letter(this.glyph, this.marks);
  String glyph;
  String marks;

  String get kind {
    if ('اٱٰآ'.contains(glyph)) return 'ا';
    if ('ىيےی'.contains(glyph)) return 'ي';
    if ('أإءؤئ'.contains(glyph) || glyph == 'ـ' && marks.contains('ٔ')) {
      return 'ء';
    }
    return glyph;
  }
}

final _markChar = RegExp(
  '[\u064B-\u065F\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]',
);
final _pauseMark = RegExp('[\u06D6-\u06DC]');

List<_Letter> _lettersOf(String word) {
  final out = <_Letter>[];
  for (final c in word.split('')) {
    if (_markChar.hasMatch(c) && out.isNotEmpty) {
      out.last.marks += c;
    } else {
      out.add(_Letter(c, ''));
    }
  }
  // A mark on the alif is its letter's before it (لاَّ for لَّا); the fathatan
  // of «كِتَاباً» too.
  for (var i = 1; i < out.length; i++) {
    if (out[i].kind != 'ا' || out[i].glyph == 'ٰ') continue;
    final moved = out[i].marks.replaceAll(RegExp('[ٓۡۖ-ْۜ]'), '');
    final madd = out[i].marks.contains('ٓ') ? 'ٓ' : '';
    out[i].marks = madd;
    if (moved.isNotEmpty) out[i - 1].marks += moved;
  }
  return out;
}

/// The marks of a letter, one sign each however a text writes it.
Set<String> _signs(String marks) => marks
    .replaceAll('ۡ', 'ْ')
    .replaceAll('ٗ', 'ً')
    .replaceAll('ٖ', 'ٍ')
    .replaceAll('ٞ', 'ٌ')
    .replaceAll(RegExp('[ٓۥۦ]'), '')
    .replaceAll(_pauseMark, '')
    .split('')
    .where((c) => c.isNotEmpty)
    .toSet();

/// A word of [text] as read, written as [hafs]: every letter unchanged, and
/// every one with no mark of its own, takes Hafs's letter and marks; what the
/// text reads otherwise stays («البرُّ» for «ٱلۡبِرَّ» → «ٱلۡبِرُّ»).
String vowelledAsHafs(String text, String hafs, {bool dagger = true}) {
  final own = _lettersOf(text);
  final base = _lettersOf(hafs.replaceAll(_pauseMark, ''));
  // Their letters in common, in order.
  final table = List.generate(
    own.length + 1,
    (_) => List.filled(base.length + 1, 0),
  );
  for (var i = own.length - 1; i >= 0; i--) {
    for (var j = base.length - 1; j >= 0; j--) {
      table[i][j] = own[i].kind == base[j].kind
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] > table[i][j + 1]
                ? table[i + 1][j]
                : table[i][j + 1]);
    }
  }
  final sign = RegExp('[ً-ِْٖٗٞۡ]');
  String asOwn(_Letter l) => '${l.glyph}${l.marks.replaceAll('ْ', 'ۡ')}';
  // A letter told in another's place («تَكُن» for «يَكُن») has its vowel.
  // Its sukun not on the letter of a madd («فَاذَنُواْ» for «فَأۡذَنُواْ»).
  String swapped(_Letter l, _Letter other) {
    if (l.marks.isNotEmpty || l.kind == 'ا') return asOwn(l);
    final vowel = other.marks.replaceAll(RegExp('[ْۡٓ]'), '');
    return '${l.glyph}${l.marks}${other.kind == 'ء' ? vowel : other.marks.replaceAll('ٓ', '')}';
  }

  final out = StringBuffer();
  var i = 0, j = 0;
  // A letter of madd after a vowel Hafs's lacks has no sukun of his
  // («أَاتُوهُ» for «أَتَوۡهُ»).
  var otherwise = false;
  while (i < own.length) {
    if (j < base.length && own[i].kind == base[j].kind) {
      final o = own[i], h = base[j];
      final told = sign.hasMatch(o.marks);
      final differs =
          told &&
          !(_signs(o.marks).length == _signs(h.marks).length &&
              _signs(o.marks).containsAll(_signs(h.marks)));
      final small = RegExp('[ۥۦ]').stringMatch(o.marks) ?? '';
      final keep = small.isNotEmpty && !h.marks.contains(small) ? small : '';
      if (h.glyph == 'ٱ') {
        out.write('ٱ');
      } else if (!told && otherwise && 'اوي'.contains(o.kind)) {
        out.write(asOwn(o));
      } else if (!told) {
        // No vowel of its own: Hafs's letter and marks, its shadda kept.
        final shadda = o.marks.contains('ّ') && !h.marks.contains('ّ');
        // «تُؤوِي» for «تُـٔۡوِي»: its own seat, the hamza no mark over it.
        final seat = h.glyph == 'ـ' && o.glyph != 'ـ';
        // Its own madd where Hafs has none (وَمِيكَٰٓئِلَ).
        final madd = o.marks.contains('ٓ') && !h.marks.contains('ٓ');
        out.write(
          '${seat ? o.glyph : h.glyph}${shadda ? 'ّ' : ''}'
          '${seat ? h.marks.replaceAll('ٔ', '') : h.marks}${madd ? 'ٓ' : ''}',
        );
      } else if (!differs) {
        // The same read: as Hafs writes it, its tanwin and sukun signs; a
        // hamza on its own seat («ءَ» for his «أَ» of another word).
        final silah = RegExp('[ۥۦ]');
        final sameMarks =
            o.marks.length == h.marks.length &&
            o.marks.split('').toSet().containsAll(h.marks.split(''));
        final marks =
            sameMarks || silah.hasMatch(h.marks) && !silah.hasMatch(o.marks)
            ? o.marks.replaceAll('ْ', 'ۡ')
            : h.marks;
        out.write('${o.kind == 'ء' ? o.glyph : h.glyph}$marks$keep');
      } else {
        // Its own vowel, or no shadda (لَمَا), on Hafs's letter unless the
        // hamza's seat differs.
        final glyph = o.kind == 'ء' ? o.glyph : h.glyph;
        out.write('$glyph${o.marks.replaceAll('ْ', 'ۡ')}');
      }
      otherwise = differs;
      i++;
      j++;
      continue;
    }
    final skipOwn = table[i + 1][j];
    final skipBase = j < base.length ? table[i][j + 1] : -1;
    if (skipOwn == skipBase && j < base.length) {
      out.write(swapped(own[i], base[j]));
      i++;
      j++;
    } else if (skipOwn >= skipBase) {
      out.write(asOwn(own[i]));
      i++;
    } else {
      // A dagger alif the text leaves out, one letter short of Hafs's word.
      if (dagger && base[j].glyph == 'ٰ' && base.length - own.length == 1) {
        out.write('ٰ${base[j].marks}');
      }
      j++;
    }
  }
  return '$out';
}

/// A row's text written over more words than it counts (لَيۡسَ ٱلۡبِرُّ on «لَيۡسَ»
/// alone, «ٱلۡبِرَّ» then shown after it): it counts them, to be kept to those
/// it reads otherwise.
void applyWordCount(Map quran, List rows) {
  final words = <String, List<String>>{
    for (final x in quran['ayahs'] as List)
      '${x[0]}:${x[1]}': (x[4] as String).split(' '),
  };
  for (final v in rows.cast<List>()) {
    final own = '${v[4]}'.trim().split(RegExp(r'\s+'));
    final count = (v[3] as num).toInt();
    if ('${v[4]}'.trim().isEmpty || own.length <= count) continue;
    final ayah = words['${v[0]}:${v[1]}'];
    final from = v[2] as int;
    if (ayah == null || from + own.length > ayah.length) continue;
    if (List.generate(
      own.length,
      (i) => i,
    ).every((i) => _alike(_key(own[i]), _key(ayah[from + i])) >= .6)) {
      v[3] = own.length;
    }
  }
}

/// Abu Ja'far's rows, every word in them vowelled: Hafs's marks and letters
/// with the reader's difference. The number changed.
int applyVowelsFromHafs(Map quran, List rows) {
  final words = <String, List<String>>{
    for (final x in quran['ayahs'] as List)
      '${x[0]}:${x[1]}': (x[4] as String).split(' '),
  };
  // What each word is followed by: the separated madd is short.
  final after = <String, String>{};
  final all = [
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        ('${x[0]}:${x[1]}:$i', w),
  ];
  for (var n = 0; n + 1 < all.length; n++) {
    after[all[n].$1] = all[n + 1].$2;
  }
  final shortMadd = RegExp('ٓ(ا[ْ۟]?)?\$');
  var changed = 0;
  final gone = <List>{};
  final seen = <String>{};
  for (final v in rows.cast<List>()) {
    // One row told twice (سُدّٗا, يس ٩).
    if (!seen.add(jsonEncode(v.take(7).toList()))) {
      gone.add(v);
      continue;
    }
    // Two vowels on a letter in the source: «فِيَةٖ» (البقرة ٢٤٩) with its
    // tanwin of kasr, «أُمَّهَٰتِكُمۡ» (النور ٦١) read as Hafs.
    if (v[0] == 2 && v[1] == 249 && v[2] == 50 && '${v[4]}'.isNotEmpty) {
      v[4] = 'فِيَةٖ';
    }
    if (v[0] == 24 && v[1] == 61 && v[2] == 24 && v[5] == 'f') {
      v[4] = 'أُمَّهَٰتِكُمُۥ';
    }
    // Written by hand: their sources' letters bare or mistaken.
    final fixed = _writtenAs['${v[0]}:${v[1]}:${v[2]}'];
    if (fixed != null && '${v[4]}'.isNotEmpty && v[5] != 'u' ||
        fixed != null && v[0] == 83) {
      v[4] = fixed;
      if (v[0] == 33 || v[0] == 70) v[6] = 'بإبدال الهمزة واوًا';
      continue;
    }
    // «يَٰعِبَادِۦ» (الزخرف ٦٨) on its one word.
    if (v[0] == 43 && v[1] == 68 && v[2] == 0) v[4] = 'يَٰعِبَادِۦ';
    // «أَهَٰنَنِۦ» (الفجر ١٦), its ya shown as in «أَكۡرَمَنِۦ» before it.
    if (v[0] == 89 && v[1] == 16 && v[2] == 9) v[4] = 'أَهَٰنَنِۦ';
    // «دَرَجَٰتِ مَن» (الأنعام ٨٣): its source's text with the tanwin it denies.
    if (v[0] == 6 && v[1] == 83 && v[2] == 7 && v[5] == 'f') {
      v[4] = 'دَرَجَٰتِ';
    }
    // Written by a rule, or as Qalun's, or by hand: as it is.
    final rule = v.length > 7 ? '${v[7]}' : '';
    if (!const {
          '',
          'ya_idafa',
          'ya_zaida',
          'idgham_saghir',
          'first_sakin',
          'ha_kinaya',
          'hamza_hadhf',
        }.contains(rule) ||
        v.length > 8 && v[8] is Map && (v[8] as Map)['source'] != null) {
      continue;
    }
    if (v[0] == 2 && v[1] == 72 && v[2] == 3) continue;
    final text = '${v[4]}';
    if (text.isEmpty || text.contains('[')) continue;
    if (RegExp('[۪۬]').hasMatch(text)) continue;
    // «لَبِثتُّ» and «لَبِثتَّ»: the tha bare, the ta with its shadda.
    if ('${v[6]}'.contains('إدغام الثاء في التاء') && (v[3] as num) == 1) {
      final ayahWords = words['${v[0]}:${v[1]}'];
      if (ayahWords != null && (v[2] as int) < ayahWords.length) {
        final silah = text0(v).endsWith('مُۥ');
        var read = ayahWords[v[2] as int]
            .replaceAll(RegExp('[ۖ-ۜ]'), '')
            .replaceFirstMapped(RegExp('ثۡتّ?([َُِ]?)ّ?'), (m) => 'ثتّ${m[1]}');
        if (silah) read = read.replaceFirst(RegExp('مۡ?\$'), 'مُۥ');
        if (read != v[4]) {
          v[4] = read;
          changed++;
        }
        continue;
      }
    }
    // «مِاْيَةَ»: Hafs's word, its hamza a ya; usul, not farsh.
    if ((v[3] as num) == 1 &&
        (v[2] as int) < (words['${v[0]}:${v[1]}']?.length ?? 0)) {
      final word = words['${v[0]}:${v[1]}']![v[2] as int];
      if (RegExp('م[ِّ]+اْئ').hasMatch(word)) {
        v
          ..[4] = word.replaceAll(RegExp('[ۖ-ۜ]'), '').replaceFirst('ئ', 'ي')
          ..[5] = 'h'
          ..[6] = 'بإبدال الهمزة ياءً';
        changed++;
        continue;
      }
    }
    final own = text.split(' ');
    final ayah = words['${v[0]}:${v[1]}'];
    final from = v[2] as int;
    if (ayah == null || own.length != (v[3] as num).toInt()) continue;
    if (from + own.length > ayah.length) continue;
    final next = [
      for (var i = 0; i < own.length; i++)
        () {
          var word = vowelledAsHafs(
            own[i],
            ayah[from + i],
            dagger: !RegExp('حذف|دون ألف').hasMatch('${v[6]}'),
          );
          // No silah on a ha told short.
          if (RegExp('(قصر|بلا صلة|دون صلة)').hasMatch('${v[6]}')) {
            word = word.replaceFirst(RegExp('(?<=ه[َُِ]?)[ۥۦ]'), '');
          }
          // A ya of the zawaid written after the word, as Yaqub's.
          if (v.length > 7 && v[7] == 'ya_zaida') {
            word = word.replaceFirst(RegExp('[ىي]\$'), 'ۦ');
          }
          final following = after['${v[0]}:${v[1]}:${from + i}'] ?? '';
          return RegExp('^[ءأإآ]').hasMatch(following)
              ? word.replaceFirstMapped(shortMadd, (m) => m[1] ?? '')
              : word;
        }(),
    ].join(' ');
    if (next != text) {
      v[4] = next;
      changed++;
    }
    // Written all as Hafs, and told as a farsh: nothing differs (أَنۢبِيَآءَ
    // «بالياء»). A hamza eased is read otherwise for all its letters.
    String plain(String t) => t
        .replaceAll(RegExp('[ۖ-ۛ]'), '')
        .replaceAll('ٓ', '')
        // Its silah is told by its own row; a wasl alif's mark is no reading.
        .replaceFirst(RegExp('م[ُْۡ]?ۥ?\$'), 'م')
        .replaceFirst(RegExp('ا[ْ۟]\$'), 'ا');
    final hafs = ayah.sublist(from, from + own.length).join(' ');
    if (v[5] == 'f' &&
        plain(next) == plain(hafs) &&
        !RegExp('سهل|سهيل').hasMatch('${v[6]}')) {
      gone.add(v);
    }
  }
  rows.removeWhere(gone.contains);
  // «إِنَّ ٱلۡقُوَّةَ» and «وَإِنَّ ٱللَّهَ» (البقرة ١٦٥): «وَأَنَّ اكْسِرْ مَعًا حَائِزَ
  // الْعُلَا». Last, as the usul pass drops «بكسر الهمزة» for a general rule.
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final (w, text) in const [(23, 'إِنَّ'), (27, 'وَإِنَّ')]) {
    if (rows.cast<List>().any(
      (v) => v[0] == 2 && v[1] == 165 && v[2] == w && v[4] == text,
    )) {
      continue;
    }
    final row = [2, 165, w, 1, text, 'f', 'بكسر الهمزة', ''];
    final at = rows.indexWhere((o) => order(o as List) > order(row));
    rows.insert(at < 0 ? rows.length : at, row);
  }
  return changed;
}

/// Abu Ja'far's «ٱلۡ» as Hafs writes it, the wasl and its sukun, the rest of the
/// word as read («المَيِّتَةَ» → «ٱلۡمَيِّتَةَ»); «لِلْ» likewise.
int applyAlFromHafs(Map quran, List rows) {
  final words = <String, List<String>>{
    for (final x in quran['ayahs'] as List)
      '${x[0]}:${x[1]}': (x[4] as String).split(' '),
  };
  final hafsAl = RegExp('^([وفبكلَِ]*)(ٱل|لِل)(ۡ?)');
  final ownAl = RegExp('^([وفبكلَِ]*)(ال|لِل)([ْۡ]?)(?![ً-ْ])');
  var changed = 0;
  for (final v in rows.cast<List>()) {
    final text = '${v[4]}';
    if (text.isEmpty) continue;
    final ayah = words['${v[0]}:${v[1]}'];
    if (ayah == null) continue;
    final own = text.split(' ');
    final count = (v[3] as num).toInt();
    if (own.length != count) continue;
    var touched = false;
    for (var i = 0; i < count; i++) {
      final at = (v[2] as int) + i;
      if (at >= ayah.length) break;
      final hafs = hafsAl.firstMatch(ayah[at]);
      final mine = ownAl.firstMatch(own[i]);
      if (hafs == null || mine == null) continue;
      String plain(String t) => t.replaceAll(RegExp('[َِ]'), '');
      if (plain(hafs[1]!) != plain(mine[1]!)) continue;
      final next = own[i].substring(mine.end);
      own[i] = '${hafs[0]}$next';
      touched = true;
    }
    final joined = own.join(' ');
    if (touched && joined != text) {
      v[4] = joined;
      changed++;
    }
  }
  return changed;
}

/// Keeps a row of Abu Ja'far's source to the words it reads otherwise: «قُلۡ»
/// and «إِنۡ» beside «أَرَءَيۡتُمۡ» are read as Hafs's, and would be shaded with
/// it. Words apart become rows apart. Returns what it changed, for the report.
List<String> applyWordTrim(Map quran, List rows) {
  final words = <String, List<String>>{
    for (final x in quran['ayahs'] as List)
      '${x[0]}:${x[1]}': (x[4] as String).split(' '),
  };
  applyWordCount(quran, rows);
  final report = <String>[];
  final added = <List>[];
  final gone = <List>{};
  for (final v in rows.cast<List>()) {
    if (v.length > 7 && '${v[7]}'.isNotEmpty) continue;
    if (_toldTwice.contains('${v[0]}:${v[1]}:${v[2]}') && v[5] != 'u') {
      gone.add(v);
    }
  }
  // «يُوَاخِذُكُمۡ» «بواو مفتوحة بعد الياء»: its hamza changed, no farsh.
  final mere = RegExp(
    r'^ب?(واو|ياء) مفتوحة بعد (ال[ء-ي]+)( بعدها ألف تمد حركتين)?$',
  );
  final told = RegExp(r'^ب?[إا]بدال الهمزة (واو|ياء|ألف)[ًاٌءً]*( [ء-ي]+)?$');
  for (final v in rows.cast<List>()) {
    if (v[5] != 'f' || v.length > 7 && '${v[7]}'.isNotEmpty) continue;
    final how = '${v[6]}'.trim();
    final m = mere.firstMatch(how);
    if (m == null && !told.hasMatch(how)) continue;
    v[5] = 'h';
    if (m != null) v[6] = 'بإبدال الهمزة ${m[1] == 'واو' ? 'واوًا' : 'ياءً'}';
    report.add('HAMZA\t${v[0]}:${v[1]}:${v[2]} «${v[4]}»\t$how');
  }
  // «جَآءَتۡهُ» «قصر الهاء»: Hafs's ha is short too, nothing to tell.
  final longHa = RegExp('ه[ُِ]?[ۥۦ]');
  for (final v in rows.cast<List>()) {
    if (v.length < 8 || v[7] != 'ha_kinaya' || v[3] != 1) continue;
    if (!'${v[6]}'.contains('قصر') || '${v[4]}'.isNotEmpty) continue;
    final hafs = words['${v[0]}:${v[1]}']?[(v[2] as num).toInt()] ?? '';
    if (hafs.isNotEmpty && !longHa.hasMatch(hafs)) {
      gone.add(v);
      report.add('GONE\t${v[0]}:${v[1]}:${v[2]} «$hafs»\t${v[6]}');
    }
  }
  // «فَٱذۡكُرُونِيٓ» «بإسكان الياء»: Hafs's ya is sakin too, nothing to tell.
  for (final v in rows.cast<List>()) {
    if (v.length < 8 || v[7] != 'ya_idafa' || !'${v[6]}'.contains('إسكان')) {
      continue;
    }
    final hafs = words['${v[0]}:${v[1]}']?[(v[2] as num).toInt()] ?? '';
    final last = hafs.replaceAll(RegExp('[ۖ-ۜٓ]'), '');
    if (v[3] == 1 && hafs.isNotEmpty && !last.endsWith('يَ')) {
      gone.add(v);
      report.add('GONE\t${v[0]}:${v[1]}:${v[2]} «${v[4]}»\t${v[6]}');
    }
  }
  for (final v in rows.cast<List>()) {
    final place = '${v[0]}:${v[1]}:${v[2]}+${v[3]}';
    if ((v[3] as num) > 1 && _placed.containsKey(place)) {
      final to = _placed[place];
      if (to == null) {
        gone.add(v);
        report.add('GONE\t$place «${v[4]}»\t${v[6]}');
        continue;
      }
      final own = '${v[4]}'.trim().split(RegExp(r'\s+'));
      v
        ..[4] =
            to.$3 ??
            (own.length >= to.$1 + to.$2
                ? own.sublist(to.$1, to.$1 + to.$2).join(' ')
                : '')
        ..[2] = (v[2] as int) + to.$1
        ..[3] = to.$2;
      if (to.$4 != null) v[6] = to.$4;
      report.add('MOVE\t$place\t→ ${v[2]}+${v[3]} «${v[4]}»\t${v[6]}');
      continue;
    }
    // «إِنِّيَ» told on the ayah before it.
    if (place == '26:134:0+2') {
      v
        ..[1] = 135
        ..[3] = 1
        ..[4] = 'إِنِّيَ'
        ..[5] = 'u'
        ..[6] = 'بفتح الياء';
      while (v.length < 8) {
        v.add('');
      }
      v[7] = 'ya_idafa';
      report.add('MOVE\t$place\t→ 26:135:0 «${v[4]}»\t${v[6]}');
      continue;
    }
    final count = (v[3] as num).toInt();
    final text = '${v[4]}'.trim();
    if (count < 2 || text.isEmpty) continue;
    final own = text.split(RegExp(r'\s+'));
    final ayah = words['${v[0]}:${v[1]}'];
    final from = v[2] as int;
    if (own.length != count || ayah == null || from + count > ayah.length) {
      continue;
    }
    final differ = [
      for (var i = 0; i < count; i++)
        if (!sameAsHafs(own[i], ayah[from + i])) i,
    ];
    final was = '${v[0]}:${v[1]}:$from+$count «$text»';
    // «بَلۡ رَانَ»: the idgham is between the two.
    if (v[0] == 83 && v[1] == 14) continue;
    if (differ.length == count) continue;
    if (differ.isEmpty) {
      // «بَلۡ رَانَ»: what it tells is between the two.
      if (v.length > 7 && v[7] == 'idgham_saghir') continue;
      gone.add(v);
      report.add('GONE\t$was\t${v[6]}');
      continue;
    }
    // Runs of words read otherwise.
    final runs = <List<int>>[];
    for (final i in differ) {
      if (runs.isNotEmpty && runs.last.last == i - 1) {
        runs.last.add(i);
      } else {
        runs.add([i]);
      }
    }
    for (final (n, run) in runs.indexed) {
      final row = n == 0 ? v : [...v];
      while (row.length < 8) {
        row.add('');
      }
      row
        ..[2] = from + run.first
        ..[3] = run.length
        ..[4] = [for (final i in run) own[i]].join(' ');
      if (n > 0) added.add(row);
    }
    report.add(
      'TRIM\t$was\t→ ${[
        for (final r in runs) '${from + r.first}+${r.length} «${[for (final i in r) own[i]].join(' ')}»',
      ].join(' ، ')}\t${v[6]}',
    );
  }
  rows.removeWhere(gone.contains);
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final v in added) {
    final next = rows.indexWhere((o) => order(o as List) > order(v));
    rows.insert(next < 0 ? rows.length : next, v);
  }
  // On its word, told as Qalun's where he reads the same way.
  for (final v in rows.cast<List>()) {
    if (v.length < 8 || v[7] != 'tasheel_word' || v[3] != 1) continue;
    if (v.length > 8 && v[8] is Map && (v[8] as Map)['ways'] != null) continue;
    final way = '${v[6]}'.replaceFirst(RegExp('^ب'), '');
    while (v.length < 9) {
      v.add(<String, Object>{});
    }
    v[8] = {
      if (v[8] is Map) ...(v[8] as Map),
      'ways': [way],
    };
  }
  return report;
}

void main(List<String> args) {
  final dry = args.contains('--dry');
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  // The others' sources are still to be verified, some with a wording for text.
  for (final id in const ['ibn_wardan', 'ibn_jammaz']) {
    final f = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(f.readAsStringSync()) as Map;
    final rows = data['variants'] as List;
    final trimmed = applyWordTrim(quran, rows);
    for (final a in args) {
      if (a.startsWith('--report=')) {
        File('${a.substring(9)}/trim_$id.txt')
            .writeAsStringSync(trimmed.join('\n'));
      }
    }
    final n = applyWordSpan(quran, rows) + trimmed.length;
    final left = [
      for (final v in rows.cast<List>())
        if ('${v[4]}'.trim().isNotEmpty &&
            '${v[4]}'.trim().split(RegExp(r'\s+')).length < (v[3] as num))
          '${v[0]}:${v[1]}:${v[2]}+${v[3]} ${v[4]} | ${v.length > 6 ? v[6] : ''}',
    ];
    stdout.writeln(
      '${f.uri.pathSegments.last}: $n, one for more: ${left.length}',
    );
    if (!dry && n > 0) f.writeAsStringSync(jsonEncode(data));
  }
}
