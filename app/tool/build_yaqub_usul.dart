// Source: Noor-Book.com اصول قراءة يعقوب البصري.pdf, pp.7–39.
// Only Ruways and Rawh are written. Run from app with dart run tool/build_yaqub_usul.dart.
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

import 'yaqub_zawaid.dart';

typedef YaqubWord = ({int s, int a, int w, String t});
const yaqubSource = 'yaqub_usul_pdf';

String _bare(String s) => s
    .replaceAllMapped(RegExp(r'([^اى])ٰ'), (m) => '${m[1]}ا')
    .replaceAll('ٱ', 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[ً-ٰٟۖ-ۭـ]'), '');
bool _hamza(String s) => RegExp(r'^[ءأإؤئآ]').hasMatch(s);
String _vowel(String s) => s.contains('ُ')
    ? 'ُ'
    : s.contains('ِ')
    ? 'ِ'
    : 'َ';

/// Stable, independently auditable source-derived annotations. Orthographic
/// changes use the Hafs cluster carrying the rule; stop-only rows never replace
/// continuous text. Genuine pre-existing lexical readings are retained.
Map<String, int> buildYaqubUsul(Map quran, Map data, String id) {
  if (!const {'ruways', 'rawh'}.contains(id)) {
    throw ArgumentError.value(id, 'id', 'Only Yaqub narrators are supported');
  }
  final original = (data['variants'] as List).cast<List>();
  final words = <YaqubWord>[
    for (final a in quran['ayahs'] as List)
      for (final (w, t) in (a[4] as String).split(' ').indexed)
        (s: a[0] as int, a: a[1] as int, w: w, t: t),
  ];
  String key(YaqubWord w) => '${w.s}:${w.a}:${w.w}';
  final index = {for (final w in words) key(w): w};
  bool yaPosition(List v) {
    final t = index['${v[0]}:${v[1]}:${v[2]}']?.t;
    return t != null && const {'ي', 'ى'}.contains(lettersOf(t).last[0]);
  }

  // Save the individually indexed written-ya readings, rather than inferring
  // missing Qur'anic letters from a word's final kasra.
  final seedMap = <String, List>{
    for (final v in (data['yaqubYaSeeds'] as List? ?? const []).cast<List>())
      if (v[5] == 'ya_zaida' || yaPosition(v))
        '${v[0]}:${v[1]}:${v[2]}:${v[5]}': v,
  };
  for (final v in original) {
    if (v.length > 8 && v[8] is Map && v[8]['source'] == yaqubSource) continue;
    if ((v.length > 7 && v[7] == 'ya_zaida') ||
        (yaPosition(v) &&
            v.length > 6 &&
            RegExp(
              r'ياء الإضافة|ياء الاضافة|إسكان الياء|اسكان الياء|بفتح الياء',
            ).hasMatch(v[6] as String))) {
      final rule = v.length > 7 && v[7] == 'ya_zaida' ? 'ya_zaida' : 'ya_idafa';
      seedMap['${v[0]}:${v[1]}:${v[2]}:$rule'] = [
        v[0],
        v[1],
        v[2],
        v[3],
        v[4],
        rule,
      ];
    }
  }
  final seeds = seedMap.values.toList();
  // Replace the old catalogue of extra ya positions with the checked finite
  // catalogue. Existing ya-idafa seeds remain independent of this audit.
  seeds.removeWhere((v) => v[5] == 'ya_zaida');
  void writtenYa(YaqubWord w) {
    seeds.add([
      w.s,
      w.a,
      w.w,
      1,
      '${w.t.replaceAll(RegExp(r'[ۖ-ۭ]'), '')}ي',
      'ya_zaida',
    ]);
  }

  for (final k in yaqubWrittenYaPlaces.trim().split(RegExp(r'\s+'))) {
    final w = index[k];
    if (w == null) throw StateError('Unknown reviewed extra-ya location: $k');
    writtenYa(w);
  }
  for (final (s, a, b) in yaqubMissingYaWords) {
    final candidates = words
        .where(
          (w) =>
              w.s == s &&
              w.a == a &&
              _bare(w.t).replaceAll('ي', 'ا') == b.replaceAll('ي', 'ا'),
        )
        .toList();
    if (candidates.length != 1) {
      throw StateError('Ambiguous reviewed extra-ya: $s:$a $b');
    }
    writtenYa(candidates.single);
  }
  if (id == 'ruways') {
    for (final k in ['39:16:14', '43:68:0']) {
      writtenYa(index[k]!);
    }
  }
  data['yaqubYaSeeds'] = seeds;
  bool generated(List v) =>
      v.length > 8 && v[8] is Map && v[8]['source'] == yaqubSource;
  bool pureUsul(List v) {
    if (generated(v) || (v.length > 7 && v[7] == 'ya_zaida')) return true;
    final d = v.length > 6 ? v[6] as String : '';
    final text = v[4] as String;
    if (v[5] == 'u' && text.isEmpty) return true;
    if (RegExp(
      r'^(ب?ضم الهاء|ب?كسر الهاء|اشمام كسرة|إشمام كسرة|ب?اسكان ياء الإضافة|ب?إسكان ياء الإضافة|إبدال الهمزة الثانية|ابدال الهمزة الثانية|تسهيل الهمزة الثانية)',
    ).hasMatch(d.isEmpty ? text : d)) {
      return true;
    }
    if (d.isEmpty &&
        RegExp(r'^(فتح |ضم |كسر |ترقيق |تغليظ |إدغام |ادغام )')
            .hasMatch(text)) {
      return true;
    }
    if (v[5] != 'f' &&
        (text.isEmpty ||
            RegExp(
              r'إمالة|بالفتح|مد المتصل|مد المنفصل|تسهيل|تحقيق الهمزة|إظهار|اظهار|ادغام|إدغام|القصر|بالقصر',
            ).hasMatch(d))) {
      return true;
    }
    if (yaPosition(v) &&
        v.length > 6 &&
        RegExp(r'ياء الإضافة|ياء الاضافة|إسكان الياء|اسكان الياء|بفتح الياء')
            .hasMatch(d)) {
      return true;
    }
    return false;
  }

  final rows = <List>[
    for (final v in original)
      if (!pureUsul(v)) [...v],
  ];
  for (final v in rows) {
    if (id == 'rawh' && v[0] == 27 && v[1] == 36 && v[2] == 7 && v[3] == 2) {
      v[3] = 1;
      v[4] = 'ءَاتَانِ';
      v[6] = 'بحذف الياء وصلاً';
    }
  }
  for (final v in rows) {
    v[4] = (v[4] as String).split(RegExp(r'[:(]')).first.trim();
  }
  final counts = <String, int>{};
  final added = <String>{};
  void add(
    YaqubWord w,
    String rule,
    String how,
    int page, {
    String text = '',
    int count = 1,
    String context = '',
    bool stop = false,
    String stopText = '',
    List<String> ways = const [],
  }) {
    if (!added.add('${key(w)}:$rule')) return;
    rows.add([
      w.s,
      w.a,
      w.w,
      count,
      text,
      'u',
      how,
      rule,
      {
        'source': yaqubSource,
        'sourcePage': page,
        if (context.isNotEmpty) 'context': context,
        if (stop) 'stopOnly': true,
        if (stopText.isNotEmpty) 'stopText': stopText,
        if (ways.isNotEmpty) 'ways': ways,
      },
    ]);
    counts.update(rule, (n) => n + 1, ifAbsent: () => 1);
  }

  for (var i = 0; i < words.length; i++) {
    final w = words[i], b = _bare(w.t), cs = lettersOf(w.t);
    final next = i + 1 < words.length && words[i + 1].s == w.s
        ? words[i + 1]
        : null;
    final previous = i > 0 && words[i - 1].s == w.s ? words[i - 1] : null;
    final ns = next == null ? <String>[] : lettersOf(next.t);
    // Madd rules from p.7. Never attach Warsh's badal to Yaqub's ishmam.
    if (next != null && ns.isNotEmpty && _hamza(ns.first) && cs.isNotEmpty) {
      final last = cs.last.replaceAll(RegExp(r'[ٓۖ-ۭ]'), '');
      if (RegExp(r'^[اويى]$').hasMatch(last) &&
          cs.length > 1 &&
          ((last == 'ا' && cs[cs.length - 2].contains('َ')) ||
              (last == 'و' && cs[cs.length - 2].contains('ُ')) ||
              ('يى'.contains(last) && cs[cs.length - 2].contains('ِ')))) {
        add(
          w,
          'madd_munfasil',
          'بقصر المد المنفصل حركتين',
          7,
          context: '${w.t} ${next.t}',
        );
      }
    }
    for (var c = 1; c < cs.length; c++) {
      if (_hamza(cs[c]) &&
          (cs[c - 1].contains('ٓ') ||
              (RegExp(r'^[اويى]').hasMatch(cs[c - 1]) &&
                  c > 1 &&
                  ((cs[c - 1][0] == 'ا' && cs[c - 2].contains('َ')) ||
                      (cs[c - 1][0] == 'و' && cs[c - 2].contains('ُ')) ||
                      ('يى'.contains(cs[c - 1][0]) &&
                          cs[c - 2].contains('ِ')))))) {
        add(w, 'madd_muttasil', 'بتوسط المد المتصل أربع حركات', 7);
      }
    }
    // Yaqub's hā of plural/dual/feminine pronouns after a quiescent yā.
    for (var c = 1; c < cs.length; c++) {
      if (cs[c].startsWith('ه') &&
          cs[c - 1].startsWith('ي') &&
          !RegExp(r'[َُِّ]').hasMatch(cs[c - 1]) &&
          RegExp(r'^(هم|هما|هن)$').hasMatch(_bare(cs.skip(c).join()))) {
        final changed = [...cs];
        changed[c] = changed[c].replaceAll('ِ', 'ُ');
        add(
          w,
          'ha_damir',
          'بضم هاء الضمير بعد الياء الساكنة',
          35,
          text: changed.join(),
        );
      }
    }
    if (id == 'ruways' &&
        RegExp(r'^[وف]?(أتهم|يأتهم|يخزهم|يكفهم|استفتهم)$').hasMatch(b)) {
      add(
        w,
        'ha_damir',
        'بضم الهاء بعد الياء المحذوفة للجزم أو البناء',
        35,
        text: w.t.replaceFirst(RegExp(r'هِ'), 'هُ'),
      );
    }
    if (next != null &&
        ns.isNotEmpty &&
        next.t.startsWith('ٱ') &&
        b.endsWith('هم') &&
        cs.length > 1) {
      final changed = [...cs];
      final ha = changed.length - 2;
      final raised =
          ha > 0 &&
          changed[ha - 1].startsWith('ي') &&
          !RegExp(r'[َُِّ]').hasMatch(changed[ha - 1]);
      final kasr = changed[ha].contains('ِ') && !raised;
      changed[ha] = changed[ha].replaceAll('ِ', raised ? 'ُ' : 'ِ');
      changed[changed.length - 1] =
          changed.last.replaceAll(RegExp(r'[ُِْۡ]'), '') + (kasr ? 'ِ' : 'ُ');
      add(
        w,
        'mim_jam',
        kasr
            ? 'بكسر ميم الجمع إتباعًا للهاء قبل الساكن'
            : 'بضم ميم الجمع إتباعًا للهاء قبل الساكن',
        36,
        text: changed.join(),
        context: '${w.t} ${next.t}',
      );
    }
    // Seven passive verbs: Ruways only; p.37 mistakenly says Rawh in its body.
    if (id == 'ruways' &&
        RegExp(r'^(و|ف)?(قيل|غيض|جيء|حيل|سيق|سيء|سيئت)$').hasMatch(b)) {
      add(w, 'ishmam', 'بإشمام كسرة الحرف الأول ضمًّا', 37);
    }
    if (id == 'ruways' &&
        (b.contains('أصدق') || b == 'يصدفون' || b == 'وتصدية')) {
      add(w, 'ishmam_sad', 'بإشمام الصاد صوت الزاي', 37);
    }
    if ((w.s == 17 &&
            w.a == 72 &&
            b == 'أعمي' &&
            !words
                .take(i)
                .any((x) => x.s == 17 && x.a == 72 && _bare(x.t) == 'أعمي')) ||
        (w.s == 27 && w.a == 43 && b == 'كافرين') ||
        (id == 'ruways' && RegExp(r'^(و|ف)?(ال)?كافرين$').hasMatch(b)) ||
        (id == 'rawh' && w.s == 36 && w.a == 1)) {
      add(w, 'imala', 'بالإمالة الكبرى', 12);
    }
    if (w.s == 11 && w.a == 41 && const {'مجراها', 'مجريها'}.contains(b)) {
      add(
        w,
        'fath',
        'بالفتح الخالص',
        12,
        text: w.t.replaceAll(RegExp(r'[۪ٜ]'), ''),
      );
    }
    if (id == 'ruways' && cs.length > 1 && _hamza(cs[0]) && _hamza(cs[1])) {
      add(
        w,
        'tasheel_word',
        'بتسهيل الهمزة الثانية بلا إدخال',
        19,
        ways: ['تسهيل الهمزة الثانية بين بين بلا إدخال'],
      );
    }
    if (id == 'rawh' && w.s == 41 && w.a == 44 && b.contains('أعجمي')) {
      add(
        w,
        'tasheel_word',
        'بتحقيق الهمزتين بلا إدخال',
        20,
        text: w.t.replaceFirst('ءَا', 'ءَأَ'),
      );
    }
    if (id == 'ruways' &&
        previous != null &&
        cs.isNotEmpty &&
        _hamza(cs.first)) {
      final ps = lettersOf(previous.t);
      if (ps.isNotEmpty && _hamza(ps.last)) {
        final v1 = _vowel(ps.last), v2 = _vowel(cs.first);
        if (v1 == v2 || v1 == 'َ') {
          add(
            w,
            'tasheel_pair',
            'بتسهيل الهمزة الثانية وصلاً',
            24,
            context: '${previous.t} ${w.t}',
            ways: ['تسهيل الهمزة الثانية بين بين وصلاً'],
          );
        } else if (v2 == 'َ') {
          final letter = v1 == 'ِ' ? 'ي' : 'و';
          add(
            w,
            letter == 'ي' ? 'ibdal_ya' : 'ibdal_waw',
            'بإبدال الهمزة الثانية ${letter == 'ي' ? 'ياءً' : 'واوًا'} خالصة وصلاً',
            24,
            text: [
              cs.first.replaceFirst(RegExp(r'^[ءأإؤئآ]'), letter),
              ...cs.skip(1),
            ].join(),
            context: '${previous.t} ${w.t}',
          );
        } else if (v1 == 'ُ' && v2 == 'ِ') {
          add(
            w,
            'ibdal_waw',
            'بإبدال الهمزة الثانية واوًا مكسورة أو تسهيلها وصلاً، والإبدال مقدّم',
            24,
            text: [
              cs.first.replaceFirst(RegExp(r'^[ءأإؤئآ]'), 'و'),
              ...cs.skip(1),
            ].join(),
            context: '${previous.t} ${w.t}',
            ways: [
              'إبدال الثانية واوًا مكسورة وهو المقدّم',
              'تسهيل الثانية بين بين',
            ],
          );
        }
      }
    }
    if (w.s == 53 && w.a == 50 && b.contains('الأولي')) {
      add(
        w,
        'naql',
        'بنقل حركة الهمزة إلى اللام وإدغام تنوين عادًا في اللام وصلاً',
        19,
        text: 'ٱلُّولَىٰ',
        context: '${previous?.t ?? ''} ${w.t}',
        ways: [
          'الابتداء: لَأُولَى وهو المقدّم',
          'الابتداء: اَلُولَى',
          'الابتداء: لُولَى',
        ],
      );
    }
    if (id == 'ruways' && w.s == 55 && w.a == 54 && b == 'إستبرق') {
      add(
        w,
        'naql',
        'بنقل حركة الهمزة إلى نون مِن وحذف الهمزة وصلاً',
        19,
        text: cs.skip(1).join(),
        context: '${previous?.t ?? ''} ${w.t}',
      );
      if (previous != null) {
        add(
          previous,
          'naql_source',
          'بنقل كسرة الهمزة إلى النون وصلاً',
          19,
          text: '${previous.t.replaceAll(RegExp(r'[ْۡۖ-ۭ]'), '')}ِ',
        );
      }
    }
    if ((w.s == 36 && w.a == 1) || (w.s == 68 && w.a == 1)) {
      add(
        w,
        'idgham_saghir',
        'بإدغام النون في الواو مع الغنة وصلاً',
        8,
        context: '${w.t} ${next?.t ?? ''}',
      );
    }
    if (id == 'rawh' &&
        RegExp(r'اتخذت|أخذت').hasMatch(b) &&
        b.contains('اتخذت')) {
      add(
        w,
        'idgham_saghir',
        'بإدغام الذال في التاء',
        8,
        text: w.t.replaceAll(RegExp(r'ذ[ْۡ]?ت'), 'ذتّ'),
      );
    }
    if ((w.s == 4 && w.a == 36 && b == 'والصاحب') ||
        (w.s == 27 && w.a == 36 && b.startsWith('أتمدون')) ||
        (w.s == 53 && w.a == 55 && b == 'ربك') ||
        (id == 'ruways' &&
            ((w.s == 23 && w.a == 101 && b == 'أنساب') ||
                (w.s == 20 &&
                    const {33, 34, 35}.contains(w.a) &&
                    b.endsWith('ك')) ||
                (w.s == 34 && w.a == 46 && b == 'ثم')))) {
      add(
        w,
        'idgham_kabir',
        'بالإدغام الكبير وصلاً',
        9,
        context: '${w.t} ${next?.t ?? ''}',
      );
    }
    final optionalKabir =
        id == 'ruways' &&
        ((w.s == 2 && w.a == 20 && b == 'لذهب') ||
            (w.s == 2 &&
                const {79, 176}.contains(w.a) &&
                b == 'الكتاب' &&
                next != null &&
                next.t.startsWith('ب')) ||
            (w.s == 16 &&
                b.endsWith('جعل') &&
                next != null &&
                _bare(next.t) == 'لكم') ||
            (w.s == 27 && w.a == 37 && b == 'قبل') ||
            (w.s == 53 && const {43, 44, 48, 49}.contains(w.a) && b == 'وأنه'));
    if (optionalKabir) {
      add(
        w,
        'idgham_kabir',
        'بالإظهار أو الإدغام الكبير وصلاً',
        10,
        context: '${w.t} ${next?.t ?? ''}',
        ways: ['الإظهار', 'الإدغام الكبير'],
      );
    }
    if (b == 'أو' &&
        next != null &&
        ns.length > 2 &&
        ns.first.startsWith('ٱ') &&
        ns[2].contains('ُ')) {
      add(
        w,
        'first_sakin',
        'بضم واو أو للتخلص من التقاء الساكنين قبل فعل يُبدأ بهمزة مضمومة',
        39,
        text: w.t.replaceFirst(RegExp(r'و[ْۡ]'), 'وُ'),
        context: '${w.t} ${next.t}',
      );
    }
    if (const {'عوجا', 'مرقدنا'}.contains(b) &&
            ((w.s == 18 && w.a == 1) || (w.s == 36 && w.a == 52)) ||
        (w.s == 75 && w.a == 27 && b == 'من') ||
        (w.s == 83 && w.a == 14 && b == 'بل')) {
      add(
        w,
        'no_sakt',
        w.s == 75
            ? 'بلا سكت مع إدغام النون في الراء'
            : w.s == 83
            ? 'بلا سكت مع إدغام اللام في الراء'
            : 'بالوصل دون سكت',
        7,
        context: '${w.t} ${next?.t ?? ''}',
      );
    }
    if ((w.s == 2 && w.a == 259 && b == 'يتسنه') ||
        (w.s == 6 && w.a == 90 && b == 'اقتده') ||
        (w.s == 69 &&
            const {19, 20, 25, 26, 28, 29}.contains(w.a) &&
            b.endsWith('ه')) ||
        (w.s == 101 && w.a == 10 && b == 'هيه')) {
      add(
        w,
        'ha_sakt',
        'بحذف هاء السكت وصلاً وإثباتها وقفًا',
        34,
        text: cs.take(cs.length - 1).join(),
        ways: ['حذف هاء السكت وصلاً', 'إثبات هاء السكت وقفًا'],
      );
    }
    // The source (p.31) specifies the built first-person doubled ya, not
    // every final doubled ya (النبي، الحي، أي...). Ya bunayya is read with
    // kasra by Yaqub and stops without this ha; plural ya baniyya retains it.
    final firstPersonYa =
        RegExp(r'^(?:[وفبل])?(?:إلي|علي|لدي|يدي|والدي|ابنتي|بمصرخي)$')
            .hasMatch(b) ||
        (const {'بني', 'وبني', 'يابني'}.contains(b) && w.t.contains('نِ'));
    final stopHa =
        const {
          'عم',
          'فيم',
          'بم',
          'مم',
          'هو',
          'فهو',
          'وهو',
          'لهو',
          'هي',
          'فهي',
          'وهي',
        }.contains(b) ||
        (b == 'لم' && w.t.startsWith('لِ')) ||
        (cs.length >= 2 &&
            cs[cs.length - 2].startsWith('ه') &&
            RegExp(r'[ُِ]').hasMatch(cs[cs.length - 2]) &&
            cs.last.startsWith('ن') &&
            cs.last.contains('ّ')) ||
        (firstPersonYa && RegExp(r'يّ[َُِ]?[ۖ-ۭ]*$').hasMatch(w.t));
    if (stopHa ||
        (id == 'ruways' &&
            (const {'ياأسفي', 'ياويلتي', 'ياحسرتا'}.contains(b) ||
                (b == 'ثم' && w.t.startsWith('ثَ'))))) {
      add(
        w,
        'ha_sakt',
        'بإلحاق هاء السكت وقفًا فقط',
        31,
        stop: true,
        stopText: '${w.t.replaceAll(RegExp(r'[ۖ-ۭ]'), '')}هۡ',
        ways: ['إلحاق هاء السكت عند الوقف، دون الوصل'],
      );
    }
    if (b == 'وكأين' ||
        b == 'كأين' ||
        (const {24, 43, 55}.contains(w.s) &&
            const {31, 49}.contains(w.a) &&
            b == 'أيه')) {
      add(
        w,
        'rasm_stop',
        b.contains('كأين')
            ? 'بالوقف على الياء دون النون'
            : 'بإثبات الألف وقفًا',
        29,
        stop: true,
        stopText: b.contains('كأين')
            ? w.t.replaceFirst(RegExp(r'ن[ْۡ]?$'), '')
            : '${w.t}ا',
      );
    }
    if (RegExp(r'^(و|ف|ب|ل)?(رحمت|نعمت|سنت|امرأت|شجرت|لعنت|جنت|فطرت|قرت|بقيت)$')
            .hasMatch(b) ||
        b == 'ياأبت') {
      add(
        w,
        'rasm_stop',
        'بالوقف بالهاء على تاء التأنيث المرسومة تاء مفتوحة',
        29,
        stop: true,
        stopText: w.t.replaceFirst(RegExp(r'ت[َُِۖ-ۭ]*$'), 'هۡ'),
      );
    }
  }
  // The finite hā-al-kināya exceptions are safer than guessing from spelling.
  for (final w in words) {
    final b = _bare(w.t);
    final noSilah =
        const {'يؤده', 'نؤته', 'نوله', 'ونصله', 'فألقه', 'ويتقه'}.contains(b) ||
        (id == 'ruways' && (b == 'يأته' || b == 'بيده')) ||
        (w.s == 25 && w.a == 69 && b == 'فيه');
    if (noSilah) {
      var t = w.t.replaceAll(RegExp(r'[ۦۥ]'), '');
      if (b == 'ويتقه') t = t.replaceFirst('قۡ', 'قِ').replaceFirst('قْ', 'قِ');
      if (RegExp(r'ه[ْۡ]$').hasMatch(t)) {
        t = t.replaceFirst(RegExp(r'ه[ْۡ]$'), 'هِ');
      }
      add(w, 'ha_silah', 'بكسر الهاء بلا صلة', 13, text: t);
    }
    if ((w.s == 18 && w.a == 63 && b == 'أنسانيه') ||
        (w.s == 48 && w.a == 10 && b == 'عليه')) {
      add(w, 'ha_silah', 'بكسر الهاء', 13, text: w.t.replaceFirst('هُ', 'هِ'));
    }
    if (b == 'أرجه') {
      add(
        w,
        'ha_silah',
        'بإثبات همزة ساكنة وضم الهاء دون صلة',
        13,
        text: 'أَرۡجِئۡهُ',
      );
    }
    if (b == 'يرضه') add(w, 'ha_silah', 'بضم الهاء دون صلة', 13);
  }
  for (final seed in seeds) {
    final v = seed;
    final w = index['${v[0]}:${v[1]}:${v[2]}'];
    if (w == null) continue;
    final z = v[5] == 'ya_zaida';
    final text = (v[4] as String).split(RegExp(r'[:(]')).first.trim();
    // Existing partial source quotations remain annotations if they include
    // prose or a different number of words, never destructive replacements.
    var safeText =
        text.isNotEmpty &&
            !RegExp(r'إشمام|اشمام|مد |فتح |ضم |كسر |إدغام|ادغام')
                .hasMatch(text) &&
            text.split(' ').length == v[3]
        ? text
        : '';
    var count = v[3] as int;
    var description = z
        ? 'بإثبات الياء الزائدة وصلاً ووقفًا'
        : 'بإسكان ياء الإضافة';
    if (z && count == 1 && safeText.isEmpty) {
      safeText = '${w.t.replaceAll(RegExp(r'[ۖ-ۭ]'), '')}ي';
    }
    if (!z) {
      final cs = lettersOf(w.t);
      final next = index['${w.s}:${w.a}:${w.w + 1}'];
      final open = next != null && next.t.startsWith('ٱل');
      cs[cs.length - 1] =
          cs.last.replaceAll(RegExp(r'[َُِْۡٓۖ-ۭ]'), '') + (open ? 'َ' : '');
      safeText = cs.join();
      count = 1;
      description = open
          ? 'بفتح ياء الإضافة قبل أل التعريف'
          : 'بإسكان ياء الإضافة';
    }
    add(
      w,
      z ? 'ya_zaida' : 'ya_idafa',
      description,
      z ? 28 : 26,
      text: safeText,
      count: count,
      ways: z ? ['إثبات الياء وصلاً ووقفًا'] : [],
    );
  }
  for (final (s, a, b) in yaqubStoppingYaWords) {
    final candidate = words
        .where(
          (w) =>
              w.s == s &&
              w.a == a &&
              _bare(w.t).replaceAll('ي', 'ا') == b.replaceAll('ي', 'ا'),
        )
        .single;
    var actual =
        rows
            .where(
              (v) =>
                  v[0] == s &&
                  v[1] == a &&
                  v[2] == candidate.w &&
                  v[3] == 1 &&
                  (v[4] as String).isNotEmpty,
            )
            .map((v) => v[4] as String)
            .firstOrNull ??
        candidate.t;
    if (s == 2 && a == 269) {
      actual = actual.replaceFirst('تَ', 'تِ');
      rows.add([
        s,
        a,
        candidate.w,
        1,
        actual,
        'f',
        'بكسر التاء',
        '',
        {'source': yaqubSource, 'sourcePage': 28},
      ]);
    }
    add(
      candidate,
      'ya_zaida',
      'بحذف الياء وصلاً لالتقاء الساكنين وإثباتها وقفًا',
      28,
      stop: true,
      stopText: '${actual.replaceAll(RegExp(r'[ۖ-ۭ]'), '')}ي',
      ways: ['حذف الياء وصلاً', 'إثبات الياء وقفًا'],
    );
  }
  final atan = index['27:36:7']!;
  if (id == 'rawh') {
    add(
      atan,
      'ya_zaida',
      'بحذف الياء وصلاً وإثباتها وقفًا',
      28,
      stop: true,
      stopText: 'ءَاتَانِي',
      ways: ['حذف الياء وصلاً', 'إثبات الياء وقفًا'],
    );
  } else {
    add(
      atan,
      'ya_zaida',
      'بإثبات الياء مفتوحة وصلاً وساكنة وقفًا',
      28,
      ways: ['إثبات الياء مفتوحة وصلاً', 'إثبات الياء ساكنة وقفًا'],
    );
  }
  final tumid = index['27:36:4']!;
  add(
    tumid,
    'ya_zaida',
    'بإثبات الياء الزائدة وصلاً ووقفًا مع إدغام النونين',
    28,
    ways: ['إثبات الياء وصلاً ووقفًا مع إدغام النونين'],
  );
  rows.sort((a, b) {
    for (final n in [0, 1, 2]) {
      final c = (a[n] as int).compareTo(b[n] as int);
      if (c != 0) return c;
    }
    return (a.length > 7 ? '${a[7]}' : '').compareTo(
      b.length > 7 ? '${b[7]}' : '',
    );
  });
  data['variants'] = rows;
  data['reviewedUsul'] = true;
  data['usulSource'] = {
    'title': 'أصول قراءة يعقوب البصري',
    'pages': '7–39',
    'route': 'الدرة',
    'corrections': [
      'ص37: الإشمام لرويس، لا روح',
      'ص12: الإمالة الكبرى، وليست التقليل',
    ],
    'excluded': [
      'ص31: زيادة روح هاء السكت في جمع المذكر السالم من المستنير؛ لا تعمم على طريق الدرة',
    ],
    'basmala': [
      'السكت بلا بسملة وهو المقدّم',
      'الوصل بلا بسملة',
      'البسملة بأوجهها الثلاثة',
    ],
  };
  return counts;
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  for (final id in ['ruways', 'rawh']) {
    final f = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(f.readAsStringSync()) as Map;
    stdout.writeln('$id: ${buildYaqubUsul(quran, data, id)}');
    f.writeAsStringSync(jsonEncode(data));
  }
}
