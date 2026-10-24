import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'arabic.dart';
import 'kharouf.dart';

/// One verse of a poem: its number, its chapter and its two halves.
typedef Bayt = ({int n, String chapter, String sadr, String ajz});

/// The poems the riwayat are read by.
enum Poem {
  shatibiyya('الشاطبية', 'حرز الأماني ووجه التهاني، للإمام الشاطبي'),
  durrah('الدرة', 'الدرة المضية في القراءات الثلاث، لابن الجزري');

  const Poem(this.nameAr, this.title);
  final String nameAr;
  final String title;

  /// The Durrah for Abu Ja'far, Ya'qub and Khalaf al-'Ashir; the Shatibiyya
  /// for the seven.
  static Poem of(String riwaya) =>
      const {'abu_jafar', 'yaqub', 'khalaf'}.contains(qiraaOf(riwaya).id)
      ? Poem.durrah
      : Poem.shatibiyya;
}

/// Selected evidence and its chapter(s). Book quotations take precedence
/// over rule statements and exact word matches. Unmatched evidence stays
/// empty; the chapter is available separately for browsing.
typedef Reference = ({
  Poem poem,
  String chapter,
  List<Bayt> verses,
  Set<int> mention,
  bool fromBook,
  Map<int, String> bookExplanation,
});

class BaytExplanation {
  const BaytExplanation(
    this.text,
    this.source,
    this.url,
    this.page,
    this.group,
  );
  final String text, source, url, page;

  /// Some adjoining verses are explained together by the author.
  final List<int> group;
}

/// The Shatibiyya and the Durrah (assets/data/manzumat.json, built by
/// tool/build_manzumat.dart from Quranpedia's books), and the place of a
/// reading in them.
class Manzumat {
  Manzumat._(this._verses, this._explanations);

  final Map<Poem, List<Bayt>> _verses;
  final Map<int, BaytExplanation> _explanations;
  final Map<Poem, Map<String, Set<int>>> _quotationCache = {};

  static const source = 'الموسوعة القرآنية quranpedia.net';

  static Future<Manzumat>? _loading;

  static Future<Manzumat> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<Manzumat> _load(AssetBundle bundle) async {
    final json = jsonDecode(
      await bundle.loadString('assets/data/manzumat.json'),
    ) as Map<String, dynamic>;
    List<Bayt> verses(String key) => [
      for (final v in json[key] as List)
        (
          n: v[0] as int,
          chapter: v[1] as String,
          sadr: v[2] as String,
          ajz: v[3] as String,
        ),
    ];
    final explanations = jsonDecode(
      await bundle.loadString('assets/data/poem_explanations.json'),
    ) as Map<String, dynamic>;
    return Manzumat._(
      {Poem.shatibiyya: verses('shatibiyya'), Poem.durrah: verses('durrah')},
      {
        for (final e in explanations['shatibiyya'] as List)
          e[0] as int: BaytExplanation(
            e[1] as String,
            (e.length > 5 ? e[5] : explanations['source']) as String,
            e[2] as String,
            e[3] as String,
            (e[4] as List).cast<int>(),
          ),
      },
    );
  }

  BaytExplanation? explanation(Poem poem, int n) =>
      poem == Poem.shatibiyya ? _explanations[n] : null;

  List<Bayt> verses(Poem poem) => _verses[poem]!;

  /// The chapters of [poem], in order.
  List<String> chapters(Poem poem) => [
    ...{for (final v in verses(poem)) v.chapter},
  ];

