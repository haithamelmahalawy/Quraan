// The usul of Qalun, Ibn Kathir and Abu Ja'far, from «أصول أصحاب الصلة», on
// the chapters of the readers already verified: each difference in its own,
// a word's letters in the farsh and its general rules in the usul; what is as
// Hafs told of no word. Never a face. Rerunning replaces the rows carrying this
// source tag; run until the files stop changing (twice).
//   dart run tool/build_ashab_silah_usul.dart
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

import 'apply_first_sakin.dart';

const ashabSilahSource = 'ashab_silah_pdf';
const ashabSilahRiwayat = [
  'qalun',
  'bazzi',
  'qunbul',
  'ibn_wardan',
  'ibn_jammaz',
];

typedef _Word = ({int s, int a, int w, String t});

bool _abuJafar(String id) => id == 'ibn_wardan' || id == 'ibn_jammaz';

const _hamzas = 'ءأإئؤ';

/// The signs of pausing, never the small sukun.
final _pauseSigns = RegExp('[\u06D6-\u06DC]');
final _hamzaCluster = RegExp('[ءأإئؤ][ً-ٰٟ]*');

String _vowelOf(String? h) => h == null
    ? ''
    : h.startsWith('إ') || h.contains('ِ')
    ? 'كسر'
    : h.contains('ُ')
    ? 'ضم'
    : 'فتح';

/// The faces of two hamzas of two words, by the vowels of the first and second.
List<String> _pairWays(String id, String first, String second) {
  if (first == second) {
    if (id == 'qunbul') {
      return [
        'تسهيل الهمزة الثانية، وهو المقدم',
        'إبدال الهمزة الثانية حرف مد',
      ];
    }
    if (_abuJafar(id)) return ['تسهيل الهمزة الثانية'];
    return first == 'فتح'
        ? [
            'إسقاط الهمزة الأولى مع القصر، وهو الأرجح',
            'إسقاط الهمزة الأولى مع المد',
          ]
        : [
            'تسهيل الهمزة الأولى مع المد، وهو الأرجح',
            'تسهيل الهمزة الأولى مع القصر',
          ];
  }
  if (first == 'ضم' && second == 'كسر') {
    return id == 'qalun' || id == 'qunbul'
        ? [
            'تسهيل الهمزة الثانية، وهو المقدم',
            'إبدال الهمزة الثانية واوًا مكسورة',
          ]
        : [
            'إبدال الهمزة الثانية واوًا مكسورة، وهو المقدم',
            'تسهيل الهمزة الثانية',
          ];
  }
  if (second == 'فتح') {
    return [
      first == 'كسر'
          ? 'إبدال الهمزة الثانية ياءً خالصة وصلاً'
          : 'إبدال الهمزة الثانية واوًا خالصة وصلاً',
    ];
  }
  return ['تسهيل الهمزة الثانية وصلاً'];
}

/// The faces of two hamzas of a word, by its Hafs word.
List<String> _wordWays(String id, String hafs) {
  final bare = hafs.replaceAll(RegExp('[ً-ٰٟ\u06D6-\u06ED]'), '');
  final idkhal = id == 'qalun' || _abuJafar(id);
  if (bare.contains('لهتنا')) return ['تسهيل الهمزة الثانية بلا إدخال'];
  if (bare.contains('ريت') || bare.contains('رءي')) {
    return ['تسهيل الهمزة الثانية'];
  }
  if (bare.contains('ئمة') || bare.contains('يمة')) {
    return [
      idkhal && _abuJafar(id)
          ? 'تسهيل الهمزة الثانية مع الإدخال'
          : 'تسهيل الهمزة الثانية بلا إدخال',
    ];
  }
  return [
    idkhal
        ? 'تسهيل الهمزة الثانية مع الإدخال'
        : 'تسهيل الهمزة الثانية بلا إدخال',
  ];
}

const _heads =
    'فتح|ضم|كسر|إسكان|اسكان|سكون|تسهيل|إبدال|ابدال|إظهار|اظهار|إدغام|ادغام|'
    'إخفاء|اخفاء|صلة|مد|قصر|حذف|تشديد|تخفيف|إثبات|تحقيق|رفع|نصب|خفض|إشمام|'
    'زيادة|نقل|ادخال|إدخال|فك|عدم|دون|ترقيق|تفخيم|كسرة|تاء|ياء|نون|همز|تنوين';
final _clauseGap = RegExp(
  '\\s+و\\s?(?=(?:ب|ال|بال)?(?:$_heads))|،\\s*|\\s+مع\\s+(?=الإقلاب|(?:ب|ال|بال)?(?:$_heads))',
);

/// Abu Ja'far's old rows tell these with a word: read as Hafs, or known of
/// the riwaya's general rules, no difference of that word.
final _asHafs = [
  RegExp(r'^ب?(ال)?فتح( الألف.*)?$'),
  RegExp('^ب?(ال)?(مدها|مد المنفصل|مد المتصل|مد الصلة|قصر المنفصل|قصر البدل)'),
  RegExp('^ب?(إ|ا)ظهار'),
  RegExp('^ب?كسرة خالصة'),
  RegExp(
    '^ب?(إ|ا)دغام (التنوين|النون)( الساكنة)? (في |ب)(ال)?(واو|ياء|لام|راء)',
  ),
  RegExp('^ب?(إ|ا)دغام بغنة'),
  RegExp(r'^ب?مد (الألف|الواو|الياء)( الأولى)? (\d|حركتين)'),
  RegExp('^ب?تحقيق الهمز'),
  RegExp('^ب?(دون|عدم) '),
  RegExp(r'^ب?إسكان (ال\S+) دون سكت'),
  RegExp('^ب?تنوين الفاء بالضم'),
  RegExp('^ب?فتح (ال)?ألف'),
  RegExp('^ب?(تفخيم|ترقيق) الراء'),
  RegExp('^ب?رفع (خوف|الفاء) بالتنوين'),
  RegExp('^ب?رفعها'),
  RegExp(r'^\(?ب?فتح الألف'),
  RegExp(r'^ب?كسر الهمزة$'),
  RegExp('^ب?ترقيق اللام'),
  RegExp('^على '),
];

final _noteText = RegExp(
  '^فتح|^كسر|^ترقيق|^السكت| : |\\) ب|صلة|إظهار|اظهار|تسهيل|إبدال|ابدال|إدغام|ادغام|إخفاء|اخفاء|بكسر|بضم|'
  'بفتح|تحقيق|بالسكت',
);
final _silahClause = RegExp('ب?صلة ((ال)?ميم( الجمع)?|الثانية)');
final _haClause = RegExp(
  r'^ب?(صلة (ال)?هاء|قصر الهاء|(كسر|ضم) الهاء (دون|مع) (ال)?صلة|هاء مكسورة دون صلة)',
);

/// Told beside a difference, no difference: its own chapter or none.
final _spoken = RegExp(
  r'\s*(و?(ب)?دون|و?مع|ووعدم|وعدم) (نقل أو سكت|سكت على \S+( الساكنه?)?|سكت عليها|سكت|روم أو إشمام|إمالة( لهما)?|الإمالة|قصر البدل)',
);
final _qasrClause = RegExp(r'^ب?(ال)?قصر$');
final _yaIdafa = RegExp(
  r'^ب?(فتح|إسكان|اسكان|سكون) (ال)?ياء(ين)?( الإضافة| الاضافة)?( \(.*\))?$',
);
final _usulWords = RegExp(
  'صلة|إبدال|ابدال|تسهيل|إدغام|ادغام|إخفاء|سكت|نقل|إمالة|تقليل|حذف الهمز|'
  r'تخفيف الهمز|زيادة الهمز|^بالهمز|إشمام|^ب?(ال)?قصر$',
);
final _tahrik = RegExp(
  r'^ب?ضم (النون|الواو|اللام|التاء|الدال|الطاء)$|^ب?ضم نون التنوين',
);

