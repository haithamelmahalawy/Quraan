part of 'build_ashab_usul.dart';

// The usul of Abu 'Amr (al-Duri, al-Susi), from «تسهيل الأمر إلى قراءة أبي
// عمرو» (the Shatibiyya, pages 1-336), built on the chapters and wording of
// the readers already verified; his farsh and imala from «التسهيل لقراءات
// التنزيل», a verified reader's row taken where he reads the word alike (the
// user, 2026-11-26). The source rows (KFGQPC) are kept in tool/abuamr_raw:
// only al-Susi's madd and ibdal, and the rows of a chapter told there, are
// still drawn from them.

const abuAmrRiwayat = ['duri_abuamr', 'susi'];

/// The rows of the source kept as they are: chapters the verified readers
/// word alike.
const _abuAmrKeptRules = {
  'ya_zaida',
  'rasm_stop',
  'no_sakt',
  'hamza_mutatarrif',
  'hamza_hadhf',
  'ha_silah',
  // اركب معنا، كهيعص ذكر.
  'idgham_saghir',
};

Map<String, int> buildAbuAmrUsul(
  Map quran,
  Map data,
  String id,
  AshabSources sources, {
  required List<List> raw,
  required Map book,
  required List<List> duriKisai,
  required List<List> khallad,
}) {
  if (!abuAmrRiwayat.contains(id)) {
    throw ArgumentError.value(id, 'id', "Not one of Abu 'Amr's");
  }
  final susi = id == 'susi';
  final words = <_Word>[
    for (final a in quran['ayahs'] as List)
      for (final (w, t) in (a[4] as String).split(' ').indexed)
        (s: a[0] as int, a: a[1] as int, w: w, t: t),
  ];
  final index = {for (final w in words) _key(w.s, w.a, w.w): w};
  final rows = <List>[];
  final told = <String>{};
  final counts = <String, int>{};
  final textAt = <String, String>{};
  const source = 'abuamr_book';

  void put(List row) {
    rows.add(row);
    for (var i = 0; i < (row[3] as int); i++) {
      told.add(_key(row[0], row[1], (row[2] as int) + i));
    }
    if (row[3] == 1 && '${row[4]}'.isNotEmpty) {
      textAt[_key(row[0], row[1], row[2])] = '${row[4]}';
    }
    counts.update('${row[7]}', (n) => n + 1, ifAbsent: () => 1);
  }

  List row(
    int s,
    int a,
    int w,
    int count,
    String text,
    String kind,
    String how,
    String rule, [
    Map<String, Object?> meta = const {},
  ]) => [
    s,
    a,
    w,
    count,
    text,
    kind,
    how,
    rule,
    {'source': source, ...meta},
  ];

  /// A verified reader's row taken as it is, its source named.
  List taken(List v, String who) => [
    ...v.take(8),
    for (var i = v.length; i < 8; i++) '',
    {
      if (v.length > 8 && v[8] is Map)
        ...Map<String, Object?>.from(v[8] as Map)
          ..remove('source')
          ..remove('sourcePage'),
      'source': source,
      'farshFrom': who,
    },
  ];

  _Word? next(_Word w) => index[_key(w.s, w.a, w.w + 1)];

  // ---- the source's rows of a chapter the verified readers word alike.
  for (final v in raw) {
    final rule = v.length > 7 ? '${v[7]}' : '';
    // And a row reviewed already, its notes with it (يَرۡضَهُۥ, بِنِعۡمَتِ).
    final meta = v.length > 8 && v[8] is Map
        ? Map<String, Object?>.from(v[8] as Map)
        : <String, Object?>{};
    if (_abuAmrKeptRules.contains(rule) ||
        rule == 'tasheel_word' ||
        meta.isNotEmpty) {
      put(
        row(
          v[0],
          v[1],
          v[2],
          v[3],
          '${v[4]}',
          '${v[5]}',
          '${v[6]}',
          rule,
          meta,
        ),
      );
    }
  }

  // ---- المد المنفصل للسوسي: القصر، كقالون («بالقصر»). For al-Duri the
  // tawassut, as Hafs: not told.
  if (susi) {
    for (final v in raw) {
      if (v[5] == 'u' && v[6] == 'بالقصر') {
        put(row(v[0], v[1], v[2], v[3], '${v[4]}', 'u', 'بالقصر', ''));
      }
    }
  }

  // ---- الإدغام الصغير، كما يقرؤه الدوري عن الكسائي ونصه: ذال «إذ» في
  // «تزصدسج»، ودال «قد» في حروفها الثمانية، وتاء التأنيث في «سثصزظج»،
  // و«اتخذتم، عذت، نبذتها، لبثت، أورثتموها، يرد ثواب، كهيعص ذكر»؛ ولام
  // «هل» في «ترى» وحدها، والباء المجزومة في الفاء.
  final saghir = RegExp(
    r'^بإدغام (الذال في (التاء|الزاي|الصاد|الدال|السين|الجيم)'
    r'|الدال في (السين|الذال|الضاد|الظاء|الزاي|الجيم|الصاد|الشين|الثاء)'
    r'|التاء في (السين|الثاء|الصاد|الزاي|الظاء|الجيم)'
    r'|الثاء في التاء|الباء في الفاء)$',
  );
  for (final v in duriKisai) {
    if (v.length < 8 || v[7] != 'idgham_saghir') continue;
    final how = '${v[6]}';
    final hal = how == 'بإدغام اللام في التاء' && '${v[4]}'.contains('تَّرَىٰ');
    if (!saghir.hasMatch(how) && !hal) continue;
    put(taken(v, 'duri_kisai'));
  }
  // «وَيُعَذِّب مَّن» كقالون.
  for (final v in sources.qalun) {
    if ('${v[6]}'.startsWith('بإدغام الباء في الميم')) put(taken(v, 'qalun'));
  }
  // الراء المجزومة في اللام: للسوسي بالإدغام، وللدوري بالوجهين والإظهار
  // المقدّم.
  for (final w in words) {
    final n = next(w);
    if (n == null || !n.t.startsWith('ل')) continue;
    final m = RegExp(r'رۡ([ۖ-ۛ]*)$').firstMatch(w.t);
    if (m == null || told.contains(_key(w.s, w.a, w.w))) continue;
    final second = n.t.replaceFirst(RegExp('^ل'), 'لّ');
    final text = '${w.t.substring(0, m.start)}ر${m[1]} $second';
    put(
      susi
          ? row(
              w.s,
              w.a,
              w.w,
              2,
              text,
              'u',
              'بإدغام الراء في اللام',
              'idgham_saghir',
            )
          : row(
              w.s,
              w.a,
              w.w,
              2,
              text,
              'u',
              'بإدغام الراء في اللام بخلف عنه، والإظهار هو المقدّم',
              'idgham_saghir',
              {
                'ways': const ['الإظهار، وهو المقدّم', 'الإدغام'],
                'ownWays': true,
                'bandNote': 'بخلف عنه، والإظهار هو المقدّم أداءً',
              },
            ),
    );
  }

  // ---- كسر ميم الجمع قبل الساكن بعد هاء مكسورة، إتباعًا لها، بنص رويس.
  for (final w in words) {
    final n = next(w);
    if (n == null || !n.t.startsWith('ٱ')) continue;
    final m = RegExp(r'هِمُ([ۖ-ۛ]*)$').firstMatch(w.t);
    if (m == null) continue;
    put(
      row(
        w.s,
        w.a,
        w.w,
        1,
        '${w.t.substring(0, m.start)}هِمِ${m[1]}',
        'u',
        'بكسر ميم الجمع إتباعًا للهاء قبل الساكن',
        'mim_jam',
        {'context': '${w.t} ${n.t}'},
      ),
    );
  }

  // ---- الإدغام الكبير للسوسي، بنص رويس: «بالإدغام الكبير وصلاً» على
  // الكلمتين؛ وفي الكلمة «مناسككم، سلككم» والقاف في الكاف (خلقكم).
  // ويوافقه الدوري في «بَيَّت طَّآئِفَةٞ» (النساء ٨١)، كخلاد.
  if (susi) {
    for (final v in raw) {
      if (v[5] != 'u') continue;
      final how = '${v[6]}';
      if (how != 'بالإدغام فيما بعدها' &&
          how != 'بإدغام الهاء في الهاء' &&
          how != 'بالإدغام') {
        continue;
      }
      final w = index[_key(v[0], v[1], v[2])];
      if (w == null || told.contains(_key(w.s, w.a, w.w))) continue;
      final n = next(w);
      if (n != null && told.contains(_key(n.s, n.a, n.w))) {
        // The small idgham told it already (قَد سَّمِعَ).
        if (rows.any(
          (r) =>
              r[0] == w.s &&
              r[1] == w.a &&
              r[2] == w.w - 0 &&
              '${r[7]}'.startsWith('idgham'),
        )) {
          continue;
        }
      }
      // Into the next ayah's first word (ٱلرَّحِيمِ ۝ مَٰلِكِ): told on this one.
      final across = n == null;
      final after = across ? index[_key(w.s, w.a + 1, 0)]?.t ?? '' : n.t;
      put(
        row(
          w.s,
          w.a,
          w.w,
          across ? 1 : 2,
          '',
          'u',
          'بالإدغام الكبير وصلاً',
          'idgham_kabir',
          {'context': '${w.t} $after'},
        ),
      );
      // The next ayah's first word coloured as well, told once in the band
      // (the user, 2026-11-26).
      if (across && after.isNotEmpty) {
        put(
          row(
            w.s,
            w.a + 1,
            0,
            1,
            '',
            'u',
            'بالإدغام الكبير وصلاً',
            'idgham_kabir',
            {'context': '${w.t} $after', 'noBand': true},
          ),
        );
      }
    }
    final inWord = RegExp('([قك])[َُِ](ك)([َُِ])');
    for (final v in raw) {
      if (v[5] != 'f') continue;
      if (!RegExp(r'^بإسكان (القاف|الكاف) وتشديد الكاف$').hasMatch('${v[6]}')) {
        continue;
      }
      final w = index[_key(v[0], v[1], v[2])];
      if (w == null || !inWord.hasMatch(w.t)) continue;
      put(
        row(
          w.s,
          w.a,
          w.w,
          1,
          w.t.replaceFirstMapped(inWord, (m) => '${m[1]}${m[2]}ّ${m[3]}'),
          'u',
          'بالإدغام الكبير',
          'idgham_kabir',
        ),
      );
    }
  }
  for (final v in khallad) {
    if (v.length > 7 && v[7] == 'idgham_kabir' && v[0] == 4 && v[1] == 81) {
      if (!told.contains(_key(v[0], v[1], v[2]))) put(taken(v, 'khallad'));
    }
  }

  // ---- إبدال الهمز الساكن للسوسي، بنص ابن وردان: «بإبدال الهمزة واوًا».
  if (susi) {
    const letters = {
      'َ': ('ا', 'ألفًا'),
      'ِ': ('ي', 'ياءً'),
      'ُ': ('و', 'واوًا'),
    };
    final sakin = RegExp('([َُِ])([ّ]?)(?:ـ?)([أإؤئءٔ])ۡ');
    for (final v in raw) {
      if (v[5] != 'h' && v[5] != 'f') continue;
      final how = '${v[6]}';
      if (!RegExp('إبدال الهمزة|^بتخفيف الهمزة').hasMatch(how)) continue;
      final w = index[_key(v[0], v[1], v[2])];
      if (w == null) continue;
      final m = sakin.firstMatch(w.t);
      if (m == null) continue;
      final (letter, name) = letters[m[1]]!;
      // The seat of the hamza drops before the letter (يَأۡكُلُ → يَاكُلُ).
      final text = w.t.replaceRange(m.start, m.end, '${m[1]}${m[2]}$letter');
      if (rows.any(
        (r) =>
            r[0] == w.s && r[1] == w.a && r[2] == w.w && r[7] == 'ibdal_single',
      )) {
        continue;
      }
      put(
        row(w.s, w.a, w.w, 1, text, 'h', 'بإبدال الهمزة $name', 'ibdal_single'),
      );
    }
  }

  // ---- الهمزتان من كلمة: كقالون، بلا صلة ميم الجمع؛ لا «أرأيت» (يحققها
  // أبو عمرو كحفص)، ولا ما في الفرش (الاستفهام المكرر، أءشهدوا، أذهبتم).
  // والمفتوحة مع المضمومة بوجهين والإدخال المقدّم.
  String noSilah(String t) => t.replaceAll('ُۥ', 'ۡ').replaceAll('ِۦ', 'ِ');
  for (final v in sources.qalun) {
    if (v.length < 8 || v[7] != 'tasheel_word') continue;
    final ctx = v.length > 8 && v[8] is Map
        ? '${(v[8] as Map)['context']}'
        : '';
    if (ctx.startsWith('أَرَءَيۡ') || '${v[6]}'.contains('الإخبار')) continue;
    if (const {'43:19', '46:20'}.contains('${v[0]}:${v[1]}')) continue;
    if (told.contains(_key(v[0], v[1], v[2]))) continue;
    final damma = ctx.contains('ءُ');
    final how = damma
        ? 'بوجهين: تسهيل الهمزة الثانية مع الإدخال، وهو المقدّم؛ أو تسهيلها بلا إدخال'
        : '${v[6]}'.replaceAll('، بصلة ميم الجمع', '');
    put([
      ...taken(v, 'qalun').take(4),
      noSilah('${v[4]}'),
      'h',
      how,
      'tasheel_word',
      {
        'source': source,
        'farshFrom': 'qalun',
        'context': ctx,
        'ways': damma
            ? const [
                'تسهيل الهمزة الثانية مع الإدخال، وهو المقدّم',
                'تسهيلها بلا إدخال',
              ]
            : (v[8] as Map)['ways'],
      },
    ]);
  }
  // «أَؤُنَبِّئُكُم» (آل عمران ١٥) مثلها.
  if (!told.contains('3:15:1')) {
    final w = index['3:15:1']!;
    put(
      row(
        3,
        15,
        1,
        1,
        w.t.replaceFirst('ؤُ', 'ٰءُ۬'),
        'h',
        'بوجهين: تسهيل الهمزة الثانية مع الإدخال، وهو المقدّم؛ أو تسهيلها بلا إدخال',
        'tasheel_word',
        {
          'context': w.t,
          'ways': const [
            'تسهيل الهمزة الثانية مع الإدخال، وهو المقدّم',
            'تسهيلها بلا إدخال',
          ],
        },
      ),
    );
  }

  // ---- الهمزتان من كلمتين: المتفقتان بإسقاط الأولى في الثلاث، وفي حرف
  // المد قبلها التوسط على توسط المنفصل (الدوري)، والقصر المقدّم والتوسط
  // على قصره (السوسي)؛ والمختلفتان كقالون، والمضمومة مع المكسورة بالإبدال
  // واوًا مكسورة المقدّم ثم التسهيل.
  final isqatHow = susi
      ? 'بوجهين: إسقاط الهمزة الأولى مع القصر، وهو المقدّم؛ أو إسقاطها مع التوسط'
      : 'بإسقاط الهمزة الأولى مع التوسط';
  final isqatWays = susi
      ? const ['إسقاط الهمزة الأولى مع القصر، وهو المقدّم', 'إسقاطها مع التوسط']
      : const ['إسقاط الهمزة الأولى مع التوسط'];
  final finalHamza = RegExp('ء[ًٌٍَُِ]?([ۖ-ۛ]*)\$');
  for (final v in sources.qalun) {
    if (v.length < 8) continue;
    final rule = '${v[7]}';
    if (!const {
      'tasheel_pair',
      'tasheel_pair_first',
      'ibdal_waw',
      'ibdal_ya',
    }.contains(rule)) {
      continue;
    }
    final meta = v.length > 8 && v[8] is Map
        ? Map<String, Object?>.from(v[8] as Map)
        : <String, Object?>{};
    final key = _key(v[0], v[1], v[2]);
    // Not where a hamza's chapter tells the word already; an idgham before
    // it does not (قَد جَّآءَ أَمۡرُ).
    if (rows.any(
      (r) =>
          _key(r[0], r[1], r[2]) == key &&
          '${r[7]}'.startsWith(RegExp('tasheel|ibdal_[wy]')),
    )) {
      continue;
    }
    if (rule == 'tasheel_pair_first') {
      final w = index[key]!;
      final m = finalHamza.firstMatch(w.t);
      put([
        v[0],
        v[1],
        v[2],
        1,
        m == null ? '' : '${w.t.substring(0, m.start)}${m[1]}',
        'h',
        isqatHow,
        'tasheel_pair_first',
        {...meta, 'source': source, 'farshFrom': 'qalun', 'ways': isqatWays},
      ]);
      continue;
    }
    var how = '${v[6]}'.replaceAll('، بصلة ميم الجمع', '');
    var ways = meta['ways'];
    // «يَشَآءُ إِلَىٰ»: the waw first, as the book (p. 38).
    if (how.contains('واوًا مكسورة')) {
      how = 'بوجهين: إبدال الهمزة الثانية واوًا مكسورة، وهو المقدّم؛ أو تسهيل الهمزة الثانية';
      ways = const [
        'إبدال الهمزة الثانية واوًا مكسورة، وهو المقدّم',
        'تسهيل الهمزة الثانية',
      ];
    }
    put([
      ...v.take(4),
      noSilah('${v[4]}'),
      'h',
      how,
      rule,
      {...meta, 'source': source, 'farshFrom': 'qalun', 'ways': ways},
    ]);
  }

  // «هَٰٓأَنتُمۡ» كقالون: بإثبات الألف وهمزة مسهلة.
  for (final v in sources.qalun) {
    if (v.length > 7 && v[7] == 'ha_antum') {
      put([...taken(v, 'qalun')..[4] = noSilah('${v[4]}')]);
    }
  }
  // «لِأَهَبَ» (مريم ١٩) بالياء كرويس.
  for (final v in sources.verified['ruways']!['19:19:5'] ?? const <List>[]) {
    put(taken(v, 'ruways'));
  }
  // الاستفهام المكرر: الثانية بالتسهيل والإدخال حيث يستفهم حفص بالتحقيق.
  final asked = RegExp('^(و?)أَ[ءئ]ِ');
  for (final v in raw) {
    if (v[5] != 'f' || v[6] != 'بتخفيف الهمزة') continue;
    final w = index[_key(v[0], v[1], v[2])];
    if (w == null || !asked.hasMatch(w.t)) continue;
    if (rows.any(
      (r) =>
          _key(r[0], r[1], r[2]) == _key(w.s, w.a, w.w) &&
          r[7] == 'tasheel_word',
    )) {
      continue;
    }
    put(
      row(
        w.s,
        w.a,
        w.w,
        1,
        w.t.replaceFirstMapped(asked, (m) => '${m[1]}أَٰئِ۬'),
        'h',
        'بتسهيل الهمزة الثانية مع الإدخال',
        'tasheel_word',
        {
          'context': w.t,
          'ways': const ['تسهيل الهمزة الثانية مع الإدخال'],
        },
      ),
    );
  }

  // ---- الفرش: صفوف المصدر، وصف القارئ المحقَّق مكانها حيث يقرأ الكلمة
  // مثله؛ وما فيها من الأصول (الإمالة، الإدغام، القصر، إبدال السوسي)
  // متروك لبابه (المستخدم، 2026-11-26).
  final usulPart = RegExp(
    susi
        ? r'^(ال)?(إمالة|تقليل|قصر|إدغام|فتح والإمالة)|^(إبدال|تخفيف) الهمزة'
        : r'^(ال)?(إمالة|تقليل|قصر|إدغام|فتح والإمالة)',
  );
  final hamzaChapters = {
    for (final r in rows)
      if (const {
        'tasheel_word',
        'tasheel_pair',
        'tasheel_pair_first',
        'ibdal_waw',
        'ibdal_ya',
        'mim_jam',
        'ha_antum',
        'idgham_saghir',
        'idgham_kabir',
      }.contains(r[7]))
        _key(r[0], r[1], r[2]),
  };
  final kabirFirst = {
    for (final r in rows)
      if (r[7] == 'idgham_kabir') _key(r[0], r[1], r[2]),
  };
  var copied = 0, ownRows = 0;
  for (final v in raw) {
    if (v[5] == 'u' || v.length > 7 && '${v[7]}'.isNotEmpty) continue;
    if (v.length > 8 && v[8] is Map) continue;
    final at = _key(v[0], v[1], v[2]);
    // The question added (أَئِنَّكُمۡ) told as the farsh, its two hamzas too.
    if (hamzaChapters.contains(at) && !'${v[6]}'.contains('استفهام')) continue;
    // Its parts told by a chapter of the usul set aside.
    final parts = '${v[6]}'
        .replaceFirst(RegExp('^ب'), '')
        .split(RegExp(' و(?!اوً|اواً|صلا|قف|احد)'))
        .where((p) => p.isNotEmpty && !usulPart.hasMatch(p))
        .where((p) => !(kabirFirst.contains(at) && p.startsWith('إسكان')))
        .toList();
    if (parts.isEmpty && '${v[6]}'.isNotEmpty) continue;
    final how = parts.isEmpty ? '' : 'ب${parts.join(' و')}';
    final text = madinahScript('${v[4]}');
    // A verified reader who reads it alike: his row.
    List? his;
    String? who;
    for (final r in _verifiedOrder) {
      for (final x in sources.verified[r]![at] ?? const <List>[]) {
        if (x[3] != v[3] || '${x[4]}'.isEmpty) continue;
        final rule = x.length > 7 ? '${x[7]}' : '';
        if (x[5] == 'u' && !_bookUsul.contains(rule)) continue;
        final mine = text.split(' '),
            other = madinahScript('${x[4]}').split(' ');
        if (mine.length != other.length) continue;
        // An alif read in neither state (ٱلظُّنُونَاْ) is not a read one.
        // The tasheel's dot, the imala's and the sign of a letter dropped
        // are readings too (أَٰئِ۬نَّكُمۡ against Hisham's whole hamza).
        String signs(String t) =>
            '${RegExp('ا[ْ۟]').hasMatch(t)}${t.replaceAll(RegExp('[^۪ۭ۬]'), '')}';
        if (signs(text) != signs(madinahScript('${x[4]}'))) continue;
        var same = true;
        for (var i = 0; i < mine.length && same; i++) {
          same =
              _plain(mine[i]) == _plain(other[i]) &&
              _alike(mine[i], other[i]) &&
              _alike(other[i], mine[i]);
        }
        if (!same) continue;
        his = x;
        who = r;
        break;
      }
      if (his != null) break;
    }
    if (his != null) {
      put(taken(his, who!));
      copied++;
      continue;
    }
    put(row(v[0], v[1], v[2], v[3], '${v[4]}', '${v[5]}', how, ''));
    ownRows++;
  }
  // al-Duri's ikhtilas (p. 43): «أرنا، أرني» his only face; «بارئكم،
  // يأمركم، ينصركم، يشعركم، يأمرهم، تأمرهم» with the iskan, the ikhtilas
  // first.
  if (!susi) {
    for (final w in words) {
      final bare = _bare(w.t).replaceFirst(RegExp('^[وف]'), '');
      if (RegExp(r'^أرن[اي]$').hasMatch(bare)) {
        rows.removeWhere(
          (r) => r[0] == w.s && r[1] == w.a && r[2] == w.w && r[5] == 'f',
        );
        put(row(w.s, w.a, w.w, 1, w.t, 'f', 'باختلاس كسرة الراء', ''));
      }
    }
    final stems = RegExp(r'^(بارئكم|يأمركم|ينصركم|يشعركم|يأمرهم|تأمرهم)$');
    for (final r in rows) {
      if (r[5] != 'f' || !'${r[6]}'.startsWith('بإسكان')) continue;
      final w = index[_key(r[0], r[1], r[2])];
      if (w == null) continue;
      final bare = _bare(w.t).replaceFirst(RegExp('^[وف]'), '');
      if (!stems.hasMatch(bare)) continue;
      final letter = '${r[6]}'.replaceFirst('بإسكان ', '');
      final vowel = bare.startsWith('بارئ') ? 'كسرة' : 'ضمة';
      final ikhtilas = 'اختلاس $vowel $letter';
      r[4] = w.t;
      r[6] = 'بوجهين: $ikhtilas، وهو المقدّم؛ أو إسكان $letter';
      (r[8] as Map)['ways'] = ['$ikhtilas، وهو المقدّم', 'إسكان $letter'];
    }
  }
  counts['farsh copied'] = copied;
  counts['farsh own'] = ownRows;

  // ---- الإمالة والتقليل، من قسم الممال في الكتاب.
  counts['imala'] = _imala(id, book, index, sources.verified['ibn_dhakwan']!, (
    r,
  ) {
    final meta = Map<String, Object?>.from(r[8] as Map)..['source'] = source;
    put([...r.take(8), meta]);
  });

  // By place, the rows of one word in the order made.
  final order = {for (final (i, v) in rows.indexed) v: i};
  data['variants'] = rows
    ..sort((x, y) {
      for (var i = 0; i < 3; i++) {
        final c = (x[i] as int).compareTo(y[i] as int);
        if (c != 0) return c;
      }
      return order[x]!.compareTo(order[y]!);
    });
  data['source'] = source;
  data.remove('font');
  // The corrections the user made to al-Ashab's rows, where they are his.
  _finishRows(id, quran, data, index, words, sources, book, counts);
  return counts;
}
