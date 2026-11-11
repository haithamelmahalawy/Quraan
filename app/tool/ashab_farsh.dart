part of 'build_ashab_usul.dart';

/// The verified readers a farsh is taken from, those written in Hafs's
/// script first; the others' own letters are not taken, only the wording.
const _verifiedOrder = [
  'shubah',
  'hisham',
  'ibn_dhakwan',
  'ruways',
  'rawh',
  'ibn_wardan',
  'ibn_jammaz',
  'qalun',
  'bazzi',
  'qunbul',
  'warsh',
];
const _ownFont = {'qalun', 'bazzi', 'qunbul', 'warsh'};

/// The letters alone, the dagger alif read as an alif.
String _plain(String s) => s
    .replaceAll('ٱ', 'ا')
    // Qalun's and Warsh's ya (يُوصِے).
    .replaceAll('ے', 'ي')
    .replaceAll('آ', 'ءا')
    .replaceAll('ۦ', 'ي')
    .replaceAll('ۥ', 'و')
    .replaceAll(RegExp('[ٕٔ]'), 'ء')
    .replaceAllMapped(RegExp('([^اى])ٰ'), (m) => '${m[1]}ا')
    .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ\\s]'), '')
    .replaceAll(RegExp('[أإآءؤئ]'), 'ء')
    .replaceAll('ى', 'ي');

/// A word's letters, each with its vowels (the sukun and the signs of
/// pausing aside); [dagger]: the alifs kept, the dagger alif among them,
/// which the book leaves out of the words it quotes around a reading.
List<(String, String)> _clusters(String x, {required bool dagger}) {
  final t = x
      .replaceAll('ٱ', 'ا')
      .replaceAll('آ', 'ءَا')
      .replaceAll('ۦ', 'ي')
      .replaceAll('ۥ', 'و')
      .replaceAll('ٗ', 'ً')
      .replaceAll('ٞ', 'ٌ')
      .replaceAll('ٖ', 'ٍ')
      .replaceAllMapped(RegExp('ـ([ً-ْ]*)[ٕٔ]([ً-ْ]*)'), (m) => 'ء${m[1]}${m[2]}')
      .replaceAllMapped(RegExp('([^اى])ٰ'), (m) => '${m[1]}ا')
      // The hamza under the alif is a kasra: «إِنَّ» is not «أَنَّ».
      .replaceAllMapped(RegExp('إ([ً-ْ]*)'), (m) => 'ءِ${m[1]!.replaceAll('ِ', '')}');
  final out = <(String, String)>[];
  for (final m in RegExp(r'([^ً-ٰٟۖ-ۭs])([ً-ٰٟۖ-ۭ]*)').allMatches(t)) {
    var base = m[1]!;
    if (base == 'ـ') continue;
    base = switch (base) {
      'أ' || 'ؤ' || 'ئ' => 'ء',
      'ى' => 'ي',
      _ => base,
    };
    if (!dagger && base == 'ا') continue;
    out.add((
      base,
      m[2]!.replaceAll('ۡ', 'ْ').replaceAll(RegExp('[^ًٌٍَُِّْ]'), ''),
    ));
  }
  // The article's lam, which the book may mark amiss (ٱلَّكفار): its vowel
  // is no reading.
  final at = out.indexWhere((c) => c.$1 == 'ا');
  if (at >= 0 && at <= 1 && at + 1 < out.length && out[at + 1].$1 == 'ل') {
    out[at + 1] = ('ل', '');
  }
  return out;
}

/// Two words written with the same letters and vowels.
bool _same(String a, String b) {
  final x = _clusters(a, dagger: true), y = _clusters(b, dagger: true);
  return x.length == y.length &&
      [for (var i = 0; i < x.length; i++) i].every(
        (i) => x[i].$1 == y[i].$1 && x[i].$2 == y[i].$2,
      );
}