/// Abu Ja'far's source wrote a note where the reading goes.
void _noteToHow(List v) {
  while (v.length < 7) {
    v.add('');
  }
  final text = '${v[4]}', how = '${v[6] ?? ''}';
  if (text.contains('بالسكت')) {
    v[4] = '';
    v[5] = 'u';
    v[6] = 'بالسكت على الحروف المقطعة';
    return;
  }
  if (how.isNotEmpty || !_noteText.hasMatch(text)) return;
  // «رِيَآء : بياء مفتوحة»: the reading, then what is told of it.
  final parts = text.split(':');
  final word = parts.length > 1 ? parts.first.trim() : '';
  v[4] = word.isNotEmpty && !_noteText.hasMatch(word) ? word : '';
  v[6] = parts.last.replaceFirst(RegExp(r'^[^()]*\)\s*'), '').trim();
}

/// A row's chapter by what its remaining words tell; the kind only, never the
/// face. Mixed rows have had their general rules set apart by now.
void _setChapter(List v, String id, List<String> hafs) {
  while (v.length < 8) {
    v.add('');
  }
  final how = '${v[6]}';
  final bare = hafs.map(skeleton).toList();
  final endsInYa = bare.any((w) => RegExp(r'[يى]$').hasMatch(w));
  if (RegExp('نقل.*همزة  ?الوصل|همزة استفهام قبل همزة الوصل').hasMatch(how)) {
    v[5] = 'h';
    v[7] = 'hamza_wasl';
  } else if (how.isNotEmpty && hafs.any((w) => w.contains('هَٰٓأَن'))) {
    v[5] = 'h';
    v[7] = 'ha_antum';
  } else if (_yaIdafa.hasMatch(how) && (how.contains('ضافة') || endsInYa)) {
    v[5] = 'u';
    v[7] = 'ya_idafa';
  } else if (RegExp('إثبات (ال)?ياء').hasMatch(how) && !how.contains('حذف')) {
    v[5] = 'u';
    v[7] = 'ya_zaida';
  } else if (RegExp(r'^ب?(ال)?(إدغام|ادغام)').hasMatch(how) &&
      !RegExp(' و(ب|ال)?(فتح|ضم|كسر|تشديد|تخفيف|زيادة)').hasMatch(how)) {
    v[5] = 'u';
    v[7] = 'idgham_saghir';
  } else if (RegExp(r'^ب?(ال)?(إخفاء|اخفاء)').hasMatch(how)) {
    v[5] = 'u';
    v[7] = 'ikhfa';
  } else if (_haClause.hasMatch(how)) {
    v[5] = 'u';
    v[7] = 'ha_kinaya';
  } else if (RegExp('(إبدال|ابدال|تسهيل|تخفيف|حذف) ?(ال)?(همز|الثانية)')
          .hasMatch(how) &&
      !RegExp('الواو همزة|بالتاء|بالياء|تشديد|بكسر (?!الهاء)').hasMatch(how) &&
      (!how.contains('بضم') || how.contains('حذف الهمزة'))) {
    v[5] = 'h';
  } else if (_abuJafar(id)) {
    if (_tahrik.hasMatch(how)) {
      v[5] = 'u';
      v[7] = 'first_sakin';
    } else if (RegExp('السكت على|السكت عليها').hasMatch(how)) {
      v[5] = 'u';
      v[7] = 'fawatih';
    } else if (RegExp('مسهلة|إدخال ألف').hasMatch(how) &&
        !how.contains('زكري')) {
      v[5] = 'h';
    }
  }
  // Only a word's letters or vowels: farsh, whatever its source called it.
  if ('${v[7]}'.isEmpty &&
      v[5] != 'f' &&
      how.isNotEmpty &&
      !_usulWords.hasMatch(how)) {
    v[5] = 'f';
  }
}

/// The word with its mim of the plural joined to a waw.
String _withSilah(String word, bool beforeHamza) {
  final at = word.lastIndexOf('م');
  if (at < 0) return word;
  return '${word.substring(0, at)}مُۥ${beforeHamza ? 'ٓ' : ''}';
}

