// Reviewed Ibn Amir origins, from القول الموصول, pp.8–45.
// This generator never reads or writes another narrator's data.
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

const ibnAmirUsulSource = 'ibn_amir_usul_pdf';
typedef _Word = ({int s, int a, int w, String t});

String _plain(String text) => text
    .replaceAll('ـٔ', 'ء')
    .replaceAll(RegExp(r'ا[ْ۠]'), '')
    .replaceAllMapped(RegExp(r'([^اى])ٰ'), (m) => '${m[1]}ا')
    .replaceAll('ٱ', 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '');
bool _hamza(String letter) => RegExp('[ءأإؤئإٓٔ]').hasMatch(letter);
String _clear(String letter) => letter.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '');
String _vowel(String letter) => letter.contains('ُ')
    ? 'ُ'
    : letter.contains('ِ')
    ? 'ِ'
    : letter.contains('َ')
    ? 'َ'
    : '';
String _lastVowel(String text, String vowel) {
  final cs = lettersOf(text);
  if (cs.isEmpty) return text;
  cs[cs.length - 1] = _clear(cs.last) + vowel;
  return cs.join();
}

/// Adds only independently reconstructed origins. Existing approved farsh
/// remains intact; rerunning replaces only rows carrying this source tag.
Map<String, int> buildIbnAmirUsul(Map quran, Map data, String id) {
  if (!const {'hisham', 'ibn_dhakwan'}.contains(id)) {
    throw ArgumentError.value(
      id,
      'id',
      'Only Ibn Amir narrators are supported',
    );
  }
  final hisham = id == 'hisham';
  final rows = <List>[
    for (final v in (data['variants'] as List).cast<List>())
      if (!(v.length > 8 && v[8] is Map && v[8]['source'] == ibnAmirUsulSource))
        [...v],
  ];
  final words = <_Word>[
    for (final a in quran['ayahs'] as List)
      for (final (w, t) in (a[4] as String).split(' ').indexed)
        (s: a[0] as int, a: a[1] as int, w: w, t: t),
  ];
  final counts = <String, int>{};
  final added = <String>{};
  void add(
    _Word w,
    String rule,
    String how,
    int page, {
    String text = '',
    String context = '',
    bool stop = false,
    String stopText = '',
    List<String> ways = const [],
  }) {
    if (!added.add('${w.s}:${w.a}:${w.w}:$rule:$stop')) return;
    rows.add([
      w.s,
      w.a,
      w.w,
      1,
      stop ? '' : text,
      'u',
      how,
      rule,
      {
        'source': ibnAmirUsulSource,
        'sourcePage': page,
        if (context.isNotEmpty) 'context': context,
        if (stop) 'stopOnly': true,
        if (stopText.isNotEmpty) 'stopText': stopText,
        if (ways.isNotEmpty) 'ways': ways,
      },
    ]);
    counts.update(rule, (n) => n + 1, ifAbsent: () => 1);
  }

  String actual(_Word w) {
    final v = rows
        .where(
          (v) =>
              v[0] == w.s &&
              v[1] == w.a &&
              v[2] == w.w &&
              v[3] == 1 &&
              (v[4] as String).isNotEmpty &&
              v[5] == 'f',
        )
        .firstOrNull;
    return v == null ? w.t : v[4] as String;
  }

  void ya(_Word w, bool open, int page) {
    final text = actual(w), cs = lettersOf(text);
    if (cs.isEmpty || !const {'ي', 'ى'}.contains(cs.last[0])) return;
    final output = _lastVowel(text, open ? 'َ' : 'ۡ');
    // Shared written performance is not introduced as a false difference.
    final hafs = lettersOf(w.t);
    if ((open && hafs.last.contains('َ')) ||
        (!open && !hafs.last.contains('َ'))) {
      return;
    }
    add(
      w,
      'ya_idafa',
      open ? 'بفتح ياء الإضافة' : 'بإسكان ياء الإضافة',
      page,
      text: output,
    );
  }

  void imala(
    _Word w,
    int page, {
    bool optional = false,
    bool stop = false,
    int? index,
    int? secondIndex,
  }) {
    final text = actual(w), cs = lettersOf(text);
    var at =
        index ?? cs.indexWhere((c) => c.contains('ٰ') || c.startsWith('ا'));
    if (at < 0 || at >= cs.length) return;
    cs[at] = '${cs[at].replaceAll('۪', '')}۪';
    if (secondIndex != null && secondIndex >= 0 && secondIndex < cs.length) {
      cs[secondIndex] = '${cs[secondIndex].replaceAll('۪', '')}۪';
    }
    add(
      w,
      'imala',
      optional ? 'بالفتح والإمالة الكبرى' : 'بالإمالة الكبرى',
      page,
      text: stop ? '' : cs.join(),
      stop: stop,
      stopText: stop ? cs.join() : '',
      ways: optional ? const ['الفتح', 'الإمالة الكبرى'] : const [],
    );
  }

  // General shared performances belong in a profile, rather than thousands
  // of rows falsely implying a difference from Hafs at every madd or basmala.
  data['reviewedUsul'] = true;
  data['usulProfile'] = {
    'source': ibnAmirUsulSource,
    'basmala': {
      'sourcePage': 8,
      'ways': [
        'السكت بلا بسملة وهو المقدم',
        'الوصل بلا بسملة',
        'قطع الجميع مع البسملة',
        'قطع آخر السورة ووصل البسملة بالتالية',
        'وصل الجميع مع البسملة',
      ],
      'anfalBaraa': ['الوقف', 'السكت', 'الوصل'],
      'baraaBasmala': false,
      'fourZahr': {
        'sourcePage': 9,
        'sakt': ['السكت', 'البسملة'],
        'wasl': ['الوصل', 'السكت'],
        'basmala': ['أوجه البسملة الثلاثة'],
      },
    },
    'madd': {
      'sourcePage': 10,
      'muttasil': [4],
      'munfasil': [4],
    },
    'hamzaPair': {
      'sourcePage': 18,
      'performance': 'تحقيق الهمزتين من كلمتين وصلاً',
    },
    'hamzaWord': {
      'sourcePage': 14,
      'performance': hisham
          ? 'المفتوحتان: التسهيل والتحقيق مع الإدخال؛ المكسورة والمضمومة: التحقيق مع الإدخال أو دونه، مع الاستثناءات المفصلة'
          : 'تحقيق الهمزتين دون إدخال، مع الاستثناءات المفصلة',
    },
    'haKinaya': {
      'sourcePage': 11,
      'betweenMoving': 'الصلة',
      'beforeSakin': 'عدم الصلة',
      'afterSakin': 'عدم الصلة',
    },
    'yaIdafaBeforeWasl': {
      'sourcePage': 42,
      'performance': 'الإسكان، موافقة لحفص، فلا تضاف صفوف اختلاف كاذبة',
      'places': [
        'أخي20:30',
        'إني7:144',
        'ليتني25:27',
        'نفسي20:41',
        'ذكري20:42',
        'قومي25:30',
        'بعدي61:6',
      ],
      'shatibiyya': [411, 412],
    },
    'corrections': [
      'لا تعميم للوقف بالهاء على تاء التأنيث المبسوطة',
      'الوقف على وكأين بالنون',
      'لا ينسب الوقف على كاف ويكأن إلى ابن عامر',
      'أيّه: ضم الهاء وصلاً والوقف دون ألف',
      'آتاني بالنمل: حذف الياء وصلاً ووقفاً',
      'ولي نعجة وما كان لي ومعي ولي فيها: إسكان الياء',
      'الاستفهام المكرر بالنمل27:67 والواقعة56:47–48',
    ],
  };

  for (var n = 0; n < words.length; n++) {
    final w = words[n], b = _plain(w.t), text = actual(w);
    final cs = lettersOf(text);
    final next = n + 1 < words.length && words[n + 1].s == w.s
        ? words[n + 1]
        : null;
    final ns = next == null ? <String>[] : lettersOf(next.t);
    final where = '${w.s}:${w.a}';

    // Passive verbs only: the nominal قيلاً / قيله never enter this rule.
    final verb = b.replaceFirst(RegExp(r'^[وف]'), '');
    if ((hisham && const {'قيل', 'غيض', 'جيء'}.contains(verb)) ||
        const {'حيل', 'سيق', 'سيء', 'سيئت', 'سيءت'}.contains(verb)) {
      add(w, 'ishmam', 'بإشمام كسرة الحرف الأول الضم', 10);
    }

    // Ha exceptions. Written ha length is separate from its retained vowel.
    if (RegExp(r'^(يؤده|نوله|ونوله|نصله|ونصله|نؤته|ونؤته|فألقه)$')
        .hasMatch(b)) {
      final raw = text.replaceAll(RegExp('[ۦۥ]'), '');
      add(
        w,
        'ha_kinaya',
        hisham ? 'بكسر الهاء مع الصلة وعدمها' : 'بكسر الهاء وصلتها',
        12,
        text: hisham ? _lastVowel(raw, 'ِ') : '${_lastVowel(raw, 'ِ')}ۦ',
        ways: hisham
            ? const ['كسر الهاء دون صلة', 'كسر الهاء مع الصلة']
            : const [],
      );
    }
    if (where == '24:52' && b == 'ويتقه') {
      final at = cs.indexWhere((c) => c.startsWith('ق'));
      if (at >= 0) cs[at] = 'قِ';
      final raw = cs.join().replaceAll(RegExp('[ۦۥ]'), '');
      add(
        w,
        'ha_kinaya',
        hisham
            ? 'بكسر القاف والهاء مع الصلة وعدمها'
            : 'بكسر القاف والهاء وصلتها',
        12,
        text: '${_lastVowel(raw, 'ِ')}${hisham ? '' : 'ۦ'}',
        ways: hisham
            ? const ['كسر الهاء دون صلة', 'كسر الهاء مع الصلة']
            : const [],
      );
    }
    if (where == '39:7' && b == 'يرضه') {
      add(
        w,
        'ha_kinaya',
        hisham ? 'بإسكان الهاء أو ضمها دون صلة' : 'بضم الهاء وصلتها',
        12,
        text: '${_lastVowel(text, hisham ? 'ۡ' : 'ُ')}${hisham ? '' : 'ۥ'}',
        ways: hisham ? const ['إسكان الهاء', 'ضم الهاء دون صلة'] : const [],
      );
    }
    if (hisham && w.s == 99 && const {7, 8}.contains(w.a) && b == 'يره') {
      add(w, 'ha_kinaya', 'بإسكان الهاء', 12, text: _lastVowel(text, 'ۡ'));
    }
    if (const {'7:111', '26:36'}.contains(where) && b == 'أرجه') {
      add(
        w,
        'ha_kinaya',
        hisham ? 'بضم هاء أرجئه وصلتها' : 'بكسر هاء أرجئه دون صلة',
        12,
        text: hisham ? 'أَرۡجِئۡهُۥ' : 'أَرۡجِئۡهِ',
      );
    }
    if ((where == '48:10' && b == 'عليه') ||
        (where == '18:63' && b == 'أنسانيه')) {
      add(w, 'ha_kinaya', 'بكسر الهاء', 12, text: _lastVowel(text, 'ِ'));
    }
    if (where == '25:69' && b == 'فيه') {
      add(
        w,
        'ha_kinaya',
        'بكسر الهاء بلا صلة',
        12,
        text: text.replaceAll(RegExp('[ۦۥ]'), ''),
      );
    }

    // Word-initial dual hamza. Lexical additions/deletions stay in farsh;
    // these rows encode only the permitted hamza performance.
    final initialHamzas = cs.length > 1 && _hamza(cs[0]) && _hamza(cs[1]);
    final amantum =
        const {'7:123', '20:71', '26:49'}.contains(where) &&
        b.contains('امنتم');
    final ankan = where == '68:14' && b == 'أن';
    final adhhabtum = where == '46:20' && b == 'أذهبتم';
    if (amantum ||
        ankan ||
        (initialHamzas && hisham) ||
        (adhhabtum && hisham)) {
      if (!(where == '41:44' && hisham)) {
        final movement = initialHamzas ? _vowel(cs[1]) : 'َ';
        final repeated = const {
          '13:5',
          '17:49',
          '17:98',
          '23:82',
          '29:28',
          '29:29',
          '32:10',
          '37:16',
          '37:53',
          '27:67',
          '79:10',
          '79:11',
          '56:47',
          '56:48',
        }.contains(where);
        final mandatory = const {
          '7:81',
          '7:113',
          '19:66',
          '26:41',
          '37:52',
          '37:86',
          '41:9',
        }.contains(where);
        final ways = amantum
            ? <String>['تسهيل الهمزة الثانية بلا إدخال']
            : ankan
            ? <String>[
                hisham
                    ? 'تسهيل الهمزة الثانية مع إدخال ألف الفصل'
                    : 'تسهيل الهمزة الثانية بلا إدخال',
              ]
            : repeated
            ? <String>['تحقيق الهمزتين مع إدخال ألف الفصل']
            : mandatory
            ? <String>[
                'تحقيق الهمزتين مع إدخال ألف الفصل',
                if (where == '41:9') 'تسهيل الثانية مع إدخال ألف الفصل',
              ]
            : movement == 'َ'
            ? <String>[
                'تسهيل الثانية مع إدخال ألف الفصل',
                'تحقيق الهمزتين مع إدخال ألف الفصل',
              ]
            : <String>[
                'تحقيق الهمزتين دون إدخال',
                'تحقيق الهمزتين مع إدخال ألف الفصل',
                if (const {'54:25', '38:8'}.contains(where))
                  'تسهيل الثانية مع إدخال ألف الفصل',
              ];
        add(
          w,
          'tasheel_word',
          ways.join(' أو '),
          amantum
              ? 15
              : ankan
              ? 14
              : movement == 'ُ'
              ? 16
              : movement == 'َ'
              ? 14
              : 15,
          ways: ways,
        );
      }
    }

    // Small assimilation. Its written forms are independent of the farsh
    // classification of another narrator, so shared readings compare equally.
    if (ns.isNotEmpty && next != null) {
      final first = ns.first[0];
      var assimilate = false, optional = false;
      var page = 20;
      if (RegExp(r'^[وف]?إذ$').hasMatch(b)) {
        assimilate = (hisham ? 'تزسصجد' : 'د').contains(first);
      } else if (RegExp(r'^[وفل]?قد$').hasMatch(b)) {
        page = 21;
        assimilate = (hisham ? 'سذضظزجصش' : 'ذضظز').contains(first);
        if (hisham && where == '38:24') assimilate = false;
        optional = !hisham && first == 'ز';
      } else if (b.endsWith('ت') &&
          cs.last.contains('ۡ') &&
          'ثظص'.contains(first)) {
        page = 22;
        assimilate = !(hisham && where == '22:40' && b == 'لهدمت');
      } else if (hisham && (b == 'بل' || b == 'هل')) {
        page = 23;
        assimilate =
            (b == 'بل' ? 'تظزسط' : 'تث').contains(first) && where != '13:16';
      } else if (b == 'يرد' &&
          w.s == 3 &&
          const {145}.contains(w.a) &&
          first == 'ث') {
        page = 24;
        assimilate = true;
      }
      if (assimilate) {
        final source = _lastVowel(text, '');
        add(
          w,
          'idgham_saghir',
          optional
              ? 'بالإظهار والإدغام'
              : 'بإدغام الحرف الأخير في أول الكلمة التالية',
          page,
          text: source,
          context: '$text ${next.t}',
          ways: optional ? const ['الإظهار', 'الإدغام'] : const [],
        );
        // The second word carries the written shadda, but remains one aligned
        // Quran word rather than duplicating the full boundary quotation.
        if (!ns.first.contains('ّ')) {
          final target = [...ns];
          target[0] = '${target[0]}ّ';
          add(
            next,
            'idgham_saghir',
            'بتشديد أول الكلمة لإدغام ما قبلها',
            page,
            text: target.join(),
          );
        }
      }
    }
    if (b.contains('اتخذ') || b.contains('أخذت')) {
      final index = cs.indexWhere((c) => c.startsWith('ذ'));
      if (index >= 0 &&
          index + 1 < cs.length &&
          cs[index + 1].startsWith('ت')) {
        final target = [...cs];
        target[index] = 'ذ';
        target[index + 1] =
            '${_clear(target[index + 1])}ّ${_vowel(target[index + 1])}';
        add(
          w,
          'idgham_saghir',
          'بإدغام الذال في التاء',
          24,
          text: target.join(),
        );
      }
    }
    if ((b.startsWith('لبثت') ||
        b.startsWith('ولبثت') ||
        (hisham && b.contains('أورثتموها')))) {
      final index = cs.indexWhere((c) => c.startsWith('ث'));
      if (index >= 0 &&
          index + 1 < cs.length &&
          cs[index + 1].startsWith('ت')) {
        final target = [...cs];
        target[index] = 'ث';
        target[index + 1] =
            '${_clear(target[index + 1])}ّ${_vowel(target[index + 1])}';
        add(
          w,
          'idgham_saghir',
          'بإدغام الثاء في التاء',
          24,
          text: target.join(),
        );
      }
    }
    if (where == '7:176' && b == 'يلهث' && hisham) {
      add(
        w,
        'idgham_saghir',
        'بإظهار الثاء عند الذال',
        24,
        text: _lastVowel(text, 'ۡ'),
      );
      if (next != null) {
        add(
          next,
          'idgham_saghir',
          'بإظهار الثاء دون تشديد الذال بعدها',
          24,
          text: next.t.replaceFirst('ّ', ''),
        );
      }
    }
    if (where == '11:42' && b == 'اركب') {
      add(
        w,
        'idgham_saghir',
        'بإظهار الباء عند الميم',
        24,
        text: _lastVowel(text, 'ۡ'),
      );
      if (next != null) {
        add(
          next,
          'idgham_saghir',
          'بإظهار الباء دون تشديد الميم بعدها',
          24,
          text: next.t.replaceFirst('ّ', ''),
        );
      }
    }
    if ((where == '36:1' && b == 'يس') ||
        (where == '68:1' && b == 'ن') ||
        (where == '19:1' && b == 'كهيعص')) {
      add(
        w,
        'idgham_saghir',
        where == '19:1'
            ? 'بإدغام دال صاد في ذال ذكر'
            : 'بإدغام النون في الواو مع الغنة',
        24,
      );
    }

    // First of two sakins: only identifiable originally-sakin particles and
    // tanween, never arbitrary case-ending kasras before an imperative.
    if (next != null &&
        ns.length > 2 &&
        ns.first.startsWith('ٱ') &&
        ns[2].contains('ُ')) {
      final particle = RegExp(r'^[وف]?(أن|إن|من|عن|أو|قل|قد|لقد|قالت|بل|هل)$')
          .hasMatch(b);
      final tanween = RegExp('[ًٌٍٖٗٞ]').hasMatch(w.t);
      final exceptional =
          !hisham && const {'7:49', '14:26'}.contains(where) && tanween;
      if (particle || tanween && (hisham || exceptional)) {
        add(
          w,
          'first_sakin',
          exceptional
              ? 'بضم التنوين أو كسره للتخلص من التقاء الساكنين'
              : 'بضم الساكن الأول للزوم ضم ثالث الفعل',
          25,
          context: '${w.t} ${next.t}',
          ways: exceptional ? const ['كسر التنوين', 'ضم التنوين'] : const [],
        );
      }
    }

    // Major imala: explicitly bounded lexical sets and opening letters.
    if (w.w == 0 && w.a == 1 && const {10, 11, 12, 13, 14, 15}.contains(w.s)) {
      imala(w, 26, index: cs.indexWhere((c) => c.startsWith('ر')));
    }
    if (w.s == 19 && w.a == 1 && w.w == 0) {
      imala(w, 26, index: cs.indexWhere((c) => c.startsWith('ي')));
    }
    if (hisham) {
      if ((where == '33:53' && const {'إناه', 'إنيه'}.contains(b)) ||
          (where == '88:5' && b == 'ءانية') ||
          (w.s == 109 && const {'عابد', 'عابدون'}.contains(b)) ||
          (where == '36:73' && const {'مشارب', 'ومشارب'}.contains(b))) {
        imala(
          w,
          26,
          index: cs.indexWhere((c) => c.contains('ٰ') || c.startsWith('ا')),
        );
      }
    } else {
      if (RegExp(r'^[وف]?(جاء|شاء)(نا|ك|كم|هم|ه|ت)?$').hasMatch(b)) {
        imala(w, 26, index: cs.indexWhere((c) => c.startsWith('ا')));
      }
      if (RegExp(r'^[وف]?زاد(هم|ه|كم|نا|ت)?$').hasMatch(b)) {
        imala(
          w,
          27,
          optional: where != '2:10',
          index: cs.indexWhere((c) => c.startsWith('ا')),
        );
      }
      if (RegExp(r'^[وف]?ر(أ|ء)ا?(ي)?(ك|ها|ه)?$').hasMatch(b) &&
          (b.contains('أ') || b.contains('ء'))) {
        final attached = RegExp(r'(ك|ها|ه)$').hasMatch(b);
        final sakinNext =
            !attached && ns.isNotEmpty && ns.first.startsWith('ٱ');
        imala(
          w,
          27,
          optional: attached,
          stop: sakinNext,
          index: cs.indexWhere((c) => _hamza(c)),
          secondIndex: cs.indexWhere((c) => c.startsWith('ر')),
        );
      }
      if (w.a == 1 && w.w == 0 && w.s >= 40 && w.s <= 46 && b == 'حم') {
        imala(w, 28, index: 0);
      }
      if ((where == '9:109' && b == 'هار') ||
          b == 'حمارك' ||
          b == 'الحمار' ||
          b == 'المحراب' ||
          b == 'إكراههن' ||
          b == 'الإكرام' ||
          b == 'عمران') {
        final obligatory =
            b == 'المحراب' && const {'3:39', '19:11'}.contains(where);
        imala(
          w,
          28,
          optional: !obligatory,
          index: cs.lastIndexWhere((c) => c.startsWith('ا') || c.contains('ٰ')),
        );
      }
    }

    // Corrected explicit ya lists (pp.42–43), rather than borrowing rules
    // from other narrators or interpreting every final ya as possessive.
    if (b == 'لعلي' &&
        const {
          '12:46',
          '20:10',
          '23:100',
          '28:29',
          '28:38',
          '40:36',
        }.contains(where)) {
      ya(w, true, 42);
    }
    if (where == '11:91' && b == 'أرهطي') ya(w, !hisham, 42);
    if (where == '40:41' && b == 'لي') ya(w, hisham, 42);
    if (const {
          'رسلي': '58:21',
          'دعائي': '71:6',
          'دعاءي': '71:6',
          'ءابائي': '12:38',
          'آبائي': '12:38',
          'ءاباءي': '12:38',
          'حزني': '12:86',
          'توفيقي': '11:88',
        }[b.replaceFirst(RegExp(r'^[وف]'), '')] ==
        where) {
      ya(w, true, 42);
    }
    if ((where == '5:28' && b == 'يدي') ||
        (where == '14:31' && b == 'لعبادي') ||
        (where == '7:146' && b == 'ءاياتي')) {
      ya(w, false, 42);
    }
    if ((b == 'بيتي' && const {'2:125', '22:26', '71:28'}.contains(where)) ||
        (b == 'ولي' && where == '109:6') ||
        (b == 'لي' && where == '27:20')) {
      ya(w, hisham, 43);
    }
    if ((b == 'أرضي' && where == '29:56') ||
        (b == 'صراطي' && where == '6:153')) {
      ya(w, true, 43);
    }
    if ((b == 'معي' &&
            const {
              '7:105',
              '9:83',
              '18:67',
              '18:72',
              '18:75',
              '21:24',
              '26:62',
              '26:118',
              '28:34',
            }.contains(where)) ||
        (b == 'ولي' && where == '38:23') ||
        (b == 'لي' && const {'14:22', '38:69', '20:18'}.contains(where))) {
      ya(w, false, 43);
    }
    if (where == '43:68' && b == 'ياعباد') {
      add(
        w,
        'ya_zaida',
        'بإثبات الياء وإسكانها وصلاً ووقفاً',
        45,
        text: '$textيۡ',
      );
    }
    if (hisham && where == '7:195' && b == 'فكيدون') {
      add(
        w,
        'ya_zaida',
        'بإثبات الياء وصلاً ووقفاً بخلاف عنه',
        45,
        text: '$textيۡ',
        ways: const ['إثبات الياء وصلاً ووقفاً', 'حذف الياء وصلاً ووقفاً'],
      );
    }
    if (where == '27:36' && b == 'ءاتين') {
      add(
        w,
        'ya_zaida',
        'بحذف الياء وصلاً ووقفاً',
        45,
        text: text.replaceAll(RegExp(r'ۦَ?'), ''),
      );
    }
    if (!hisham && where == '18:70' && b == 'تسءلني') {
      add(
        w,
        'ya_zaida',
        'بحذف الياء وصلاً ووقفاً',
        45,
        text: text.replaceFirst(RegExp(r'[يى][ً-ٰٟۖ-ۭ]*$'), ''),
      );
    }

    // Correct the erroneous general ta-to-ha statement in the source: only
    // the specifically transmitted يا أبت is represented here.
    if (b == 'ياأبت') {
      final stopText = [...cs.take(cs.length - 1), 'هۡ'].join();
      add(
        w,
        'waqf_rasm',
        'بالوقف على يا أبت بالهاء',
        40,
        stop: true,
        stopText: stopText,
      );
    }
    if (const {'24:31', '43:49', '55:31'}.contains(where) && b == 'أيه') {
      add(
        w,
        'waqf_rasm',
        'بضم الهاء وصلاً والوقف دون إثبات ألف',
        40,
        stop: true,
        stopText: _lastVowel(text, 'ۡ'),
      );
    }

    if (hisham) _stoppingHamza(w, text, add);
  }
  rows.sort((a, b) {
    for (final i in [0, 1, 2]) {
      final d = (a[i] as int).compareTo(b[i] as int);
      if (d != 0) return d;
    }
    return (a.length > 7 ? a[7].toString() : '').compareTo(
      b.length > 7 ? b[7].toString() : '',
    );
  });
  data['variants'] = rows;
  return counts;
}