  /// Where [reading] (of [hafs], the Hafs word(s), in surah [surah]) is
  /// stated, with the surah names of the mushaf ([surahNames], 1-based by
  /// number - 1) to find the chapter of the farsh.
  Reference referenceOf(
    Variant reading,
    String hafs,
    int surah,
    List<String> surahNames, {
    Iterable<KharoufEntry> entries = const [],
  }) {
    final poem = Poem.of(reading.riwayaId);
    var chapter =
        _usulChapter(poem, reading) ??
        _surahChapter(poem, surah, surahNames) ??
        chapters(poem).first;
    var inChapter = [
      for (final v in verses(poem))
        if (v.chapter == chapter) v,
    ];
    // A book entry may quote evidence for several readers and several rules.
    // For usul, keep the selected rule's chapter; farsh quotations may cite
    // another chapter. Only use entries naming this narrator.
    final quoted = <int>{};
    final bookExplanation = <int, String>{};
    for (final e in entries) {
      final mine = e.readings.where(
        (r) =>
            r.riwayat.contains(reading.riwayaId) ||
            r.disputed.contains(reading.riwayaId),
      );
      if (mine.isEmpty) continue;
      final ids = {for (final quote in e.verses) ...quotedVerses(poem, quote)};
      for (final b in verses(poem).where(
        (b) =>
            ids.contains(b.n) &&
            (!reading.isUsul || b.chapter == chapter) &&
            _citationFits(poem, reading, b.n),
      )) {
        quoted.add(b.n);
        bookExplanation[b.n] = [
          for (final r in mine)
            [
              if (r.text.isNotEmpty) 'القراءة: «${r.text}».',
              r.how,
              if (r.taqlil) 'بالتقليل.',
              if (r.stopOnly) 'وقفًا فقط.',
              for (final (note, readers) in r.notes)
                if (readers.contains(reading.riwayaId)) note,
            ].where((s) => s.isNotEmpty).join(' '),
        ].where((s) => s.isNotEmpty).join('\n');
      }
    }
    if (quoted.isNotEmpty) {
      final citedChapters = {
        for (final b in verses(poem))
          if (quoted.contains(b.n)) b.chapter,
      };
      inChapter = [
        for (final b in verses(poem))
          if (citedChapters.contains(b.chapter)) b,
      ];
      chapter = citedChapters.join(' • ');
    }
    // Exact word forms, not substring matches against common Arabic letters.
    final keys = {
      for (final w in [...hafs.split(' '), ...reading.text.split(' ')])
        if (skeleton(w).length >= 3 &&
            !_common.map(skeleton).contains(skeleton(w)))
          skeleton(w),
    };
    bool names(Bayt v) => '${v.sadr} ${v.ajz}'
        .split(' ')
        .map(skeleton)
        .any((w) => keys.any((k) => w == k || w == 'و$k' || w == 'ف$k'));
    final ruleVerses = _ruleVerses(poem, reading);
    final selected = quoted.isNotEmpty
        ? quoted
        : ruleVerses.isNotEmpty
        ? ruleVerses
        : {
            for (final v in inChapter)
              if (names(v)) v.n,
          };
    return (
      poem: poem,
      chapter: chapter,
      verses: inChapter,
      mention: {
        for (final b in inChapter)
          if (selected.contains(b.n)) b.n,
      },
      fromBook: quoted.isNotEmpty,
      bookExplanation: bookExplanation,
    );
  }

  bool _citationFits(Poem poem, Variant v, int n) {
    if (poem == Poem.shatibiyya && v.riwayaId == 'warsh' && v.isLinHamz) {
      return v.rule == 'lin_hamz' ? {179, 180}.contains(n) : n == 182;
    }
    // Naql and Hamzah's sakt share a chapter and often share a book note.
    // The sakt couplets are not evidence of Warsh's naql.
    if (poem == Poem.shatibiyya && v.riwayaId == 'warsh' && v.rule == 'naql') {
      return !{227, 228}.contains(n);
    }
    return true;
  }

  static const _common = {
    'الذين',
    'الذي',
    'الله',
    'امنوا',
    'انهم',
    'عليهم',
    'اليهم',
  };

  /// Preserve alefs/hamzas: the general Quran skeleton deliberately removes
  /// them, making it too permissive for assigning a poem as evidence.
  static String _letters(String s) => s
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ـ', '')
      .replaceAll(RegExp('[^ء-ي]'), '');