Map<String, int> buildAshabSilahUsul(
  Map quran,
  Map data,
  String id, {
  required Set<String> mimSites,
  required Set<String> wordSites,
  Map<String, String> haSites = const {},
  List<List> taStops = const [],
}) {
  final rows = <List>[
    for (final v in (data['variants'] as List).cast<List>())
      if (!(v.length > 8 && v[8] is Map && v[8]['source'] == ashabSilahSource))
        [...v],
  ];
  final words = <_Word>[
    for (final a in quran['ayahs'] as List)
      for (final (w, t) in (a[4] as String).split(' ').indexed)
        (s: a[0] as int, a: a[1] as int, w: w, t: t),
  ];
  final hafsAt = {for (final w in words) '${w.s}:${w.a}:${w.w}': w.t};
  final at = <String, List<List>>{};
  for (final v in rows) {
    (at['${v[0]}:${v[1]}:${v[2]}'] ??= []).add(v);
  }
  final counts = <String, int>{};
  void count(String k) => counts.update(k, (n) => n + 1, ifAbsent: () => 1);

  void add(
    _Word w,
    String rule,
    String how, {
    String text = '',
    String kind = 'u',
    List<String> ways = const [],
    String context = '',
    bool note = false,
  }) {
    final row = <Object>[
      w.s,
      w.a,
      w.w,
      1,
      text,
      kind,
      how,
      rule,
      {
        'source': ashabSilahSource,
        if (context.isNotEmpty) 'context': context,
        if (ways.isNotEmpty) 'ways': ways,
        if (note) 'hamesh': true,
      },
    ];
    rows.add(row);
    (at['${w.s}:${w.a}:${w.w}'] ??= []).add(row);
    count(rule.isEmpty ? 'silah' : rule);
  }

  /// Marks a row of the source as told by [rule], its reading unchanged.
  void tag(List v, String rule, String how, List<String> ways, String context) {
    while (v.length < 9) {
      v.add(v.length == 7 ? '' : (v.length == 8 ? <String, Object>{} : ''));
    }
    v[5] = 'h';
    v[6] = how;
    v[7] = rule;
    final meta = v[8] is Map
        ? Map<String, Object?>.from(v[8] as Map)
        : <String, Object?>{};
    v[8] = meta
      ..['context'] = context
      ..['ways'] = ways;
    count(rule);
  }

  String faces(List<String> ways) =>
      ways.length == 1 ? 'ب${ways.single}' : 'بوجهين: ${ways.join('؛ أو ')}';

  if (_abuJafar(id)) {
    for (final v in rows) {
      if ('${v.length > 7 ? v[7] : ''}'.isEmpty) _noteToHow(v);
      if (v.length > 6) {
        v[6] = '${v[6] ?? ''}'.replaceAll(
          RegExp(r'\s*و?(ب)?دون (أي )?إمالة( فيها| لهما)?'),
          '',
        );
      }
    }
  }

  // ---- أئمة، هار: the book and the source agree against the old rows.
  for (final key in const [
    '9:12:10',
    '21:73:1',
    '28:5:9',
    '28:41:1',
    '32:24:2',
  ]) {
    final hafs = hafsAt[key]!;
    final ways = _wordWays(id, hafs);
    final own = (at[key] ?? const <List>[])
        .where((v) => v[5] != 'f' || RegExp('إبدال الهمزة').hasMatch('${v[6]}'))
        .toList();
    if (own.isNotEmpty) {
      for (final v in own) {
        tag(v, 'tasheel_word', faces(ways), ways, hafs);
      }
    } else {
      final p = key.split(':').map(int.parse).toList();
      add(
        (s: p[0], a: p[1], w: p[2], t: hafs),
        'tasheel_word',
        faces(ways),
        kind: 'h',
        text: hafs.replaceFirst('ئِ', 'ىِ۪'),
        ways: ways,
        context: hafs,
      );
    }
  }
  if (id == 'qalun') {
    for (final v in at['9:109:16'] ?? const <List>[]) {
      v[6] = 'بالإمالة الكبرى';
    }
  }

  // ---- الهمزتان من كلمة: rows told only as an eased hamza.
  final easedOnly = RegExp(
    r'^(بصلة ميم الجمع و)?(بتخفيف الهمزة|تخفيف الهمزة|بإبدال الهمزة ياءً|إبدال الهمزة ياءً)( وإثبات الألف| وزيادة الواو| وإسكان اللام)?$'
    r'|^بحذف الهمزة وإسكان اللام$|^بالإشمام وتخفيف الهمزة$',
  );
  for (final key in wordSites) {
    final hafs = hafsAt[key];
    if (hafs == null) continue;
    for (final v in at[key] ?? const <List>[]) {
      final how = '${v.length > 6 ? v[6] ?? '' : ''}';
      if (!easedOnly.hasMatch(how)) continue;
      final ways = _wordWays(id, hafs);
      tag(
        v,
        'tasheel_word',
        [
          faces(ways),
          if (how.contains('صلة ميم الجمع')) 'بصلة ميم الجمع',
        ].join('، '),
        ways,
        hafs,
      );
    }
  }
  // ءَامَنتُمۡ: the sources tell it word by word.
  for (final key in const ['7:123:2', '20:71:1', '26:49:1']) {
    final hafs = hafsAt[key]!;
    final p = key.split(':').map(int.parse).toList();
    final own = at[key] ?? const <List>[];
    // قنبل: his waw in the Araf, and as Hafs in Taha.
    if (id == 'qunbul' && !key.startsWith('26')) continue;
    const ways = ['تسهيل الهمزة الثانية بلا إدخال'];
    final told = own.where((v) => v[5] != 'f').toList();
    if (told.isNotEmpty) {
      for (final v in told) {
        tag(v, 'tasheel_word', '${faces(ways)}، بصلة ميم الجمع', ways, hafs);
      }
    } else if (own.isEmpty) {
      add(
        (s: p[0], a: p[1], w: p[2], t: hafs),
        'tasheel_word',
        '${faces(ways)}، بصلة ميم الجمع',
        kind: 'h',
        text: _withSilah(hafs.replaceFirst('ءَا', 'ءَاٰ۬'), false),
        ways: ways,
        context: hafs,
      );
    }
  }

  // ---- الهمزتان من كلمتين.
  final pairHow = RegExp(
    'تخفيف الهمزة|حذف الهمزة|تسهيل|إبدال الهمزة|تشديد الواو|'
    'إبدال همزة|ابدال',
  );
  final otherFarsh = RegExp('بضم|بفتح الياء|بالتاء|بالياء|بكسر (?!الهاء)');
  for (var n = 0; n + 1 < words.length; n++) {
    final a = words[n], b = words[n + 1];
    if (a.s != b.s) continue;
    final inAyah = a.a == b.a;
    if (!inAyah) continue;
    final last = _hamzaCluster.allMatches(a.t).lastOrNull;
    // The hamza ends the first word, and opens the second.
    if (last == null || last.end != a.t.replaceAll(_pauseSigns, '').length) {
      continue;
    }
    if (!_hamzas.contains(b.t[0])) continue;
    final first = _vowelOf(last.group(0)),
        second = _vowelOf(_hamzaCluster.matchAsPrefix(b.t)?.group(0));
    if (second.isEmpty) continue;
    final ways = _pairWays(id, first, second);
    final context = '${a.t} ${b.t}';
    final onFirst = first == second && (id == 'qalun' || id == 'bazzi');
    final keyA = '${a.s}:${a.a}:${a.w}', keyB = '${b.s}:${b.a}:${b.w}';
    final told = [
      for (final key in [keyA, keyB])
        for (final v in at[key] ?? const <List>[])
          if (v.length > 6 &&
              (v[5] != 'f' ||
                  // Abu Ja'far's source tells these among its farsh.
                  (_abuJafar(id) && !otherFarsh.hasMatch('${v[6]}'))) &&
              (v.length < 8 || '${v[7]}'.isEmpty) &&
              pairHow.hasMatch('${v[6]}'))
            (key, v),
    ];
    final silah = told.any((t) => '${t.$2[6]}'.contains('صلة'));
    final how = [faces(ways), if (silah) 'بصلة ميم الجمع'].join('، ');
    final ibdal = ways.length == 1 && ways.single.startsWith('إبدال');
    final rule = onFirst
        ? 'tasheel_pair_first'
        : ibdal
        ? (ways.single.contains('ياء') ? 'ibdal_ya' : 'ibdal_waw')
        : 'tasheel_pair';
    if (told.isEmpty) continue;
    for (final (key, v) in told.skip(1)) {
      rows.remove(v);
      at[key]!.remove(v);
    }
    final (key, row) = told.first;
    final target = onFirst ? a : b;
    if (key != '${target.s}:${target.a}:${target.w}') {
      at[key]!.remove(row);
      (at['${target.s}:${target.a}:${target.w}'] ??= []).add(row);
      row[2] = target.w;
      row[4] = '';
    }
    row[3] = 1;
    if (ibdal) row[4] = target.t;
    // Abu Ja'far's rows wrote both words, or a note, where the reading goes.
    if (_abuJafar(id)) row[4] = '';
    tag(row, rule, how, ways, context);
  }

  // ---- Each difference in its chapter: a word's farsh apart from its usul.
  for (final v in [...rows]) {
    if (v.length > 7 && '${v[7]}'.isNotEmpty) continue;
    if (v.length > 8 && v[8] is Map && v[8]['source'] == ashabSilahSource) {
      continue;
    }
    if (v.length < 7) continue;
    final span = (v[3] as num).toInt();
    final hafs = [
      for (var d = 0; d < (span < 1 ? 1 : span); d++)
        ?hafsAt['${v[0]}:${v[1]}:${(v[2] as int) + d}'],
    ];
    // Qalun's and Ibn Kathir's rows without a word of how: the three of
    // «ترك السكت», else the word's own farsh.
    if ('${v[6] ?? ''}'.isEmpty && v[5] != 'f') {
      if (hafs.any(
        (w) => RegExp('مرقدنا|عوجا|من راق|بل ران').hasMatch(skeleton(w)),
      )) {
        v[5] = 'u';
        v[6] = 'بالوصل دون سكت';
        while (v.length < 8) {
          v.add('');
        }
        v[7] = 'no_sakt';
      } else if ('${v[4]}'.isNotEmpty) {
        v[5] = 'f';
      }
      continue;
    }
    final said = '${v[6] ?? ''}'
        .replaceAll('دون صلة للهاء', 'وقصر الهاء')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(
          'بكسر القاف والهاء مع مد الصلة حركتين',
          'بصلة الهاء وكسر القاف',
        )
        .replaceFirst(RegExp(r'^[^()]*\)\s*'), '');
    final clauses = said
        .split(_clauseGap)
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (clauses.isEmpty) continue;
    // بالإدغام beside another clause: as Hafs, the other is the difference.
    if (clauses.length > 1) {
      clauses.removeWhere(
        (c) => RegExp(r'^ب?(ال)?إدغام$').hasMatch(c) && !said.contains('القصر'),
      );
    }
    final hadSilah = clauses.any(_silahClause.hasMatch);
    for (var c = clauses.length - 1; c >= 0; c--) {
      if (!_silahClause.hasMatch(clauses[c])) continue;
      final rest = clauses[c].replaceAll(_silahClause, '').trim();
      if (!RegExp('$_heads|الإقلاب').hasMatch(rest)) {
        clauses.removeAt(c);
      } else {
        clauses[c] = rest;
      }
    }
    if (hadSilah) {
      clauses.removeWhere((c) => RegExp('^ب?(مدها|مد الصلة)').hasMatch(c));
    }
    if (_abuJafar(id)) {
      clauses.removeWhere((c) {
        if (_asHafs.any((re) => re.hasMatch(c))) return true;
        return RegExp(r'^ب?كسر الهاء$').hasMatch(c) &&
            hafs.any((w) => w.contains('هِ'));
      });
      for (var c = clauses.length - 1; c >= 0; c--) {
        final rest = clauses[c].replaceAll(_spoken, '').trim();
        if (rest.isEmpty) {
          clauses.removeAt(c);
        } else {
          clauses[c] = rest;
        }
      }
    }
    // Abu Ja'far's ikhfa has its own rows; وَإِسۡرَٰٓءِيلَ tells its easing thus.
    if (_abuJafar(id)) {
      clauses.removeWhere((c) => RegExp('^ب?(ال)?(إخفاء|اخفاء)').hasMatch(c));
      if (hafs.any((w) => w.contains('سۡرَٰٓءِ')) &&
          clauses.any((c) => c.contains('تسهيل'))) {
        clauses
          ..clear()
          ..add('بتسهيل الهمزة مع التوسط أو القصر');
      }
    }
    // A sakin hamza told off its word: its own row is built below.
    if (_abuJafar(id) &&
        '${v[4]}'.isEmpty &&
        clauses.length == 1 &&
        RegExp(r'^ب?(إ|ا)بدال الهمزة$').hasMatch(clauses.single) &&
        hafs.any((w) => RegExp('[ءأإئؤ]ۡ|ـۡٔ').hasMatch(w))) {
      rows.remove(v);
      at['${v[0]}:${v[1]}:${v[2]}']?.remove(v);
      count('as_hafs');
      continue;
    }
    final place = (s: v[0] as int, a: v[1] as int, w: v[2] as int, t: '');
    final key = '${v[0]}:${v[1]}:${v[2]}';
    if (clauses.isEmpty) {
      // All of it as Hafs, or the silah told by its own row below.
      if (_abuJafar(id) || id == 'qalun') {
        rows.remove(v);
        at[key]?.remove(v);
        count('as_hafs');
      }
      continue;
    }
    // General rules told of a word whose letters also differ: their own row,
    // which stays as its source's did, never rebuilt from the row it left.
    void apart(String rule, String told, String kind) {
      add(place, rule, told, kind: kind);
      (rows.last[8] as Map).remove('source');
    }

    if (clauses.length > 1) {
      for (final c in clauses.where(_haClause.hasMatch).toList()) {
        clauses.remove(c);
        apart('ha_kinaya', c, 'u');
      }
      for (final c in clauses.where(_qasrClause.hasMatch).toList()) {
        clauses.remove(c);
        apart('', 'بالقصر', 'u');
      }
    }
    if (hadSilah && !_abuJafar(id) && id != 'qalun') {
      apart('', 'بصلة ميم الجمع', 'u');
    }
    var how = clauses.join(' و').replaceFirst(RegExp(r'^و\s*'), '');
    // بالإدغام والقصر: the idgham as Hafs, the word's madd alone told.
    if (RegExp(r'^ب?(ال)?إدغام$').hasMatch(how) && said.contains('القصر')) {
      how = 'بالقصر';
    }
    // ءَآلۡـَٰٔنَ: on the chapter of the question's hamza before a wasl.
    if (how == 'باللام' && id == 'qalun') {
      how = 'بنقل حركة الهمزة إلى اللام';
      while (v.length < 8) {
        v.add('');
      }
      v[5] = 'h';
      v[6] = how;
      v[7] = 'hamza_wasl';
      continue;
    }
    if (how == 'إسكان الهاء' && '${v[4]}'.isEmpty) {
      rows.remove(v);
      at[key]?.remove(v);
      continue;
    }
    final kind = v[5];
    v[6] = how;
    _setChapter(v, id, hafs);
    if (v[5] != kind) count('kind_${kind}_${v[5]}');
    if ('${v[7]}'.isNotEmpty) count('rule_${v[7]}');
    // وَجَآءَ أَمۡرُ رَبِّكَ: told of two words, on their shared chapter.
    if (_abuJafar(id) &&
        '${v[7]}'.isEmpty &&
        RegExp('همزة \\(|الهمز الثانية|إبدالها واو|^تسهيل الثانية|ادخال|إدخال')
            .hasMatch(how) &&
        how.contains('تسهيل')) {
      v[5] = 'h';
      v[7] =
          RegExp('أنتم|ءانتم|ادخال|إدخال').hasMatch(how) ||
              hafs.any((w) => w.contains('رَءَي') || w.contains('رَءَيۡ'))
          ? 'tasheel_word'
          : 'tasheel_pair';
    }
    // أَرَءَيۡتُمۡ and its like: on the shared chapter of the two hamzas.
    if (_abuJafar(id) &&
        '${v[7]}'.isEmpty &&
        RegExp('تسهيل (الهمزة )?الثانية').hasMatch(how)) {
      for (var d = 0; d < hafs.length; d++) {
        final there = '${v[0]}:${v[1]}:${(v[2] as int) + d}';
        if (!wordSites.contains(there) &&
            !RegExp('رءي|رأي').hasMatch(skeleton(hafs[d]))) {
          continue;
        }
        const ways = ['تسهيل الهمزة الثانية'];
        at[key]?.remove(v);
        (at[there] ??= []).add(v);
        v[2] = (v[2] as int) + d;
        v[3] = 1;
        v[4] = '';
        tag(v, 'tasheel_word', faces(ways), ways, hafs[d]);
        break;
      }
    }
  }

  if (_abuJafar(id)) {
    for (final v in rows) {
      if (v.length < 8 ||
          v.length > 8 && v[8] is Map && v[8]['source'] == ashabSilahSource) {
        continue;
      }
      final how = '${v[6]}';
      switch (v[7]) {
        case 'ya_idafa':
          v[6] = RegExp('فتح').hasMatch(how) ? 'بفتح الياء' : 'بإسكان الياء';
        case 'ya_zaida'
            when RegExp(r'^ب?إثبات (ال)?ياء( (ساكنة )?(بعد|في) .*)?$')
                .hasMatch(how):
          v[6] = 'بإثبات الياء الزائدة وصلاً وحذفها وقفًا';
        case 'idgham_saghir':
          v[6] = how
              .replaceAll('ادغام', 'إدغام')
              .replaceFirst(RegExp('^ب?(ال)?إدغام'), 'بإدغام')
              .replaceFirst(RegExp(r'\(.*\)'), '')
              .trim();
        case 'tasheel_word' || 'tasheel_pair':
          final eased = how.contains('تسهيل') && !how.contains('إبدال');
          if (!eased) break;
          if (how.contains('ادخال') || how.contains('إدخال')) {
            v[6] = 'بتسهيل الهمزة الثانية مع الإدخال';
            final meta = v.length > 8 && v[8] is Map
                ? v[8] as Map
                : <String, Object?>{};
            meta['ways'] = const ['تسهيل الهمزة الثانية مع الإدخال'];
            if (v.length > 8) {
              v[8] = meta;
            } else {
              v.add(meta);
            }
          } else {
            v[6] = 'بتسهيل الهمزة الثانية';
          }
      }
    }
  }

  // ---- وَهۡوَ، فَهۡيَ: of the book's farsh words, Qalun's and Abu Ja'far's.
  if (_abuJafar(id)) {
    final told = <String>{};
    for (final v in rows) {
      if (!RegExp('(إسكان|اسكان) (ال)?ها|هْو|هْي')
          .hasMatch('${v[4]} ${v[6]}')) {
        continue;
      }
      final span = (v[3] as num).toInt();
      for (var d = 0; d < (span < 1 ? 1 : span); d++) {
        told.add('${v[0]}:${v[1]}:${(v[2] as int) + d}');
      }
    }
    haSites.forEach((key, text) {
      if (told.contains(key)) return;
      final p = key.split(':').map(int.parse).toList();
      add(
        (s: p[0], a: p[1], w: p[2], t: text),
        'ha_sakin',
        'بإسكان الهاء',
        text: text,
        kind: 'f',
      );
    });
    for (final v in rows) {
      if (v.length > 7 && v[7] == 'ha_sakin') v[7] = '';
    }
  }

  // ---- صلة ميم الجمع.
  if (id == 'qalun' || _abuJafar(id)) {
    final next = <String, String>{};
    for (var n = 0; n + 1 < words.length; n++) {
      if (words[n].s == words[n + 1].s) {
        next['${words[n].s}:${words[n].a}:${words[n].w}'] = words[n + 1].t;
      }
    }
    for (final key in mimSites) {
      final own = at[key] ?? const <List>[];
      if (own.any((v) => '${v.length > 6 ? v[6] : ''}'.contains('صلة'))) {
        continue;
      }
      final hafs = hafsAt[key];
      if (hafs == null) continue;
      final p = key.split(':').map(int.parse).toList();
      final w = (s: p[0], a: p[1], w: p[2], t: hafs);
      final after = next[key] ?? '';
      final hamzaNext = after.isNotEmpty && _hamzas.contains(after[0]);
      // A word told otherwise keeps its row: the silah is told beside it.
      final written = own.where(
        (v) => '${v[4]}'.isNotEmpty && !'${v[4]}'.contains(' '),
      );
      if (written.isNotEmpty) {
        final v = written.first;
        v[4] = _withSilah('${v[4]}', hamzaNext);
        add(w, '', 'بصلة ميم الجمع');
        count('silah_beside');
        continue;
      }
      add(
        w,
        '',
        'بصلة ميم الجمع',
        text: _withSilah(hafs.replaceAll(_pauseSigns, ''), hamzaNext),
      );
    }
  }

  // ---- الهمز المفرد: every sakin hamza of Abu Ja'far, save those excepted.
  if (_abuJafar(id)) {
    final excepted = RegExp('^[وف]?(أنبئهم|نبئهم)\$');
    final sakin = RegExp('[ءأإئؤ]ۡ|ـۡٔ|ـٔۡ');
    // رءيا and its like are merged, told apart.
    final merged = RegExp('رءي|رؤي|رئي');
    for (final w in words) {
      final m = sakin.firstMatch(w.t);
      if (m == null) continue;
      if (excepted.hasMatch(skeleton(w.t))) continue;
      if (merged.hasMatch(w.t.replaceAll(RegExp('[ً-ٰٟ\u06E1]'), ''))) continue;
      final key = '${w.s}:${w.a}:${w.w}';
      if ((at[key] ?? const <List>[]).any(
        (v) => RegExp('إبدال').hasMatch('${v.length > 6 ? v[6] : ''}'),
      )) {
        continue;
      }
      final before = w.t.substring(0, m.start);
      final vowel = RegExp('[َُِ]').allMatches(before).lastOrNull?.group(0);
      final letter = vowel == 'ُ'
          ? 'و'
          : vowel == 'ِ'
          ? 'ي'
          : 'ا';
      final name = letter == 'و'
          ? 'واوًا'
          : letter == 'ي'
          ? 'ياءً'
          : 'ألفًا';
      add(
        w,
        'ibdal_single',
        'بإبدال الهمزة $name',
        kind: 'h',
        text: '${w.t.substring(0, m.start)}$letter${w.t.substring(m.end)}',
      );
    }
    // الإخفاء: the nun sakina and tanween before kha and ghayn.
    for (var n = 0; n + 1 < words.length; n++) {
      final a = words[n], b = words[n + 1];
      if (a.s != b.s || a.a != b.a) continue;
      if (!const {'خ', 'غ'}.contains(b.t[0])) continue;
      final plain = a.t.replaceAll(_pauseSigns, '');
      if (!RegExp('(نۡ|[ًٌٍٖٗٞ]ا?)\$').hasMatch(plain)) continue;
      add(a, 'ikhfa', 'بإخفاء النون عند ${b.t[0] == 'خ' ? 'الخاء' : 'الغين'}');
    }
    // Their exceptions are told by Ibn Jazari: they keep the izhar.
    rows.removeWhere(
      (v) =>
          v.length > 7 &&
          v[7] == 'ikhfa' &&
          const {'4:135', '17:51'}.contains('${v[0]}:${v[1]}'),
    );
  }

  // ---- The new chapters.
  void fawatih(String key, String how, List<String> ways) {
    final p = key.split(':').map(int.parse).toList();
    final hafs = hafsAt[key];
    if (hafs == null) return;
    add((s: p[0], a: p[1], w: p[2], t: hafs), 'fawatih', how, ways: ways);
  }

  if (!_abuJafar(id)) {
    fawatih('19:1:0', 'مد العين بالتوسط أو الإشباع', const [
      'التوسط',
      'الإشباع',
    ]);
    fawatih('42:2:0', 'مد العين بالتوسط أو الإشباع', const [
      'التوسط',
      'الإشباع',
    ]);
    fawatih('36:1:0', 'بإظهار النون', const ['الإظهار']);
    fawatih('68:1:0', 'بإظهار النون', const ['الإظهار']);
  }
  if (_abuJafar(id)) {
    for (final v in rows) {
      if (v[5] == 'u' &&
          v.length > 6 &&
          RegExp('السكت على').hasMatch('${v[6]}') &&
          '${v.length > 7 ? v[7] : ''}'.isEmpty) {
        while (v.length < 8) {
          v.add('');
        }
        v[7] = 'fawatih';
        count('fawatih');
      }
    }
    // All of it the one sakt; what else it told of them is as Hafs.
    for (final v in rows) {
      if (v.length > 7 && v[7] == 'fawatih') {
        v[4] = '';
        v[6] = 'بالسكت على كل حرف من الحروف المقطعة';
      }
    }
  }
  if (id == 'bazzi') {
    for (final v in rows) {
      if (v[5] == 'u' &&
          v[6] == 'بالمد' &&
          '${v.length > 7 ? v[7] : ''}'.isEmpty) {
        while (v.length < 8) {
          v.add('');
        }
        v[7] = 'bazzi_ta';
        count('bazzi_ta');
      }
    }
    // Told at the end of each sura, no difference of its word.
    final lastOf = <int, _Word>{};
    for (final w in words) {
      if (w.s >= 93) lastOf[w.s] = w;
    }
    for (final w in lastOf.values) {
      add(w, 'takbir', 'التكبير من آخر الضحى إلى آخر الناس', note: true);
    }
  }
  _bookGaps(id, rows, at, words, taStops, count);
  // They all read the separated madd short: no madd sign on a word's last
  // letter before a hamza of the next word (لَهُمُۥ أَمۡ، بِمَا أُنزِلَ).
  final next = <String, String>{};
  for (var n = 0; n + 1 < words.length; n++) {
    next['${words[n].s}:${words[n].a}:${words[n].w}'] = words[n + 1].t;
  }
  for (final v in rows) {
    if (v.length > 7 && v[7] == 'fawatih') continue;
    final text = '${v[4]}';
    final end = RegExp('ٓ([ۖ-ۜ]*)\$');
    if (!end.hasMatch(text)) continue;
    final last = (v[2] as int) + (v[3] as num).toInt() - 1;
    final after = next['${v[0]}:${v[1]}:$last'] ?? '';
    if (!RegExp('^[ءأإآ]').hasMatch(after)) continue;
    v[4] = text.replaceFirstMapped(end, (m) => m[1]!);
    count('qasr_munfasil_sign');
  }
  // A farsh telling only the ha read with kasra, where Hafs reads it so
  // («فلا خوفٌ عليهِمُ»: as against Yaqub's damma): nothing differs.
  rows.removeWhere((v) {
    if (v[5] != 'f' || !RegExp(r'^ب?كسر ?الهاء$').hasMatch('${v[6]}'.trim())) {
      return false;
    }
    final hafs = [
      for (var d = 0; d < (v[3] as num).toInt(); d++)
        hafsAt['${v[0]}:${v[1]}:${(v[2] as int) + d}'] ?? '',
    ].join(' ');
    final gone = hafs.contains('هِ') && !RegExp('ه[ُۡۥ]').hasMatch(hafs);
    if (gone) count('same_kasr_ha');
    return gone;
  });
  applyFirstSakin(id, quran, rows);
  data['variants'] = rows;
  data['reviewedUsul'] = true;
  return counts;
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  Map load(String id) =>
      jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync()) as Map;
  // Where a mim of the plural is joined: Ibn Kathir's rows, verified against
  // «وصل ضم ميم الجمع قبل محرك دراكا».
  final mimSites = <String>{
    for (final v in (load('bazzi')['variants'] as List).cast<List>())
      if (RegExp('صلة ميم الجمع').hasMatch('${v.length > 6 ? v[6] : ''}'))
        '${v[0]}:${v[1]}:${v[2]}',
  };
  final wordSites = <String>{
    for (final v in (load('warsh')['variants'] as List).cast<List>())
      if (v.length > 7 && v[7] == 'tasheel_word') '${v[0]}:${v[1]}:${v[2]}',
    for (final v in (load('hisham')['variants'] as List).cast<List>())
      if (v.length > 7 && v[7] == 'tasheel_word') '${v[0]}:${v[1]}:${v[2]}',
  };
  // وَهۡوَ، فَهۡيَ: as Qalun's rows; never «لَهۡوٞ», the noun.
  final haSites = <String, String>{
    for (final v in (load('qalun')['variants'] as List).cast<List>())
      if (v.length > 6 &&
          v[6] == 'بإسكان الهاء' &&
          RegExp(r'^[وفل](هو|هي|هى)$').hasMatch(skeleton('${v[4]}')))
        '${v[0]}:${v[1]}:${v[2]}': '${v[4]}',
  };
  // Ya'qub stops on an open feminine ta as Ibn Kathir does: «حقا» of the poem.
  final taStops = <List>[
    for (final v in (load('ruways')['variants'] as List).cast<List>())
      if (v.length > 8 &&
          v[7] == 'rasm_stop' &&
          '${v[6]}'.contains('تاء التأنيث'))
        v,
  ];
  final described = <String, String>{};
  for (final f in Directory(
    'assets/data/qiraat',
  ).listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final d = jsonDecode(f.readAsStringSync());
    if (d is! Map || d['variants'] is! List) continue;
    for (final v in (d['variants'] as List).cast<List>()) {
      final how = '${v.length > 6 ? v[6] ?? '' : ''}';
      if (how.isEmpty || '${v[4]}'.isEmpty) continue;
      described.putIfAbsent(
        '${v[0]}:${v[1]}:${v[2]}:${skeleton('${v[4]}')}',
        () => how,
      );
    }
  }
  // Qalun's two hamzas of a word, which Abu Ja'far reads as he does.
  final qalunWords = <String, List>{};
  final built = <String, (File, Map, Map<String, int>)>{};
  for (final id in ashabSilahRiwayat) {
    final file = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(file.readAsStringSync()) as Map;
    final counts = buildAshabSilahUsul(
      quran,
      data,
      id,
      mimSites: mimSites,
      wordSites: wordSites,
      haSites: haSites,
      taStops: taStops,
    );
    if (id == 'qalun') {
      for (final v in (data['variants'] as List).cast<List>()) {
        if (v.length > 8 && v[7] == 'tasheel_word') {
          qalunWords['${v[0]}:${v[1]}:${v[2]}'] = v;
        }
      }
    } else if (id == 'ibn_wardan' || id == 'ibn_jammaz') {
      _asQalun(data, qalunWords, counts);
    }
    // A word's farsh told of no how: as another riwaya describes those letters.
    for (final v in (data['variants'] as List).cast<List>()) {
      if (v[5] != 'f' || v.length > 6 && '${v[6] ?? ''}'.isNotEmpty) continue;
      final told = described['${v[0]}:${v[1]}:${v[2]}:${skeleton('${v[4]}')}'];
      if (told == null) continue;
      while (v.length < 7) {
        v.add('');
      }
      v[6] = told;
      counts.update('described', (n) => n + 1, ifAbsent: () => 1);
    }
    built[id] = (file, data, counts);
  }
  _oneText({for (final e in built.entries) e.key: e.value.$2}, {
    for (final e in built.entries) e.key: e.value.$3,
  });
  for (final MapEntry(key: id, value: (file, data, counts)) in built.entries) {
    file.writeAsStringSync(jsonEncode(data));
    stdout.writeln('$id: $counts');
  }
}