typedef _Add = void Function(
  _Word,
  String,
  String,
  int, {
  String text,
  String context,
  bool stop,
  String stopText,
  List<String> ways,
});

void _stoppingHamza(_Word w, String text, _Add add) {
  final cs = lettersOf(text);
  var compensationAlif = false;
  if (cs.length > 1 &&
      cs.last.startsWith('ا') &&
      _hamza(cs[cs.length - 2]) &&
      RegExp('[ًٗ]').hasMatch(cs[cs.length - 2])) {
    compensationAlif = true;
    cs.removeLast();
  }
  // The rasm sometimes follows a final hamza by an unpronounced alif.
  // This carrier must not make a genuinely terminal hamza look medial.
  if (cs.isNotEmpty &&
      cs.last.startsWith('ا') &&
      RegExp('[ْ۟۠]').hasMatch(cs.last) &&
      cs.length > 1 &&
      _hamza(cs[cs.length - 2])) {
    cs.removeLast();
  }
  if (cs.length < 2 || !_hamza(cs.last)) return;
  final h = cs.last, before = cs[cs.length - 2], v = _vowel(before);
  final fathatan = compensationAlif || RegExp('[ًٗ]').hasMatch(h);
  final base = _clear(before);
  final prefix = cs.take(cs.length - 1).join();
  String stopText;
  final ways = <String>[];
  var page = 30;
  if (base == 'ا' && v.isEmpty) {
    page = 31;
    stopText = prefix;
    ways.addAll([
      'إبدال الهمزة ألفاً مع القصر',
      'إبدال الهمزة ألفاً مع التوسط',
      'إبدال الهمزة ألفاً مع الإشباع',
    ]);
    if (h.contains('ِ') ||
        h.contains('ُ') ||
        h.contains('ٞ') ||
        h.contains('ٖ')) {
      ways.addAll([
        'تسهيل الهمزة بالروم مع القصر',
        'تسهيل الهمزة بالروم مع المد',
      ]);
    }
  } else if (v.isNotEmpty) {
    final replacement = v == 'َ'
        ? 'ا'
        : v == 'ِ'
        ? 'ي'
        : 'و';
    stopText = fathatan && v == 'ِ'
        ? '$prefix$replacementَا'
        : '$prefix$replacement';
    ways.add(
      fathatan && v == 'ِ'
          ? 'إبدال الهمزة ياءً مفتوحة مع إثبات ألف العوض عن تنوين النصب'
          : 'إبدال الهمزة حرف مد من جنس حركة ما قبلها',
    );
    if (h.contains('ِ') || h.contains('ُ')) {
      ways.add('تسهيل الهمزة بين بين بالروم');
    }
  } else {
    page = base == 'و' || base == 'ي' ? 32 : 31;
    final extra = RegExp(r'(هنيء|مريء|بريء|نسيء|قروء)(ا)?$')
        .hasMatch(_plain(text));
    stopText = [
      ...cs.take(cs.length - 2),
      extra
          ? '$baseّ${fathatan ? 'َا' : 'ۡ'}'
          : '$base${fathatan ? 'َا' : 'ۡ'}',
    ].join();
    if (!extra) {
      ways.add(
        fathatan
            ? 'نقل حركة الهمزة وحذفها مع إبقاء ألف العوض عن تنوين النصب'
            : 'نقل حركة الهمزة إلى الساكن قبلها وحذف الهمزة',
      );
    }
    if (base == 'و' || base == 'ي') {
      ways.add('إبدال الهمزة من جنس الواو أو الياء وإدغامها');
    }
    if (h.contains('ِ') || h.contains('ُ')) ways.add('الروم بعد النقل');
    if (h.contains('ُ')) ways.add('الإشمام بعد النقل');
  }
  // The source restricts the additional rasm ways to written carriers.
  // Keep them alongside the qiyasi ways; never replace every hamza by its
  // apparent seat. These exact spellings are the examples on pp.34–36.
  if (h.startsWith('ؤ') && RegExp(r'اْ[ۖ-ۭ]*$').hasMatch(text)) {
    ways.addAll([
      'الإبدال واواً على الرسم مع السكون المحض${base == 'ا' ? ' والقصر والتوسط والإشباع' : ''}',
      'الإبدال واواً على الرسم مع الروم${base == 'ا' ? ' والقصر' : ''}',
      'الإبدال واواً على الرسم مع الإشمام${base == 'ا' ? ' والقصر والتوسط والإشباع' : ''}',
    ]);
  }
  final where = '${w.s}:${w.a}';
  if (const {
        '10:15',
        '16:90',
        '20:130',
        '42:51',
        '30:8',
        '30:16',
      }.contains(where) &&
      base == 'ا' &&
      (h.startsWith('ي') || h.startsWith('ئ'))) {
    ways.addAll([
      'الإبدال ياءً على الرسم مع السكون والقصر والتوسط والإشباع',
      'الإبدال ياءً على الرسم مع الروم والقصر',
    ]);
  }
  add(
    w,
    'hisham_waqf',
    'بتغيير الهمز المتطرف عند الوقف على المذهب القياسي',
    page,
    stop: true,
    stopText: stopText,
    ways: ways,
  );
}

void main(List<String> args) {
  if (!args.contains('--write')) {
    throw ArgumentError(
      'Use --write explicitly, after replacing the reviewed farsh',
    );
  }
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  for (final id in ['hisham', 'ibn_dhakwan']) {
    final file = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(file.readAsStringSync()) as Map;
    final counts = buildIbnAmirUsul(quran, data, id);
    file.writeAsStringSync(jsonEncode(data));
    stdout.writeln('$id: $counts');
  }
}
