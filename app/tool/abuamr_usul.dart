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
  required List<List> susiRaw,
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

  // ---- المد المنفصل: القصر لأبي عمرو، للدوري والسوسي كقالون («بالقصر»)،
  // من صفوف السوسي في الكتاب (المستخدم، 2026-11-27).
  for (final v in susiRaw) {
    if (v[5] == 'u' && v[6] == 'بالقصر') {
      put(row(v[0], v[1], v[2], v[3], '${v[4]}', 'u', 'بالقصر', ''));
    }
  }
  // An added ya before a hamza (ٱلدَّاعِۦٓ إِذَا) short with it: no madd sign
  // on al-Duri's word, as al-Susi's (the user, 2026-11-27).
  for (final r in rows) {
    if (r[7] == 'ya_zaida') r[4] = '${r[4]}'.replaceFirst(RegExp('ۦٓ'), 'ۦ');
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
  // ذال «إذ» في الجيم (وَإِذ جَّعَلۡنَا): أبو عمرو يدغمها، والكسائي لا، فلم
  // تُنقل من صفوفه (المستخدم، 2026-11-26).
  for (final w in words) {
    final n = next(w);
    if (n == null || !n.t.startsWith('ج')) continue;
    if (!RegExp(r'^[وف]?َ?إِذۡ$')
        .hasMatch(w.t.replaceAll(RegExp('[ۖ-ۜ]'), ''))) {
      continue;
    }
    if (told.contains(_key(w.s, w.a, w.w))) continue;
    put(
      row(
        w.s,
        w.a,
        w.w,
        2,
        '${w.t.replaceFirst('ۡ', '')} ${n.t.replaceFirst('ج', 'جّ')}',
        'u',
        'بإدغام الذال في الجيم',
        'idgham_saghir',
      ),
    );
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
              // The idgham first, the izhar his second face (the user,
              // 2026-11-26); with al-Susi one row in the band (mushaf_page).
              'بوجهين: إدغام الراء في اللام، وهو المقدّم؛ أو الإظهار',
              'idgham_saghir',
              {
                'ways': const ['الإدغام، وهو المقدّم', 'الإظهار'],
                'ownWays': true,
              },
            ),
    );
  }

  // «فَيَغۡفِرۡ لِّمَن … وَيُعَذِّبۡ مَّن» (البقرة ٢٨٤): أبو عمرو يجزمهما فيدغم
  // الصغير، لا الكبير؛ الأول بتعرية الراء وتشديد اللام، وللدوري وجه بالإظهار،
  // والثاني بتعرية الباء وتشديد الميم (المستخدم، 2026-11-27).
  if (!told.contains('2:284:17')) {
    final ghafara = index['2:284:17']!.t.replaceFirst('رُ', 'ر');
    final liman = index['2:284:18']!.t.replaceFirst('ل', 'لّ');
    put(
      susi
          ? row(2, 284, 17, 2, '$ghafara $liman', 'u',
              'بإدغام الراء في اللام', 'idgham_saghir')
          : row(
              2,
              284,
              17,
              2,
              '$ghafara $liman',
              'u',
              'بوجهين: إدغام الراء في اللام، وهو المقدّم؛ أو الإظهار',
              'idgham_saghir',
              {
                'ways': const ['الإدغام، وهو المقدّم', 'الإظهار'],
                'ownWays': true,
              },
            ),
    );
  }
  if (!told.contains('2:284:20')) {
    final qalun = sources.qalun.firstWhere(
      (v) => v[0] == 2 && v[1] == 284 && v[2] == 20,
    );
    put(taken(qalun, 'qalun'));
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
      // A surah's last word (الرعد ٤٣، إبراهيم ٥٢): nothing to merge into.
      if (after.isEmpty) continue;
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
      // (the user, 2026-11-26). Not marked told: its own farsh (مَلِكِ) stays.
      if (across && after.isNotEmpty) {
        rows.add(
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
  // «أَؤُنَبِّئُكُم» (آل عمران ١٥): بوجهين، التسهيل مع الإدخال ومن غير
  // إدخال، ويُرسم بلا إدخال (المستخدم، 2026-11-27)؛ لا كقالون بالإدخال وحده.
  {
    final w = index['3:15:1']!;
    rows.removeWhere(
      (r) => r[0] == 3 && r[1] == 15 && r[2] == 1 && r[7] == 'tasheel_word',
    );
    told.remove('3:15:1');
    put(
      row(
        3,
        15,
        1,
        1,
        // Hafs's word, its second hamza eased, no alif between the two.
        noSilah(w.t.replaceFirst('ؤُ', 'ؤُ۬')),
        'h',
        'بوجهين: تسهيل الهمزة الثانية مع الإدخال؛ أو التسهيل من غير إدخال',
        'tasheel_word',
        {
          'context': w.t,
          'ways': const [
            'تسهيل الهمزة الثانية مع الإدخال',
            'التسهيل من غير إدخال',
          ],
        },
      ),
    );
  }

  // ---- الهمزتان من كلمتين: المتفقتان (هَٰٓؤُلَآءِ إِن، جَآءَ أَحَدٞ، أَوۡلِيَآءُ
  // أُوْلَٰٓئِكَ) بإسقاط الأولى مع القصر والمد، للدوري والسوسي سواءً، بلا
  // مقدّم (المستخدم، 2026-11-26)؛ والمختلفتان كقالون، والمضمومة مع المكسورة
  // بالإبدال واوًا مكسورة المقدّم ثم التسهيل.
  const isqatHow = 'بوجهين: إسقاط الهمزة الأولى مع القصر؛ أو إسقاطها مع المد';
  const isqatWays = ['إسقاط الهمزة الأولى مع القصر', 'إسقاطها مع المد'];
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
        // The hamza dropped, its madd sign with it, as Qalun's
        // «ٱلسُّفَهَا» (the user, 2026-11-28); not a madd before a hamza
        // still read (هَٰٓؤُلَا).
        m == null
            ? ''
            : '${w.t.substring(0, m.start).replaceFirst(RegExp('ٓ\$'), '')}${m[1]}',
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
          }.contains(r[7]) &&
          // The next ayah's word merged into (مَلِكِ): its farsh its own.
          !(r.length > 8 && (r[8] as Map)['noBand'] == true))
        _key(r[0], r[1], r[2]),
  };
  // al-Susi's big idgham the source wrote as a farsh «بإسكان النون» on the
  // word's last letter (لِلۡكَٰفِرِينَ نَّصِيبٞ، ٱلنَّارِ لَّهُمۡ، ٱلتَّوۡرَىٰةَ ثُّمَّ): its
  // row under the big idgham, the next word's first letter doubled (the
  // user, 2026-11-28); across an ayah's end, as «ٱلرَّحِيمِ ۝ مَّلِكِ».
  if (susi) {
    const letter = {'النون': 'ن', 'الراء': 'ر', 'التاء': 'ت', 'اللام': 'ل'};
    const into = {
      'ن': 'ن',
      'ر': 'رل',
      'ت': 'تث',
      'ل': 'لر',
    };
    String bare(String t) =>
        t.replaceAll(RegExp('[ً-ٰۖ-ۭ]'), '').replaceAll('ٱ', 'ا');
    for (final v in raw) {
      if (v[5] != 'f' || v[3] != 1) continue;
      // Its imala told with it, under its own chapter (بالإمالة وإسكان النون).
      final m = RegExp(
        r'^ب(?:الإمالة و)?إسكان (\S+)$',
      ).firstMatch('${v[6]}');
      final l = m == null ? null : letter[m[1]];
      if (l == null) continue;
      final w = index[_key(v[0], v[1], v[2])];
      // The ta marbuta read a ta (ٱلتَّوۡرَىٰةَ ثُّمَّ).
      if (w == null ||
          !bare(w.t).endsWith(l) && !(l == 'ت' && bare(w.t).endsWith('ة'))) {
        continue;
      }
      final next = index[_key(w.s, w.a, w.w + 1)];
      final across = next == null ? index[_key(w.s, w.a + 1, 0)] : null;
      final first = next ?? across;
      if (first == null) continue;
      // The article's lam silent before a sun letter: the letter after it.
      var head = bare(first.t);
      if (head.startsWith('ال')) head = head.substring(2);
      if (head.isEmpty || !into[l]!.contains(head[0])) continue;
      if (rows.any(
        (r) =>
            r[7] == 'idgham_kabir' &&
            _key(r[0], r[1], r[2]) == _key(w.s, w.a, w.w),
      )) {
        continue;
      }
      final context = {'context': '${w.t} ${first.t}'};
      if (next != null) {
        put(row(w.s, w.a, w.w, 2, '', 'u', 'بالإدغام الكبير وصلاً',
            'idgham_kabir', context));
      } else {
        put(row(w.s, w.a, w.w, 1, '', 'u', 'بالإدغام الكبير وصلاً',
            'idgham_kabir', context));
        rows.add(row(first.s, first.a, 0, 1, '', 'u', 'بالإدغام الكبير وصلاً',
            'idgham_kabir', {...context, 'noBand': true}));
      }
    }
  }
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
    // The next ayah's word merged into (مَّلِكِ): its doubled first letter is
    // the idgham's, drawn by the page; the farsh its own (مَلِكِ).
    final merged = rows.any(
      (r) =>
          r[7] == 'idgham_kabir' &&
          _key(r[0], r[1], r[2]) == at &&
          r.length > 8 &&
          (r[8] as Map)['noBand'] == true,
    );
    final text = merged
        ? madinahScript('${v[4]}').replaceFirst('ّ', '')
        : madinahScript('${v[4]}');
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
  // يأمركم، ينصركم، يشعركم، يأمرهم، تأمرهم» with the ikhtilas, the iskan
  // first, written so (the user, 2026-11-26).
  if (!susi) {
    for (final w in words) {
      final bare = _bare(w.t).replaceFirst(RegExp('^[وف]'), '');
      if (RegExp(r'^أرن[اي]$').hasMatch(bare)) {
        rows.removeWhere(
          (r) => r[0] == w.s && r[1] == w.a && r[2] == w.w && r[5] == 'f',
        );
        // Told under the usul's «الاختلاس», its red dot under the ra
        // (the user, 2026-11-27).
        put(
          row(
            w.s,
            w.a,
            w.w,
            1,
            w.t.replaceFirst('رِ', 'رِ'),
            'u',
            'باختلاس كسرة الراء',
            'ikhtilas',
            // In the hamesh too, its word apart from Hafs's.
            {'hamesh': true},
          ),
        );
      }
    }
    final stems = RegExp(r'^أ?(بارئكم|يأمركم|ينصركم|يشعركم|يأمرهم|تأمرهم)$');
    for (final r in rows) {
      if (r[5] != 'f' || !'${r[6]}'.startsWith('بإسكان')) continue;
      final w = index[_key(r[0], r[1], r[2])];
      if (w == null) continue;
      final bare = _bare(w.t).replaceFirst(RegExp('^[وف]'), '');
      if (!stems.hasMatch(bare)) continue;
      final letter = '${r[6]}'.replaceFirst('بإسكان ', '');
      final vowel = bare.startsWith('بارئ') ? 'كسرة' : 'ضمة';
      final ikhtilas = 'اختلاس $vowel $letter';
      r[6] = 'بوجهين: إسكان $letter، وهو المقدّم؛ أو $ikhtilas';
      (r[8] as Map)['ways'] = ['إسكان $letter، وهو المقدّم', ikhtilas];
    }
    // «بَارِئِكُمۡ» (البقرة ٥٤، معًا): al-Duri leans the alif after the ba, told
    // under the imala beside his farsh (the user, 2026-11-26).
    for (final w in words) {
      if (_bare(w.t) != 'بارئكم') continue;
      put(row(w.s, w.a, w.w, 1, '', 'u', 'بإمالة الألف', ''));
    }
  } else {
    // Al-Susi's iskan of these words is their farsh, al-Duri's first face;
    // his ibdal (يَامُرۡكُمۡ) told with it, drawn as the farsh's (the user,
    // 2026-11-26).
    final stems = RegExp(r'^أ?(بارئكم|يأمركم|ينصركم|يشعركم|يأمرهم|تأمرهم)$');
    for (final r in [...rows]) {
      if (r[5] != 'h' ||
          '${r[7]}'.isNotEmpty ||
          !'${r[6]}'.startsWith('بإسكان')) {
        continue;
      }
      final w = index[_key(r[0], r[1], r[2])];
      if (w == null) continue;
      final bare = _bare(w.t).replaceFirst(RegExp('^[وف]'), '');
      if (!stems.hasMatch(bare)) {
        // The book's «بإبدال الهمزة واوًا وإسكان النون» (نُّؤۡمِنَ لَكَ، يَأۡتِيَ
        // يَوۡمٞ): its big idgham, the iskan of the merged letter, not an
        // asl of its own (the user, 2026-11-27).
        final n = next(w);
        if (n == null) continue;
        rows.remove(r);
        if (told.contains(_key(w.s, w.a, w.w)) &&
            rows.any(
              (o) =>
                  o[7] == 'idgham_kabir' &&
                  _key(o[0], o[1], o[2]) == _key(w.s, w.a, w.w),
            )) {
          continue;
        }
        put(
          row(
            w.s,
            w.a,
            w.w,
            2,
            '',
            'u',
            'بالإدغام الكبير وصلاً',
            'idgham_kabir',
            {'context': '${w.t} ${n.t}'},
          ),
        );
        continue;
      }
      r[5] = 'f';
      for (final o in rows) {
        if (o[0] == r[0] &&
            o[1] == r[1] &&
            o[2] == r[2] &&
            o[7] == 'ibdal_single') {
          o[4] = r[4];
        }
      }
    }
  }
  // ---- الوقف بالهاء على تاء التأنيث المبسوطة (نِعۡمَتَ، رَحۡمَتَ): «فَبِالْهَاءِ
  // قِفْ حَقًّا»، كابن كثير؛ صفوف البزي ورويس، إلا «يا أبت» وما يقرؤه جمعًا،
  // و«بَيِّنَتٖ» (فاطر ٤٠) (المستخدم، 2026-11-27).
  final stopsTold = {
    for (final r in rows)
      if (r[7] == 'rasm_stop') _key(r[0], r[1], r[2]),
  };
  for (final src in const ['bazzi', 'ruways']) {
    for (final list in sources.verified[src]!.values) {
      for (final v in list) {
        if (v.length < 9 || v[7] != 'rasm_stop') continue;
        final key = _key(v[0], v[1], v[2]);
        final feminine =
            '${v[6]}'.contains('تاء التأنيث') || v[0] == 35 && v[1] == 40;
        if (!feminine) continue;
        final word = index[key];
        if (word == null || _bare(word.t).contains('يأبت')) continue;
        final own = textAt[key];
        if (own != null && _bare(own).contains('ات')) continue;
        if (!stopsTold.add(key)) continue;
        put([
          ...v.take(8),
          {...(v[8] as Map), 'source': source, 'farshFrom': src},
        ]);
      }
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

  // The extraction's «بفتح الألف» on a wasl alif (لَٱنفَضُّواْ، تَٱللَّهِ): the
  // same letters as Hafs's, its alif only drawn otherwise; no farsh (the
  // user, 2026-11-27).
  String plain(Object? t) => _bare('$t').replaceAll('ٱ', 'ا');
  rows.removeWhere(
    (r) =>
        r[5] == 'f' &&
        r[6] == 'بفتح الألف' &&
        plain(r[4]) == plain(index[_key(r[0], r[1], r[2])]?.t),
  );
  // So its «بإثبات الألف» on a silent alif of the Soosi rasm (لَإِاْلَى،
  // لَأَاْنتُمۡ): read as Hafs.
  rows.removeWhere(
    (r) =>
        r[5] == 'f' &&
        r[6] == 'بإثبات الألف' &&
        RegExp('[اٱ][ْ۟]').hasMatch('${r[4]}') &&
        {
          plain(index[_key(r[0], r[1], r[2])]?.t),
          // Hafs's rasm writes it too (وَلَأَاْوۡضَعُواْ، التوبة ٤٧).
          plain(
            '${index[_key(r[0], r[1], r[2])]?.t}'.replaceAll(
              RegExp('[اٱ][ْ۟]'),
              '',
            ),
          ),
        }.contains(plain('${r[4]}'.replaceAll(RegExp('[اٱ][ْ۟]'), ''))),
  );
  // «فَنِعِمَّا، نِعِمَّا» (البقرة ٢٧١، النساء ٥٨): the extraction's «بفتح العين
  // والإمالة» a mistake; Abu 'Amr reads them as Qalun, the iskan first, then
  // the ikhtilas of the 'ain's kasra (the user, 2026-11-27).
  for (final r in rows) {
    if (r[5] != 'f') continue;
    final at = _key(r[0], r[1], r[2]);
    if (at != _key(2, 271, 3) && at != _key(4, 58, 17)) continue;
    final qalun = sources.verified['qalun']?[at]
        ?.where((v) => v[5] == 'f')
        .firstOrNull;
    if (qalun == null) continue;
    // Both narrators drawn with the iskan, the face first, told as one in
    // the hamesh; the ikhtilas not drawn (the user, 2026-11-28).
    r[4] = qalun[4];
    r[6] = qalun[6];
    (r[8] as Map)['farshFrom'] = 'qalun';
  }
  // The farsh the extraction left without its wording, as the book words it
  // in its tables (pp. 105، 118، 156، 172، 199، 289، 314) (the user,
  // 2026-11-26); al-Susi's word merged into the next one by the big idgham
  // is the same farsh.
  for (final r in rows) {
    if (r[5] != 'f' || '${r[6]}'.isNotEmpty) continue;
    final wording = _abuAmrBookWording['${r[0]}:${r[1]}:${r[2]}'];
    if (wording != null) r[6] = wording;
  }

  // «نُؤۡتِهۡ» (آل عمران ١٤٥ معًا، الشورى ٢٠): al-Susi's as al-Duri's, its
  // farsh «بإسكان الهاء», his ibdal under its asl, «نُوتِهۡ» (not Ibn
  // Wardan's row of the two told as one, nor an ibdal with the silah; the
  // user, 2026-11-27).
  if (susi) {
    final joined = RegExp(r'^(بإبدال الهمزة \S+) و(إسكان الهاء)$');
    for (final r in [...rows]) {
      final m = r[5] == 'h' ? joined.firstMatch('${r[6]}') : null;
      if (m == null) continue;
      rows.removeWhere(
        (o) =>
            o[0] == r[0] &&
            o[1] == r[1] &&
            o[2] == r[2] &&
            o[7] == 'ibdal_single' &&
            !identical(o, r),
      );
      r[6] = m[1];
      (r[8] as Map).remove('farshFrom');
      rows.add(
        row(r[0], r[1], r[2], 1, '${r[4]}', 'f', 'ب${m[2]}', '', {
          'farshFrom': 'shubah',
        }),
      );
    }
  }

  // al-Susi's ibdal on his own farsh word, not Hafs's (يُوتِيهِ «بالياء», not
  // «نُوتِيهِ»; لِّيُومِنُواْ، يُوثِرُونَ، وَلُولُؤٖاْ): both rows drawn as his word
  // with the hamza changed, told «…، مع الإبدال للسوسي» (the user,
  // 2026-11-28).
  if (susi) {
    String changed(String t) => t
        .replaceFirst('ؤۡ', 'و')
        .replaceFirst('ئۡ', 'ي')
        .replaceFirst('أۡ', 'ا');
    for (final ibdal in rows.where((r) => r[7] == 'ibdal_single').toList()) {
      final farsh = rows
          .where(
            (r) =>
                r[5] == 'f' &&
                '${r[4]}'.isNotEmpty &&
                _key(r[0], r[1], r[2]) == _key(ibdal[0], ibdal[1], ibdal[2]),
          )
          .firstOrNull;
      if (farsh == null || farsh[4] == ibdal[4]) continue;
      final text = changed('${farsh[4]}');
      ibdal[4] = text;
      farsh[4] = text;
    }
  }

  // The ra into the ra across an ayah's end the source left out (ٱلنَّارِ ۝
  // رَّبَّنَآ، ٱلۡأَبۡرَارِ ۝ رَّبَّنَا، آل عمران ١٩١، ١٩٣): the first ra bare, the
  // second doubled, as the others across an ayah (the user, 2026-11-27).
  if (susi) {
    for (final (s, a) in const [(3, 191), (3, 193)]) {
      final last = words.lastWhere((w) => w.s == s && w.a == a);
      // Its imala or another asl on it besides: only another big idgham
      // there keeps it out.
      if (rows.any(
        (r) =>
            r[7] == 'idgham_kabir' &&
            _key(r[0], r[1], r[2]) == _key(s, a, last.w),
      )) {
        continue;
      }
      final first = index[_key(s, a + 1, 0)]!;
      final context = {'context': '${last.t} ${first.t}'};
      put(row(s, a, last.w, 1, '', 'u', 'بالإدغام الكبير وصلاً',
          'idgham_kabir', context));
      // The next ayah's word told with it, not apart (its farsh kept).
      rows.add(row(s, a + 1, 0, 1, '', 'u', 'بالإدغام الكبير وصلاً',
          'idgham_kabir', {...context, 'noBand': true}));
    }
  }

  // The qaf merged into the kaf within a word (صَدَقكُّمُ، نَرۡزُقكُّمۡ،
  // فَنُغۡرِقكُّم): al-Susi's big idgham, as «خَلَقكُّمۡ», not a farsh «بإسكان
  // القاف وتشديد الكاف»; «فَنُغۡرِقَكُم» keeps its farsh «بالنون» (the user,
  // 2026-11-27).
  if (susi) {
    const merged = 'إسكان القاف وتشديد الكاف';
    for (final r in [...rows]) {
      final how = '${r[6]}';
      if (r[5] != 'f' || !how.endsWith(merged)) continue;
      final text = '${r[4]}';
      // The word as the big idgham writes it, its first letter as Hafs's
      // (its doubling another idgham's).
      final kabir = text.replaceFirstMapped(
        RegExp(r'^([^ً-ْ]+?[ً-ِ]?)ّ'),
        (m) => m[1]!,
      );
      rows.remove(r);
      put(row(r[0], r[1], r[2], 1, kabir, 'u', 'بالإدغام الكبير',
          'idgham_kabir'));
      final rest = how.substring(0, how.length - merged.length).trim();
      if (rest.endsWith(' و')) {
        // Its own farsh besides (بالنون): the word unmerged.
        put(row(r[0], r[1], r[2], 1,
            kabir.replaceFirst(RegExp('قك[ًٌٍَُِّ]+'), 'قَكُ'), 'f',
            rest.substring(0, rest.length - 2), ''));
      }
    }
  }

  // «زَكَرِيَّآءُ» told under «زيادة الهمز» in every place, so its places on
  // a page alike are told together (آل عمران ٣٧ «(معًا)»; the first was
  // taken from Ibn Wardan's row without its asl; the user, 2026-11-27).
  for (final r in rows) {
    if (r[5] == 'h' &&
        '${r[7]}'.isEmpty &&
        '${r[6]}'.startsWith('بزيادة الهمزة') &&
        '${r[4]}'
            .replaceAll(RegExp('[ً-ٰٓ-ٕۖ-ۭ]'), '')
            .contains('زكرياء')) {
      r[7] = 'hamza_zaida';
    }
  }

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
  // Built from «تسهيل الأمر»: al-Kharouf's rows are not mixed in on loading
  // (their «بِهِمِ الأسبَاب» of two words took «ٱلۡأَسۡبَابُ» off the page, the
  // user, 2026-11-27).
  data['reviewedFarsh'] = true;
  data.remove('font');
  // The corrections the user made to al-Ashab's rows, where they are his.
  _finishRows(id, quran, data, index, words, sources, book, counts);
  // «فَٱدَّٰرَٰٔتُمۡ» (البقرة ٧٢): al-Duri reads it as Hafs, the extraction's
  // «بالهمز وحذف الهمزة» a mistake; al-Susi's quiet hamza an alif, his ibdal
  // (the user, 2026-11-26).
  final all = (data['variants'] as List).cast<List>();
  _abuAmrFinalAlif(all, index, words);
  // «مُوسَىٰ، يَٰمُوسَىٰ، عِيسَىٰ» with Abu 'Amr's taqlil, never the imala: its
  // imala rows dropped, one turned to the taqlil where none is told, and the
  // taqlil added where the book's list left the word out (مُوسَىٰ وَعِيسَىٰ،
  // البقرة ١٣٦) (the user, 2026-11-26/27).
  final musaWord = RegExp(r'^[وفبل]?ي?(موسى|عيسى)$');
  final musa = <String, List<List>>{};
  for (final r in all) {
    if (r[5] != 'u') continue;
    final w = index[_key(r[0], r[1], r[2])];
    if (w == null || !musaWord.hasMatch(_bare(w.t).replaceAll('ٰ', ''))) {
      continue;
    }
    (musa[_key(r[0], r[1], r[2])] ??= []).add(r);
  }
  for (final place in musa.values) {
    final imala = [
      for (final r in place)
        if ('${r[6]}'.startsWith('بإمالة')) r,
    ];
    if (imala.isEmpty) continue;
    final taqlil = place.where((r) => '${r[6]}'.startsWith('بالتقليل'));
    if (taqlil.isEmpty) {
      final keep = imala.first;
      keep[6] = '${keep[6]}'.contains('وقفًا') ? 'بالتقليل وقفًا' : 'بالتقليل';
      imala.remove(keep);
    }
    all.removeWhere((r) => imala.any((i) => identical(i, r)));
  }
  for (final w in words) {
    if (!musaWord.hasMatch(_bare(w.t).replaceAll('ٰ', ''))) continue;
    if (musa.containsKey(_key(w.s, w.a, w.w))) continue;
    // In its place, after the rows of the words before it.
    final at = all.indexWhere(
      (o) =>
          (o[0] as int) > w.s ||
          o[0] == w.s && (o[1] as int) > w.a ||
          o[0] == w.s && o[1] == w.a && (o[2] as int) > w.w,
    );
    final taqlil = row(w.s, w.a, w.w, 1, '', 'u', 'بالتقليل', '');
    if (at < 0) {
      all.add(taqlil);
    } else {
      all.insert(at, taqlil);
    }
  }
  // The taqlil of an alif before a quiet letter (ٱلۡقَتۡلَى ٱلۡحُرُّ، مُوسَى
  // ٱلۡكِتَٰبَ): at the stop only, as the imala; no sign on the page, «وقفًا
  // فقط» in the band (the user, 2026-11-27).
  final stopTaqlil = <String>{
    for (final r in all)
      if ('${r[6]}'.startsWith('بالتقليل') &&
          r.length > 8 &&
          (r[8] as Map)['stopOnly'] == true)
        _key(r[0], r[1], r[2]),
  };
  final beforeSakin = <List>[];
  for (final r in all) {
    if (r[5] != 'u' ||
        '${r[6]}' != 'بالتقليل' ||
        r.length > 8 && (r[8] as Map)['stopOnly'] == true) {
      continue;
    }
    final w = index[_key(r[0], r[1], r[2])];
    final n = w == null ? null : next(w);
    if (w == null ||
        n == null ||
        !n.t.startsWith('ٱ') ||
        !RegExp('[ىا]ٰ?\$').hasMatch(
          w.t.replaceAll(RegExp('[ۖ-ۜ]'), '').replaceAll(RegExp('[ًٌٍ]'), ''),
        )) {
      continue;
    }
    beforeSakin.add(r);
  }
  for (final r in beforeSakin) {
    if (stopTaqlil.contains(_key(r[0], r[1], r[2]))) {
      all.remove(r);
      continue;
    }
    r[6] = 'بالتقليل وقفًا';
    if (r.length < 9) {
      while (r.length < 8) {
        r.add('');
      }
      r.add(<String, Object?>{});
    }
    (r[8] as Map)['stopOnly'] = true;
  }
  all.removeWhere(
    (r) => !susi && r[0] == 2 && r[1] == 72 && r[2] == 3 && r[5] == 'h',
  );
  for (final r in all) {
    if (susi && r[0] == 2 && r[1] == 72 && r[2] == 3 && r[5] == 'h') {
      r[6] = 'بإبدال الهمزة ألفًا';
      r[7] = 'ibdal_single';
    }
  }
  // Al-Susi's ra leaned before a quiet letter (نَرَى ٱللَّهَ، ٱلۡقُرَى ٱلَّتِي):
  // in wasl too by khulf, the imala first, then the fath; before the Name,
  // its lam thick or thin with the imala; told on the row of the stop, not a
  // row of its own: «وَقَبْلَ سُكُونٍ ... خُلْفُ يَصْطَلِى» (the user,
  // 2026-11-26).
  if (susi) {
    for (final r in (data['variants'] as List).cast<List>()) {
      if (r.length < 9 ||
          (r[8] as Map)['stopOnly'] != true ||
          !'${r[6]}'.contains('إمالة')) {
        continue;
      }
      final w = index[_key(r[0], r[1], r[2])];
      final next = index[_key(r[0], r[1], (r[2] as int) + 1)];
      if (w == null ||
          next == null ||
          !next.t.startsWith('ٱ') ||
          !RegExp(r'رَ[ىا]ٰ?$').hasMatch(w.t.replaceAll(RegExp('[ۖ-ۜ]'), ''))) {
        continue;
      }
      final name = _bare(next.t) == 'الله';
      r[6] = name
          ? 'بإمالة الألف وقفًا؛ ووصلًا بخلف عنه: الإمالة مع تغليظ لام لفظ '
                'الجلالة أو ترقيقها، أو الفتح'
          : 'بإمالة الألف وقفًا؛ ووصلًا بخلف عنه: الإمالة، أو الفتح';
      (r[8] as Map)
        ..remove('stopOnly')
        // Beside the word in the band, as al-Duri's «(وقفًا فقط)».
        ..['bandNote'] = name
            ? 'وقفًا، والوصل بخلف عنه مع تغليظ لام لفظ الجلالة أو ترقيقها'
            : 'وقفًا، والوصل بخلف عنه'
        ..['ways'] = name
            ? [
                'الإمالة مع تغليظ لام لفظ الجلالة',
                'الإمالة مع ترقيقها',
                'الفتح وصلًا',
              ]
            : ['الإمالة', 'الفتح وصلًا'];
    }
  }

  return counts;
}

/// The book's wording of the farsh words its extraction left bare; where al-Duri
/// has a verified reader's wording, al-Susi takes the same.
const _abuAmrBookWording = {
  // «حَيۡثُ يَجۡعَلُ رِسَالَٰتِهِۦ» (ص ١٠٥).
  '6:124:17': 'بإثبات الألف وكسر التاء وكسر الهاء والياء',
  // «خَطَٰيَٰكُمۡ» (ص ١١٨).
  '7:161:17': 'بفتح الطاء وبعدها ألف وفتح الياء وحذف الهمزة والتاء',
  '8:70:7': 'بضم الهمزة وفتح السين وإثبات الألف',
  // «ٱلۡكَٰفِرُ» (ص ١٥٦).
  '13:42:14': 'بفتح الكاف وبعدها ألف وبكسر الفاء وتخفيفها وبعدها راء مرفوعة مظهرة مفخمة',
  // «تُفَجِّرَ» (ص ١٧٢).
  '17:90:5': 'بضم التاء وفتح الفاء وكسر الجيم وتشديدها',
  // «يَدۡفَعُ» (ص ١٩٩).
  '22:38:2': 'بفتح الياء ودال ساكنة وحذف الألف وفتح الفاء',
  // «وَأَتۡبَعۡنَٰهُمۡ» (ص ٢٨٩).
  '52:21:2': 'بهمزة قطع مفتوحة وإسكان التاء الأولى والعين، ونون مفتوحة بدل التاء ثم ألف',
  // «خَطَٰيَٰهُمۡ» (ص ٣١٤).
  '71:25:1':
      'بفتح الطاء وبعدها ألف ثم فتح الياء، وحذف الهمزة والتاء، وضم الهاء',
};

/// Abu 'Amr's imala of a final alif (هُدٗى، ٱلدُّنۡيَا، يَخۡشَىٰ), by his rules in
/// the Shatibiyya (the user, 2026-11-27):
/// - a ra before it: the big imala (ذِكۡرَىٰ، ٱشۡتَرَىٰ), kept;
/// - فَعۡلَى، فُعۡلَى، فِعۡلَى (ٱلدُّنۡيَا، ٱلتَّقۡوَىٰ، ٱلۡأُنثَىٰ، مُوسَىٰ) and
///   فُعَالَى: the taqlil, «وَكَيْفَ جَرَتْ فَعْلَى»;
/// - the ayah's end in the eleven surahs (طه، النجم ...): the taqlil;
/// - «أَنَّىٰ، يَٰوَيۡلَتَىٰ، يَٰحَسۡرَتَىٰ»: the taqlil;
/// - else (هُدٗى، كَفَىٰ، مَأۡوَىٰهُمۡ، ءَاتَىٰكُمۡ): no imala, the row dropped.
/// «أَعۡمَىٰ» (الإسراء ٧٢) the first, «حُكْمُ صُحْبَةٍ أَوَّلَا», keeps its imala.
void _abuAmrFinalAlif(
  List<List> rows,
  Map<String, _Word> index,
  List<_Word> words,
) {
  const elevenSurahs = {20, 53, 70, 75, 79, 80, 87, 91, 92, 93, 96};
  final lastWord = <String, int>{};
  for (final w in words) {
    final k = '${w.s}:${w.a}';
    if (w.w > (lastWord[k] ?? -1)) lastWord[k] = w.w;
  }
  final pronoun = '(?:ه|ها|هم|هما|هن|ك|كم|كما|كن|نا|ني)?';
  final finalAlif = RegExp('[ىا]$pronoun\$');
  final marks = RegExp('[ّٓۖ-ۜ]');
  // The pattern on Hafs's word, its pronoun aside.
  bool falaPattern(String t) {
    final w = t
        .replaceAll(marks, '')
        .replaceFirst(
          RegExp(
            r'(?:ه[ُِ]?|هَا|هُمۡ?|هِمۡ?|هُمَا|هِمَا|هُنَّ?|كَ|كُمۡ?|كُمَا|نَا|نِي)$',
          ),
          '',
        );
    final m = RegExp(
      r'^(?:[وفبلك][َِ])?(?:ٱلۡ?|لِلۡ?)?([^ً-ٰ])([َُِ])([^ً-ٰ])ۡ?([^ً-ٰ])َ(?:ىٰ?|ا|ٰ)$',
    ).firstMatch(w);
    if (m != null) {
      final stem = '${m[1]}${m[3]}${m[4]}';
      if (m[2] == 'َ') {
        return const {
          'موت',
          'سلو',
          'تقو',
          'صرع',
          'مرض',
          'قتل',
          'نجو',
          'دعو',
          'يحي',
        }.contains(stem);
      }
      return !(m[2] == 'ُ' && 'يتن'.contains(m[1]!));
    }
    if (RegExp(
      r'^(?:[وفبلك][َِ])?(?:ٱلۡ?|لِلۡ?)?(?:يَٰ)?[^ً-ٰ][ُِ][وي][^ً-ٰ]َىٰ?$',
    ).hasMatch(w)) {
      return true;
    }
    return RegExp(
      r'^(?:[وفبلك][َِ])?(?:ٱلۡ?|لِلۡ?)?[^ً-ٰ]ُ[^ً-ٰ]َ(?:ٰ|ا)[^ً-ٰ]َىٰ?$',
    ).hasMatch(w);
  }

  final taqlilAt = <String>{
    for (final r in rows)
      if (r[5] == 'u' && '${r[6]}'.startsWith('بالتقليل'))
        _key(r[0], r[1], r[2]),
  };
  final drop = <List>[];
  for (final r in rows) {
    if (r[5] != 'u' ||
        '${r[7]}'.isNotEmpty ||
        !RegExp('^بإمالة الألف(?: وقفًا)?\$').hasMatch('${r[6]}')) {
      continue;
    }
    final w = index[_key(r[0], r[1], r[2])];
    if (w == null) continue;
    final letters = _bare(w.t).replaceAll('ٰ', '');
    if (!finalAlif.hasMatch(letters)) continue;
    final stem = letters.replaceFirst(RegExp('[ىا]$pronoun\$'), '');
    // A ra before it (ذِكۡرَىٰ), or «رَءَا» and its like: his own imala.
    if (stem.endsWith('ر') || RegExp('ر[ءأ]').hasMatch(letters)) continue;
    // «أَعۡمَىٰ» the first of الإسراء ٧٢.
    if (r[0] == 17 && r[1] == 72 && r[2] == 4) continue;
    final taqlil =
        falaPattern(w.t) ||
        elevenSurahs.contains(w.s) && lastWord['${w.s}:${w.a}'] == w.w ||
        RegExp(r'^[وف]?(أنى|يويلتى|يحسرتى)$').hasMatch(letters);
    if (!taqlil || taqlilAt.contains(_key(r[0], r[1], r[2]))) {
      drop.add(r);
      continue;
    }
    r[6] = '${r[6]}'.contains('وقفًا') ? 'بالتقليل وقفًا' : 'بالتقليل';
    taqlilAt.add(_key(r[0], r[1], r[2]));
  }
  // The book's own taqlil rows (al-Kharouf's) by the same rule: not on a
  // word his rule does not lean (مَأۡوَىٰهُمۡ; the user, 2026-11-27).
  for (final r in rows) {
    if (r[5] != 'u' || !'${r[6]}'.startsWith('بالتقليل')) continue;
    if (r[8] is! Map || (r[8] as Map)['book'] != 'kharouf') continue;
    final w = index[_key(r[0], r[1], r[2])];
    if (w == null) continue;
    final letters = _bare(w.t).replaceAll('ٰ', '');
    final stem = letters.replaceFirst(RegExp('[ىا]$pronoun\$'), '');
    final kept =
        !finalAlif.hasMatch(letters) ||
        stem.endsWith('ر') ||
        falaPattern(w.t) ||
        elevenSurahs.contains(w.s) && lastWord['${w.s}:${w.a}'] == w.w ||
        RegExp(r'^[وف]?(?:يَٰ)?(أنى|يويلتى|يحسرتى|موسى|عيسى|يموسى|يعيسى)$')
            .hasMatch(letters) ||
        // فَعۡلَى the pattern misses (شَتَّىٰ، لَلۡحُسۡنَىٰ، يَٰيَحۡيَىٰ), and
        // «يَٰٓأَسَفَىٰ» as the book tells it.
        const {
          '59:14:17',
          '41:50:22',
          '19:12:0',
          '12:84:3',
        }.contains(_key(r[0], r[1], r[2]));
    if (!kept) {
      stdout.writeln('taqlil dropped ${_key(r[0], r[1], r[2])} ${w.t}');
      drop.add(r);
    }
  }
  rows.removeWhere((r) => drop.any((d) => identical(d, r)));
}