/// A word the readers read with one rule, one how and the same faces is
/// written once, so it is told in one row: as the reader it is taken from
/// writes it, where the other leaves it unwritten or spells it otherwise.
void _oneText(Map<String, Map> data, Map<String, Map<String, int>> counts) {
  String spelling(String t) => t
      .replaceAll(RegExp('[ۖ-ۜ]'), '')
      .replaceAll('ۡ', 'ْ')
      .replaceAll('ى', 'ي');
  String letters(String t) => t
      .replaceAll(RegExp('[ۦىے]'), 'ي')
      .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا');
  String keyOf(List v) =>
      '${v[0]}:${v[1]}:${v[2]}|${v[7]}|${v[6]}|'
      '${v.length > 8 && v[8] is Map ? jsonEncode((v[8] as Map)['ways']) : ''}';
  bool usul(List v) => v.length > 7 && v[5] != 'f' && '${v[7]}'.isNotEmpty;
  // Each reader's rules at a word: an unwritten row may take another's text
  // only when that text tells nothing more of the word.
  final rulesAt = <String, Map<String, Set<String>>>{};
  for (final MapEntry(key: id, value: d) in data.entries) {
    final at = rulesAt[id] = {};
    for (final v in (d['variants'] as List).cast<List>()) {
      if (v.length < 7 || v[5] == 'f') continue;
      (at['${v[0]}:${v[1]}:${v[2]}'] ??= {}).add('${v.length > 7 ? v[7] : ''}|${v[6]}');
    }
  }
  final written = {
    for (final id in data.keys)
      id: {
        for (final v in (data[id]!['variants'] as List).cast<List>())
          if (usul(v) && '${v[4]}'.isNotEmpty) keyOf(v): v,
      },
  };
  // Each reader's font writes its own signs: a text goes only to Abu Ja'far,
  // who has none, and between Ibn Kathir's two.
  const takesFrom = {
    'qunbul': ['bazzi'],
    'ibn_wardan': ['qalun', 'bazzi', 'qunbul'],
    'ibn_jammaz': ['qalun', 'bazzi', 'qunbul'],
  };
  for (final MapEntry(key: id, value: sources) in takesFrom.entries) {
    for (final v in (data[id]!['variants'] as List).cast<List>()) {
      if (!usul(v)) continue;
      final from = sources.firstWhere(
        (s) => written[s]!.containsKey(keyOf(v)),
        orElse: () => '',
      );
      if (from.isEmpty) continue;
      final c = written[from]![keyOf(v)]!;
      if (v[4] == c[4]) continue;
      final word = '${v[0]}:${v[1]}:${v[2]}';
      final own = rulesAt[id]![word] ?? const <String>{};
      final theirs = rulesAt[from]![word] ?? const <String>{};
      // A ya of idafa told with the word after it, which only shows where.
      final context = v[7] == 'ya_idafa' && (v[3] as int) > (c[3] as int);
      final unwritten = '${v[4]}'.isEmpty &&
          (v[3] == c[3] || context) &&
          own.length == theirs.length &&
          own.containsAll(theirs);
      final head = '${v[4]}'.split(' ').take(c[3] as int).join(' ');
      final mine = context ? head : '${v[4]}';
      // Or the same letters, of a word the two read alike in all else.
      final alike = own.length == theirs.length &&
          own.containsAll(theirs) &&
          letters(mine) == letters('${c[4]}');
      if (!unwritten && !alike && spelling(mine) != spelling('${c[4]}')) {
        continue;
      }
      v
        ..[3] = c[3]
        ..[4] = c[4];
      counts[id]!.update('one_text', (n) => n + 1, ifAbsent: () => 1);
    }
  }
}

