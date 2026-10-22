// Builds assets/data/kharouf.json from the transcription of the hamesh of
// «القرآن الكريم وبهامشه التسهيل لقراءات التنزيل من الشاطبية والدرة»
// (Muhammad Fahd Kharouf, reviewed by Sheikh Karim Rajih), the certified
// source of who reads what, and writes a report comparing it with the
// riwayat data the app has (KFGQPC, Quranpedia).
//
//   dart run tool/build_kharouf.dart [transcribedDir]
//
// transcribedDir (default ../tools/source/books/kharouf) holds one JSON per
// book page: the page's hamesh transcribed exactly, split into entries
// (section, surah, ayahs, word, readings {text, readers, how}, verses).
//
// Only facts are kept for the app: the readings as quoted, who reads them,
// short technical wording of how, and the Shatibiyya / Durrah verses. The
// author's explanatory sentences are not.
//
// Output: assets/data/kharouf.json
//   {"source": ..., "entries": [[surah, ayah, word, count, section,
//     [[text, [riwaya ids], [disputed ids], how, stopOnly, taqlil,
//       [[note on other readers, [riwaya ids]], ...]], ...], [verses]], ...]}
//   tools/source/books/kharouf_report.md — the disagreements to review.
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/book_readings.dart';

/// Every riwaya, in the order of the ten qiraat.
const all = [
  'qalun', 'warsh', 'bazzi', 'qunbul', 'duri_abuamr', 'susi', //
  'hisham', 'ibn_dhakwan', 'shubah', 'hafs', 'khalaf_hamzah', 'khallad',
  'abul_harith', 'duri_kisai', 'ibn_wardan', 'ibn_jammaz', 'ruways', 'rawh',
  'ishaq', 'idris',
];

/// The book's names, longest first so that «خلف عن حمزة» wins over «خلف».
final names = <String, List<String>>{
  'الدوري عن أبي عمرو': ['duri_abuamr'],
  'الدوري عن الكسائي': ['duri_kisai'],
  'دوري أبي عمرو': ['duri_abuamr'],
  'دوري البصري': ['duri_abuamr'],
  'دوري الكسائي': ['duri_kisai'],
  'دوري علي': ['duri_kisai'],
  'السكائي': ['abul_harith', 'duri_kisai'],
  'خلف عن حمزة': ['khalaf_hamzah'],
  'خلف في اختياره': ['ishaq', 'idris'],
  'خلف العاشر': ['ishaq', 'idris'],
  'أبو الحارث': ['abul_harith'],
  'ابن وردان': ['ibn_wardan'],
  'ابن جماز': ['ibn_jammaz'],
  'ابن ذكوان': ['ibn_dhakwan'],
  'ابن كثير': ['bazzi', 'qunbul'],
  'ابن عامر': ['hisham', 'ibn_dhakwan'],
  'أبو عمرو': ['duri_abuamr', 'susi'],
  'أبي عمرو': ['duri_abuamr', 'susi'],
  'أبو جعفر': ['ibn_wardan', 'ibn_jammaz'],
  'أبي جعفر': ['ibn_wardan', 'ibn_jammaz'],
  'المدنيان': ['qalun', 'warsh', 'ibn_wardan', 'ibn_jammaz'],
  'البصريان': ['duri_abuamr', 'susi', 'ruways', 'rawh'],
  'الكوفيون': [
    'shubah',
    'hafs',
    'khalaf_hamzah',
    'khallad',
    'abul_harith',
    'duri_kisai',
    'ishaq',
    'idris',
  ],
  'الأخوان': ['khalaf_hamzah', 'khallad', 'abul_harith', 'duri_kisai'],
  'الحرميان': ['qalun', 'warsh', 'bazzi', 'qunbul'],
  'قالون': ['qalun'],
  'ورش': ['warsh'],
  'نافع': ['qalun', 'warsh'],
  'البزي': ['bazzi'],
  'قنبل': ['qunbul'],
  'المكي': ['bazzi', 'qunbul'],
  'السوسي': ['susi'],
  'البصري': ['duri_abuamr', 'susi'],
  'هشام': ['hisham'],
  'الشامي': ['hisham', 'ibn_dhakwan'],
  'شعبة': ['shubah'],
  'حفص': ['hafs'],
  'عاصم': ['shubah', 'hafs'],
  'خلاد': ['khallad'],
  'حمزة': ['khalaf_hamzah', 'khallad'],
  'الكسائي': ['abul_harith', 'duri_kisai'],
  'رويس': ['ruways'],
  'روح': ['rawh'],
  'يعقوب': ['ruways', 'rawh'],
  'إسحاق': ['ishaq'],
  'إدريس': ['idris'],
  // Alone, «خلف» is Khalaf al-'Ashir, the tenth reader.
  'خلف': ['ishaq', 'idris'],
};