  /// Match substantial consecutive words of a book quotation against the
  /// appropriate poem. A quotation can span multiple bayts; a short common
  /// word alone is never sufficient. Cached because entries repeat citations.
  Set<int> quotedVerses(Poem poem, String quotation) =>
      (_quotationCache[poem] ??= {}).putIfAbsent(quotation, () {
        final quote = _letters(quotation);
        return {
          for (final b in verses(poem))
            if (_quotesBayt(quote, b)) b.n,
        };
      });

  bool _quotesBayt(String quote, Bayt b) {
    final words = '${b.sadr} ${b.ajz}'
        .split(RegExp(r'\s+'))
        .map(_letters)
        .where((w) => w.isNotEmpty)
        .toList();
    for (var i = 0; i < words.length - 1; i++) {
      final pair = words[i] + words[i + 1];
      if (pair.length >= 18 && quote.contains(pair)) return true;
      if (i + 2 < words.length) {
        final triple = pair + words[i + 2];
        if (triple.length >= 11 && quote.contains(triple)) return true;
      }
    }
    return false;
  }

  /// Verified rule statements for cases where the book has no quotation.
  /// No chapter-wide fallback: the rest remains available under “more”.
  bool _anaWasl(Variant v) {
    final word = v.text.trim().split(RegExp(r'\s+')).first;
    final d = v.shownDescription.replaceAll(RegExp('[ً-ٰٟ]'), '');
    return const {'warsh', 'qalun'}.contains(v.riwayaId) &&
        _letters(word) == 'انا' &&
        (d.contains('مد') || RegExp('إثبات.*ألف.*أنا').hasMatch(d));
  }

  Set<int> _ruleVerses(Poem poem, Variant v) {
    final d = v.shownDescription;
    if (poem == Poem.shatibiyya && _anaWasl(v)) return {521};
    if (poem == Poem.durrah) {
      if (const {'ruways', 'rawh'}.contains(v.riwayaId)) {
        final specific = switch (v.rule) {
          'ishmam' when v.riwayaId == 'ruways' => <int>{62, 63},
          'ha_damir' => <int>{11, 12},
          'mim_jam' => <int>{13},
          'madd_munfasil' || 'madd_muttasil' => <int>{22},
          'imala' || 'fath' => <int>{44, 45},
          'ha_silah' || 'ha_kinaya' => <int>{18, 19, 20, 21},
          'no_sakt' => <int>{37},
          'naql' when v.surah == 55 && v.ayah == 54 => <int>{37},
          'idgham_saghir' when v.surah == 36 || v.surah == 68 => <int>{41},
          'idgham_saghir' => <int>{40},
          'idgham_kabir' when v.surah == 27 => <int>{15, 16},
          'idgham_kabir' => <int>{14, 15},
          _ => <int>{},
        };
        if (specific.isNotEmpty) return specific;
      }
      return switch (v.rule) {
        'tasheel_word' => {23},
        'tasheel_pair' || 'ibdal_waw' || 'ibdal_ya' => {27},
        'silah' when d.contains('ميم الجمع') => {13},
        _ => {},
      };
    }
    if (v.riwayaId == 'warsh') {
      switch (v.rule) {
        case 'naql':
          return {226};
        case 'badal':
          return {171, 172};
        case 'lin_hamz':
          return {179, 180};
        case 'lin_hamz_exception':
        case 'lin_hamz_sawat':
          return {182};
        case 'tarqiq':
          return {343, 344};
        case 'taghliz':
          return {359, 360};
        case 'tasheel_word':
          return v.usulWays.length == 1 ? {183} : {183, 184};
        case 'tasheel_pair':
          return {206};
        case 'ibdal_waw':
        case 'ibdal_ya':
          return {209, 210, 211};
      }
      if (d.contains('ميم الجمع')) return {112};
      if (d.contains('نقل') && v.isUsul) return {226};
    }
    if (v.rule == 'sakt') return {227, 228, 229};
    if (d.contains('ميم الجمع')) return {111, 112};
    return {};
  }