/// What the book «الجامع» tells, read from its pages, that the earlier
/// sources missed.
void _bookGaps(
  String id,
  List<List> rows,
  Map<String, List<List>> at,
  List<_Word> words,
  List<List> taStops,
  void Function(String) count,
) {
  String bare(String t) => t
      .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي');
  final byAyah = <String, List<_Word>>{};
  for (final w in words) {
    (byAyah['${w.s}:${w.a}'] ??= []).add(w);
  }
  _Word? find(int s, int a, String pattern, {String? after}) {
    final ws = byAyah['$s:$a'] ?? const <_Word>[];
    for (final (i, w) in ws.indexed) {
      if (!RegExp(pattern).hasMatch(bare(w.t))) continue;
      if (after != null && (i == 0 || bare(ws[i - 1].t) != after)) continue;
      return w;
    }
    return null;
  }

  void put(
    _Word w,
    String kind,
    String how,
    String rule, {
    String text = '',
    int n = 1,
    Map<String, Object> meta = const {},
  }) {
    final row = <Object>[
      w.s,
      w.a,
      w.w,
      n,
      text,
      kind,
      how,
      rule,
      {'source': ashabSilahSource, ...meta},
    ];
    rows.add(row);
    (at['${w.s}:${w.a}:${w.w}'] ??= []).add(row);
    count('book_${rule.isEmpty ? kind : rule}');
  }

  void drop(_Word w, bool Function(List v) which) {
    final key = '${w.s}:${w.a}:${w.w}';
    final gone = (at[key] ?? const <List>[]).where(which).toList();
    for (final v in gone) {
      rows.remove(v);
      at[key]!.remove(v);
    }
  }

  String clean(String t) => t.replaceAll(RegExp('[ۖ-ۜ]'), '');
  final kathir = id == 'bazzi' || id == 'qunbul';
  final abuJafar = id == 'ibn_wardan' || id == 'ibn_jammaz';

  if (kathir) {
    // «إذا كتبت بالتاء هاء مؤنث فبالهاء قف حقا»: as Ya'qub's rows.
    for (final v in taStops) {
      final w = (s: v[0] as int, a: v[1] as int, w: v[2] as int, t: '');
      if ((at['${w.s}:${w.a}:${w.w}'] ?? const <List>[]).any(
        (o) => o.length > 7 && o[7] == 'rasm_stop',
      )) {
        continue;
      }
      put(
        w,
        'u',
        '${v[6]}',
        'rasm_stop',
        meta: {'stopOnly': true, 'stopText': '${(v[8] as Map)['stopText']}'},
      );
    }
    // «وباق دنا هاد وواق ووال»: the ya when stopping.
    for (final (s, a, word) in const [
      (13, 7, 'هاد'),
      (13, 33, 'هاد'),
      (39, 23, 'هاد'),
      (39, 36, 'هاد'),
      (40, 33, 'هاد'),
      (13, 34, 'واق'),
      (13, 37, 'واق'),
      (40, 21, 'واق'),
      (13, 11, 'وال'),
      (16, 96, 'باق'),
    ]) {
      final w = find(s, a, '^$word\$');
      if (w == null) continue;
      drop(w, (v) => '${v[6]}'.contains('ترك تنوين'));
      final stop = clean(w.t).replaceAll(RegExp('[ٍٖٞ]'), 'ِ');
      put(
        w,
        'u',
        'بالوقف بالياء',
        'rasm_stop',
        meta: {'stopOnly': true, 'stopText': '$stopي'},
      );
    }
  }

  if (id == 'bazzi') {
    // His taʾs: the ta of the verb doubled when joined, a madd before it.
    rows.removeWhere(
      (v) => v.length > 7 && v[7] == 'bazzi_ta' && v[6] == 'بالمد',
    );
    for (final (s, a, pattern, after) in const <(int, int, String, String?)>[
      (2, 267, r'^تيمموا$', null),
      (3, 103, r'^تفرقوا$', null),
      (4, 97, r'^توفيهم', null),
      (5, 2, r'^تعاونوا$', 'ولا'),
      (6, 153, r'^فتفرق$', null),
      (7, 117, r'^تلقف$', null),
      (8, 20, r'^تولوا$', null),
      (8, 46, r'^تنزعوا$', null),
      (9, 52, r'^تربصون$', null),
      (11, 3, r'^تولوا$', null),
      (11, 57, r'^تولوا$', null),
      (11, 105, r'^تكلم$', null),
      (20, 69, r'^تلقف$', null),
      (24, 15, r'^تلقونه$', null),
      (24, 54, r'^تولوا$', null),
      (26, 45, r'^تلقف$', null),
      (26, 221, r'^تنزل$', null),
      (26, 222, r'^تنزل$', null),
      (33, 33, r'^تبرجن$', null),
      (33, 52, r'^تبدل$', null),
      (37, 25, r'^تناصرون$', null),
      (49, 11, r'^تنابزوا$', null),
      (49, 12, r'^تجسسوا$', null),
      (49, 13, r'^لتعارفوا$', null),
      (60, 9, r'^تولوهم$', null),
      (67, 8, r'^تميز$', null),
      (68, 38, r'^تخيرون$', null),
      (80, 10, r'^تلهي$', null),
      (92, 14, r'^تلظي$', null),
      (97, 4, r'^تنزل$', null),
    ]) {
      final w = find(s, a, pattern, after: after);
      if (w == null) {
        count('book_bazzi_ta_not_found');
        continue;
      }
      final ws = byAyah['$s:$a']!;
      final i = ws.indexOf(w);
      final before = i > 0 ? clean(ws[i - 1].t).replaceAll('ٓ', '') : '';
      final madd =
          RegExp(r'[اوىي]$').hasMatch(before) &&
          !RegExp('[ً-ٍٖٗٞ]').hasMatch(before);
      put(
        w,
        'u',
        madd ? 'بتشديد التاء وصلاً مع المد المشبع قبلها' : 'بتشديد التاء وصلاً',
        'bazzi_ta',
        text: clean(w.t).replaceFirst('ت', 'تّ'),
      );
    }
  }

  if (id == 'qalun') {
    // «الظنونا، الرسولا، السبيلا»: the alif joined and stopped on.
    for (final (s, a) in const [(33, 10), (33, 66), (33, 67)]) {
      final w = find(s, a, r'(ظنونا|رسولا|سبيلا)$');
      if (w == null) continue;
      put(
        w,
        'f',
        'بإثبات الألف وصلاً ووقفًا',
        '',
        text: clean(w.t).replaceAll('۠', ''),
      );
    }
  }

  if (id == 'qalun' || abuJafar) {
    // أنا before a hamza: its alif joined before the open and the closed;
    // Qalun has two faces before the broken.
    for (final ws in byAyah.values) {
      for (var i = 0; i + 1 < ws.length; i++) {
        if (!RegExp(r'^[وف]?انا$').hasMatch(bare(ws[i].t)) ||
            !ws[i].t.contains('أَنَا۠')) {
          continue;
        }
        final next = ws[i + 1].t;
        if (!RegExp('^[أإآء]').hasMatch(next)) continue;
        final w = ws[i];
        drop(w, (v) => v[5] == 'f' && '${v[6]}'.contains('ألف'));
        final text = '${clean(w.t).replaceAll('۠', '')}ٓ';
        if (next.startsWith('إ')) {
          if (id != 'qalun') continue;
          put(
            w,
            'u',
            'بوجهين: حذف الألف وصلاً، وهو المقدم؛ أو إثباتها',
            'ana_madd',
            text: text,
            meta: {
              'ways': ['حذف الألف وصلاً، وهو المقدم', 'إثبات الألف وصلاً'],
            },
          );
        } else {
          put(w, 'u', 'بإثبات الألف وصلاً', 'ana_madd', text: text);
        }
      }
    }
  }

  if (abuJafar) {
    final irtadd = find(5, 54, r'^يرتد$');
    if (irtadd != null) {
      put(
        irtadd,
        'f',
        'بدالين، الأولى مكسورة والثانية ساكنة',
        '',
        text: 'يَرۡتَدِدۡ',
      );
    }
    final yuaddih = find(3, 75, r'^يؤده');
    if (yuaddih != null &&
        (at['3:75:${yuaddih.w}'] ?? const <List>[]).every(
          (v) => !'${v[6]}'.contains('بدال'),
        )) {
      put(
        yuaddih,
        'f',
        'بإبدال الهمزة واوًا وإسكان الهاء',
        '',
        text: 'يُوَدِّهۡ',
      );
    }
    final shahid = find(18, 51, r'^اشهدتهم$');
    if (shahid != null) {
      drop(shahid, (v) => '${v[6]}' == 'بصلة ميم الجمع');
      put(
        shahid,
        'f',
        'بالنون بدل التاء وألف بعدها، بصلة ميم الجمع',
        '',
        text: 'أَشۡهَدۡنَٰهُمُۥ',
      );
    }
    _Word place(int s, int a, int w) => (s: s, a: a, w: w, t: '');
    bool told(List v, String how) => v[5] == 'f' && '${v[6]}'.trim() == how;
    // The source's farsh where he reads as Hafs, against Ya'qub or Khalaf:
    // nothing differs.
    for (final (s, a, w, how) in [
      (7, 143, 8, 'بكسر الراء'),
      (10, 15, 11, 'بإسكان الراء وبعدها همزة مفتوحة'),
      (11, 46, 7, 'بفتح الميم وضم اللام وتنوينها وضم الراء وتفخيمها'),
      (20, 87, 6, 'بضم الحاء وكسر الميم وتشديدها'),
      (22, 58, 6, 'بتخفيف التاء'),
      (42, 3, 1, 'بكسر الحاء وبعدها ياء ساكنة تمد حركتين'),
      (43, 4, 1, 'ضم الهمزة'),
    ]) {
      drop(place(s, a, w), (v) => told(v, how));
    }
    // Written as Hafs, though read otherwise.
    for (final (s, a, w, how, text) in [
      (11, 81, 8, 'بهمزة وصل', 'فَاسْرِ'),
      (12, 4, 7, 'بإسكان العين', 'أَحَدَ عْشَرَ'),
    ]) {
      for (final v in at['$s:$a:$w'] ?? const <List>[]) {
        if (told(v, how)) v[4] = text;
      }
    }
    // Told on the word after: «عقبا»، «صليا»، and the tanween of «وعيونٍ».
    for (final (from, to, how, text, kind, rule) in [
      (place(18, 45, 0), place(18, 44, 8), 'بضم القاف', 'عُقُبٗا', 'f', ''),
      (place(19, 71, 0), place(19, 70, 7), 'بضم الصاد', 'صُلِيّٗا', 'f', ''),
    ]) {
      drop(from, (v) => told(v, how));
      put(to, kind, how, rule, text: text);
    }
    // «وعيونٍ ادخلوها»: the ain as Hafs; its tanween in «التقاء الساكنين».
    drop(
      place(15, 46, 0),
      (v) => told(v, 'بضم العين وبضم نون التنوين لالتقاء الساكنين'),
    );
  }

  if (id == 'qunbul') {
    final la = find(75, 1, r'^لا$');
    if (la != null) {
      drop(la, (v) => true);
      put(la, 'f', 'بحذف الألف بعد اللام', '', text: 'لَأُقۡسِمُ', n: 2);
    }
  }
}

