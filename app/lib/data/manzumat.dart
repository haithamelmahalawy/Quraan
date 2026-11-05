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
    final poem =
        _yaqubShatibiyya(reading) != null ||
            (_idghamDhal(reading, hafs) ||
                    reading.rule == 'hamza_zaida' ||
                    // «ٱلصَّٰبِـِٔينَ» with Nafi'; his bab of «مُسۡتَهۡزُونَ» has
                    // its verse in the Durrah.
                    reading.rule == 'hamza_hadhf' &&
                        RegExp('صب[يو]ن').hasMatch(_letters(reading.text))) &&
                qiraaOf(reading.riwayaId).id == 'abu_jafar'
        ? Poem.shatibiyya
        : Poem.of(reading.riwayaId);
    var chapter =
        _usulChapter(poem, reading, hafs) ??
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
    final ruleVerses = _ruleVerses(poem, reading, hafs);
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
    // «سراط» with the sin is told in its verse alone, wherever it comes.
    final sirat = _sirat(poem, v);
    if (sirat.isNotEmpty) return sirat.contains(n);
    if (_nansaha(poem, v)) return n == 475;
    if (_innaQuwwa(poem, v)) return n == 70;
    if (_abuJafarYahsab(poem, v)) return n == 83;
    final yaghfir = _yaghfirYuadhib(poem, v);
    if (yaghfir.isNotEmpty) return yaghfir.contains(n);
    final bazziTa = _bazziTa(poem, v);
    if (bazziTa.isNotEmpty) return bazziTa.contains(n);
    final huwa = _abuJafarHuwa(poem, v);
    if (huwa.isNotEmpty) return huwa.contains(n);
    // «وَالصَّادُ زَاياً اشِمَّهَا لَدَى خَلَفٍ وَاشْمِمْ لِخَلاَّدِ الاَوَّلَا» is
    // Hamzah's ishmam, not evidence of another reader.
    if (poem == Poem.shatibiyya && n == 109) {
      return const {'khalaf_hamzah', 'khallad'}.contains(v.riwayaId);
    }
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
        (_letters(word) == 'انا' ||
            // وَأَنَآ، فَأَنَآ with the same madd.
            v.riwayaId == 'warsh' &&
                const {'وانا', 'فانا'}.contains(_letters(word))) &&
        (d.contains('مد') || RegExp('إثبات.*ألف.*أنا').hasMatch(d));
  }

  /// Warsh's two faces of أَرَءَيۡتَ of the question, wherever it comes:
  /// «أَرَيْتَ فِي الاِسْتِفْهَامِ لاَ عَيْنَ رَاجِعٌ».
  bool _araayta(Variant v) =>
      v.riwayaId == 'warsh' &&
      v.description.contains('تسهيل الهمزة الثانية، أو إبدالها ألفًا');

  /// Ibn Dhakwan's imala of «ٱلتَّوۡر۪ىٰةَ», in the farsh of Al 'Imran:
  /// «وَإِضْجَاعُكَ التَّوْرَاةَ مَا رُدَّ حُسْنُهُ».
  bool _ibnDhakwanTawrat(Variant v) =>
      v.riwayaId == 'ibn_dhakwan' &&
      v.isImala &&
      v.text.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '').contains('تور');

  /// Qalun's two faces of it, in the same place: «وَبِالْخُلْفِ بَلَّلَا».
  bool _qalunTawrat(Variant v) => v.riwayaId == 'qalun' && v.fathPreferred;

  /// Ibn 'Amir's «قُتِّلُواْ» with the shadda, in Al 'Imran and al-Hajj:
  /// «بِمَا قُتِلُوا التَّشْدِيدُ لَبَّى وَبَعْدَهُ وَفي الْحَجِّ لِلشَّامِيْ».
  /// And Ibn Kathir's, the last of Al 'Imran: «دَرَاكِ».
  bool _ibnAmirQuttilu(Variant v) =>
      (const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId) ||
          const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
              v.surah == 3 &&
              v.ayah == 195) &&
      v.text.contains('تِّلُو');

  /// Ibn 'Amir's damma for the first of two sakins before a third letter
  /// with damma (وَلَقَدُ ٱسۡتُهۡزِئَ، فَتِيلًا ٱنظُرۡ): «وَضَمُّكَ أُولَى
  /// السَّاكِنَيْنِ» with «وَمَحْظُوراً انْظُرْ مَعْ قَدِ اسْتُهْزِئَ»; for the
  /// tanween, Ibn Dhakwan's kasra, in dispute in «رحمة» and «خبيثة».
  Set<int> _ibnAmirSakinayn(Variant v) {
    final d = v.description;
    if (!d.contains('لالتقاء الساكنين') || !d.contains('بضم')) return {};
    return v.riwayaId == 'ibn_dhakwan' && d.contains('التنوين')
        ? {495, 497, 498}
        : {495, 496};
  }

  /// Ibn 'Amir's farsh whose verse the words of the page do not find: the
  /// verse's word is without the mushaf's prefix, or in another surah.
  Set<int> _ibnAmirFarsh(Variant v) {
    if (!const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId)) return {};
    // «وَسَيُصۡلَوۡنَ» (4:10): «يَصْلَوْنَ ضُمَّ كَمْ صَفَا».
    if (v.text.contains('يُصۡلَوۡنَ')) return {588};
    // «وَأَحَلَّ» (4:24): «وَضَمٌّ وَكَسْرٌ فِي أَحَلَّ صِحَابُهُ».
    if (v.surah == 4 && v.text == 'وَأَحَلَّ') return {597};
    // «هُزُؤًا» everywhere: «وَهُزْؤاً وَكُفْؤاً في السَّوَاكِنِ فُصِّلَا
    // وَضُمَّ لِبَاقِيهِمْ».
    if (v.text.contains('هُزُؤ')) return {460, 461};
    // The ya made sakin that Hafs opens in «وَلِيَ نَعۡجَةٌ»، «مَا كَانَ لِيَ»
    // (twice) and «مَعِيَ» (eight places): «وَلِيْ نَعْجَةٌ مَا كَانَ لِيْ اثْنَيْنِ
    // مَعْ مَعِيْ ثَمَانٍ عُلاً».
    if (v.description.contains('إسكان') &&
        (v.text == 'مَعِى' ||
            v.text == 'لِى' &&
                const {'14:22', '38:69'}.contains('${v.surah}:${v.ayah}') ||
            v.text == 'وَلِى' && v.surah == 38 && v.ayah == 23)) {
      return {417};
    }
    // The nun of «يسٓ» and «نٓ» merged into the waw: «وَيَاسِيْنَ أَظْهِرْ عنْ
    // فَتًى حَقُهُ بَدَا وَنُونَ», Ibn 'Amir not among those who show it.
    if (v.description.startsWith('بإدغام النون من «')) return {281};
    // Ibn Dhakwan's «أَدۡر۪ىٰكَ», imala or fath: «وَبَصْرٍ وَهُمْ أَدْرَى
    // وَبِالْخُلْفِ مُثِّلَا».
    if (v.riwayaId == 'ibn_dhakwan' && v.text.contains('أَدۡر۪')) return {740};
    // Ibn Dhakwan's kasra of «عِيُون، شِيُوخ، جِيُوب», in the farsh of
    // al-Ma'ida: «يَكْسِرَانِ عُيُوناً الْعُيُونِ شُيُوخاً دَانَهُ صُحْبَهٌ مِلَا
    // جُيُوبِ مُنِيرٌ».
    if (v.riwayaId == 'ibn_dhakwan') {
      // «وَنَآءَ» (17:83، 41:51), in the farsh of al-Isra: «نَآى أَخِّرْ مَعاً
      // هَمْزَهُ مَلَا».
      if (v.text.contains('نَآءَ')) return {826};
      final bare = v.text.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '');
      if (bare.contains('جيوب')) return {628, 629};
      if (RegExp('عيون|شيوخ').hasMatch(bare)) return {628};
      // «رَأَى» in the farsh of al-An'am: «وَحَرْفَيْ رَأَى كُلاًّ أَمِلْ مُزْنَ»;
      // with a pronoun in two ways, «وَخُلْفٌ فِيهِماَ مَعَ مُضْمِرٍ»; before a
      // sakin on stopping, «وَقِفْ فِيهِ كَالأُولَى».
      if (v.isImala && RegExp(r'^[وف]?رء?ا(ه|ها|ك)?$').hasMatch(bare)) {
        if (v.stopOnly) return {648, 649};
        return RegExp(r'(ه|ها|ك)$').hasMatch(bare) ? {646, 647} : {646};
      }
    }
    // «مَيۡت» light (بلد ميت، الميت), in the farsh of Al 'Imran: «وَفي بَلَدٍ
    // مَيْتٍ مَعَ المَيْتِ خَفَّفُوا صَفَا نَفَرًا».
    if (RegExp('مَّ?يۡتِ?[ٍَٖ]?\$').hasMatch(v.text) &&
        v.description.contains('بإسكان الياء')) {
      return {550};
    }
    // 40:26 «وَأَن» for «أَوۡ أَن»: «أَوْ أَنْ زِدِ الْهَمْزَ ثُمَّلَا»; «يَظۡهَرَ …
    // ٱلۡفَسَادُ»: «وَاضْمُمْ بِيَظْهَرَ وَاكْسِرَنْ وَرَفْعَ الْفَسَادَ انْصِبْ».
    if (v.surah == 40 && v.ayah == 26) {
      if (v.text == 'وَأَن') return {1010};
      if (v.text.contains('يَظۡهَرَ') || v.text.contains('ٱلۡفَسَادُ')) {
        return {1011};
      }
    }
    // «مِّن رِّجۡزٍ أَلِيمٍ» (34:5، 45:11), in the farsh of Saba': «وَرَفْعُ خَفْضِهِ
    // عَمَّ مِنْ رِجْزٍ أَلِيْمٍ مَعاً وِلَا».
    if ((v.surah == 34 || v.surah == 45) && v.text.contains('أَلِيمٍ')) {
      return {975};
    }
    // 44:47 «فَٱعۡتُلُوهُ»: «وَضَمَّ اعْتِلُوهُ اكْسِرْ غِنىً».
    if (v.surah == 44 && v.text.contains('ٱعۡتُلُوهُ')) return {1030};
    // «نُدۡخِلۡهُ» (4:13-14، 48:17، 64:9، 65:11)، «نُكَفِّرۡ» (64:9)،
    // «نُعَذِّبۡهُ» (48:17): «وَنُدْخِلْهُ نُونٌ مَعْ طَلاَقٍ وَفَوْقُ مَعْ
    // نُكَفِّرْ نُعَذِّبْ مَعْهُ في الْفَتْحِ إِذْ كَلَا».
    if (const {4, 48, 64, 65}.contains(v.surah) &&
        const {'ندخله', 'وندخله', 'نكفر', 'نعذبه'}.contains(_letters(v.text))) {
      return {592};
    }
    // 48:29 Ibn Dhakwan's «شَطَـَٔهُۥ فَأَزَرَهُۥ»: «حَرَّكَ شَطْأَهُ دُعَا مَاجِدٍ
    // وَاقْصُرْ فَآزَرَهُ مُلاَ».
    if (v.surah == 48 &&
        v.ayah == 29 &&
        const {'شطه', 'فازره'}.contains(_letters(v.text))) {
      return {1043};
    }
    // «ذُرِّيَّٰتِهِمۡ» (7:172، 36:41، 52:21): «وَيَقْصُرُ ذُرِّيَّاتِ مَعْ فَتْحِ
    // تَائِهِ وَفِي الطُّورِ فِي الثَّانِي ظَهِيرٌ تَحَمَّلَا وَيَاسِينَ دُمْ غُصْناً
    // وَيُكْسَرُ رَفْعُ أَوَّلِ الطُّورِ لِلْبَصْرِيْ وَبِالْمَدِّ كَمْ حَلَا».
    if (const {7, 36, 52}.contains(v.surah) &&
        RegExp('^ذُرِّيَّ[ٰا]ت').hasMatch(v.text)) {
      return {706, 707};
    }
    // 52:37 Hisham's «ٱلۡمُسَيۡطِرُونَ»: «وَالْمُسَيْـطِرُونَ لِسَانٌ عَابَ
    // بِالْخُلْفِ زُمَّلَا».
    if (v.surah == 52 && v.ayah == 37 && v.text.contains('طِرُونَ')) {
      return {1048};
    }
    // «يُضَعِّفۡهُ» and the like (2:245، 4:40، 11:20، 25:69، 57:11، 64:17):
    // «وَالْعَيْنُ في الْكُلِّ ثُقِّلَا كَماَ دَارَ وَاقْصُرْ».
    if (RegExp('يُضَعَّ|يُضَعِّ').hasMatch(v.text)) return {516, 517};
    // 73:6 «وِطَآءً»، 73:9 «رَبِّ»: «وَوَطْئاً وِطَاءً فَاكْسِرُوهُ كَمَا حَكَوْا
    // وَرَبُّ بِخَفْضِ الرَّفْعِ صُحْبَتُهُ كَلَا».
    if (v.surah == 73 &&
        (v.text.contains('وِطَآء') ||
            v.ayah == 9 && _letters(v.text) == 'رب')) {
      return {1088};
    }
    // 75:20-21 «يُحِبُّونَ … وَيَذَرُونَ»: «يَذَرُونَ مَعْ يُحِبُّونَ حَقٌّ كَفَّ».
    if (v.surah == 75 && const {'يحبون', 'ويذرون'}.contains(_letters(v.text))) {
      return {1092};
    }
    // Hafs's sakt left out: «عِوَجٗا» (18:1) «وَسَكْتَةُ حَفْصٍ … فِي عِوَجاً»;
    // «مَّرۡقَدِنَا» (36:52)، «مَن رَّاقٖ» (75:27)، «بَل رَّانَ» (83:14): «وَفِي نُونِ
    // مَنْ رَاق وَمَرْقَدِناَ وَلاَمِ بَلْ رَانَ وَالْبَاقُونَ لاَ سَكْتَ مُوصَلَا».
    if (v.surah == 18 && v.ayah == 1 && _letters(v.text) == 'عوجا') {
      return {830};
    }
    if (v.surah == 36 && v.ayah == 52 && _letters(v.text) == 'مرقدنا' ||
        v.surah == 75 && v.ayah == 27 && _letters(v.text) == 'منراق' ||
        v.surah == 83 && v.ayah == 14 && _letters(v.text) == 'بلران') {
      return {831};
    }
    // 76:4 Hisham's «سَلَٰسِلًا»: «سَلاَسِلَ نَوِّنْ إِذْ رَوَوَا صَرْفَهُ لَنَا»;
    // 76:16 his stop on «قَوَارِيرَا» with the alef: «وَفِي الثَّانِ نَوِّنْ إِذْ رَوَوْا
    // صَرْفَهُ وَقُلْ يَمُدُّ هِشَامٌ وَاقِفاً مَعْهُمُ وِلَا».
    if (v.surah == 76 && v.ayah == 4 && _letters(v.text) == 'سلاسلا') {
      return {1093};
    }
    if (v.surah == 76 && v.ayah == 16 && _letters(v.text) == 'قواريرا') {
      return {1094, 1095};
    }
    // 77:6 «نُذُرًا»: «وَنُذْرًا صِحَابُهُمْ حَمَوْهُ».
    if (v.surah == 77 && v.ayah == 6 && _letters(v.text) == 'نذرا') {
      return {618};
    }
    // 98:6-7 Ibn Dhakwan's «ٱلۡبَرِيٓـَٔةِ»: «وَحَرْفَيِ الْـبَرِيَّةِ فَاهْمِزْ آهِلاً
    // مُتَأَهِّلَا».
    if (v.surah == 98 && v.text.contains('بَرِي')) return {1116};
    // «مُوصَدَةٌ» (90:20، 104:8) without the hamza: «وَمُؤْصَدَةٌ فَاهْمِزْ مَعاً عَنْ
    // فَتىً حِمىً».
    if ((v.surah == 90 || v.surah == 104) && _letters(v.text) == 'موصدة') {
      return {1114};
    }
    // 58:21 «وَرُسُلِيَ»: «وَفِي رُسُلِي أَصْلٌ كَسَا وَافِيَ الْمُلَا».
    if (v.surah == 58 && _letters(v.text) == 'ورسلي') return {402};
    // 48:10 «فَسَنُؤۡتِيهِ»: «وَفي ياَءِ يُؤْتيِهِ غَدِيرٌ تَسَلْسَلَا».
    if (v.surah == 48 && v.text.contains('سَنُؤ')) return {1041};
    // 46:17 «أَتَعِدَآنِّيٓ», 46:19 «وَلِنُوَفِّيَهُمۡ»: «وَقُلْ عَنْ هِشاَمٍ
    // أَدْغَمُوا تَعِدَانِنِيْ نُوَفيَهُمْ بِالْيَا لَهُ حَقُّ نَهْشَلَا».
    if (v.surah == 46 &&
        (v.text.contains('تَعِدَآنِّي') || v.text.contains('نُوَفِّيَهُم'))) {
      return {1035};
    }
    // 43:38 «جَآءَٰنَا»: «وَحُكْمُ صِحَابٍ قَصْرُ هَمْزَةِ جَاءَنَا».
    if (v.surah == 43 && v.ayah == 38 && v.word == 2 && !v.isImala) {
      return {1024};
    }
    // «يَرۡضَهُ» (39:7), in the chapter of the pronoun ha: «وَإِسْكَانُ يَرْضَهُ
    // يُمْنُهُ لُبْسُ طَيِّبٍ بِخُلْفِهِمَا وَالْقَصْرُ فَاذْكُرْهُ نَوْفَلَا».
    if (v.surah == 39 && v.text.contains('يَرۡضَه')) return {164};
    // «يَٰبُنَيِّ» with kasra (six places), in the farsh of Hud: «وَفَتْحُ يَا
    // بُنَيِّ هُنَا نَصٌّ وَفِي الْكُلِّ عُوِّلَا».
    if (v.text.contains('يَٰبُنَيِّ')) return {757};
    // «أَوۡ ءَابَآؤُنَا» (37:17، 56:48), in the farsh of al-Saffat: «وَسَاكِنٌ
    // مَعاً اَوْ آبَاؤُنَا كَيْفَ بَلَّلَا».
    if (v.text.startsWith('أَوۡ ءَابَآؤُنَا')) return {996};
    // «نَنۡكُسۡهُ» (36:68): «وَنَنْكُسْهُ فَاضْمُمْهُ وَحَرِّكْ لِعَاصِمٍ وَحَمْزَةَ»
    // (the verse is written «وَتَنْكُسْهُ» in the text of the poem).
    if (v.surah == 36 && v.text.contains('نَنۡكُسۡهُ')) return {991};
    // «ضُعۡف» of al-Rum (30:54, three times), in the farsh of al-Anfal:
    // «وَضُعْفاً بِفَتْحِ الضَّمِّ فَاشِيهِ نُفِّلا وِفي الرُّومِ صِفْ عَنْ خُلْفِ فَصْلٍ».
    if (v.surah == 30 && v.text.contains('ضُعۡف')) return {722, 723};
    // «يَٰٓأَبَتَ» wherever it comes, in the farsh of Yusuf: «وَيَا أَبَتِ افْتَحْ
    // حَيْثُ جَا لاِبْنِ عَامِرٍ».
    if (v.text.contains('أَبَتَ')) return {772};
    // «فَزَعِ يَوۡمِئِذٍ» (27:89), in the farsh of Hud: «وَيَوْمَئِذٍ مَعْ سَالَ
    // فَافْتَحْ أَتَى رِضاً وَفِي النَّمْلِ حِصْنٌ قَبْلَهُ النُّونُ ثُمِّلاَ».
    if (v.surah == 27 && v.text.contains('يَوۡمِئِذٍ')) return {761};
    // «قُل رَّبِّ» for Hafs's «قال» (21:4، 21:112): «وَقُلْ قَالَ عَنْ شُهْدٍ
    // وَآخِرُهَا عَلاَ».
    if (v.surah == 21 && v.text.startsWith('قُل ر')) return {887};
    // «وَلُؤۡلُؤٖ» (al-Hajj and Fatir) and «سَوَآءٌ» (22:25): «وَمَعْ فَاطِرِ
    // انْصِبْ لُؤْلُؤاً نَظْمُ أُلْفَةٍ وَرَفْعَ سَوَاءً غَيْرُ حَفْصٍ».
    if (v.text.contains('لُؤۡلُؤٖ') ||
        v.surah == 22 && v.ayah == 25 && v.text.startsWith('سَوَآءٌ')) {
      return {895};
    }
    return _ibnAmirSakinayn(v);
  }

  /// The ishmam of «قِيلَ، غِيضَ، جِيٓءَ» (447) or of «حِيلَ، سِيقَ، سِيٓءَ،
  /// سِيٓـَٔتۡ» (448), both in the farsh of al-Baqara whatever the surah.
  Set<int> _ishmamVerses(Variant v, [String hafs = '']) {
    final word = '$hafs ${v.usulText} ${v.description}'.replaceAll(
      RegExp('[ً-ٰٟۖ-ۭـ]'),
      '',
    );
    return RegExp('حيل|سيق|سي[ءئ]|السين|الحاء').hasMatch(word) ? {448} : {447};
  }

  /// Where the Durrah is silent, Ya'qub reads with his base, Abu Amr, as the
  /// Shatibiyya states it: 28:32 «وَصُحْبَةٌ كَهْفُ ضَمِّ الرَّهْبِ وَاسْكِنْهُ
  /// ذُبَّلَا» (the others, Abu Amr among them, open both).
  /// 33:10، 66، 67 «...وَهْوَ فِي الْوَقْفِ فِي حُلَا» (the Durrah's «وَالظُّنُونَ
  /// قِفْ مَعَ اخْتَيْهِ مَدًّا فُقْ» is Khalaf's).
  static const _yaqubInShatibiyya = {
    '28:32:13': {947},
    '33:10:15': {969},
    '33:66:10': {969},
    '33:67:7': {969},
  };

  Set<int>? _yaqubShatibiyya(Variant v) =>
      const {'ruways', 'rawh'}.contains(v.riwayaId)
      ? _yaqubInShatibiyya['${v.surah}:${v.ayah}:${v.word}']
      : null;

  /// «سراط، الصراط» with the sin (written صِۜ), wherever it comes: Qunbul's
  /// «وَعَنْدَ سِرَاطٍ وَالسِّرَاطَ لِ قُنْبُلَا» in the Shatibiyya, Ruways's
  /// «وَالصِرَاطَ فَأَسْجِلَا وَبِالسِّيْنِ طِبْ» in the Durrah.
  Set<int> _sirat(Poem poem, Variant v) {
    if (v.isUsul || !v.text.replaceAll(RegExp('[ً-ٰ]'), '').contains('صۜرط')) {
      return {};
    }
    if (poem == Poem.shatibiyya && v.riwayaId == 'qunbul') return {108};
    if (poem == Poem.durrah && v.riwayaId == 'ruways') return {10, 11};
    return {};
  }

  /// Abu Ja'far drops the hamza of «مستهزءون» and its bab: «وَيَحْذِفُ
  /// مُسْتَهْزُونَ وَالْبَابَ مَعْ تَطَوْا يَطَوْا مُتَّكًا خَاطِيْنَ مُتَّكِئِي أُولا
  /// كَمُسْتَهْزِئِيْ مُنْشُونَ خُلْفٌ بَدَا».
  Set<int> _abuJafarHamzaBab(Poem poem, Variant v) {
    if (poem != Poem.durrah ||
        qiraaOf(v.riwayaId).id != 'abu_jafar' ||
        v.kind != VariantKind.hamza ||
        !v.description.contains('حذف الهمزة')) {
      return {};
    }
    final read = _letters(v.text);
    if (RegExp('تهزين|منشو').hasMatch(read)) return {32, 33};
    return RegExp('تهزو|طفوا|واطوا|تطو|متك|يتكو|خاطي|خطين|خاطو|مالو|نبو')
            .hasMatch(read)
        ? {32}
        : {};
  }

  /// The dhal of «أَخَذتُّمۡ / ٱتَّخَذتُّمُ» merged into the ta, for all who merge
  /// it: «فَازَ اتَخَذْتُمْ أَخَذْتُمْ وَفِي الإِفْرَادِ عاشَرَ دَغْفَلَا»; Abu
  /// Ja'far with Nafi', the Durrah silent. Rawh has the Durrah's «أَخَذْتُ طُلُ».
  /// Its own text or, written by another row (Warsh's naql: قُلَ اَتَّخَذتُّمْ),
  /// [hafs]'s word.
  static bool _idghamDhal(Variant v, [String hafs = '']) =>
      v.rule == 'idgham_saghir' &&
      v.description.contains('الذال في التاء') &&
      RegExp('خَذۡ?ت').hasMatch('${v.text} $hafs') &&
      !const {'ruways', 'rawh'}.contains(v.riwayaId);

  /// Nafi''s hamza of «ٱلنَّبِيٓءُ» and its bab: «وَجَمْعاً وَفَرْداً فِي النَّبِيءِ
  /// وَفي النُّبُوءَةِ الْهَمْزَ كُلٌّ غَيْرَ نَافِعٍ ابْدَلاَ»; without it in
  /// «ٱلصَّٰبِـِٔينَ»: «وَفي الصَّابِئِينَ الْهَمْزُ وَالصَّابِئُونَ خُذْ», and Abu
  /// Ja'far with him.
  ///
  /// «هُزُؤًا، كُفُؤًا» with the hamza and the damma: «وَهُزْؤاً وَكُفْؤاً في
  /// السَّوَاكِنِ فُصِّلَا وَضُمَّ لِبَاقِيهِمْ ... وَحَفْصٌ وَاقِفاً ثُمَّ مُوصِلَا».
  Set<int> _nafiHamza(Poem poem, Variant v) => poem != Poem.shatibiyya
      ? {}
      : v.rule == 'hamza_zaida' && RegExp('^(هُزُؤ|كُفُؤ)').hasMatch(v.text)
      ? {460, 461}
      : v.rule == 'hamza_zaida'
      ? {458}
      : v.rule == 'hamza_hadhf'
      ? {460}
      : {};

  /// Abu Ja'far's ha of «هُوَ، هِيَ» made sakin after waw, fa and lam, and after
  /// «ثُمَّ، يُمِلَّ»: «هُوْ وَهِيْ يُمِلَّ هْوَ ثُمَّ هْوَ اسْكِنًا أُدْ», not the stop
  /// of «مَعْ هُوْ وَهِيْ».
  Set<int> _abuJafarHuwa(Poem poem, Variant v) {
    if (poem != Poem.durrah ||
        qiraaOf(v.riwayaId).id != 'abu_jafar' ||
        !v.description.contains('إسكان الهاء')) {
      return {};
    }
    final words = [
      for (final w in v.text.trim().split(RegExp(r'\s+'))) _letters(w),
    ];
    final huwa = RegExp(r'^[وفل]?ه[وي]$');
    final ok = words.length == 1
        ? huwa.hasMatch(words.single)
        : words.length == 2 &&
              (huwa.hasMatch(words.first) ||
                  const {'ثم', 'يمل'}.contains(words.first) &&
                      huwa.hasMatch(words.last));
    return ok ? {64} : {};
  }

  /// Ibn Kathir's «نَنسَـٔۡهَا» (البقرة ١٠٦): «وَنَنْسَخْ بِهِ ضَمٌّ وَكَسْرٌ كَفَى
  /// وَنُنْسِهَا مِثْلُهُ مِنْ غَيْرِ هَمْزٍ ذَكَتْ إِلَى».
  bool _nansaha(Poem poem, Variant v) =>
      poem == Poem.shatibiyya &&
      const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
      v.surah == 2 &&
      v.ayah == 106 &&
      v.word == 5;

  /// «فَيَغۡفِرُ … وَيُعَذِّبُ» (البقرة ٢٨٤): Abu Ja'far's raf', «يَغْفِرْ يُعَذِّبْ
  /// حَمَى الْعُلَا بِرَفْعٍ»; Qalun's idgham of the ba, «وَفِي
  /// الْبَقَرَهْ فَقُلْ يُعَذِّبْ دَنَا بِالْخُلْفِ».
  Set<int> _yaghfirYuadhib(Poem poem, Variant v) {
    if (v.surah != 2 || v.ayah != 284) return const {};
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        (v.word == 17 || v.word == 20)) {
      return {84, 85};
    }
    if (poem == Poem.shatibiyya && v.riwayaId == 'qalun' && v.word == 20) {
      return {285};
    }
    return const {};
  }

  /// Abu Ja'far's «يَحۡسَبُ» with the fatha, as Hafs, against Qalun's kasra:
  /// «وَمَيْسَرَةِ افْتَحَاً كَيَحْسَبُ أُدْ».
  bool _abuJafarYahsab(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      RegExp('^[وفأ]?[يت]حسب(?!ن)')
          .hasMatch(v.text.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), ''));

  /// Al-Bazzi's ta shaddaed in wasl, each in the verse that names it, from
  /// «وَفي الْوَصْلِ لِلْبَزِّيِّ شَدِّدْ تَيَمَّمُوا» on.
  Set<int> _bazziTa(Poem poem, Variant v) {
    if (poem != Poem.shatibiyya ||
        v.riwayaId != 'bazzi' ||
        v.rule != 'bazzi_ta') {
      return const {};
    }
    return switch ('${v.surah}:${v.ayah}') {
      '2:267' || '4:97' => {526},
      // With the head of the rule: «وَفي الْوَصْلِ لِلْبَزِّيِّ شَدِّدْ».
      '3:103' || '6:153' => {526, 527},
      '5:2' || '7:117' || '20:69' || '26:45' => {528},
      '26:221' || '26:222' || '97:4' || '37:25' || '92:14' || '24:15' => {529},
      '11:105' || '11:3' || '11:57' || '24:54' || '60:9' => {530},
      '8:20' => {530, 531},
      '8:46' || '33:33' || '33:52' => {531},
      '9:52' => {532},
      '67:8' || '68:38' || '80:10' => {533},
      '49:11' || '49:12' || '49:13' => {534},
      // «وَكُنْتُمْ تَمَنَّوْنَ الَّذِي مَعْ تَفَكَّهُونَ عَنْهُ عَلَى وَجْهَيْنِ».
      '3:143' || '56:65' => {526, 535},
      _ => const {},
    };
  }

  /// Abu Ja'far's and Yaqub's «إِنَّ ٱلۡقُوَّةَ لِلَّهِ» and «وَإِنَّ ٱللَّهَ»
  /// (البقرة ١٦٥): «وَأَنَّ اكْسِرْ مَعًا حَائِزَ الْعُلَا».
  bool _innaQuwwa(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      v.surah == 2 &&
      v.ayah == 165 &&
      (v.word == 23 || v.word == 27);

  /// Abu Ja'far's eased hamza of «إِسۡرَٰٓءِيلَ», its second, in the single
  /// hamza: «أَرَيْتَ وَإِسْرَائِيْلَ كَائِنْ وَمَدَّ أُدْ».
  Set<int> _abuJafarIsrail(Poem poem, Variant v) =>
      poem == Poem.durrah &&
          qiraaOf(v.riwayaId).id == 'abu_jafar' &&
          v.kind == VariantKind.hamza &&
          // And his «هَٰٓأَنتُمۡ»: «وَمَدَّ أُدْ مَعَ اللاَّءِ هَا أَنْتُمْ».
          (v.text.contains('سۡرَٰٓءِ') || v.rule == 'ha_antum')
      ? {34}
      : {};

  /// Abu Ja'far's «يَضُرُّكُمۡ» (آل عمران ١٢٠), read as Hafs, against Nafi's and
  /// Ibn Kathir's: «وَاقْرَأْ يَضُرُّكُمُ أَلَا». Its row tells its silah alone.
  bool _abuJafarYadurrukum(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.surah == 3 &&
      v.ayah == 120 &&
      v.word == 13;

  /// His «يَحۡزُنكَ» wherever it comes, «يُحۡزِنُهُمُ» of الأنبياء the one with the
  /// damma: «وَيَحْزُنُ فَافْتَحْ ضُمَّ كُلًّا سِوَى الَّذِي لَدَى الْأَنْبِيَا». Not
  /// «يَحۡزَنُونَ», another verb.
  bool _abuJafarYahzun(Poem poem, Variant v, String hafs) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      RegExp('ي[ً-ْۡ]*ح[ً-ْۡ]*ز[ُِ]ن').hasMatch('$hafs ${v.text}');

  /// His «وَكَآئِن» with the hamza eased: «أَرَيْتَ وَإِسْرَائِيْلَ كَائِنْ».
  bool _abuJafarKaayin(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.text.contains('۬') &&
      RegExp('^[وف]?كا?[ئي]ن').hasMatch(_letters(v.text));

  Set<int> _ruleVerses(Poem poem, Variant v, [String hafs = '']) {
    final yaqub = _yaqubShatibiyya(v);
    if (yaqub != null) return yaqub;
    final sirat = _sirat(poem, v);
    if (sirat.isNotEmpty) return sirat;
    final hamzaBab = _abuJafarHamzaBab(poem, v);
    if (hamzaBab.isNotEmpty) return hamzaBab;
    // Ibn Kathir's «ءَا۬ن» (٧٣): «وَفِي آلِ عِمْرَانٍ عَنِ ابْنِ كَثِيرِهِمْ يُشَفَّعُ
    // أَنْ يُؤْتَى».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        v.rule == 'ha_antum' &&
        v.surah == 3 &&
        v.ayah == 73) {
      return {188};
    }
    if (_abuJafarYadurrukum(poem, v)) return {88};
    if (_abuJafarKaayin(poem, v)) return {34};
    if (_abuJafarYahzun(poem, v, hafs)) return {91};
    // «قَٰتَلَ» (آل عمران ١٤٦), for all who read it either way: «وَقَاتَلَ بَعْدَهُ
    // يُمَدُّ وَفَتْحُ الضَّمِّ وَالْكَسْرِ ذُو وِلَا».
    if (poem == Poem.shatibiyya &&
        v.surah == 3 &&
        v.ayah == 146 &&
        v.word == 3) {
      return {571};
    }
    final israil = _abuJafarIsrail(poem, v);
    if (israil.isNotEmpty) return israil;
    if (_nansaha(poem, v)) return {475};
    if (_innaQuwwa(poem, v)) return {70};
    if (_abuJafarYahsab(poem, v)) return {83};
    final yaghfir = _yaghfirYuadhib(poem, v);
    if (yaghfir.isNotEmpty) return yaghfir;
    final bazziTa = _bazziTa(poem, v);
    if (bazziTa.isNotEmpty) return bazziTa;
    final huwa = _abuJafarHuwa(poem, v);
    if (huwa.isNotEmpty) return huwa;
    // Ibn Wardan's naql of «ٱلۡـَٰٔنَ», and of Yunus's «ءَآلۡـَٰٔنَ»: «وَلاَ
    // نَقْلَ إِلاَّ الآنَ مَعْ يُوْنُسٍ بَدَا».
    if (poem == Poem.durrah &&
        v.riwayaId == 'ibn_wardan' &&
        const {'naql', 'hamza_wasl'}.contains(v.rule) &&
        RegExp(r'^مل$|لا?ن$').hasMatch(_letters(v.text))) {
      return {36};
    }
    if (poem == Poem.shatibiyya && _idghamDhal(v, hafs)) return {283};
    final nafi = _nafiHamza(poem, v);
    if (nafi.isNotEmpty) return nafi;
    // Al-Bazzi's «فَلِمَهۡ» and the four with it: «وَفِيمَهْ وَمِمَّهْ قِفْ وَعَمَّهْ
    // لِمَهْ بِمَهْ بِخُلْفٍ عَنِ الْبَزِّيِّ».
    if (poem == Poem.shatibiyya &&
        v.riwayaId == 'bazzi' &&
        v.rule == 'ha_sakt') {
      return {386};
    }
    final d = v.shownDescription;
    if (poem == Poem.shatibiyya && _anaWasl(v)) return {521};
    if (poem == Poem.shatibiyya && _araayta(v)) return {638};
    if (poem == Poem.durrah) {
      // Abu Ja'far's sakt on each letter that opens a sura: «حُرُوفَ
      // التَّهَجِّي افْصِلْ بِسَكْتٍ كَحَا أَلِفْ».
      if (v.rule == 'fawatih') return {62};
      // His ikhfa of the nun before kha and ghayn: «وَبِخَا وَغَيْنِ الاِخْفَا
      // سِوَى يُنْغِضْ يَكُنْ مُنْخَنِقْ أَلَا».
      if (v.rule == 'ikhfa') return {42};
      // 14:2 Ruways's «ٱللَّهُ» when starting: «وَطِبْ رَفْعَ أَللهِ ابْتِدَاءً».
      if (v.riwayaId == 'ruways' && v.surah == 14 && v.ayah == 2) {
        if (v.word == 0) return {138};
      }
      // 28:82 Ya'qub stops on the kaf of وَيۡكَأَنَّ as Abu Amr:
      // «...مَعْ وَيْكَأَنَّهْ وَيْكَأَنَّ كَذَا تَلَا».
      if (const {'ruways', 'rawh'}.contains(v.riwayaId) &&
          v.rule == 'rasm_stop' &&
          v.surah == 28 &&
          v.ayah == 82) {
        return {51};
      }
      // 28:34 «وَيُصَدِّقْ فِه»: the book's entry begins two words before.
      if (const {'ruways', 'rawh'}.contains(v.riwayaId) &&
          v.surah == 28 &&
          v.ayah == 34 &&
          v.word == 9) {
        return {176};
      }
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
          // ذِكْرًا وسِتْرًا وبابه: «وَتَفْخِيمُهُ ذِكْرًا وَسِتْرًا وَبَابَهُ».
          return v.description.contains('تفخيم') ? {346} : {343, 344};
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
    // «وَقِيلَ وَغِيضَ ثُمَّ جِيءَ يُشِمُّهَا ... لَدَى كَسْرِهَا ضَمًّا رِجَالٌ لِتَكْمُلَا».
    // «وَحِيلَ بِإِشْمَامٍ وَسِيقَ كَمَا رَسَا وَسِيءَ وَسِيئَتْ كَانَ رَاوِيهِ أَنْبَلَا».
    if (v.rule == 'ishmam') return _ishmamVerses(v, hafs);
    // Hisham's hamza with damma after one with fatha: «وَمَدُّكَ قَبْلَ الضَّمِّ
    // لَبَّى حَبِيبُهُ بِخُلْفهِمَا ... وَفي آلِ عِمْرَانَ رَووْا لِهِشَامِهِمْ كَحَفْصٍ».
    if (v.riwayaId == 'hisham' &&
        v.rule == 'tasheel_word' &&
        RegExp('^[ءأ]َ[ءؤ]ُ').hasMatch(v.usulText)) {
      return {200, 201};
    }
    // With kasra: «وَمَدُّكَ قَبْلَ الْفَتْحِ وَالْكَسْرِ حُجَّةٌ بِهَا لُذْ وَقَبْلَ
    // الْكَسْرِ خُلْفٌ لَهُ», but «وَفي سَبْعَةٍ لاَ خُلْفَ عَنْهُ».
    if (v.riwayaId == 'hisham' &&
        v.rule == 'tasheel_word' &&
        RegExp('^[ءأ]َ[ءئإ]ِ').hasMatch(v.usulText)) {
      // The seven: مريم، حرفا الأعراف، الشعراء، حرفا الصافات، فصلت.
      const seven = {
        '19:66',
        '7:81',
        '7:113',
        '26:41',
        '37:52',
        '37:86',
        '41:9',
      };
      return v.usulWays.length > 1 && !v.description.contains('تسهيل') ||
              !seven.contains('${v.surah}:${v.ayah}') &&
                  !v.description.contains('تسهيل')
          ? {196}
          : {196, 197, 198};
    }
    // Hisham stops on the last hamza as Hamza does: «وَمِثْلُهُ يَقُولُ هِشَامٌ
    // مَا تَطَرَّفَ مُسْهِلَا», with the ways of the chapter.
    if (v.rule == 'hisham_waqf') return {236, 237, 239, 242, 250, 252};
    // «وَجَاءَ ابْنُ ذَكْوَانٍ وَفِي شَاءَ مَيَّلَا»; and «زاد», «فَزَادَهُمُ
    // الأُولَى وَفِي الْغَيْرِ خُلْفُهُ».
    // Any word of the reading (وَلَقَدۡ جَآءَكُم), without its marks:
    // skeleton() drops the alef and the hamza.
    if (v.riwayaId == 'ibn_dhakwan' && v.isImala) {
      final words = hafs.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '').split(' ');
      if (words.any(RegExp('^[وفل]?[شج][اآ]ء').hasMatch)) return {319};
      if (words.any(RegExp('^[وف]?ز[اآ]د').hasMatch)) return {319, 320};
      // «حِمَارِكَ وَالمِحْرَابِ إِكْرَاهِهِنَّ وَالْحِمَارِ وَفي الإِكْرَامِ عِمْرَانَ
      // مُثِّلَا، وَكُلٌّ بِخُلْفٍ لاِبْنِ ذَكْوَانَ غَيْرَ مَا يُجَرُّ مِنَ الْمِحْرَابِ».
      if (words.any(RegExp('حمار|محراب|إكراه|إكرام|عمر[اٰ]?ن').hasMatch)) {
        return {332, 333};
      }
    }
    if (poem == Poem.shatibiyya && (_ibnDhakwanTawrat(v) || _qalunTawrat(v))) {
      return {546};
    }
    if (poem == Poem.shatibiyya && _ibnAmirQuttilu(v)) {
      // The last of Al 'Imran (3:195): «وَالآخِرُ كَمَّلَا دَرَاكِ».
      return v.surah == 3 && v.ayah == 195 ? {576, 577} : {576};
    }
    if (poem == Poem.shatibiyya) {
      final farsh = _ibnAmirFarsh(v);
      if (farsh.isNotEmpty) return farsh;
    }
    if (d.contains('ميم الجمع')) return {111, 112};
    return {};
  }

  /// The chapter of the usul a reading belongs to, by its rule or by the
  /// words of its description.
  String? _usulChapter(Poem poem, Variant v, [String hafs = '']) {
    for (final own in [
      _sirat(poem, v),
      _abuJafarHamzaBab(poem, v),
      _abuJafarIsrail(poem, v),
      _abuJafarHuwa(poem, v),
      if (poem == Poem.shatibiyya &&
          v.riwayaId == 'bazzi' &&
          v.rule == 'ha_sakt')
        {386},
      if (poem == Poem.durrah &&
          v.riwayaId == 'ibn_wardan' &&
          const {'naql', 'hamza_wasl'}.contains(v.rule) &&
          RegExp(r'^مل$|لا?ن$').hasMatch(_letters(v.text)))
        {36},
      if (poem == Poem.shatibiyya && _idghamDhal(v, hafs)) {283},
      _nafiHamza(poem, v),
    ]) {
      if (own.isNotEmpty) {
        return verses(poem).firstWhere((b) => b.n == own.first).chapter;
      }
    }
    if (_abuJafarYadurrukum(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 88).chapter;
    }
    if (_abuJafarKaayin(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 34).chapter;
    }
    if (_abuJafarYahzun(poem, v, hafs)) {
      return verses(poem).firstWhere((b) => b.n == 91).chapter;
    }
    // Told in the farsh of al-Baqara, not under «السكت».
    if (poem == Poem.durrah && v.rule == 'fawatih') {
      return verses(poem).firstWhere((b) => b.n == 62).chapter;
    }
    if (poem == Poem.durrah && v.rule == 'ikhfa') {
      return verses(poem).firstWhere((b) => b.n == 42).chapter;
    }
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
    if (poem == Poem.shatibiyya && _araayta(v)) {
      return verses(poem).firstWhere((b) => b.n == 638).chapter;
    }
    if (poem == Poem.shatibiyya && v.rule == 'ishmam') {
      final ishmam = _ishmamVerses(v);
      return verses(poem).firstWhere((b) => ishmam.contains(b.n)).chapter;
    }
    if (poem == Poem.shatibiyya && (_ibnDhakwanTawrat(v) || _qalunTawrat(v))) {
      return verses(poem).firstWhere((b) => b.n == 546).chapter;
    }
    if (poem == Poem.shatibiyya && _ibnAmirQuttilu(v)) {
      return verses(poem).firstWhere((b) => b.n == 576).chapter;
    }
    // Al-Bazzi's ta's, told together in the farsh of al-Baqara, and Ibn Kathir's
    // «ءَا۬ن», told in its chapter: not in the sura of the word.
    final bazziTa = _bazziTa(poem, v);
    if (bazziTa.isNotEmpty) {
      return verses(poem).firstWhere((b) => bazziTa.contains(b.n)).chapter;
    }
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        v.rule == 'ha_antum' &&
        v.surah == 3 &&
        v.ayah == 73) {
      return verses(poem).firstWhere((b) => b.n == 188).chapter;
    }
    if (poem == Poem.shatibiyya) {
      final farsh = _ibnAmirFarsh(v);
      if (farsh.isNotEmpty) {
        return verses(poem).firstWhere((b) => farsh.contains(b.n)).chapter;
      }
    }
    final d = v.shownDescription;
    final topics = <String>[
      // Before the hamza topics its ways name (تسهيلها، إبدالها).
      if (v.rule == 'hisham_waqf') 'وقف حمزة وهشام',
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
    // Surah numbers named in a chapter title, in order: as whole words with
    // their alefs («الحج» is not «الحجر», «الناس» not «النساء»), by the
    // poem's own names (المؤمن، الشريعة، ن), or else anywhere in the title.
    String words(String s) => s
        .replaceAll(RegExp('[()]'), ' ')
        .split(RegExp(r'\s+'))
        .map(_letters)
        .join(' ');
    const poemNames = {
      38: 'ص',
      40: 'المؤمن',
      45: 'الشريعة',
      60: 'الامتحان',
      68: 'ن',
    };
    List<int> named(String title, {required bool whole}) {
      final t = skeleton(title);
      final spaced = ' ${words(title)} ';
      final found = <(int, int)>[];
      for (var s = 1; s <= surahNames.length; s++) {
        final k = skeleton(surahNames[s - 1]);
        var at = -1;
        if (whole) {
          for (final name in [surahNames[s - 1], ?poemNames[s]]) {
            final w = words(name);
            at = spaced.contains(' $w ')
                ? spaced.indexOf(' $w ')
                : spaced.indexOf(' و$w ');
            if (at >= 0) break;
          }
        } else if (k.length >= 2) {
          at = t.indexOf(k);
        }
        if (at >= 0) found.add((at, s));
      }
      if (t.contains('ملقرن')) found.add((0, 1)); // أم القرآن
      if (t.contains('خرلقرن')) found.add((t.length, 115)); // آخر القرآن
      found.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final f in found) f.$2];
    }

    for (final whole in const [true, false]) {
      for (final c in chapters(poem)) {
        // A chapter of the usul («باب الفتح والإمالة»، «الفتح والإمالة»)
        // names no surah.
        if (!skeleton(c).contains('سوره') && !skeleton(c).contains('ملقرن')) {
          continue;
        }
        final s = named(c, whole: whole);
        if (s.isEmpty) continue;
        // «ومن سورة … إلى سورة …»: from the first up to the last, excluded.
        final range = c.replaceAll(RegExp('[ً-ْٰ]'), '').contains('إلى');
        if (range && s.length >= 2 && surah >= s.first && surah < s.last) {
          return c;
        }
        if (!range && s.contains(surah)) return c;
      }
    }
    return null;
  }
}