/// Two words read alike: the same letters, and each of the book's vowels on
/// the same letter of the other; the book may leave some out (ٱلَّذِين).
bool _alike(String a, String b, {bool dagger = true}) {
  final x = _clusters(a, dagger: dagger), y = _clusters(b, dagger: dagger);
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i].$1 != y[i].$1) return false;
    final (book, other) = (x[i].$2, y[i].$2);
    final voweled = other.replaceAll('ْ', '').isNotEmpty;
    // The book's sukun on a letter the other moves (وَهْوَ).
    if (book.contains('ْ') && voweled && !other.contains('ْ')) return false;
    // The book's vowel on a letter the other doubles, without the shadda
    // (لَمَا).
    if (book.replaceAll('ْ', '').isNotEmpty &&
        other.contains('ّ') &&
        !book.contains('ّ')) {
      return false;
    }
    for (final v in book.replaceAll('ْ', '').split('')) {
      if (!other.contains(v)) return false;
    }
  }
  return true;
}

/// The book's tanween of fath on the alef (حَسَناً) on the letter before
/// it, as the Madinah script writes it (حَسَنًا).
String _bookText(String quoted) =>
    quoted.replaceAllMapped(RegExp('َ?اً(?=\\s|\$)'), (_) => 'ًا');

/// One tanween per letter, the book's own over the one completed from Hafs.
String _oneTanween(String text) => text
    .replaceAllMapped(RegExp('([ٖٗٞ])([ً-ٍ])'), (m) => m[2]!)
    .replaceAllMapped(RegExp('([ً-ٍ])([ٖٗٞ])'), (m) => m[1]!)
    .replaceAllMapped(RegExp('[ٖٗٞ](?=ا[ً-ٍ])'), (m) => '');

/// Whether the book's wording tells how the word is read, not only where
/// (معاً، وصلاً ووقفاً).
bool _says(String how) =>
    // A note of the book (ولا يخفى أنهم يقرؤون بالإمالة) is not how.
    how.startsWith('ب') &&
    !RegExp(
      r'^(معاً|معا|وصلاً|وقفاً|وصلاً ووقفاً|كله|حيث وقع|[،\s])*$',
    ).hasMatch(how);

typedef _FarshCounts = ({int copied, int worded, int quoted, int usul});

/// The usul chapters a verified reader tells what the book lists as farsh:
/// taken from him in their own chapter.
const _bookUsul = {
  'ya_idafa',
  'ya_zaida',
  'first_sakin',
  'ha_damir',
  'mim_jam',
  'ha_kinaya',
  'ha_silah',
  'ishmam',
  'fath',
  'ibdal_single',
  'hamza_zaida',
  'hamza_hadhf',
  'tasheel_word',
  'rasm_stop',
};