final everyone = ['الباقون', 'للجميع', 'لجميع القراء', 'الجميع', 'الكل'];

/// Letters only, without tashkil, tatweel or the shadda of the print.
String plain(String s) =>
    s.replaceAll(RegExp('[ً-ٰٟۖ-ۭـّ]'), '').replaceAll('ّ', '');

/// Said of stopping only: «وقفاً», not «وصلاً ووقفاً».
bool stopOnly(String s) => s.contains('وقف') && !s.contains('وصل');

class Readers {
  final ids = <String>{};
  final disputed = <String>{};
  bool rest = false;
  bool stopOnly = false;
  bool taqlil = false;
  final unknown = <String>[];
}

/// Parses one reader string of the book: «وبالتقليل ورش بخلفه»,
/// «حمزة بخلف عن خلّاد», «وقفاً الكسائي بلا خلاف», «الباقون».
Readers parseReaders(Iterable<String> raw) {
  final r = Readers();
  for (var s in raw) {
    s = plain(s).replaceAll(RegExp(r'[\[\]():،,.]'), ' ').trim();
    if (stopOnly(s)) r.stopOnly = true;
    if (s.contains('تقليل')) r.taqlil = true;
    // «بخلف عن X»: X is disputed; «X بخلفه / بخلف عنه»: X is disputed.
    final against = RegExp(r'بخلف عن (\S+(?: عن \S+)?)').firstMatch(s);
    var disputedNames = <String>[];
    if (against != null) {
      disputedNames.add(against[1]!);
      s = s.replaceFirst(against[0]!, ' ');
    }
    final selfDisputed = RegExp(r'بخلفه|بخلف عنه|بخلف$|بخلف ').hasMatch(s);
    s = s
        .replaceAll(
          RegExp(
            r'بخلفه|بخلف عنه|بخلف|بلا خلاف|وقفاً|وقفا|وقف|'
            r'وبالتقليل|بالتقليل|معاً|معا|حيث وقع|في هذا الموضع فقط|قرأ|وصلاً',
          ),
          ' ',
        )
        .trim();
    if (everyone.any(s.contains)) {
      r.rest = true;
      continue;
    }
    // Names, longest first.
    var left = ' $s ';
    final keys = names.keys.toList()..sort((a, b) => b.length - a.length);
    final found = <String>[];
    for (final k in keys) {
      for (final form in [' $k ', ' و$k ', ' ل$k ', ' ول$k ']) {
        while (left.contains(form)) {
          found.add(k);
          left = left.replaceFirst(form, ' ');
        }
      }
    }
    final ids = {for (final k in found) ...names[k]!};
    if (selfDisputed) {
      r.disputed.addAll(ids);
    } else {
      r.ids.addAll(ids);
    }
    for (final d in disputedNames) {
      final k = keys.firstWhere((k) => d.contains(k), orElse: () => '');
      if (k.isNotEmpty) {
        r.disputed.addAll(names[k]!);
        r.ids.removeAll(names[k]!);
      }
    }
    final rest = left.trim();
    if (rest.isNotEmpty && ids.isEmpty) r.unknown.add(rest);
  }
  return r;
}

/// Riwayat named in [s] («ووقف حمزة بالتسهيل» → Khalaf, Khallad).
Set<String> namedIn(String s) {
  var left = ' ${plain(s).replaceAll(RegExp(r'[\[\]():،,.«»]'), ' ')} ';
  final keys = names.keys.toList()..sort((a, b) => b.length - a.length);
  final ids = <String>{};
  for (final k in keys) {
    // «للبزي», «وللكسائي»: لِ before ال.
    final li = k.startsWith('ال') ? k.substring(1) : k;
    for (final form in [' $k ', ' و$k ', ' ل$li ', ' ول$li ', ' فل$li ']) {
      while (left.contains(form)) {
        ids.addAll(names[k]!);
        left = left.replaceFirst(form, ' ');
      }
    }
  }
  return ids;
}