  /// The chapter of the usul a reading belongs to, by its rule or by the
  /// words of its description.
  String? _usulChapter(Poem poem, Variant v) {
    if (poem == Poem.durrah &&
        const {'ruways', 'rawh'}.contains(v.riwayaId) &&
        v.isUsul) {
      final evidence = _ruleVerses(poem, v);
      if (evidence.isNotEmpty) {
        return verses(poem).firstWhere((b) => evidence.contains(b.n)).chapter;
      }
    }
    if (poem == Poem.shatibiyya && _anaWasl(v)) {
      return verses(poem).firstWhere((b) => b.n == 521).chapter;
    }
    final d = v.shownDescription;
    final topics = <String>[
      if (v.rule == 'ya_zaida') 'الزوائد',
      if (v.rule == 'ya_idafa') 'الإضافة',
      if (const {'rasm_stop', 'waqf_rasm', 'ha_sakt'}.contains(v.rule))
        'المرسوم',
      if (v.rule == 'naql') 'نقل',
      if (v.rule == 'tasheel_word' || v.rule == 'hamza_wasl')
        'الهمزتين من كلمة',
      if (const {'tasheel_pair', 'ibdal_waw', 'ibdal_ya'}.contains(v.rule))
        'الهمزتين من كلمتين',
      if (v.rule == 'badal' || v.isLinHamz) 'المد',
      if (v.rule == 'tarqiq') 'الراء',
      if (v.rule == 'taghliz') 'اللام',
      if (v.rule == 'sakt' || d.contains('سكت')) 'نقل',
      if (v.isImala) 'الإمالة',
      if (d.contains('ميم الجمع')) 'أم القرآن', // the mim al-jam' is there
      if (d.contains('هاء') && d.contains('صلة')) 'الكناية',
      if (d.contains('إدغام') || d.contains('ادغام')) 'الإدغام',
      if (d.contains('تسهيل') ||
          d.contains('الهمزتين') ||
          d.contains('الهمزة الثانية'))
        'الهمزتين',
      if (d.contains('نقل')) 'نقل',
      if (d.contains('إبدال') || d.contains('بالهمز')) 'الهمز المفرد',
      if (d.contains('المد') || d.contains('مد ') || d.contains('القصر'))
        'المد',
      if (d.contains('الياء') && (d.contains('فتح') || d.contains('إسكان')))
        'الإضافة',
      if (d.contains('إثبات الياء') || d.contains('بإثبات ياء')) 'الزوائد',
    ];
    if (!v.isUsul) {
      return null; // a farsh: the chapter of its surah
    }
    final all = chapters(poem);
    for (final t in topics) {
      final hit = all
          .where((c) => skeleton(c).contains(skeleton(t)))
          .firstOrNull;
      if (hit != null) return hit;
    }
    return null;
  }

  /// The chapter of the farsh of [surah]: the one naming it, or covering it
  /// («ومن سورة الأحقاف إلى سورة الرحمن»).
  String? _surahChapter(Poem poem, int surah, List<String> surahNames) {
    // Surah numbers named in a chapter title, in order.
    List<int> named(String title) {
      final t = skeleton(title);
      final found = <(int, int)>[];
      for (var s = 1; s <= surahNames.length; s++) {
        final k = skeleton(surahNames[s - 1]);
        if (k.length < 2) continue;
        final at = t.indexOf(k);
        if (at >= 0) found.add((at, s));
      }
      if (t.contains('ملقرن')) found.add((0, 1)); // أم القرآن
      if (t.contains('خرلقرن')) found.add((t.length, 115)); // آخر القرآن
      found.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final f in found) f.$2];
    }

    for (final c in chapters(poem)) {
      final s = named(c);
      if (s.isEmpty) continue;
      // «ومن سورة … إلى سورة …»: from the first up to the last, excluded.
      final range = c.replaceAll(RegExp('[ً-ْٰ]'), '').contains('إلى');
      if (range && s.length >= 2 && surah >= s.first && surah < s.last) {
        return c;
      }
      if (!range && s.contains(surah)) return c;
    }
    return null;
  }
}