/// The farsh of [id] from «التسهيل لقراءات التنزيل»: each run of words the
/// book's reading changes; a run a verified reader reads alike takes his row
/// (his wording, and his text when written in Hafs's script); one none of
/// them reads is the book's, its vowels completed from Hafs. What the usul
/// built here already tell is left out.
_FarshCounts _farsh(
  String id,
  Map book,
  Map<String, _Word> index,
  Map<String, String> textAt,
  Map<String, Map<String, List<List>>> verified,
  void Function(List row) put,
) {
  var copied = 0, worded = 0, quoted = 0, usul = 0;
  // The readers who read each of the book's readings with [id], and whether
  // [id] reads it by khulf.
  final siblings = <String, (List<String>, bool)>{};
  for (final e in book['entries'] as List) {
    for (final g in e[5] as List) {
      final all = [...(g[1] as List), ...(g[2] as List)].cast<String>();
      if (!all.contains(id) || g[4] == true) continue;
      siblings['${e[0]}:${e[1]}:${e[2]}:${_plain(g[0] as String)}'] = (
        all,
        (g[2] as List).contains(id),
      );
    }
  }
  final done = <String>{};
  bd.currentRiwaya = id;
  for (final p in ((book['riwayat'] as Map)[id] as List? ?? const [])) {
    final (s, a, w, c) = (p[0] as int, p[1] as int, p[2] as int, p[3] as int);
    final quote = p[4] as String, how = p[5] as String;
    // «أئنا ... إذا»: the repeated question, told with the two hamzas.
    if (p[6] != 'farsh' || quote.isEmpty || quote.contains('...')) continue;
    final span = [for (var i = w; i < w + c; i++) index[_key(s, a, i)]];
    if (span.contains(null)) continue;
    final hafs = span.map((x) => x!.t).join(' ');
    final own = _bookText(quote);
    final completed = _polish(
      _withHafsSilah(_oneTanween(completeReadingVowels(own, hafs)), hafs),
      hafs,
    );
    final parts = completed.split(' ');
    final (readers, khulf) =
        siblings['$s:$a:$w:${_plain(quote)}'] ?? (const <String>[], false);
    String withKhulf(String d) =>
        khulf && !d.contains('بخلف') ? '$d بخلف عنه' : d;
    // The runs of words the reading changes, each as the usul here read it.
    final runs = <(int, int)>[];
    if (parts.length == c) {
      List<bool> changedBy({required bool dagger}) => [
        for (var i = 0; i < c; i++)
          !_alike(parts[i], span[i]!.t, dagger: dagger) &&
              !_alike(
                parts[i],
                textAt[_key(s, a, w + i)] ?? '',
                dagger: dagger,
              ),
      ];
      // The dagger alif a difference only where nothing else is.
      final loose = changedBy(dagger: false);
      final changed = loose.contains(true) ? loose : changedBy(dagger: true);
      // A verified reader's chapter row the book's wording does not show
      // (أَجۡرِي إِلَّا, its ya without a sukun): his row then.
      if (!changed.contains(true)) {
        var taken = false;
        for (var i = 0; i < c && !taken; i++) {
          for (final r in _verifiedOrder) {
            if (!readers.contains(r)) continue;
            final hit = (verified[r]![_key(s, a, w + i)] ?? const <List>[])
                .where(
                  (v) =>
                      v[3] == 1 &&
                      v.length > 7 &&
                      const {'ya_idafa', 'ya_zaida'}.contains(v[7]) &&
                      '${v[4]}'.isNotEmpty &&
                      !_same('${v[4]}', span[i]!.t),
                )
                .firstOrNull;
            if (hit == null) continue;
            if (done.add(_key(s, a, w + i))) {
              put(_taken(hit, r, s, a, w + i, 1, '${hit[4]}', withKhulf));
              _ownFont.contains(r) ? worded++ : copied++;
            }
            taken = true;
            break;
          }
        }
        if (taken) continue;
        if (Platform.environment['ASHAB_DEBUG'] == id) {
          stdout.writeln('usul $s:$a:$w «$hafs» ← «$quote» $how');
        }
        usul++;
        continue;
      }
      for (var i = 0; i < c; i++) {
        if (!changed[i]) continue;
        var j = i;
        while (j + 1 < c && changed[j + 1]) {
          j++;
        }
        runs.add((i, j - i + 1));
        i = j;
      }
    } else {
      runs.add((0, c));
    }
    for (final (from, n) in runs) {
      final at = w + from;
      if (!done.add(_key(s, a, at))) continue;
      final hafsRun = span.sublist(from, from + n).map((x) => x!.t).join(' ');
      final text = parts.length == c
          ? parts.sublist(from, from + n).join(' ')
          : completed;
      // A verified reader who reads the run alike, his row at its word.
      // Rows of a chapter of the usul (ياءات الإضافة) before the farsh; the
      // book's «فهو» for «وهو» of the word.
      String bare(String x) => _plain(x).replaceFirst(RegExp('^[وف]'), '');
      List? row;
      String? who;
      for (final chapter in [true, false]) {
        for (final r in _verifiedOrder) {
          if (!readers.contains(r)) continue;
          for (final v in verified[r]!['$s:$a:$at'] ?? const <List>[]) {
            final rule = v.length > 7 ? '${v[7]}' : '';
            if (v[3] != n || _bookUsul.contains(rule) != chapter) continue;
            if (v[5] == 'u' && !_bookUsul.contains(rule)) continue;
            // A stop as the rasm is written, told without a text of its own.
            if (rule != 'rasm_stop' && bare('${v[4]}') != bare(text)) continue;
            row = v;
            who = r;
            break;
          }
          if (row != null) break;
        }
        if (row != null) break;
      }
      if (row != null) {
        put(_taken(row, who!, s, a, at, n, text, withKhulf));
        _ownFont.contains(who) ? worded++ : copied++;
        continue;
      }
      put([
        s,
        a,
        at,
        n,
        text,
        'f',
        withKhulf(
          _says(how) && runs.length == 1
              ? how
              : _orBook(bd.describe(hafsRun, text), how),
        ),
        '',
        {'source': ashabSource, 'book': 'kharouf', 'vocalizationSource': own},
      ]);
      quoted++;
    }
  }
  return (copied: copied, worded: worded, quoted: quoted, usul: usul);
}