/// The book's wording of a reading split in two: what it says of the
/// reading itself, and its clauses on other readers («ووقف حمزة بالتسهيل»,
/// «ولورش ثلاثة البدل»), each with the riwayat it names, to be told only
/// where they are read.
(String, List<List<Object>>) splitHow(String how) {
  final own = <String>[];
  final notes = <List<Object>>[];
  // The book's own sentences; not what it quotes of other books (قال صاحب
  // التيسير..., وأهمل الشاطبي...).
  final sentences = how
      .split('.')
      .where((s) => !RegExp(r'قال |أهمل|كما نقلت').hasMatch(s))
      .join('،');
  for (final clause in sentences.split('،')) {
    final c = clause.trim();
    if (c.isEmpty) continue;
    final ids = namedIn(c);
    if (ids.isEmpty) {
      own.add(c);
    } else {
      notes.add([
        c.replaceFirst(RegExp('^و'), ''),
        [
          for (final id in all)
            if (ids.contains(id)) id,
        ],
      ]);
    }
  }
  final text = own.join('، ').replaceFirst(RegExp('^و(?=[ابتم])'), '');
  return (text, notes);
}

/// Resolve the alif rule cited from الظنونا using the current word's text.
List<List<Object?>> expandFinalAlifReference(
  List<List<Object?>> groups,
  String hafs,
) {
  final withAlif = hafs.replaceAll(RegExp('[۠۟]'), '');
  final withoutAlif = withAlif.replaceFirst(RegExp(r'ا$'), '');
  return [
    for (final g in groups)
      [
        (g[3] as String).startsWith('بإثبات الألف')
            ? withAlif
            : (g[3] as String).startsWith('بحذف الألف')
            ? withoutAlif
            : '',
        ...g.skip(1),
      ],
  ];
}

/// A waqf clause on a named reader does not restrict the other readers
/// sharing a quoted reading. A clause covering the whole group still does.
bool readingStopOnly(
  Readers readers,
  String text,
  String how,
  String own,
  List<List<Object>> notes,
) {
  if (readers.stopOnly) return true;
  if (!stopOnly(how) ||
      (text.isNotEmpty &&
          !RegExp(r'^[وف]?(عند )?(ال)?وقف').hasMatch(how.trim()))) {
    return false;
  }
  if (stopOnly(own)) return true;
  final stopped = <String>{
    for (final n in notes)
      if (stopOnly(n[0] as String) || (n[0] as String).startsWith('قف '))
        ...(n[1] as List).cast<String>(),
  };
  return {...readers.ids, ...readers.disputed}.every(stopped.contains);
}

int _distance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Letters to compare a quote of the book with the Hafs words: the
/// skeleton (hamza seats left out, so شيتما / شِئۡتُمَا differ by one
/// letter only), with sin for sad (سراط / صراط).
String _letters(String s) =>
    skeleton(plain(s)).replaceAll(' ', '').replaceAll('ص', 'س');

/// The Hafs words of [ayah] where [word] is: (index, count) of the best
/// match of each occurrence — the quote as one span, or else as the words
/// of a list «a، b».
List<(int, int)> locate(List<String> ayah, String word) {
  final target = _letters(word);
  if (target.isEmpty) return const [];
  final n = word.trim().split(RegExp(r'\s+')).length;
  final best = <(int, int, double)>[];
  for (var i = 0; i < ayah.length; i++) {
    for (final c in {n, n - 1, n + 1}) {
      if (c < 1 || i + c > ayah.length) continue;
      final s = _letters(ayah.sublist(i, i + c).join());
      final d =
          _distance(s, target) /
          (target.length > s.length ? target.length : s.length);
      if (d <= 0.34) best.add((i, c, d));
    }
  }
  if (best.isEmpty) return const [];
  // Ties broken by the full letters, alef and hamza included (حسنا is not
  // إحسانا).
  String full(String x) =>
      plain(x)
          .replaceAll(RegExp('[^ء-يٱ]'), '')
          .replaceAll(RegExp('[أإآٱ]'), 'ا');
  final whole = full(word);
  double score((int, int, double) b) =>
      b.$3 +
      _distance(full(ayah.sublist(b.$1, b.$1 + b.$2).join()), whole) / 1000;
  final min = best.map((b) => b.$3).reduce((x, y) => x < y ? x : y);
  final ranked = best.where((b) => b.$3 == min).toList()
    ..sort((x, y) => score(x).compareTo(score(y)));
  // Every occurrence as good as the best one (the book's «معاً»), once.
  final out = <(int, int)>[];
  for (final b in ranked) {
    if (out.every((o) => (o.$1 - b.$1).abs() >= o.$2)) out.add((b.$1, b.$2));
  }
  return out;
}