/// Abu Ja'far's two hamzas of a word where his face is Qalun's: written as
/// Qalun's (the eased hamza, the small alif let in between), his silah told
/// in the same row, so both are told together.
void _asQalun(Map data, Map<String, List> qalunWords, Map<String, int> counts) {
  final rows = (data['variants'] as List).cast<List>();
  final at = <String, List<List>>{};
  for (final v in rows) {
    (at['${v[0]}:${v[1]}:${v[2]}'] ??= []).add(v);
  }
  final gone = <List>{};
  for (final e in qalunWords.entries) {
    final q = e.value;
    final ways = (q[8] as Map)['ways'];
    for (final v in at[e.key] ?? const <List>[]) {
      if (v.length < 9 || v[7] != 'tasheel_word' || v[8] is! Map) continue;
      if (jsonEncode((v[8] as Map)['ways']) != jsonEncode(ways)) continue;
      v
        ..[3] = q[3]
        ..[4] = q[4]
        ..[5] = q[5]
        ..[6] = q[6]
        ..[8] = {...(v[8] as Map), ...(q[8] as Map)};
      counts.update('as_qalun', (n) => n + 1, ifAbsent: () => 1);
      if ('${q[6]}'.contains('صلة ميم الجمع')) {
        gone.addAll(
          (at[e.key] ?? const <List>[]).where(
            (o) => o != v && '${o.length > 6 ? o[6] : ''}' == 'بصلة ميم الجمع',
          ),
        );
      }
    }
  }
  rows.removeWhere(gone.contains);
}