/// A verified reader's row taken for [id]: his wording, and his text unless
/// his riwaya has letters of its own (then [text], in Hafs's script).
List _taken(
  List row,
  String who,
  int s,
  int a,
  int at,
  int n,
  String text,
  String Function(String) withKhulf,
) {
  // Qalun's small ya «مَعِے» as Hafs's script writes it.
  final own = _ownFont.contains(who)
      ? text.replaceAll('ے', 'ي')
      : row[4];
  return [
    s,
    a,
    at,
    n,
    own,
    row[5],
    withKhulf('${row.length > 6 ? row[6] : ''}'),
    row.length > 7 ? row[7] : '',
    {
      if (row.length > 8 && row[8] is Map)
        ...Map<String, Object?>.from(row[8] as Map)
          ..remove('source')
          ..remove('sourcePage'),
      'source': ashabSource,
      'farshFrom': who,
    },
  ];
}

/// The book leaves out the small waw and ya of the ha's silah: where Hafs
/// joins the ha and the reading moves it, it is joined too.
String _withHafsSilah(String text, String hafs) {
  final ours = text.split(' '), his = hafs.split(' ');
  if (ours.length != his.length) return text;
  return [
    for (var i = 0; i < ours.length; i++)
      () {
        final h = RegExp(r'ه([ُِ])([ۥۦ])(ٓ?)[ۖ-ۛ]*$').firstMatch(his[i]);
        final o = RegExp(r'ه([ُِ])([ۖ-ۛ]*)$').firstMatch(ours[i]);
        if (h == null || o == null) return ours[i];
        // The silah's letter by the ha's own vowel (غَيۡرِهِۦ for غَيۡرُهُۥ).
        final silah = o[1] == 'ِ' ? 'ۦ' : 'ۥ';
        return '${ours[i].substring(0, o.start)}ه${o[1]}$silah${h[3]}${o[2]}';
      }(),
  ].join(' ');
}

/// The book's wording where the difference cannot be put briefly.
String _orBook(String described, String how) => described.isNotEmpty
    ? described
    : how.replaceAll(RegExp(r'^[،s]+|[،s]+$'), '');

/// The book's words in the Madinah script, letter by letter against Hafs's
/// where they have as many: a changed letter with no vowel takes Hafs's
/// (يَعۡمَلُونَ for تَعۡمَلُونَ), «إ» its kasra (إِنَّهُۥ), the wasl's alif
/// Hafs's (ٱلرِّيَحَ), and the sukun the script's own (يُرۡجَعُونَ).
String _polish(String text, String hafs) {
  final ours = text.split(' '), his = hafs.split(' ');
  if (ours.length != his.length) return text;
  final letter = RegExp(r'([^ً-ٰٟۖ-ۭ])([ً-ٰٟۖ-ۭ]*)');
  String one(String o, String h) {
    final a = letter.allMatches(o).toList(), b = letter.allMatches(h).toList();
    if (a.length != b.length) return o;
    final out = StringBuffer();
    for (var i = 0; i < a.length; i++) {
      var base = a[i][1]!, marks = a[i][2]!;
      final hb = b[i][1]!, hm = b[i][2]!;
      if (base == 'ا' && hb == 'ٱ') base = 'ٱ';
      if (base == 'إ' && !marks.contains('ِ')) marks = 'ِ$marks';
      // Its vowels only, not the dagger alif or a madd of Hafs's letter.
      final vowels = hm.replaceAll(RegExp('[^ً-ْ]'), '');
      if (marks.isEmpty && base != hb && vowels.isNotEmpty && base != 'ا') {
        marks = vowels;
      }
      // The script's sukun, but on the alif written and not read (اْ).
      if (base != 'ا') marks = marks.replaceAll('ْ', 'ۡ');
      out.write('$base$marks');
    }
    return out.toString();
  }

  return [for (var i = 0; i < ours.length; i++) one(ours[i], his[i])].join(' ');
}