void main(List<String> args) {
  final dir = Directory(
    args.isNotEmpty ? args[0] : '../tools/source/books/kharouf',
  );
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final ayahs = <String, List<String>>{
    for (final a in quran['ayahs'] as List)
      '${a[0]}:${a[1]}': (a[4] as String).split(' '),
  };

  final out = <List<Object?>>[];
  final byRiwaya = <String, List<List<Object?>>>{};
  final unplaced = <String>[];
  final unknownNames = <String, int>{};
  // Riwayat the book says differ from Hafs at a word: (s, a, w) -> ids,
  // and the words of the book's quote.
  final differs = <String, Set<String>>{};
  final spans = <String, int>{};
  // Words the book speaks of (any riwaya).
  final covered = <String>{};
  // The farsh notes so far by the letters of their word, for the book's
  // references back to them; and how many references were told again.
  final refs = <String, (List<List<Object?>>, List<String>)>{};
  var referred = 0;
  // The readings of the note before, for «الحكم السابق».
  var previous = <List<Object?>>[];

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final page = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    for (final e
        in (page['entries'] as List? ?? []).cast<Map<String, dynamic>>()) {
      final section = e['section'] as String? ?? 'farsh';
      if (section == 'adad') continue; // ayah counting: not a reading
      final surah = e['surah'] as int?;
      final word = (e['word'] as String? ?? '').trim();
      if (surah == null || word.isEmpty) continue;
      final groups = <List<Object?>>[];
      final listed = <String>{};
      Readers? rest;
      String restText = '';
      String restHow = '';
      for (final r
          in (e['readings'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final p = parseReaders((r['readers'] as List? ?? []).cast<String>());
        for (final u in p.unknown) {
          unknownNames[u] = (unknownNames[u] ?? 0) + 1;
        }
        final how = (r['how'] as String? ?? '').trim();
        final text = (r['text'] as String? ?? '').trim();
        if (p.rest) {
          rest = p;
          restText = text;
          restHow = how;
          continue;
        }
        listed.addAll(p.ids);
        listed.addAll(p.disputed);
        // «وقفاً لهما الحكم السابق»: on stopping, read as the note before.
        if (p.ids.isEmpty &&
            p.disputed.isEmpty &&
            RegExp('الحكم السابق|كالسابق').hasMatch(how)) {
          for (final g in previous) {
            if ((g[1] as List).contains('hafs')) continue;
            groups.add([
              g[0],
              g[1],
              g[2],
              ['وقفاً', if ((g[3] as String).isNotEmpty) g[3]].join(': '),
              true,
              g[5],
              g[6],
            ]);
          }
          continue;
        }
        if (p.ids.isEmpty && p.disputed.isEmpty) continue;
        final (own, notes) = splitHow(how);
        groups.add([
          text,
          [
            for (final id in all)
              if (p.ids.contains(id)) id,
          ],
          [
            for (final id in all)
              if (p.disputed.contains(id)) id,
          ],
          own,
          // «فمن قرأ بالجمع وقف بالتاء» tells of the stop of a reading
          // quoted, not of a reading on stopping only.
          readingStopOnly(p, text, how, own, notes),
          p.taqlil,
          notes,
        ]);
      }
      if (rest != null) {
        final (own, notes) = splitHow(restHow);
        // A second face can be named in the explanation instead of readers.
        final secondFace = <String>{
          for (final n in notes)
            if ((n[0] as String).contains('الوجه الثاني'))
              ...(n[1] as List).cast<String>(),
        };
        groups.add([
          restText,
          [
            for (final id in all)
              // A reader named alongside الباقون also has this face,
              // even if another face of his was already listed above.
              if (!listed.contains(id) ||
                  ((rest.ids.contains(id) || secondFace.contains(id)) &&
                      !notes.any(
                        (n) =>
                            (n[1] as List).contains(id) &&
                            stopOnly(n[0] as String),
                      )))
                id,
          ],
          const <String>[],
          own,
          rest.stopOnly,
          false,
          notes,
        ]);
      }
      var verses = (e['verses'] as List? ?? []).cast<String>();
      // «هزؤا» انظر ص ١٠، «شيء» تقدم في ص٤، مثل «أأنذرتهم» ص٣: the note
      // referred to, told again here.
      final raw = e['raw'] as String? ?? '';
      // The explicit cross-reference on page 427 carries the three alif
      // readings from الظنونا (page 419) over to الرسولا and السبيلا.
      final alifReference =
          surah == 33 &&
          word == 'الرسولا، السبيلا' &&
          raw.contains('حكمه كما في «الظنونا»');
      if (groups.isEmpty && alifReference) {
        final earlier = refs[_letters('الظنونا')];
        if (earlier != null) {
          groups.addAll(earlier.$1);
          if (verses.isEmpty) verses = earlier.$2;
          referred++;
        }
      }
      if (groups.isEmpty && RegExp('انظر|تقدم|مثل').hasMatch(raw)) {
        final quoted = RegExp(r'(?:تقدم في|مثل|انظر)\s*«([^»]+)»')
            .firstMatch(raw)?[1];
        final earlier = refs[_letters(quoted ?? word)] ?? refs[_letters(word)];
        if (earlier != null) {
          groups.addAll(earlier.$1);
          if (verses.isEmpty) verses = earlier.$2;
          referred++;
        }
      }
      if (groups.isEmpty) continue;
      if (!groups.any((g) => g[4] == true)) previous = groups;
      if (section == 'farsh') {
        for (final piece in word.split('،')) {
          refs[_letters(piece.trim())] = (groups, verses);
        }
      }
      var placed = false;
      final pieces = word.contains('،')
          ? word.split('،').map((p) => p.trim()).where((p) => p.isNotEmpty)
          : [word];
      for (final piece in pieces) {
        for (final a in (e['ayahs'] as List? ?? []).cast<int>()) {
          final words = ayahs['$surah:$a'];
          if (words == null) continue;
          final at = locate(words, piece);
          if (at.isEmpty) continue;
          placed = true;
          final both = (e['raw'] as String? ?? '').contains('معاً');
          for (final (w, c) in both ? at : at.take(1)) {
            final placedGroups = alifReference
                ? expandFinalAlifReference(groups, words[w])
                : groups;
            out.add([surah, a, w, c, section, placedGroups, verses]);
            // Per riwaya: where it reads differently, and how.
            if (section != 'mudgham' &&
                placedGroups.any((g) => (g[1] as List).contains('hafs'))) {
              final ids = <String>{};
              for (final g in placedGroups) {
                if (bookReadingAsHafs(g, placedGroups) || g[4] == true) {
                  continue;
                }
                ids.addAll([...(g[1] as List), ...(g[2] as List)].cast());
              }
              for (final id in ids) {
                // Its readings other than Hafs's, and whether it also reads
                // as Hafs (بخلف عنه).
                final mine = [
                  for (final g in placedGroups)
                    if (!bookReadingAsHafs(g, placedGroups) &&
                        g[4] != true &&
                        ((g[1] as List).contains(id) ||
                            (g[2] as List).contains(id)))
                      g,
                ];
                final first = mine.first;
                final alsoAsHafs = placedGroups.any(
                  (g) =>
                      bookReadingAsHafs(g, placedGroups) &&
                      ((g[1] as List).contains(id) ||
                          (g[2] as List).contains(id)),
                );
                final preferredFirst = (first[6] as List).any(
                  (n) =>
                      (n[1] as List).contains(id) &&
                      RegExp('الراجح|المقدم').hasMatch(n[0] as String),
                );
                String say(List<Object?> g) => [
                  if ((g[0] as String).isNotEmpty) '«${g[0]}»',
                  if ((g[3] as String).isNotEmpty) g[3] as String,
                ].join(' ');
                final wujuh = mine.length > 1
                    ? 'بوجهين: ${mine.map(say).join('، والثاني: ')}'
                    : (first[2] as List).contains(id) || alsoAsHafs
                    ? preferredFirst
                          ? 'بوجهين: الأول: ${say(first)} (وهو المقدم)، والثاني كحفص'
                          : 'بوجهين: الأول كحفص، والثاني: ${say(first)}'
                    : '';
                (byRiwaya[id] ??= []).add([
                  surah,
                  a,
                  w,
                  c,
                  first[0],
                  first[3],
                  section,
                  wujuh,
                ]);
              }
            }
            final key = '$surah:$a:$w';
            covered.add(key);
            // Who differs from Hafs: everyone outside Hafs's group.
            final hafsGroup = placedGroups.firstWhere(
              (g) => (g[1] as List).contains('hafs'),
              orElse: () => const [],
            );
            spans[key] = c;
            if (section == 'farsh' && hafsGroup.isNotEmpty) {
              differs[key] = {
                for (final g in placedGroups)
                  // Stopping only (وقفاً) is not a reading in continuous
                  // recitation, which is what the riwayat data records.
                  if (!identical(g, hafsGroup) && g[4] != true)
                    ...(g[1] as List).cast<String>(),
              };
            }
          }
        }
      }
      if (!placed) {
        unplaced.add('p${page['bookPage']} $surah:${e['ayahs']} «$word»');
      }
    }
  }

  File('assets/data/kharouf.json').writeAsStringSync(
    jsonEncode({
      'source':
          'التسهيل لقراءات التنزيل من الشاطبية والدرة — محمد فهد خاروف، '
          'بمراجعة الشيخ كريم راجح شيخ القراء بدمشق (دار البيروتي، ١٤٢٠هـ)',
      'entries': out,
      // Where each riwaya reads differently from Hafs, per the book:
      // [surah, ayah, word, count, quoted text, how, section].
      'riwayat': byRiwaya,
    }),
  );

  // Compare with the riwayat data of the app.
  final report = StringBuffer()
    ..writeln('# Kharouf vs app data')
    ..writeln()
    ..writeln('Entries placed: ${out.length}. Not placed: ${unplaced.length}.')
    ..writeln();
  final missing = <String, List<String>>{};
  final extra = <String, List<String>>{};
  final quranWords = ayahs;
  for (final id in all.where((id) => id != 'hafs')) {
    final file = File('assets/data/qiraat/$id.json');
    if (!file.existsSync()) continue;
    // Any reading of ours (not our added usul rules), and our farsh ones.
    final any = <String>{};
    final ours = <String, String>{};
    for (final v in (jsonDecode(file.readAsStringSync())['variants'] as List)) {
      for (var w = v[2] as int; w < (v[2] as int) + (v[3] as int); w++) {
        final k = '${v[0]}:${v[1]}:$w';
        any.add(k);
        if (v.length < 8 && v[5] == 'f') {
          ours[k] = '${v[4]} ${v.length > 6 ? v[6] : ''}';
        }
      }
    }
    differs.forEach((key, ids) {
      if (!ids.contains(id)) return;
      final p = key.split(':');
      final w0 = int.parse(p[2]);
      final hit = [
        for (var w = w0; w < w0 + (spans[key] ?? 1); w++) '${p[0]}:${p[1]}:$w',
      ].any(any.contains);
      if (!hit) (missing[id] ??= []).add(key);
    });
    ours.forEach((key, text) {
      if (covered.contains(key) && !(differs[key]?.contains(id) ?? true)) {
        (extra[id] ??= []).add('$key $text');
      }
    });
  }
  String hafsWord(String key) {
    final p = key.split(':');
    final words = quranWords['${p[0]}:${p[1]}']!;
    return words[int.parse(p[2])];
  }

  report.writeln('## The book: differs from Hafs, our data: reads as Hafs');
  for (final id in all) {
    final m = missing[id];
    if (m == null) continue;
    report.writeln('\n### $id (${m.length})');
    for (final k in m) {
      report.writeln('- $k ${hafsWord(k)}');
    }
  }
  report.writeln('\n## The book: reads as Hafs, our data: a farsh difference');
  for (final id in all) {
    final x = extra[id];
    if (x == null) continue;
    report.writeln('\n### $id (${x.length})');
    for (final k in x) {
      report.writeln('- $k');
    }
  }
  report.writeln('\n## Not placed on a word');
  for (final u in unplaced) {
    report.writeln('- $u');
  }
  report.writeln('\n## Reader names not understood');
  unknownNames.forEach((k, v) => report.writeln('- $k ($v)'));
  File('../tools/source/books/kharouf_report.md').writeAsStringSync(
    report.toString().replaceAll(RegExp(r'[ \t]+$', multiLine: true), ''),
  );
  stdout.writeln(
    'kharouf.json: ${out.length} entries, ${unplaced.length} not placed, '
    '${unknownNames.length} unknown names, $referred references told '
    'again; '
    'missing ${missing.values.fold(0, (n, l) => n + l.length)}, '
    'extra ${extra.values.fold(0, (n, l) => n + l.length)}',
  );
}
