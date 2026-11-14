import 'package:flutter/services.dart';

import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'arabic.dart';
import 'background_json.dart';
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

  /// Abu Ja'far where the Durrah is silent, his reading his asl's, Nafi''s:
  /// the Durrah's «لِثَانٍ أَبُو عَمْرٍو وَالاَوَّلِ نَافِعٌ» and «فَإِنْ خَالَفُوا
  /// أَذْكُرْ وَإِلاَّ فَأُهْمِلَا» (7، 8), told before the Shatibiyya's bayt.
  List<Bayt> asl,
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
  Manzumat._(this._verses, this._explanations, this._durrahExplanations);

  final Map<Poem, List<Bayt>> _verses;
  final Map<int, BaytExplanation> _explanations;
  final Map<Poem, Map<String, Set<int>>> _quotationCache = {};

  static const source = 'الموسوعة القرآنية quranpedia.net';

  static Future<Manzumat>? _loading;

  static Future<Manzumat> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<Manzumat> _load(AssetBundle bundle) async {
    // Off the thread that draws the pages.
    final json = await decodeJsonApart(
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
    final explanations = await decodeJsonApart(
      await bundle.loadString('assets/data/poem_explanations.json'),
    ) as Map<String, dynamic>;
    Map<int, BaytExplanation> explained(String poem, Object? source) => {
      for (final e in explanations[poem] as List? ?? const [])
        // Told once, under each bayt of the group it explains.
        for (final n in (e[4] as List).cast<int>())
          n: BaytExplanation(
            e[1] as String,
            (e.length > 5 ? e[5] : source) as String,
            e[2] as String,
            e[3] as String,
            (e[4] as List).cast<int>(),
          ),
    };
    final shatibiyya = {
      for (final e in explanations['shatibiyya'] as List)
        e[0] as int: BaytExplanation(
          e[1] as String,
          (e.length > 5 ? e[5] : explanations['source']) as String,
          e[2] as String,
          e[3] as String,
          (e[4] as List).cast<int>(),
        ),
    };
    return Manzumat._(
      {Poem.shatibiyya: verses('shatibiyya'), Poem.durrah: verses('durrah')},
      shatibiyya,
      explained('durrah', explanations['durrahSource']),
    );
  }

  /// The Durrah's sharh: al-Zubaydi's, under each bayt it explains.
  final Map<int, BaytExplanation> _durrahExplanations;

  BaytExplanation? explanation(Poem poem, int n) =>
      poem == Poem.shatibiyya ? _explanations[n] : _durrahExplanations[n];

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
    // Each word's witnesses found once: a word opened again shows at once.
    final key = [
      identityHashCode(reading),
      reading.riwayaId,
      reading.surah,
      reading.ayah,
      reading.word,
      reading.count,
      reading.kind.name,
      reading.rule,
      reading.text,
      reading.description,
      hafs,
      surah,
      for (final e in entries) identityHashCode(e),
    ].join('|');
    final kept = _references.remove(key);
    if (kept != null) return _references[key] = kept;
    final found = _referenceOf(
      reading,
      hafs,
      surah,
      surahNames,
      entries: entries,
    );
    _references[key] = found;
    if (_references.length > referencesKept) {
      _references.remove(_references.keys.first);
    }
    return found;
  }

  /// The words whose witnesses are kept, the last opened.
  static const referencesKept = 500;
  final _references = <String, Reference>{};

  Reference _referenceOf(
    Variant reading,
    String hafs,
    int surah,
    List<String> surahNames, {
    Iterable<KharoufEntry> entries = const [],
  }) {
    final poem =
        _istuhiqqa(reading) ||
            _kharraqu(reading) ||
            _sihr(reading) ||
            _nunajji(reading) ||
            _tadhakkarun(reading) ||
            _hisad(reading) ||
            _aamantum(reading) ||
            _abuJafarBiis(reading) ||
            _durrahBesideShatibiyya.containsKey(_at(reading)) &&
                qiraaOf(reading.riwayaId).id == 'abu_jafar' ||
            _yaqubShatibiyya(reading) != null ||
            _khalafFatathabbatu(reading) ||
            (_idghamDhal(reading, hafs) ||
                    // Not «كُفُؤًا» (الإخلاص ٤), told in the Durrah:
                    // «وَكُفْؤًا سُكُونُ الْفَاءِ حِصْنٌ».
                    reading.rule == 'hamza_zaida' &&
                        _at(reading) != '112:4:3' ||
                    reading.rule == 'ana_madd' ||
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
            _citationFits(poem, reading, b.n, hafs),
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
    // The verses reviewed for the word stand whole, though the book quotes one.
    final reviewed = _reviewedVerses(poem, reading, hafs);
    // A reviewed bayt in another chapter than the book's quote (the sin of
    // «يَحۡسَبَنَّ» in al-Baqara beside its ya in Al 'Imran): its chapter too.
    final told = {for (final b in inChapter) b.chapter};
    final more = {
      for (final b in verses(poem))
        if (reviewed.contains(b.n) && !told.contains(b.chapter)) b.chapter,
    };
    if (more.isNotEmpty) {
      inChapter = [
        for (final b in verses(poem))
          if (told.contains(b.chapter) || more.contains(b.chapter)) b,
      ];
      chapter = [
        for (final c in chapters(poem))
          if (told.contains(c) || more.contains(c)) c,
      ].join(' • ');
    }
    final selected = reviewed.isNotEmpty
        ? reviewed
        : quoted.isNotEmpty
        ? quoted
        : ruleVerses.isNotEmpty
        ? ruleVerses
        : {
            for (final v in inChapter)
              if (names(v)) v.n,
          };
    // The Durrah's «وَالاذْنُ وَسُحْقًا الاُكْلُ ...» (75) names the words that
    // the bayt before it rules «أُثْقِلَا»: cited with it.
    final cited = poem == Poem.durrah && selected.contains(75)
        ? {...selected, 74}
        : selected;
    final mention = {
      for (final b in inChapter)
        if (cited.contains(b.n)) b.n,
    };
    final abuJafar = qiraaOf(reading.riwayaId).id == 'abu_jafar';
    // Khalaf al-'Ashir's as Abu Ja'far's: the Durrah silent, his asl's bayt in
    // the Shatibiyya, Hamza's, with the Durrah's two (the user, 2026-11-14).
    final khalaf = qiraaOf(reading.riwayaId).id == 'khalaf';
    final beside = _durrahBesideShatibiyya[_at(reading)];
    final asl = !abuJafar && !khalaf
        ? const <Bayt>[]
        : khalaf
        ? durrahAsl
        : beside != null
        ? [
            for (final b in verses(Poem.durrah))
              if (beside.contains(b.n)) b,
          ]
        : durrahAsl;
    // Abu Ja'far's, the Durrah silent: Nafi''s bayt in the Shatibiyya, as
    // Qalun's reading of it, after the Durrah's two.
    final silent =
        mention.isEmpty ||
        abuJafar &&
            _durrahSilentOnAbuJafar.contains(
              '${reading.surah}:${reading.ayah}:${reading.word}',
            ) ||
        khalaf &&
            _durrahSilentOnKhalaf.contains(
              '${reading.surah}:${reading.ayah}:${reading.word}',
            );
    if ((abuJafar || khalaf) &&
        poem == Poem.durrah &&
        silent &&
        asl.isNotEmpty) {
      final nafi = _referenceOf(
        khalaf ? _as(reading, 'khalaf_hamzah') : _asQalun(reading),
        hafs,
        surah,
        surahNames,
        entries: entries,
      );
      if (nafi.poem == Poem.shatibiyya && nafi.mention.isNotEmpty) {
        return (
          poem: nafi.poem,
          chapter: nafi.chapter,
          verses: nafi.verses,
          mention: nafi.mention,
          fromBook: nafi.fromBook,
          bookExplanation: nafi.bookExplanation,
          asl: asl,
        );
      }
    }
    // Abu Ja'far's, no bayt of the Durrah nor of the Shatibiyya found for it:
    // the Durrah's two alone.
    if ((abuJafar || khalaf) && mention.isEmpty && asl.isNotEmpty) {
      return (
        poem: Poem.durrah,
        chapter: asl.first.chapter,
        verses: asl,
        mention: {for (final b in asl) b.n},
        fromBook: false,
        bookExplanation: const {},
        asl: const [],
      );
    }
    return (
      poem: poem,
      chapter: chapter,
      verses: inChapter,
      mention: mention,
      fromBook: quoted.isNotEmpty,
      bookExplanation: bookExplanation,
      asl: poem == Poem.shatibiyya ? asl : const [],
    );
  }

  /// Words a bayt of the Durrah names for another of its three, Abu Ja'far
  /// left to his asl: «فَنُـۨجِي» (يوسف ١١٠), «نُجِّيَ حَامِدٌ» Ya'qub's;
  /// «إِنَّا دَمَّرۡنَٰهُمۡ» (النمل ٥١), «وَإِنَّا وَإِنَّ افْتَحْ حَلاَ»; «فَذَٰنِكَ»
  /// (القصص ٣٢), «فَذَانِكَ يُعْتَلَا».
  /// «أُذُن» and «أُذُنَيۡهِ», where Nafi' quiets the dhal.
  static const _udhun = {
    '5:45:10',
    '5:45:11',
    '9:61:6',
    '9:61:8',
    '31:7:11',
    '69:12:4',
  };

  // Khalaf al-'Ashir's, the book's quote from another chapter (Durrah 56, the
  // zawaid, for «يَقۡضِ» الأنعام ٥٧): his asl's bayt and the Durrah's two (the
  // user, 2026-11-14).
  static const _durrahSilentOnKhalaf = {'6:57:17', '7:40:7'};
  static const _durrahSilentOnAbuJafar = {
    '12:110:10',
    '27:51:5',
    '28:32:14',
    '30:54:4',
    '30:54:9',
    '30:54:16',
  };

  /// Abu Ja'far's words cited in both: the Shatibiyya's bayt of the word,
  /// the Durrah's of Abu Ja'far over it. «وَنَآءَ» (الإسراء ٨٣، فصلت ٥١):
  /// «نَآى أَخِّرْ مَعاً هَمْزَهُ مَلَا» and «نَاءَ أُدْ مَعًا».
  static const _durrahBesideShatibiyya = {
    '17:83:5': {147},
    '41:51:5': {147},
  };

  static String _at(Variant v) => '${v.surah}:${v.ayah}:${v.word}';

  /// [v] as Qalun's: Abu Ja'far's reading where the Durrah leaves him to Nafi'.
  static Variant _asQalun(Variant v) => _as(v, 'qalun');

  /// [v] as [id]'s: read as the riwaya of the Shatibiyya it follows.
  static Variant _as(Variant v, String id) => Variant(
    riwayaId: id,
    surah: v.surah,
    ayah: v.ayah,
    word: v.word,
    count: v.count,
    text: v.text,
    kind: v.kind,
    description: v.description,
    rule: v.rule,
    certified: v.certified,
    bookHow: v.bookHow,
    bookFarsh: v.bookFarsh,
    bookWujuh: v.bookWujuh,
    stopOnly: v.stopOnly,
    stopText: v.stopText,
    marginText: v.marginText,
    ownWays: v.ownWays,
    omission: v.omission,
    usulText: v.usulText,
    usulWays: v.usulWays,
    usulKind: v.usulKind,
    hamesh: v.hamesh,
  );

  /// The Durrah's «لِثَانٍ أَبُو عَمْرٍو وَالاَوَّلِ نَافِعٌ ...» and «وَرَمْزُهُمُ ثُمَّ
  /// الرُّوَاةُ كَأَصْلِهِمْ ...» (7، 8): each of the three reads as his asl
  /// where it tells him not.
  late final List<Bayt> durrahAsl = [
    for (final b in verses(Poem.durrah))
      if (b.n == 7 || b.n == 8) b,
  ];

  bool _citationFits(Poem poem, Variant v, int n, [String hafs = '']) {
    // The verses reviewed for the word, before what the book quotes with it.
    final reviewed = _reviewedVerses(poem, v, hafs);
    if (reviewed.isNotEmpty) return reviewed.contains(n);
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
    // «وَمَدُّ أَنَا فِي الْوَصْلِ مَعْ ضَمِّ هَمْزَةٍ وَفَتْحٍ أَتَى», wherever it is told.
    if (v.rule == 'ana_madd' &&
        const {
          'qalun',
          'warsh',
          'ibn_wardan',
          'ibn_jammaz',
        }.contains(v.riwayaId)) {
      return true;
    }
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
    // عَمَّ مِنْ رِجْزٍ أَلِيْمٍ مَعاً وِلَا / عَلَى رَفْعِ خَفْضِ الْمِيمِ دَلَّ
    // عَلِيمُهُ», the raf' (Ibn Kathir's, as Hafs) told in the next bayt.
    if ((v.surah == 34 || v.surah == 45) &&
        RegExp('أَلِيمٞ|أَلِيمٌ|أَلِيمٍ').hasMatch(v.text)) {
      return {975, 976};
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
    // 43:53 «أَسَٰوِرَةٞ»: «وَأَسْوِرَةٌ سَكِّنْ وَبِالْقَصْرِ عُدِّلَا».
    if (v.surah == 43 && v.ayah == 53 && v.word == 3) return {1024};
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
  /// 8:59 «وَبِالْغَيْبِ فِيهَا تَحْسَبَنَّ كَمَا فَشَا» (Abu Amr not among them).
  static const _yaqubInShatibiyya = {
    '8:59:1': {720},
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

  /// Ibn Kathir's «ٱلۡقُرَانَ» wherever it comes: «وَنَقْلُ قُرَانٍ وَالْقُرَانِ
  /// دَوَاؤُنَا».
  bool _ibnKathirQuran(Poem poem, Variant v, String hafs) =>
      poem == Poem.shatibiyya &&
      const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
      v.description == 'بفتح الراء وحذف الهمزة' &&
      RegExp('قر[ءا]*ن').hasMatch(_letters('$hafs ${v.text}'));

  /// «مُؤۡمِنٗا» (النساء ٩٤): «وَأُخْرَى مُؤْمِنًا فَتْحُهُ بَلَا», Ibn Wardan's the
  /// fatha, Ibn Jammaz as he is.
  bool _abuJafarMuminan(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.surah == 4 &&
      v.ayah == 94 &&
      v.word == 16;

  /// «خِفُّ الْأَمَانِيَ مُسْجَلَا»: «بِأَمَانِيكُمۡ» and its like.
  bool _abuJafarAmani(Poem poem, Variant v, String hafs) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      _letters('$hafs ${v.text}').contains('ماني');

  /// His ha sakin, told beside an ibdal: its own couplet, not the hamza's.
  /// «وَسَكِّنْ يُؤَدِّهْ مَعْ نُوَلِّهْ وَنُصْلِهِ وَنُؤْتِهْ وَأَلْقِهْ».
  bool _abuJafarSakinHa(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.description.contains('إسكان الهاء') &&
      RegExp(r'(يوده|نوله|نصله|نوته|لقه)$').hasMatch(_letters(v.text));

  /// «هَٰٓأَنتُمۡ» of Qalun and Ibn Kathir: «وَلَا أَلِفٌ فِي هَا هَأَنْتُمْ زَكَا
  /// جَنًا وَسَهِّلْ أَخَا حَمْدٍ وَكَمْ مُبْدِلٍ جَلَا». Not Ibn Kathir's «ءَا۬ن».
  bool _haAntum(Poem poem, Variant v) =>
      poem == Poem.shatibiyya &&
      const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
      v.rule == 'ha_antum' &&
      !(v.surah == 3 && v.ayah == 73);

  /// The first of two sakins of Qalun and Ibn Kathir: «وَضَمُّكَ أَولَى
  /// السَّاكِنَيْنِ لِثَالِثٍ يُضَمُّ لُزُومًا».
  bool _firstSakinOfSilah(Poem poem, Variant v) =>
      poem == Poem.shatibiyya &&
      const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
      v.rule == 'first_sakin';

  /// Abu Ja'far's, and his «ٱضۡطِرَّ» after it: «وَأَوَّلَ السَّاكِنَيْنِ اضْمُمْ فَتًى
  /// وَبِقُلْ حَلَا بِكَسْرٍ وَطَاءَ اضْطُرَّ فَاكْسِرْهُ آمِنًا».
  bool _abuJafarFirstSakin(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      (v.rule == 'first_sakin' ||
          // Its ta with the kasra; not «نَضۡطَرُّهُمۡ» or «ٱضۡطُرِرۡتُمۡ».
          RegExp('ض.?طِر').hasMatch(v.text));

  /// «مِنِ ٱجۡلِ» (المائدة ٣٢): «مِنِ اجْلِ اكْسِرْ انْقُلْ أُدْ».
  bool _abuJafarMinAjli(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.surah == 5 &&
      v.ayah == 32 &&
      v.word == 0;

  bool _abuJafarYuzlamun(Poem poem, Variant v, String hafs) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.surah == 4 &&
      v.ayah == 77 &&
      _letters('$hafs ${v.text}').contains('ظلمون');

  /// His «وَكَآئِن» with the hamza eased: «أَرَيْتَ وَإِسْرَائِيْلَ كَائِنْ».
  bool _abuJafarKaayin(Poem poem, Variant v) =>
      poem == Poem.durrah &&
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.text.contains('۬') &&
      RegExp('^[وف]?كا?[ئي]ن').hasMatch(_letters(v.text));

  /// «ٱسۡتُحِقَّ» (المائدة ١٠٧), for every reader, the Durrah's too: «وَضَمَّ
  /// اسْتُحِقَّ افْتَحْ لَحِفْصٍ وَكَسْرَهُ».
  bool _istuhiqqa(Variant v) => v.surah == 5 && v.ayah == 107 && v.word == 11;

  /// «حِصَادِهِۦ» (الأنعام ١٤١) with the kasra: «وَافْتَحْ حِصَادِ كَذِي حُلَا».
  bool _hisad(Variant v) =>
      v.surah == 6 &&
      v.ayah == 141 &&
      v.word == 24 &&
      const {
        'qalun',
        'warsh',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      }.contains(v.riwayaId);

  /// «ءَآمَنتُم» (الأعراف ١٢٣، طه ٧١، الشعراء ٤٩) of Ashab al-Silah, Abu
  /// Ja'far's too: «وَطه وفِي الأَعْرَافِ وَالشُّعَرَا بِهَا ءَآمَنْتُمُ ...».
  bool _aamantum(Variant v) =>
      const {
        '7:123:2',
        '20:71:1',
        '26:49:1',
      }.contains('${v.surah}:${v.ayah}:${v.word}') &&
      const {
        'qalun',
        'bazzi',
        'qunbul',
        'ibn_wardan',
        'ibn_jammaz',
      }.contains(v.riwayaId);

  /// Abu Ja'far's «بِيسٍ» (الأعراف ١٦٥), as Nafi''s: the Durrah tells it not;
  /// «وَبِيسٍ بِيَاءٍ أَمَّ».
  bool _abuJafarBiis(Variant v) =>
      qiraaOf(v.riwayaId).id == 'abu_jafar' &&
      v.surah == 7 &&
      v.ayah == 165 &&
      v.word == 14;

  /// «لَسِحۡرٞ» (يونس ٢) of Nafi' and Abu Ja'far, Abu Ja'far with Nafi', the
  /// Durrah silent: «نُفَصِّلُ يَا حَقٍّ عُلاً سَاحِرٌ ظُبَى».
  bool _sihr(Variant v) =>
      v.surah == 10 &&
      v.ayah == 2 &&
      v.word == 24 &&
      const {'qalun', 'warsh', 'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId);

  /// «تَذَّكَّرُونَ» with the dhal doubled, wherever it comes: «وَتَذَّكَّرُونَ
  /// الْكُلُّ خَفَّ عَلَى شَذَا»; Abu Ja'far with Nafi', the Durrah silent. Not
  /// where a bayt of its own tells it (الأعراف ٣، النمل ٦٢، الحاقة ٤٢).
  static bool _tadhakkarun(Variant v) =>
      v.description == 'بتشديد الذال' &&
      _letters(v.text).contains('تذكرون') &&
      !const {'7:3', '27:62', '69:42'}.contains('${v.surah}:${v.ayah}');

  /// The second «نُنَجِّ» (يونس ١٠٣) doubled, Abu Ja'far with Nafi', the Durrah
  /// silent: «وَنَجْعَلُ صِفْوَ الْخِفُّ نُنْجِ رِضىً عَلَا» and «وَذَاكَ هُوَ
  /// الثَّانِي».
  static bool _nunajji(Variant v) =>
      v.surah == 10 &&
      v.ayah == 103 &&
      v.word == 8 &&
      v.description == 'بفتح النون وتشديد الجيم' &&
      !const {'ruways', 'rawh', 'ishaq', 'idris'}.contains(v.riwayaId);

  /// Qunbul's «ضِئَآءٗ» wherever it comes (يونس ٥، الأنبياء ٤٨، القصص ٧١):
  /// «وَحَيْثُ ضِيَاءً وَافَقَ الْهَمْزُ قُنْبُلَا».
  static bool _diya(Variant v) =>
      v.riwayaId == 'qunbul' && _letters(v.text).contains('ضئا');

  /// «وَخَرَّقُواْ» (الأنعام ١٠٠) of Nafi' and Abu Ja'far: «خَرَّقُوا ثِقْلُهُ انْجَلَا».
  bool _kharraqu(Variant v) =>
      v.surah == 6 &&
      v.ayah == 100 &&
      v.word == 5 &&
      const {'qalun', 'warsh', 'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId);

  /// «أُذُن» of Nafi', wherever it comes: «وَكَيْفَ أَتى أُذْنٌ بِهِ نَافِعٌ تَلَا».
  bool _nafiUdhn(Poem poem, Variant v) =>
      poem == Poem.shatibiyya &&
      const {'qalun', 'warsh'}.contains(v.riwayaId) &&
      v.description == 'بإسكان الذال';

  /// The verses reviewed word by word, each as the reviewer named it: they
  /// stand before a chapter's rule and before what the book quotes.
  Set<int> _reviewedVerses(Poem poem, Variant v, String hafs) {
    // «ٱلَّٰٓـِٔي» (الأحزاب ٤، المجادلة ٢، الطلاق ٤): «وَبِالْهَمْزِ كُلُّ اللاَّءِ
    // وَالْياَءِ بَعْدَهُ ذَكَا وَبِيَاءٍ سَاكِنٍ حَجَّ هُمَّلَا / وَكَالْيَاءِ مَكْسُوراً
    // لِوَرْشٍ وَعَنْهُمَا وَقِفْ مُسْكِناً وَالْهَمْزُ زَاكِيهِ بُجِّلَا»; Abu Ja'far's
    // and Ya'qub's, «وَسَهِّلَا / أَرَيْتَ وَإِسْرَائِيْلَ كَائِنْ وَمَدَّ أُدْ مَعَ
    // اللاَّءِ هَا أَنْتُمْ وَحَقِّقْهُمَا حَلَا».
    if (v.rule == 'hamza_mutatarrif') {
      return poem == Poem.durrah ? {33, 34} : {965, 966};
    }
    // «التقاء الساكنين», all its places (فَمَنِ ٱضۡطُرَّ، قُلِ ٱدۡعُواْ،
    // مَحۡظُورًا ٱنظُرۡ), for every riwaya that reads it so: «وَضَمُّكَ أَولَى
    // السَّاكِنَيْنِ لِثَالِثٍ ...»; the Durrah's «... وَأَوَّلَ السَّاكِنَيْنِ اضْمُمْ فَتىً وَبِقُلْ حَلَا
    // / بِكَسْرٍ ...» (the user, 2026-11-14).
    // «هُزُوٗا» and «كُفُوًا» in all their places: «... وَهُزْؤاً وَكُفْؤاً في
    // السَّوَاكِنِ فُصِّلَا / وَضُمَّ لِبَاقِيهِمْ وَحَمْزَةُ وَقْفُهُ بِوَاوٍ وَحَفْصٌ وَاقِفاً
    // ثُمَّ مُوصِلَا» (the user, 2026-11-14).
    if (poem == Poem.shatibiyya &&
        RegExp(r'^[وفبل]?(هز|كف)[وؤء]ا?$')
            .hasMatch(hafs.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), ''))) {
      return {460, 461};
    }
    // «وَهۡوَ، فَهۡيَ، لَهۡوَ» its ha quiet, all the mushaf: «وَهَا هُوَ بَعْدَ الْوَاوِ
    // وَالْفَا وَلاَمِهَا وَهَا هِيَ أَسْكِنْ رَاضِياً ...»; the Durrah's «... هُوْ وَهِيْ
    // يُمِلَّ هْوَ ثُمَّ هْوَ اسْكِنًا أُدْ وَحُمِّلَا / فَحَرِّكْ ...» (the user,
    // 2026-11-14).
    // Abu Ja'far's «يُكۡذِبُونَكَ» (الأنعام ٣٣), as his asl: «فَتَحْنَا وَتَحْتُ
    // اشْدُدْ أَلاَ طِبْ وَالانْبِيَا مَعَ اقْتَرَبَتْ حُزْ إِذْ وَيُكْذِبُ أُصِّلَا» (the user,
    // 2026-11-14).
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        '${v.surah}:${v.ayah}:${v.word}' == '6:33:8') {
      return {105};
    }
    // The ha of silence dropped in joining (the user, 2026-11-14): «وَصِلْ
    // يَتَسَنَّهْ دُونَ هَاءٍ» (522), «وَاقْتَدِهْ حَذْفُ هَائِهِ شِفَاءً» (652),
    // Hamza's «وَيَخْفَى شِفَاءً مَالِيَهْ مَاهِيَهْ فَصِلْ / وَسُلْطَانِيَهْ مِنْ دُونِ
    // هَاءٍ» (1079); the Durrah's «وَلِهَا احْذِفَنْ بِسُلْطَانِيَهْ مَالِي وَمَا هِيَ
    // مُوْصِلَا / حِمَاهُ وَأَثْبِتْ فُزْ كَذَا احْذِفْ كِتَابِيَهْ حِسَابِي تَسَنَّ اقْتَدْ
    // لَدَى الْوَصْلِ حُفِّلَا» (48، 49).
    if (v.rule == 'ha_sakt' || v.rule == 'no_sakt') {
      final at = '${v.surah}:${v.ayah}:${v.word}';
      const three = {'69:28:3', '69:29:2', '101:10:3'};
      const others = {
        '2:259:41',
        '6:90:5',
        '69:19:8',
        '69:20:4',
        '69:25:9',
        '69:26:3',
      };
      if (poem == Poem.durrah) {
        if (three.contains(at)) return {48, 49};
        if (others.contains(at)) return {49};
      } else if (three.contains(at)) {
        return {1079};
      } else if (at == '2:259:41') {
        return {522};
      } else if (at == '6:90:5') {
        return {652};
      }
    }
    // A quiescent sad before a dal its sound the zay's (يَصۡدِفُونَ، أَصۡدَقُ): «وَإِشْمَامُ
    // صَادٍ سَاكِنٍ قَبْلَ دَالِهِ كَأَصْدَقُ زَايًا شَاعَ ...» (603); the Durrah's «...
    // وَأَشْمِمْ بَابَ أَصْدَقُ طِبْ وَلَا» (95) (the user, 2026-11-14).
    if (v.rule == 'ishmam_sad' && hafs.contains('صۡد')) {
      return poem == Poem.durrah ? {95} : {603};
    }
    // «لَا تُفَتَّحُ» (الأعراف ٤٠): the ya, «... وَيُفْتَحُ شَمْلَلَا» (684), with
    // the lightening, «وَخَفِّفْ شَفَا حُكْماً» (685); Abu 'Amr's lightening alone
    // (the user, 2026-11-14).
    if (poem == Poem.shatibiyya &&
        '${v.surah}:${v.ayah}:${v.word}' == '7:40:7' &&
        !v.isUsul) {
      return v.description.contains('بالياء') ? {684, 685} : {685};
    }
    // «وَيَبۡصُطُ» (البقرة ٢٤٥) and «بَصۡطَةٗ» (الأعراف ٦٩): «... وَيَبْصُطُ عَنْهُمْ
    // غَيْرَ قُنْبُلِ اعْتَلَا / وَبِالسِّينِ بَاقِيِهِمْ وَفي الْخَلْقِ بَصْطَةً ...» (514،
    // 515); the Durrah's «... وَيَبْصُطْ بَصْطَةَ الْخَلْقِ يُعْتَلَا» (81) (the user,
    // 2026-11-14).
    if ({'2:245:13', '7:69:21'}.contains('${v.surah}:${v.ayah}:${v.word}') &&
        !v.isUsul) {
      return poem == Poem.durrah ? {81} : {514, 515};
    }
    // «ٱبۡنَ أُمِّ» (الأعراف ١٥٠) and «يَبۡنَؤُمِّ» (طه ٩٤): «وَمِيمَ ابْنَ أُمَّ اكْسِرْ
    // مَعًا كُفْؤَ صُحْبَةٍ» (701) (the user, 2026-11-14).
    if (poem == Poem.shatibiyya &&
        {'7:150:24', '20:94:1'}.contains('${v.surah}:${v.ayah}:${v.word}') &&
        !v.isUsul) {
      return {701};
    }
    // «إِنَّكُمۡ لَتَأۡتُونَ» (الأعراف ٨١): «... وَبِالإِخْبَارِ إِنَّكُمُو عَلَا» (691)
    // (the user, 2026-11-14).
    if (poem == Poem.shatibiyya &&
        '${v.surah}:${v.ayah}:${v.word}' == '7:81:0' &&
        !v.isUsul) {
      return {691};
    }
    // «وَمِنۡهَا تُخۡرَجُونَ» (الأعراف ٢٥): «هُنَا تُخْرَجُوا سَمَّى حِمًى ...» (113)
    // (the user, 2026-11-14).
    if (poem == Poem.durrah &&
        '${v.surah}:${v.ayah}:${v.word}' == '7:25:6' &&
        !v.isUsul) {
      return {113};
    }
    // «وَأَنَّ هَٰذَا صِرَٰطِي» (الأنعام ١٥٣): Ya'qub's «وَأَنْ», «... وَخِفُّ وَأَنْ
    // حِفْظٌ», Khalaf's «وَإِنَّ» as his asl beside it (the user, 2026-11-14).
    if (poem == Poem.durrah &&
        '${v.surah}:${v.ayah}:${v.word}' == '6:153:0' &&
        !v.isUsul) {
      return {111};
    }
    // «يَقۡضِ» (الأنعام ٥٧): «... وَيَقْضِ بِضَمِّ سَاكِنٍ مَعَ ضَمِّ الْكَسْرِ شَدِّدْ
    // وَأَهْمِلَا / نَعَمْ دُونَ إِلْبَاسٍ ...», not the zawaid's 421 that the book
    // quotes (the user, 2026-11-14).
    if (poem == Poem.shatibiyya &&
        '${v.surah}:${v.ayah}:${v.word}' == '6:57:17' &&
        !v.isUsul) {
      return {642, 643};
    }
    // «إِنَّهُۥ ... فَإِنَّهُۥ» (الأنعام ٥٤), Abu Ja'far's and Khalaf's their
    // hamza broken: «وَحُزْ فَتْحَ إِنَّهْ مَعْ فَإِنَّهْ ...», Ya'qub's alone named
    // (the user, 2026-11-14).
    if (poem == Poem.durrah &&
        {'6:54:13', '6:54:24'}.contains('${v.surah}:${v.ayah}:${v.word}')) {
      return {106};
    }
    final huwa = hafs.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '');
    if (v.description.contains('إسكان الهاء') &&
        RegExp(r'^[وفل]?ه[وي]$').hasMatch(huwa)) {
      // «ثُمَّ هۡوَ», alone: «وَثُمَّ هْوَ رِفْقًا بَانَ».
      return poem == Poem.durrah
          ? {64, 65}
          : huwa.length == 2
          ? {450}
          : {449};
    }
    if (v.rule == 'first_sakin') {
      return poem == Poem.durrah ? {72, 73} : {495};
    }
    // Khalaf al-'Ashir's, the Durrah's bayt of the word (the user,
    // 2026-11-14): «يُظۡلَمُونَ» (النساء ٧٧) «وَلاَ يُظْلَمُوا أُدْ يَا»; «نِعِمَّا»
    // (البقرة ٢٧١، النساء ٥٨) «وَاكْسِرْ فَصُرْهُنَّ طِبْ أَلَا / نِعِمَّا حُزَ اسْكِنْ أُدْ».
    // Hamza's and al-Kisa'i's «فَتَثَبَّتُواْ» (النساء ٩٤ مرتين، الحجرات ٦):
    // «... شَاعَ وَارْتَاحَ أَشْمُلَا / وَفِيهَا وَتَحْتَ الْفَتْحِ قُلْ فَتَثَبَّتُوا
    // مِنَ الثَّبْتِ وَالْغَيْرُ الْبَيَانَ تَبَدَّلَا» (the user, 2026-11-14).
    if (poem == Poem.shatibiyya &&
        const {
          'khalaf_hamzah',
          'khallad',
          'abul_harith',
          'duri_kisai',
          'ishaq',
          'idris',
        }.contains(v.riwayaId) &&
        const {
          '4:94:8',
          '4:94:32',
          '49:6:7',
        }.contains('${v.surah}:${v.ayah}:${v.word}')) {
      return {603, 604};
    }
    // The user's bayts (2026-11-14), al-Ashab's: the ha and mim of the plural
    // before a quiescent, damma or kasra (وَقَتۡلِهُمُ ٱلۡأَنۢبِيَآءَ، وَأَخۡذِهُمُ
    // ٱلرِّبَوٰاْ): «وَمِنْ دُونِ وَصْلٍ ضَمُّهَا قَبْلَ سَاكِنٍ ... / مَعَ الْكَسْرِ
    // قَبْلَ الْهَا أَوِ الْيَاءِ سَاكِنًا ...»; «ٱلنَّبِيّ» and its bab, «وَجَمْعًا
    // وَفَرْدًا فِي النَّبِيءِ ...», the Durrah's «... أَجِدْ بَابَ النُّبُوَّةِ
    // وَالنَّبِيْ يِّ أَبْدِلْ لَهُ»; Hamza's «سَيُؤۡتِيهِمۡ» (النساء ١٦٢), «وَحَمْزَةٌ
    // سَيُؤتِيهِمُ», the Durrah's «... عَنِ الْيَاءِ إِنْ تَسْكُنْ سِوَى الْفَرْدِ».
    const shatibiyyaAshab = {
      'khalaf_hamzah',
      'khallad',
      'abul_harith',
      'duri_kisai',
    };
    final place = '${v.surah}:${v.ayah}:${v.word}';
    final nabi = RegExp('نبي|نبو')
        .hasMatch(v.text.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), ''));
    if (poem == Poem.shatibiyya && shatibiyyaAshab.contains(v.riwayaId)) {
      if (v.rule == 'ha_damir' && RegExp(r'هُمُ$').hasMatch(v.text)) {
        return {113, 114};
      }
      if (!v.isUsul && nabi) return {458};
      if (place == '4:162:23') return {611};
    }
    if (poem == Poem.durrah && const {'ishaq', 'idris'}.contains(v.riwayaId)) {
      if (!v.isUsul && nabi) return {35};
      if (place == '4:162:23') return {11, 12};
    }
    // Their «نُؤۡتِيهِمۡ» (النساء ١٥٢): «وَيَا سَوْفَ نُؤْتِيهِمْ عَزِيزٌ» (the user,
    // 2026-11-14).
    if (poem == Poem.shatibiyya &&
        const {
          'khalaf_hamzah',
          'khallad',
          'abul_harith',
          'duri_kisai',
        }.contains(v.riwayaId) &&
        '${v.surah}:${v.ayah}:${v.word}' == '4:152:11') {
      return {611};
    }
    if (poem == Poem.durrah && const {'ishaq', 'idris'}.contains(v.riwayaId)) {
      final at = '${v.surah}:${v.ayah}:${v.word}';
      if (at == '4:77:46') return {96};
      if (at == '2:271:3' || at == '4:58:17') return {82, 83};
    }
    // «تَحۡسَبَنَّ، يَحۡسَبَنَّ» told by a bayt of their own (the ya or the ta):
    // the bayt of the sin with it, Qalun and Ibn Kathir's kasra «وَيَحْسَبُ
    // كَسْرُ السِّينِ مُسْتَقبِلاً سَمَا», Abu Ja'far's fatha «كَيَحْسَبُ أُدْ».
    final yahsibanna = '${v.surah}:${v.ayah}:${v.word}';
    if (!v.isUsul &&
        poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
      final own = _yahsibannaShatibiyya[yahsibanna];
      if (own != null) return {538, ...own};
    }
    if (!v.isUsul &&
        poem == Poem.durrah &&
        const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId)) {
      final own = _yahsibannaDurrah[yahsibanna];
      if (own != null) return {83, ...own};
    }
    if (poem == Poem.shatibiyya && _istuhiqqa(v)) return {627};
    if (poem == Poem.shatibiyya && _kharraqu(v)) return {656};
    if (poem == Poem.shatibiyya && _sihr(v)) return {742};
    if (poem == Poem.shatibiyya && _diya(v)) return {742};
    if (poem == Poem.shatibiyya && _nunajji(v)) return {753, 754};
    if (poem == Poem.shatibiyya && _tadhakkarun(v)) return {677};
    if (poem == Poem.shatibiyya && _aamantum(v)) return {189, 190, 191};
    if (poem == Poem.shatibiyya && _abuJafarBiis(v)) return {704};
    // «طَٰٓئِفٞ» (الأعراف ٢٠١): Ibn Kathir's «طَيۡفٞ», Qalun's as Hafs's:
    // «وَقُلْ طَائِفٌ طَيْفٌ رِضًى حَقُّهُ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        v.surah == 7 &&
        v.ayah == 201 &&
        v.word == 5) {
      return {712};
    }
    // Ibn Kathir's «ٱلرِّيحَ» (الأعراف ٥٧، النمل ٦٣، فاطر ٩): the verse that
    // starts the word, «وَفِي الرِّيحِ تَوْحِيدٌ», with the one naming them,
    // as in الروم.
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {
          '7:57:3',
          '27:63:8',
          '35:9:3',
        }.contains('${v.surah}:${v.ayah}:${v.word}')) {
      return {490, 491};
    }
    // «أَرۡجِهۡ» (الأعراف ١١١، الشعراء ٣٦): Ibn Kathir's hamza, his damma and
    // its silah, Qalun's kasra without it: «وَعى نَفَرٌ أَرْجِئْهُ بِالْهَمْزِ
    // سَاكِنا / وَفي الْهَاءِ ضَمٌّ لَفَّ دَعْوَاهُ حَرْمَلَا / وَأَسْكِنْ نَصِيراً
    // فَازَ وَاكْسِرْ لِغَيْرِهِمْ / وَصِلْهَا جوَاداً دُونَ رَيْبٍ لِتُوصَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        const {
          '7:111:1',
          '26:36:1',
        }.contains('${v.surah}:${v.ayah}:${v.word}')) {
      return {166, 167};
    }
    // «ٱلرِّيَٰحَ» (الفرقان ٤٨), Ibn Kathir's one, Qalun's many as Hafs: from the
    // bayt that starts the word to the one naming it, «وَفي الْفُرْقَانِ زَاكِيهِ
    // هَلَّلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        const {
          '25:48:3',
          // «ٱلرِّيَٰحَ» (الشورى ٣٣): «وَفي سُورَةِ الشُّورَى».
          '42:33:3',
        }.contains('${v.surah}:${v.ayah}:${v.word}')) {
      return {490, 491, 492};
    }
    // Qalun's «وَمَحْيَآيْ» (الأنعام ١٦٢): «وَمَحْيَايَ وَالإِسْكَانُ صَحَّ تَحَمُّلَا».
    if (poem == Poem.shatibiyya &&
        v.riwayaId == 'qalun' &&
        v.surah == 6 &&
        v.ayah == 162 &&
        v.word == 4) {
      return {680};
    }
    // Abu Ja'far's «حَقِيقٌ عَلَىٰٓ» (الأعراف ١٠٥) as Hafs, not as Nafi':
    // «أَلَا ... وَقُلْ عَلَى لَهُ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        v.surah == 7 &&
        v.ayah == 105 &&
        v.word == 1) {
      return {115, 116};
    }
    final at = '${v.surah}:${v.ayah}:${v.word}';
    // Ibn Kathir's «وَلَا۟ أَدۡرَىٰكُم» (يونس ١٦), al-Bazzi's by khulf: «وَقَصْرُ
    // وَلاَ هَادٍ بِخُلْفٍ زَكَا».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '10:16:7') {
      return {744};
    }
    // Abu Ja'far's «يَنشُرُكُمُۥ» (يونس ٢٢): «وَيَنْشُرُكُمْ أُدْ»; the others of
    // Ashab al-Silah's «يُسَيِّرُكُمْ» in the Shatibiyya's «يُسَيِّرُكُمْ قُلْ فِيهِ
    // يَنْشُرُكُمْ كَفَى».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '10:22:2') {
      return {128};
    }
    // Abu Ja'far's «تَجۡمَعُونَ» (يونس ٥٨): «يَجْمَعُوا طَلَى» at the end of the
    // one, «إِذًا» at the start of the next.
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '10:58:9') {
      return {129, 130};
    }
    // Abu Ja'far's «ءَآلسِّحۡرُ» (يونس ٨١): «اسْئَلَا» at the end of the one,
    // «ءَأَلسِّحْرُ أَمْ أَخْبِرْ حُلىً» at the start of the next.
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '10:81:7') {
      return {130, 131};
    }
    // Abu Ja'far's «يُضَعَّفُ» and its like, every place: «يُضَاعِفُهُ انْصِبْ حُزْ
    // وَشَدِّدْهُ كَيْفَ جَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        const {
          '2:245:7',
          '2:261:18',
          '4:40:8',
          '4:40:9',
          '11:20:14',
          '25:69:0',
          '33:30:7',
          '57:11:7',
          '57:18:7',
          '64:17:5',
        }.contains(at)) {
      return {81};
    }
    // Abu Ja'far's «أَنِّي لَكُمۡ» (هود ٢٥): «وَافْتِحِ اتْلُ فَا / قَ إِنِّي لَكُمْ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '11:25:5') {
      return {131};
    }
    // «مُجۡرَىٰهَا» and «يَٰبُنَيِّ» (هود ٤١، ٤٢) of Qalun and Ibn Kathir: «وَفِي
    // ضَمِّ مَجْرَاهَا سِوَاهُمْ وَفَتْحُ يَا / بُنَيِّ هُنَا نَصٌّ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'11:41:5', '11:42:12'}.contains(at)) {
      return {757};
    }
    // «أَصَلَوَٰتُكَ» (هود ٨٧) of Qalun and Ibn Kathir, the plural: «صَلاَتَكَ
    // وَحِّدْ ... شَذًّا عَلَا» and «وَوَحِّدْ لَهُمْ في هُودَ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '11:87:2') {
      return {733, 734};
    }
    // Ibn Kathir's «حَيۡثُ نَشَآءُ» (يوسف ٥٦): «وَحَيْثُ يَشَاءُ نُو / نُ دَارٍ».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '12:56:8') {
      return {780};
    }
    // Ibn Kathir's «وَسَلۡ، فَسَلِ، فَسَلۡهُۥ، وَسَلُواْ» wherever they come: «وَسَلْ /
    // فَسَلْ حَرَّكُوا بِالنَّقْلِ رَاشِدُهُ دَلَا».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        RegExp('^ب(نقل حركة الهمزة إلى|فتح) السين').hasMatch(v.description) &&
        _letters(v.text).contains('سل')) {
      return {598};
    }
    // Al-Bazzi's «ٱسۡتَٰيَسُواْ» and its kin by khulf (يوسف ٨٠، ٨٧، ١١٠، الرعد
    // ٣١): «وَيَيْأَسْ مَعًا وَاسْتَيْأَسَ اسْتَيْأَسُوا وَتَيْـ / ـأَسُوا اقْلِبْ عَنِ
    // الْبَزِّيْ بِخُلْفٍ وَأَبْدِلَا».
    if (poem == Poem.shatibiyya &&
        v.riwayaId == 'bazzi' &&
        const {
          '12:80:1',
          '12:87:7',
          '12:87:13',
          '12:110:2',
          '13:31:19',
        }.contains(at)) {
      return {782};
    }
    // Ibn Kathir's «وَكَآئِن» wherever it comes: «وَمَعْ مَدِّ كَائِنْ كَسْرُ هَمْزَتِهِ
    // دَلَا».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        // Its madd written either way: آ, or the alif and its sign.
        RegExp('كَ(آ|آ)ئ').hasMatch(v.text)) {
      return {570};
    }
    // Qalun's «ٱللَّهُ ٱلَّذِي» (إبراهيم ٢): «وَفِي الْخَفْضِ فِي اللهِ الَّذِي الرَّفْعُ
    // عَمَّ».
    if (poem == Poem.shatibiyya && v.riwayaId == 'qalun' && at == '14:2:0') {
      return {797};
    }
    // Ibn Kathir's «رُّبَّمَا» (الحجر ٢) doubled, not named with those who
    // lighten it: «وَرُبَّ خَفِيفٌ إِذْ نَمَا».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '15:2:0') {
      return {802};
    }
    // «وَنَـَٔا» (الإسراء ٨٣، فصلت ٥١), of every reader, its hamza after the
    // alif or before it: «نَآى أَخِّرْ مَعاً هَمْزَهُ مَلَا».
    if (poem == Poem.shatibiyya &&
        !v.isUsul &&
        const {'17:83:5', '41:51:5'}.contains(at)) {
      return {826};
    }
    // «أَنسَىٰنِيهِ» (الكهف ٦٣) of Qalun and Ibn Kathir, the ha broken: «وَهَا
    // كَسْرِ أَنْسَانِيهِ ضُمَّ لِحَفْصِهِمْ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        at == '18:63:10') {
      return {844};
    }
    // Ibn Kathir's «تَسۡـَٔلۡنِي» (الكهف ٧٠) light, as Hafs: «وَتَسْئَلْنِ خِفُّ الْكَهْفِ
    // ظِلٌّ»; his «نُّكۡرٗا» (الكهف ٧٤): «وَنُكْرًا شَرْعُ حَقٍ لَهُ عُلَا».
    // «وَوَٰعَدۡنَٰكُمۡ»، «أَنجَيۡنَٰكُم»، «رَزَقۡنَٰكُمۡ» (طه ٨٠، ٨١) of Qalun and
    // Ibn Kathir, as Hafs: «وَأَنْجَيْتُكُمْ وَاعَدْتُكُمْ مَا رَزَقْتُكُمْ / شَفَا»,
    // and the alif of «وَاعَدْنَا»: «وَعَدْنَا جَمِيعاً دُونَ مَا أَلِفَ حَلَا».
    if (poem == Poem.shatibiyya &&
        !v.isUsul &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
      if (at == '20:80:6') return {453, 879};
      if (at == '20:80:3' || at == '20:81:4') return {879};
    }
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId)) {
      if (at == '18:70:4') return {760};
      if (at == '18:74:15' || at == '18:87:12') return {618};
    }
    // «ٱلسَّدَّيۡنِ» and «سَدّٗا» (الكهف ٩٣، ٩٤): Qalun's damma, Ibn Kathir's
    // fatha as Hafs's: «السُّدَّيْنِ سُدًّا صِحَابُ حَقْ / قٍ الضَّمُّ مَفْتُوحٌ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'18:93:4', '18:94:18'}.contains(at)) {
      return {851};
    }
    // «دَكًّا» (الكهف ٩٨) of Qalun and Ibn Kathir: «وَدَكَّاءَ لاَ تَنْوِينَ
    // وَامْدُدْهُ هَامِزاً شَفَا وَعَنِ الْكُوفِيِّ فِي الْكَهْفِ وُصِّلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '18:98:10') {
      return {697};
    }
    // «زَكَرِيَّآءَ» with its hamza, wherever it comes, for Qalun and Ibn Kathir
    // (and Abu Ja'far as Nafi'): «وَقُلْ زَكَرِيَّا دُونَ هَمْزِ جَمِيعِهِ صِحَابٌ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        _letters(v.text).contains('زكرياء')) {
      return {553};
    }
    // Qalun's «لِأَهَبَ» (مريم ١٩) by khulf: «وَهَمْزُ أَهَبْ بِالْيَا جَرَى حُلْوُ
    // بَحْرِهِ بِخُلْفٍ».
    if (poem == Poem.shatibiyya && v.riwayaId == 'qalun' && at == '19:19:5') {
      return {862};
    }
    // Ibn Kathir's «يُدۡخَلُونَ» (النساء ١٢٤، مريم ٦٠، غافر ٤٠) and
    // «سَيُدۡخَلُونَ» (غافر ٦٠): the bayt of its ruling, «وَضَمُّ يَدْ / خُلُونَ
    // وَفَتحُ الضَّمِّ حَقٌّ».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'4:124:11', '19:60:7', '40:40:17', '40:60:10'}.contains(at)) {
      return {606};
    }
    // «يُقَٰتِلُونَ» (الحج ٣٩) of Ibn Kathir, its ta broken, and «لَّهُدِمَتۡ»
    // (الحج ٤٠) light of Qalun and Ibn Kathir: «وَالْفَتْحُ فِي تَا يُقَاتِلُو / نَ
    // عَمَّ عُلاَهُ هُدِّمَتْ خَفَّ إِذْ دُلَا».
    if (poem == Poem.shatibiyya &&
        (at == '22:40:17' &&
                const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) ||
            at == '22:39:2' &&
                const {'bazzi', 'qunbul'}.contains(v.riwayaId))) {
      return {899};
    }
    // Ibn Kathir's «قُل كَم» (المؤمنون ١١٢): «وَفي قَالَ كَمْ قُلْ دُونَ شَكٍّ».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '23:112:0') {
      return {911};
    }
    // Al-Bazzi stops on «هَيۡهَاتَ» (المؤمنون ٣٦) with the ha: «وَلاَتَ رِضًى
    // هَيْهَاتَ هَادِيِه رُفِّلَا».
    if (poem == Poem.shatibiyya &&
        v.riwayaId == 'bazzi' &&
        (at == '23:36:0' || at == '23:36:1')) {
      return {379};
    }
    // Ibn Kathir's kasra of «عِيُون، شِيُوخ، جِيُوب» (دَانَهُ), and Qalun's damma
    // as Hafs's: «وَضَمَّ الْغُيُوبِ يَكْسِرَانِ عُيُوناً الْـ / ـعُيُونِ شُيُوخاً
    // دَانَهُ صُحْبَهٌ مِلَا / جُيُوبِ مُنِيرٌ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul) {
      final bare = v.text.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '');
      if (bare.contains('جيوب')) return {628, 629};
      if (RegExp('عيون|شيوخ').hasMatch(bare)) return {628};
    }
    // «بُيُوت» in every place, its ba broken by Qalun and Ibn Kathir, joined
    // by the rest (حفص عن عاصم among them): «وَكَسْرُ بُيُوتٍ وَالْبُيُوتَ
    // يُضَمُّ عَنْ / حِمَى جِلَّةٍ».
    if (poem == Poem.shatibiyya && _buyut.contains(at) && !v.isUsul) {
      return {503};
    }
    // «يَحۡسِبُ» and its like, the future, its sin broken by Qalun and Ibn
    // Kathir: «وَيَحْسَبُ كَسْرُ السِّينِ مُسْتَقبِلاً سَمَا / رِضَاهُ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        _yahsibu.contains(at)) {
      return {538};
    }
    // Ibn Kathir's «أُفَّ» (الإسراء ٢٣، الأنبياء ٦٧، الأحقاف ١٧), its fa opened:
    // «وَفَا أُفِّ كُلِّهاَ / بِفَتْحٍ دَناَ كُفْؤًا وَنَوِّنْ عَلَى اعْتِلَا».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'17:23:18', '21:67:0', '46:17:3'}.contains(at)) {
      return {818};
    }
    // «فَٱسۡرِ» (هود ٨١، الحجر ٦٥، الدخان ٢٣) and «أَنِ ٱسۡرِ» (طه ٧٧، الشعراء
    // ٥٢), the hamza of wasl for Nafi' and Ibn Kathir: «وَفَاسْرِ أَنِ اسْرِ
    // الْوَصْلُ أَصْلٌ دَناَ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {
          '11:81:8',
          '15:65:0',
          '44:23:0',
          '20:77:4',
          '26:52:3',
        }.contains(at)) {
      return {765};
    }
    // «يَتۡبَعُوكُمۡ» (الأعراف ١٩٣) and «يَتۡبَعُهُمُ» (الشعراء ٢٢٤) light for
    // Nafi', Ibn Kathir as Hafs: «وَلاَ يَتْبَعُوكُمْ خَفَّ مَعْ فَتْحِ بَائِهِ
    // / وَيَتْبَعُهُمْ فِي الظُّلَّةِ احْتَلَّ وَاعْتَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        (at == '7:193:5' || at == '26:224:1')) {
      return {711};
    }
    // «أَلَا يَا ٱسۡجُدُواْ» (النمل ٢٥): al-Kisa'i's, «أَلاَ يَسْجُدُوا رَاوٍ
    // وَقِفْ مُبْتَلىً أَلاَ / وَياَ وَاسْجُدُوا ... أَرَادَ أَلاَ يَا هؤُلاَءِ
    // اسْجُدُوا»; Abu Ja'far's and Ruways's, «وَإِذْ طَابَ قُلْ أَلَا».
    // «سَأۡقَيۡهَا» (النمل ٤٤), «بِٱلسُّوقِ» (ص ٣٣), «سُؤۡقِهِۦ» (الفتح ٢٩):
    // Qunbul's hamza, Qalun and al-Bazzi as Hafs: «مَعَ السُّوقِ سَاقَيهاَ
    // وَسُوقِ اهْمِزُوا زَكَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'27:44:10', '38:33:4', '48:29:38'}.contains(at)) {
      return {938};
    }
    // «تَذَّكَّرُونَ» (النمل ٦٢): the ta, «يَذَّكَّرُونَ لَهُ حُلَا», its dhal
    // shaddaed, «وَتَذَّكَّرُونَ الْكُلُّ خَفَّ عَلَى شَذَا»; Abu Ja'far's,
    // «وَطَرَى خِطَا / بُ يَذَّكَّرُوا».
    if (at == '27:62:15' && !v.isUsul) {
      if (poem == Poem.shatibiyya &&
          const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
        return {941, 677};
      }
      if (poem == Poem.durrah &&
          const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId)) {
        return {175};
      }
    }
    // The nun shaddaed by Ibn Kathir (النساء ١٦، طه ٦٣، الحج ١٩، القصص ٢٧ و٣٢،
    // فصلت ٢٩): «وَهذَانِ هاتَيْنِ الَّلذَانِ الَّلذَيْنِ قُلْ / يُشَدَّدُ لِلْمَكِّيْ
    // فَذَانِكَ دُمْ حَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        const {
          '4:16:0',
          '20:63:2',
          '22:19:0',
          '28:27:7',
          '28:32:14',
          '41:29:5',
        }.contains(at)) {
      return {593};
    }
    // «لِأَهۡلِهِ ٱمۡكُثُوٓاْ» (طه ١٠، القصص ٢٩), its ha broken as Hafs's, Hamza's
    // put: «لِحَمْزَةَ فَاضْمُمْ كَسْرَهاَ أَهْلِهِ امْكُثُوا / مَعاً»; Abu Ja'far's,
    // «وَهَا أَهْلِهِ قَبْلَ امْكُثُوا الْكَسْرُ فُصِّلَا».
    if (at == '20:10:4' || at == '28:29:12') {
      if (poem == Poem.shatibiyya &&
          const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
        return {871};
      }
      if (poem == Poem.durrah &&
          const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId)) {
        return {21};
      }
    }
    // «لَا يُرۡجَعُونَ» (القصص ٣٩): Qalun's named, Ibn Kathir's with Hafs,
    // «نَمَا نَفَرٌ بِالضَّمِّ وَالْفَتْحِ يَرْجِعُو / نَ»; Abu Ja'far's as Hafs's,
    // «وَيُرْجَعُ كَيْفَ جَا / إِذَا كَانَ لِلأُخْرَى فَسَمِّ حُلًى حَلَا / وَالامْرُ
    // اتْلُ وَاعْكِسْ أَوَّلَ الْقَصِّ».
    if (at == '28:39:11' && !v.isUsul) {
      if (poem == Poem.shatibiyya &&
          const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
        return {949};
      }
      if (poem == Poem.durrah &&
          const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId)) {
        return {63, 64};
      }
    }
    // «لَخُسِفَ» (القصص ٨٢): «وَفِي خُسِفَ الْفَتْحَتَيْنِ حَفْصٌ تَنَخَّلَا»; Abu
    // Ja'far's, «وَسَمِّ خُسِفْ وَنَشْـ / أَةً حَافِظٌ».
    if (at == '28:82:20' && !v.isUsul) {
      if (poem == Poem.shatibiyya &&
          const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
        return {950};
      }
      if (poem == Poem.durrah &&
          const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId)) {
        return {177};
      }
    }
    // «سِيٓءَ، سِيٓـَٔتۡ» (هود ٧٧، العنكبوت ٣٣، الملك ٢٧), the ishmam Qalun's:
    // «وَحِيلَ بِإِشْمَامٍ وَسِيقَ كَمَا رَسَا / وَسِيءَ وَسِيئَتْ كَانَ رَاوِيهِ
    // أَنْبَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'11:77:4', '29:33:5', '67:27:3'}.contains(at)) {
      return {448};
    }
    // «مَالِيَهۡۜ هَلَكَ» (الحاقة ٢٨): «وَيَخْفَى شِفَاءً مَالِيَهْ مَاهِيَهْ فَصِلْ /
    // وَسُلْطَانِيَهْ مِنْ دُونِ هَاءٍ فَتُوصلَا»; Abu Ja'far and Yaqub: «وَلِهَا
    // احْذِفَنْ / بِسُلْطَانِيَهْ مَالِي وَمَا هِيَ مُوْصِلَا / حِمَاهُ ...».
    if (at == '69:28:3') {
      if (poem == Poem.durrah) return {48, 49};
      if (poem == Poem.shatibiyya) return {1079};
    }
    // «مَنۡۜ رَاقٖ» (القيامة ٢٧) joined: «وَسَكْتَةُ حَفْصٍ دُونَ قَطْعٍ لَطِيفَةٌ ... /
    // وَفِي نُونِ مَنْ رَاق ... وَالْبَاقُونَ لاَ سَكْتَ مُوصَلَا».
    if (poem == Poem.shatibiyya && (at == '75:27:1' || at == '83:14:1')) {
      return {830, 831};
    }
    // «سَلَٰسِلَاْ» (الإنسان ٤): «يُمْنَى حُلًى وَسَلاسِلَا / لَدَى الْوَقْفِ فَاقْصُرْ
    // طُلْ».
    if (poem == Poem.durrah && at == '76:4:3') return {223, 224};
    // Abu Ja'far's «مُنذِرٞ» (النازعات ٤٥): «وَنُونُ مُنْـ / ـذِرٌ … شَدِّدْ أَلاَ».
    if (poem == Poem.durrah && at == '79:45:2') return {228};
    // «تُكَذِّبُونَ» (الانفطار ٩) with the ta, as Hafs: «تُكَذِّبُ غَيْبًا أُدْ».
    if (poem == Poem.durrah && at == '82:9:2') return {229};
    // «وَيَصۡلَىٰ» (الانشقاق ١٢) as Hafs: «وَاتْلُ يَصْلَى وَآخِرَ الْـ / بُرُوجِ كَحَفْصٍ».
    // «لِإِيلَٰفِ … إِۦلَٰفِهِمۡ» (قريش ١، ٢): «لِيْلافِ اتْلُ مَعْهُ إِلاَفِهِمْ».
    // And «كُفُؤًا» (الإخلاص ٤) with the damma, as Hafs: «وَكُفْؤًا سُكُونُ الْفَاءِ
    // حِصْنٌ تَكَمَّلَا».
    if (poem == Poem.durrah &&
        const {'106:1:0', '106:2:0', '112:4:3'}.contains(at)) {
      return {234};
    }
    if (poem == Poem.durrah && (at == '84:12:0' || at == '85:22:2')) {
      return {230};
    }
    // «نُذۡرًا» (المرسلات ٦): «وَفي سُبْلَنَا فِي الضَّمِّ الاِسْكَانُ حُصِّلَا ... / وَنُذْرًا
    // صِحَابُهُمْ حَمَوْهُ»; the Durrah: «وَالْعُسْرُ وَالْيُسْرُ أُثْقِلَا / ... وَنُذْرًا».
    if (at == '77:6:2' && !v.isUsul) {
      if (poem == Poem.shatibiyya) return {616, 618};
      if (poem == Poem.durrah) return {74, 76};
    }
    // Abu Ja'far's: «وَاشْمِمًا طِلَا / بِقِيْلَ وَمَا مَعْهُ».
    if (poem == Poem.durrah &&
        const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId) &&
        const {'11:77:4', '29:33:5', '67:27:3'}.contains(at)) {
      return {62, 63};
    }
    // «لَنُنَجِّيَنَّهُۥ، مُنَجُّوكَ» (العنكبوت ٣٢، ٣٣): «وَفِي الْعَنْكَبُوتِ نُنْـ /
    // ـجِيَنَّ شَفَا مُنْجُوكَ صُحْبَتُهُ دَلَا»; Abu Ja'far's shaddaed, «يُنْجِي
    // فَثَقِّلَا / بِثَانٍ أَتَى وَالْخِفَّ فِي الْكُلِّ حُزْ».
    if ((at == '29:32:9' || at == '29:33:16') && !v.isUsul) {
      if (poem == Poem.shatibiyya &&
          const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
        return {806};
      }
      if (poem == Poem.durrah &&
          const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId)) {
        return {106, 107};
      }
    }
    // «ءَايَٰتٞ مِّن رَّبِّهِۦ» (العنكبوت ٥٠), one for Ibn Kathir: «وَمُوَحِّدٌ / هُنَا
    // آيَةٌ مِنْ رَبِّهِ صُحْبَةٌ دَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '29:50:4' &&
        !v.isUsul) {
      return {954};
    }
    // «لِنُذِيقَهُم» (الروم ٤١): Qunbul's nun, Qalun and al-Bazzi as Hafs:
    // «وَبِالنُّونِ نُذِيقُ زَكَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '30:41:9' &&
        !v.isUsul) {
      return {958};
    }
    // «كِسَفًا» (الإسراء ٩٢، الشعراء ١٨٧، الروم ٤٨، سبأ ٩): «وَعَمَّ نَدىً كِسْفاً
    // بِتَحْرِيكِهِ وَلَا / وَفي سَبَأٍ حَفْصٌ مَعَ الشُّعَرَاءِ قُلْ / وَفِي الرُّومِ
    // سَكِّنْ لَيْسَ بِالْخُلْفِ مُشْكِلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        _letters(v.text) == 'كسفا') {
      return {827, 828};
    }
    // «تُسۡمِعُ ٱلصُّمَّ» (النمل ٨٠، الروم ٥٢): Ibn Kathir's «يَسۡمَعُ ٱلصُّمُّ»,
    // Qalun as Hafs: «وَتُسْمِعُ فَتْحُ الضَّمِّ وَالْكَسْرِ غَيْبَةً / سِوَى الْيَحْصَبِيْ
    // وَالصُّمَّ بِالرَّفْعِ وُكِّلا / وَقَالَ بِهِ فِي النَّمْلِ وَالرُّومِ دَارِمٌ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        const {'27:80:5', '27:80:6', '30:52:5', '30:52:6'}.contains(at)) {
      return {888, 889};
    }
    // «ضُعۡف» of al-Rum (30:54, three times): «وَضُعْفاً بِفَتْحِ الضَّمِّ فَاشِيهِ
    // نُفِّلا / وِفي الرُّومِ صِفْ عَنْ خُلْفِ فَصْلٍ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        const {'30:54:4', '30:54:9', '30:54:16'}.contains(at)) {
      return {722, 723};
    }
    // «أُذُن» (المائدة ٤٥، التوبة ٦١، لقمان ٧، الحاقة ١٢): Nafi''s quiet dhal,
    // Ibn Kathir as Hafs: «وَفي سُبْلَنَا فِي الضَّمِّ الاِسْكَانُ حُصِّلَا / وَكَيْفَ
    // أَتى أُذْنٌ بِهِ نَافِعٌ تَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        _udhun.contains(at)) {
      return {616, 617};
    }
    // «إِسۡوَةٌ» (الأحزاب ٢١، الممتحنة ٤ و٦), its kasra Hafs's damma: «وَفِي
    // الْكُلِّ ضَمُّ الْكَسْرِ فِي إِسْوَةٌ نَدىً».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        const {'33:21:6', '60:4:3', '60:6:4'}.contains(at)) {
      return {971};
    }
    // «تُرۡجِئُ» (الأحزاب ٥١), Ibn Kathir's hamza, Qalun as Hafs: «تُرْجِئُ هَمْزُهُ
    // صَفَا نَفَرٍ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        at == '33:51:0') {
      return {734};
    }
    // «مَّيِّتٖ، ٱلۡمَيِّتِ» shaddaed, Qalun as Hafs: «وَفي بَلَدٍ مَيْتٍ مَعَ
    // المَيْتِ خَفَّفُوا صَفَا نَفَرًا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        RegExp(r'^(ال)?ميت$').hasMatch(_letters(v.text))) {
      return {550};
    }
    // «بَيِّنَتٖ» (فاطر ٤٠), Ibn Kathir's as Hafs's (his stop with the ha too),
    // Qalun's plural: «بَيِّناتٍ قَصْرُ حَقٍّ فَتًى عَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '35:40:23') {
      return {985};
    }
    // «يسٓ ۝ وَٱلۡقُرۡءَانِ», its nun shown: «وَيَاسِيْنَ أَظْهِرْ عنْ فَتًى حَقُهُ
    // بَدَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '36:1:0') {
      return {281};
    }
    // «بِخَالِصَةٖ» (ص ٤٦), Qalun's added to «ذِكۡرَى», Ibn Kathir as Hafs:
    // «خَالِصَةٍ أَضِفْ / لَهُ الرَّحْبُ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        at == '38:46:2') {
      return {1001};
    }
    // «أَمَنۡ» (الزمر ٩) light: «أَمَنْ خَفَّ حِرْمِيٌّ فَشَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        !v.isUsul &&
        at == '39:9:0') {
      return {1005};
    }
    // Ibn Kathir's stop with the ya: «هَادِ، وَالِ، وَاقِ، بَاقِ»: «وَهَادٍ وَوَالٍ قِفْ
    // وَوَاقٍ بِيَائِهِ / وَبَاقٍ دَنَا».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        v.rule == 'rasm_stop' &&
        RegExp(r'^(هاد|وال|واق|باق)$').hasMatch(_letters(v.stopText))) {
      return {794};
    }
    // «وَصَدَّ» (غافر ٣٧) with the fatha: «وَضَمُّهُمْ / وَصُدُّوا ثَوَى مَعْ صُدَّ
    // فِي الطَّوْلِ وَانْجَلَا».
    if (poem == Poem.shatibiyya && at == '40:37:14' && !v.isUsul) {
      return {795};
    }
    // «ٱدۡخُلُوٓاْ» (غافر ٤٦) with a hamzat al-wasl: «أَدْخِلُوا نَفَرٌ صِلَا / عَلَى
    // الْوَصْلِ وَاضْمُمْ كَسْرَهُ»; «يَتَذَكَّرُونَ» (غافر ٥٨): «يَتَذَكَّرُو / نَ
    // كَهْفٌ سَماَ».
    if (poem == Poem.shatibiyya && at == '40:46:8' && !v.isUsul) {
      return {1012, 1013};
    }
    if (poem == Poem.shatibiyya && at == '40:58:12' && !v.isUsul) {
      return {1013};
    }
    // «وَهۡيَ» (فصلت ١١): «وَهَا هُوَ بَعْدَ الْوَاوِ … / وَهَا هِيَ أَسْكِنْ».
    // «يُبَشِّرُ» (الشورى ٢٣): «يَبْشُرُ كَمْ سَمَا / نَعَمْ ضُمَّ حَرِّكْ وَاكْسِرِ
    // الضَّمَّ أَثْقَلَا / نعَمْ عَمَّ فِي الشُّورَى».
    if (poem == Poem.shatibiyya && at == '42:23:2' && !v.isUsul) {
      return {555, 556};
    }
    // «يَفۡعَلُونَ» (الشورى ٢٥) with the ya: «وَيَفْعَلُو / نَ غَيْرُ صِحَابٍ».
    if (poem == Poem.shatibiyya && at == '42:25:11' && !v.isUsul) {
      return {1018};
    }
    if (poem == Poem.shatibiyya && at == '41:11:4' && !v.isUsul) {
      return {449};
    }
    // «ثَمَرَتٖ» (فصلت ٤٧) singular: «وَالْجَمْعُ عَمَّ عَقَنْقَلَا / لَدَى ثَمَرَاتٍ».
    if (poem == Poem.shatibiyya && at == '41:47:7' && !v.isUsul) {
      return {1016, 1017};
    }
    // «سَقۡفٗا» (الزخرف ٣٣): «وَسَقْفاً بِضَمِّهِ / وَتَحْرِيكِهِ بِالضَّمِّ ذَكَّرَ
    // أَنْبَلَا».
    if (poem == Poem.shatibiyya && at == '43:33:11' && !v.isUsul) {
      return {1023};
    }
    // «مِّن رِّجۡزٍ أَلِيمٞ» (سبأ ٥، الجاثية ١١): «وَرَفْعُ خَفْـ / ـضِهِ عَمَّ مِنْ
    // رِجْزٍ أَلِيْمٍ مَعاً وِلَا / عَلَى رَفْعِ خَفْضِ الْمِيمِ دَلَّ عَلِيمُهُ».
    if (poem == Poem.shatibiyya &&
        (at == '34:5:10' || at == '45:11:10') &&
        !v.isUsul) {
      return {975, 976};
    }
    // «وَلِيُوَفِّيَهُمۡ» (الأحقاف ١٩): «نُوَفيَهُمْ بِالْيَا لَهُ حَقُّ نَهْشَلَا».
    if (poem == Poem.shatibiyya && at == '46:19:4' && !v.isUsul) {
      return {1035};
    }
    // «يُدۡخِلۡهُ، يُعَذِّبۡهُ» (الفتح ١٧): «وَنُدْخِلْهُ نُونٌ مَعْ طَلاَقٍ وَفَوْقُ
    // مَعْ / نُكَفِّرْ نُعَذِّبْ مَعْهُ في الْفَتْحِ إِذْ كَلَا».
    if (poem == Poem.shatibiyya &&
        const {
          '48:17:16',
          '48:17:24',
          '64:9:12',
          '64:9:15',
          '65:11:20',
        }.contains(at) &&
        !v.isUsul) {
      return {592};
    }
    // Ibn Kathir's «شَطَـَٔهُۥ» (الفتح ٢٩): «حَرَّكَ شَطْأَهُ دُعَا مَاجِدٍ».
    if (poem == Poem.shatibiyya && at == '48:29:33' && !v.isUsul) {
      return {1043};
    }
    // The second «ذُرِّيَّتَهُمۡ» (الطور ٢١): «وَيَقْصُرُ ذُرِّيَّاتِ مَعْ فَتْحِ تَائِهِ /
    // وَفِي الطُّورِ فِي الثَّانِي ظَهِيرٌ تَحَمَّلَا / ... وَبِالْمَدِّ كَمْ حَلَا».
    if (poem == Poem.shatibiyya && at == '52:21:7' && !v.isUsul) {
      return {706, 707};
    }
    // «عَادًا ٱلۡأُولَىٰ» (النجم ٥٠): «وَقُلْ عَادًا الأُوْلَى بِإِسْكَانِ لامِهِ» to
    // «وَتَبْدَاْ بِهَمْزِ الْوَصْلِ في النَّقْلِ كُلِّهِ وَإِنْ كُنْتَ مُعْتَدًّا بِعَارِضِهِ فَلَا».
    if (poem == Poem.shatibiyya &&
        (at == '53:50:2' || at == '53:50:3') &&
        !v.isUsul) {
      return {230, 231, 232, 233};
    }
    // «شُوَاظٞ … وَنُحَاسٞ» (الرحمن ٣٥): «شُوَاظٌ بِكَسْرِ الضَّمِّ مَكِّيُّهُمْ جَلَا /
    // وَرَفْعَ نُحَاسٌ جَرَّ حَقٌّ».
    if (poem == Poem.shatibiyya &&
        (at == '55:35:2' || at == '55:35:5') &&
        !v.isUsul) {
      return {1054, 1055};
    }
    // «لِيُحۡزِنَ» (المجادلة ١٠): «وَيَحْزُنُ غَيْرَ اْلاَنْـ / ـبِيَاءِ بِضَمٍّ وَاكْسِرِ
    // الضَّمَّ أَحْفَلَا».
    if (poem == Poem.shatibiyya && at == '58:10:4' && !v.isUsul) return {578};
    // Ibn Kathir's «نُّكۡرٍ» (القمر ٦): «وَفي سُبْلَنَا فِي الضَّمِّ الاِسْكَانُ
    // حُصِّلَا ... / وَنُكْرٍ دَنَا».
    if (poem == Poem.shatibiyya && at == '54:6:7' && !v.isUsul) {
      return {616, 619};
    }
    // «نُّكۡرٗا» (الطلاق ٨): «وَفي سُبْلَنَا فِي الضَّمِّ الاِسْكَانُ حُصِّلَا ... /
    // وَنُكْرًا شَرْعُ حَقٍ لَهُ عُلَا».
    if (poem == Poem.shatibiyya && at == '65:8:13' && !v.isUsul) {
      return {616, 618};
    }
    // «وَجِبۡرِيلُ» (التحريم ٤): «وَجِبْرِيلَ فَتْحُ الْجِيمِ وَالرَّا وَبَعْدَهَا / وَعَى
    // هَمْزَةً مَكْسُورَةً صُحْبَةٌ وِلَا / بِحَيْثُ أَتَى ... / وَمَكِيُّهُمْ في الْجِيمِ
    // بالْفَتْحِ وُكِّلَا».
    if (poem == Poem.shatibiyya && at == '66:4:14' && !v.isUsul) {
      return {471, 472};
    }
    // Ibn Kathir's «وَمَنَوٰٓءَةَ» (النجم ٢٠): «مَناءَةَ لِلْمَكِّيْ زِدِ الْهَمْزَ».
    if (poem == Poem.shatibiyya && at == '53:20:0' && !v.isUsul) return {1050};
    // «ٱلنَّشَآءَةَ» (النجم ٤٧): «وَحَرِّكْ وَمُدَّ فِي النْـ / ـنَشَاءَةِ حَقاًّ».
    if (poem == Poem.shatibiyya && at == '53:47:2' && !v.isUsul) return {952};
    // «فَسَنُؤۡتِيهِ» (الفتح ١٠) with the nun: «وَفي ياَءِ يُؤْتيِهِ غَدِيرٌ تَسَلْسَلَا».
    if (poem == Poem.shatibiyya && at == '48:10:22' && !v.isUsul) {
      return {1041};
    }
    // «لِيَجۡزِيَ» (الجاثية ١٤) with the ya, as Hafs: «لِنَجْزِيَ يَا نَصٍّ سَمَا».
    if (poem == Poem.shatibiyya && at == '45:14:9' && !v.isUsul) {
      return {1032};
    }
    if (at == '27:25:0') {
      if (poem == Poem.shatibiyya &&
          const {'duri_kisai', 'abul_harith'}.contains(v.riwayaId)) {
        return {934, 935};
      }
      if (poem == Poem.durrah &&
          const {'ibn_wardan', 'ibn_jammaz', 'ruways'}.contains(v.riwayaId)) {
        return {174};
      }
    }
    // «بِشِهَابِ» (النمل ٧) without the tanween: «شِهَابٍ بِنُونٍ ثِقْ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '27:7:12') {
      return {932};
    }
    // «سَبَإٖ» (النمل ٢٢، سبأ ١٥): Qalun's as Hafs's, al-Bazzi's open without
    // the tanween, Qunbul's quiet: «مَعاً سَبَأَ افْتَحْ دُونَ نُونٍ حِمًى هُدًى
    // / وَسَكِّنْهُ وَانْوِ الْوَقْفَ زُهْراً وَمَنْدَلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        (at == '27:22:11' || at == '34:15:2')) {
      return {933};
    }
    // «فَرِهِينَ» (الشعراء ١٤٩) without the alif, the madd «ذَاعَ» others':
    // «وَفِي حَاذِرُونَ الْمدُّ مَا ثُلَّ فَارِهِيْـ / ـنَ ذَاعَ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '26:149:4') {
      return {927};
    }
    // «ٱرۡكَب مَّعَنَا» (هود ٤٢): al-Bazzi and Qalun by khulf, Qunbul not named,
    // reading it merged: «وَفِي ارْكَبْ هُدَى بَرٍّ قَرِيبٍ بِخُلْفِهِمْ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        at == '11:42:13') {
      return {284};
    }
    // Abu Ja'far's, shown: «يَلْهَثَ اَظْهِرْ أُدْ وَفِي ارْكَبْ فَشَا أَلَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '11:42:13') {
      return {41};
    }
    // «وَإِن كُلّٗا لَّمَا» (هود ١١١) of Qalun and Ibn Kathir: «وَخِفُّ وَإِنْ
    // كُلاًّ إِلَى صَفْوِهِ دَلَا» and «وَفِيها ... يُشَدِّدُ لَمَّا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        const {'11:111:0', '11:111:2'}.contains(at)) {
      return {766, 767};
    }
    // Abu Ja'far's «وَإِنَّ» doubled: «إِنْ كُلاًّ اتْلُ مُثَقِّلَا»; his «وَزُلُفٗا»:
    // «وَخِفُّ الْكُلِّ فُقْ زُلَفَا أَلَا».
    if (poem == Poem.durrah && qiraaOf(v.riwayaId).id == 'abu_jafar') {
      if (at == '11:111:0') return {133};
      if (at == '11:114:4') return {134};
      // «يَتَّبِعُوكُمۡ، يَتَّبِعُهُمُ» shaddaed, as Hafs: «نَكِدًا أَلاَ افْـ /
      // تَحَنْ يَقْتُلُوا مَعْ يَتْبَعُ اشْدُدْ».
      if ((at == '7:193:5' || at == '26:224:1') && !v.isUsul) return {115};
      // «ٱلۡمَيِّتِ» shaddaed, as Hafs (آل عمران ٢٧، الأنعام ٩٥، يونس ٣١، الروم
      // ١٩): «وَاشْدُدَنْ مَيْتَهْ وَمَيْتًا أُدْ وَالانْعَامُ حُلِّلَا / وَفِي
      // حُجُرَاتٍ طُلْ وَفِي الْمَيْتِ حُزْ».
      if (!v.isUsul && RegExp(r'^(ال)?ميت$').hasMatch(_letters(v.text))) {
        return {71, 72};
      }
      // «بِشِهَابِ» and «سَبَإٖ», the tanween Ya'qub's: «وَنَوِّنْ سَبَأْ شِهَا /
      // بِ حُزْ».
      if (const {'27:7:12', '27:22:11', '34:15:2'}.contains(at) && !v.isUsul) {
        return {174};
      }
      // «لِيُذِيقَهُم» (الروم ٤١) with the ya, as Hafs: «يُذِيْقَهُمُ نُوْنٌ يَعِيْ».
      if (at == '30:41:9' && !v.isUsul) return {179};
      // «وَيَتَّخِذُهَا» (لقمان ٦) with the damma, the nasb Ya'qub's: «وَيَتْـ /
      // ـتَخِذْ حُزْ».
      if (at == '31:6:12' && !v.isUsul) return {180};
      // «نِعَمَهُۥ» (لقمان ٢٠) the plural, as Hafs: «نِعْمَةً حَلَا».
      if (at == '31:20:14' && !v.isUsul) return {180};
      // «تُوعَدُونَ» (ص ٥٣) with the ta, as Hafs: «وَحُزْ يُوْعَدُوا خَاطِبْ».
      if (at == '38:53:2' && !v.isUsul) return {197};
      // «إِنَّمَا أَنَا۠ نَذِيرٞ» (ص ٧٠) with the kasra: «وَأُدْ كَسْرَ أَنَّمَا».
      if (at == '38:70:4' && !v.isUsul) return {197};
      // «يَدۡعُونَ» (غافر ٢٠) with the ya, as Hafs: «يَدْعُو اتْلُ».
      if (at == '40:20:4' && !v.isUsul) return {198};
      // «دِينَكُمُۥ وَأَن» (غافر ٢٦) with the waw: «أَوْ أَنْ وَقَلْبِ لَا»; and
      // «يُظۡهِرَ … ٱلۡفَسَادَ» as Hafs: «… تُنَوِّنْهُ وَاقْطَعِ ادْخُلُوا حُمْ».
      if ((at == '40:26:11' || at == '40:26:12') && !v.isUsul) return {198};
      if ((at == '40:26:14' || at == '40:26:17') && !v.isUsul) return {199};
      // «وَصَدَّ» (غافر ٣٧) with the fatha, the damma Ya'qub's: «صَدَّ اضْمُمَنْ حَلَا».
      if (at == '40:37:14' && !v.isUsul) return {137};
      // «يُدۡخَلُونَ» (غافر ٤٠) unnamed of its doer: «وَيَدْ / خُلُوا سَمِّ طِبْ
      // جَهِّلْ كَطَوْلٍ وَكَافَ الَا».
      if (at == '40:40:17' && !v.isUsul) return {97};
      // «سَيُدۡخَلُونَ» (غافر ٦٠): «سَيَدْخُلُو / نَ جَهِّلْ أَلاَ طِبْ»; «شُيُوخٗا»
      // (غافر ٦٧) with the damma, as Hafs: «اضْمُمْ … شُيُوخًا فِدْ».
      if (at == '40:60:10' && !v.isUsul) return {199};
      if (at == '40:67:19' && !v.isUsul) return {102};
      // «تَكَادُ» (الشورى ٥) with the ta, as Hafs: «يَكَادُ أَنْ / نِثِ».
      if (at == '42:5:0' && !v.isUsul) return {156};
      // «يُبَشِّرُ» (الشورى ٢٣) doubled, as Hafs: «يُبَشِّرُ فِي حِمًى».
      if (at == '42:23:2' && !v.isUsul) return {201};
      // «يَصُدُّونَ» (الزخرف ٥٧): «ضُمَّ يَصِدُّ فُقْ».
      if (at == '43:57:8' && !v.isUsul) return {203};
      // «تُرۡجَعُونَ» (الزخرف ٨٥) as Hafs, beside Ruways's ya: «وَطِبْ يَرْجِعُونَ».
      if (at == '43:85:12' && !v.isUsul) return {204};
      // «عَسَيۡتُمۡ» (البقرة ٢٤٦، محمد ٢٢) with the fatha, as Hafs: «عَسِيْتُ افْتَحِ
      // اذْ».
      if ((at == '2:246:23' || at == '47:22:1') && !v.isUsul) return {82};
      // «يُسُرٗا» (الذاريات ٣) with the damma: «وَالْعُسْرُ وَالْيُسْرُ أُثْقِلَا».
      if (at == '51:3:1' && !v.isUsul) return {74};
      // «عُسۡرٖ يُسۡرٗا» (الطلاق ٧) with the damma: «وَالْعُسْرُ وَالْيُسْرُ أُثْقِلَا».
      if (at == '65:7:23' && !v.isUsul) return {74};
      // «يُبَدِّلَهُ» (التحريم ٥) doubled: «كُلَّ يُبْدِلَ خِفَّ حُطْ».
      if ((at == '66:5:5' || at == '68:32:3') && !v.isUsul) return {151};
      // «تُؤۡمِنُونَ، تَذَكَّرُونَ» (الحاقة ٤١، ٤٢) with the ta: «وَحُطْ يُؤْمِنُوا يَذَّكَّرُوا».
      if ((at == '69:41:6' || at == '69:42:5') && !v.isUsul) return {220};
      // «وَوَلَدُهُۥٓ» (نوح ٢١) with the fatha: «وَلَدًا لاَ نُوْحَ فَافْتَحْ».
      if (at == '71:21:10' && !v.isUsul) return {156};
      // «قُلۡ إِنَّمَآ» (الجن ٢٠) as Hafs: «وَقُلْ إِنَّمَا أَلَا / وَقَالَ فَتًى».
      if (at == '72:20:0' && !v.isUsul) return {221, 222};
      // «وَٱلرُّجۡزَ» (المدثر ٥) with the damma: «الرِّجْزَ إِذْ حَلاَ / فَضُمَّ».
      if (at == '74:5:0' && !v.isUsul) return {222, 223};
      // «وَنُحَاسٞ» (الرحمن ٣٥) raised, as Hafs: «نُحَاسٌ طَوَى».
      if (at == '55:35:5' && !v.isUsul) return {213};
      // «تَكُونُ» (المجادلة ٧) and «تَكُونَ دُولَةٌۢ» (الحشر ٧): «أَنِّثْ مَعًا يَكُو / نُ دُوْلَةٌ اِذْ رَفْعٌ».
      if (at == '58:7:12' && !v.isUsul) return {216};
      // «خُشُبٞ» (المنافقون ٤) as Hafs: «وَالْعُسْرُ وَالْيُسْرُ أُثْقِلَا … خُشْبُ
      // سُبْلَنَا حِمًا».
      if (at == '63:4:9' && !v.isUsul) return {74, 76};
      // «ٱلنَّشۡأَةَ» (العنكبوت ٢٠، النجم ٤٧، الواقعة ٦٢) as Hafs: «وَنَشْـأَةً حَافِظٌ».
      if (const {'29:20:11', '53:47:2', '56:62:2'}.contains(at) && !v.isUsul) {
        return {177};
      }
      // «لَٰكِنَّ ٱلَّذِينَ» (آل عمران ١٩٨، الزمر ٢٠): «وَشَدِّدْ لَكِنِ الَّذْ مَعًا أَلَا».
      if ((at == '3:198:0' || at == '39:20:0') && !v.isUsul) return {93};
      // «أَمَّنۡ» (الزمر ٩) doubled, as Hafs: «أَمَنْ شَدِّدِ اعْلَمْ فِدْ».
      if (at == '39:9:0' && !v.isUsul) return {197};
      // «ٱصۡطَفَى» (الصافات ١٥٣) with a hamzat al-wasl: «وَصْلُ اصْطَفَى أَصْلُهُ
      // اعْتَلَا».
      if (at == '37:153:0' && !v.isUsul) return {195};
      // «ٱللَّهُ رَبُّكُمۡ وَرَبُّ» (الصافات ١٢٦) raised: «وَاللهُ رَبُّ انْصِبَنْ حَلَا /
      // وَرَبُّ … أُدْ».
      if (const {'37:126:0', '37:126:1', '37:126:2'}.contains(at) &&
          !v.isUsul) {
        return {194, 195};
      }
      // «أَوۡ ءَابَآؤُنَا» (الصافات ١٧، الواقعة ٤٨): «وَاسْكِنَنْ أَوْ أُدْ».
      if ((at == '37:17:0' || at == '56:48:0') && !v.isUsul) return {193};
      // «نَنكُسۡهُ» (يس ٦٨): «نَنْكُسِ افْتَحْ ضُمَّ خَفِّفْ فِدًا».
      if (at == '36:68:2' && !v.isUsul) return {192};
      // «فَلَا تُذۡهِبۡ نَفۡسَكَ» (فاطر ٨): «تَذْهَبْ فَضُمَّ اكْسِرَنْ أَلَا / لَهُ
      // نَفْسُكَ انْصِبْ».
      if (at == '35:8:16' && !v.isUsul) return {187, 188};
      // «مِنسَاتَهُۥ» (سبأ ١٤), its hamza an alif: «وَمِنْسَأْتَهْ حَمَى الْهَمْزَ
      // فَاتِحًا».
      if (at == '34:14:12') return {184};
      // «مُعَٰجِزِينَ» (الحج ٥١، سبأ ٥ و٣٨) with the alif, as Hafs: «وَمُعَاجِزِيْنَ
      // بِالْمَدِّ حُلِّلَا».
      if (const {'22:51:4', '34:5:4', '34:38:4'}.contains(at) && !v.isUsul) {
        return {165};
      }
      // «أُذُن» doubled, as Hafs: «وَالْعُسْرُ وَالْيُسْرُ أُثْقِلَا / وَالاذْنُ».
      if (_udhun.contains(at) && !v.isUsul) return {74, 75};
      // «إِنَّكَ لَأَنتَ يُوسُفُ» (يوسف ٩٠) on the khabar: «وَإِنَّكْ لأَنْتَ أُدْ».
      if (at == '12:90:1') return {24};
      // «لِأَهَبَ» (مريم ١٩) with its hamza: «وَالْهَمْزُ فِي لأَهَبْ أَلاَ».
      if (at == '19:19:5') return {153};
      // «وَرِيًّا» (مريم ٧٤), its quiet hamza made a ya: «وَأَبْدِلَنْ إِذَنْ غَيْرَ
      // أَنْبِئْهُمْ وَنَبِّئْهُمْ فَلَا».
      if (at == '19:74:8') return {28};
      // «فَيَسۡحَتَكُم» (طه ٦١), its ya and ha opened: «وَطُولًا فَيَسْحَتَ ضُمَّ
      // اكْسِرْ».
      if (at == '20:61:9') return {158};
      // «لِتُحۡصِنَكُم» (الأنبياء ٨٠) with the ta, as Hafs: «وَطِبْ نُوْنَ يُحْصِنْ
      // أَنِّثاً أُدْ».
      if (at == '21:80:4' && !v.isUsul) return {162};
      // «يَتَأَلَّ» (النور ٢٢) for «يَأۡتَلِ»: «وَلاَ يَتَأَلَّ اعْلَمْ».
      if (at == '24:22:1') return {170};
      // «أَرۡجِهِ» (الأعراف ١١١، الشعراء ٣٦): Ibn Wardan's kasra short, Ibn
      // Jammaz's with its silah: «وَبِالْقَصْرِ طُفْ وَأَرْ / جِهِ بِنْ وَأَشْبِعْ جُدْ».
      if ((at == '7:111:1' || at == '26:36:1') && !v.isUsul) return {20};
      // «وَيَتَّقِهِ» (النور ٥٢): Ibn Jammaz's silah, Ibn Wardan's sukun:
      // «كَيَتَّقْهِ وَامْدُدْ جُدْ وَسَكِّنْ بِهِ».
      if (at == '24:52:6') return {19};
      // «يَحۡسَبُ» and its like opened, as Hafs: «وَمَيْسَرَةِ افْتَحَاً / كَيَحْسَبُ
      // أُدْ».
      if (_yahsibu.contains(at) && !v.isUsul) return {83};
      // «بُيُوت» with the ba joined, as Hafs: «بُيُوتَ اضْمُمًا».
      if (_buyut.contains(at) && !v.isUsul) return {77};
      // «رَبُّ» (الأنبياء ١١٢) and «وَرَبَـَٔتۡ» (الحج ٥، فصلت ٣٩): «وَبَا رَبِّ
      // ضُمَّ اهْمِزْ مَعًا رَبَأَتْ أَتَى».
      if (const {'21:112:1', '22:5:63', '41:39:11'}.contains(at)) return {164};
      // «مِن تَحۡتِهَآ» (مريم ٢٤): «وَمَنْ تَحْتَهَا اكْسِرِ اخْـ / ـفِضًا يَعْلُ».
      if (at == '19:24:1' || at == '19:24:2') return {154};
      // «وَلَنَجۡزِيَنَّ» (النحل ٩٦) with the nun: «لِيَجْزِيَ نُونٌ اِذْ».
      if (at == '16:96:7') return {143};
      // «وَيُخۡرَجُ» (الإسراء ١٣): «نخْرِجُ انْجَلَا» at the end of the one,
      // «حَوَى الْيَا وَضُمَّ افْتَحْ أَلاَ» at the start of the next.
      if (at == '17:13:6') return {143, 144};
      // «خَطَـًٔا» (الإسراء ٣١): «وَقُلْ خَطَأً أَتَى».
      if (at == '17:31:11') return {145};
      // «ٱللَّهُ ٱلَّذِي» (إبراهيم ٢) in the raf': «وَطِبْ رَفْعَ أَللهِ ابْتِدَاءً».
      if (at == '14:2:0') return {138};
      // «ٱلۡأُكُلِ» (الرعد ٤) and «رُعُبٗا» (الكهف ١٨) with the damma: «أُثْقِلَا / وَالاذْنُ وَسُحْقًا
      // الاُكْلُ إِذْ».
      // «رُحُمٗا» (الكهف ٨١): «شُغْلِ رُحْمًا حَوَى الْعُلَا».
      if (at == '13:4:20' || at == '18:18:21' || at == '18:81:8') {
        return {74, 75};
      }
      // «عُسُرٗا» (الكهف ٧٣): «وَالْعُسْرُ وَالْيُسْرُ أُثْقِلَا».
      // «يُسُرٗا» (الكهف ٨٨) too.
      if (at == '18:73:9' || at == '18:88:12') return {74};
      // «ثَمَرٞ» and «بِثَمَرِهِۦ» (الكهف ٣٤، ٤٢) open: «كَثُمْرِهِ بِضَمَّيْ طُوىً
      // فَتْحَا اتْلُ».
      if (at == '18:34:2' || at == '18:42:1') return {148};
      // «يَرۡجِعُ ٱلۡأَمۡرُ» (هود ١٢٣): «وَيُرْجَعُ كَيْفَ جَا / إِذَا كَانَ لِلأُخْرَى
      // فَسَمِّ» and «وَالامْرُ اتْلُ».
      if (at == '11:123:5') return {63, 64};
      // «يَٰٓأَبَتَ» with its ta open, wherever it comes: «وَيَا أَبَتِ افْتَحْ أُدْ».
      if (!v.isUsul && v.text.contains('أَبَتَ')) return {136};
    }
    // Khalaf's «وَسَلۡ، فَسَلِ، وَسَلُواْ» wherever they come: «وَسَلْ مَعْ فَسَلْ فَشَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'khalaf' &&
        v.description == 'بفتح السين وحذف الهمزة') {
      return {37};
    }
    // Khalaf's «تَحۡسِبَنَّ» (الأنفال ٥٩) with the ta, Abu Ja'far's with the ya
    // as Hafs's: «وَيَحْسَبْ أُدْ وَخَاطَبَ فَاعْتَلَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'khalaf' &&
        at == '8:59:1') {
      return {119};
    }
    // Abu Ja'far's «ٱثۡنَآ عۡشَرَ» (التوبة ٣٦)، «أَحَدَ عۡشَرَ» (يوسف ٤)، «تِسۡعَةَ عۡشَرَ»
    // (المدثر ٣٠): «وَعَيْنَ عَشَرْ أَلَا» at the end
    // of the one, «فَسَكِّنْ جَمِيْعًا وَامْدُدْ اثْنَا» at the start of the next.
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        const {'9:36:5', '12:4:8', '74:30:2'}.contains(at)) {
      return {122, 123};
    }
    // Abu Ja'far's «يُقَتِّلُونَ» (الأعراف ١٤١) with the shadda, as Hafs:
    // «أَلَا افْـتَحَنْ يَقْتُلُوا مَعْ يَتْبَعُ اشْدُدْ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '7:141:8') {
      return {115};
    }
    // Abu Ja'far's «يَبۡطُشُونَ» (الأعراف ١٩٥، القصص ١٩، الدخان ١٦): «ضُمَّ طَا
    // يَبْطِشُ اسْجِلَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        const {'7:195:7', '28:19:4', '44:16:1'}.contains(at)) {
      return {117};
    }
    // Abu Ja'far's «يَتَّبِعُوكُمۡ» (الأعراف ١٩٣) doubled, as Hafs's: «مَعْ
    // يَتْبَعُ اشْدُدْ»; his mim's silah keeps its own verse.
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        !v.isUsul &&
        at == '7:193:5') {
      return {115};
    }
    // Abu Ja'far's «أَنَا۠» before a broken hamza short, as Hafs's (الأعراف
    // ١٨٨، الشعراء ١١٥، الأحقاف ٩): «وَقَصْرَ أَنَا مَعْ كَسْرٍ اعْلَمْ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        const {'7:188:22', '26:115:1', '46:9:20'}.contains(at)) {
      return {118};
    }
    // Abu Ja'far's «وَسۡـَٔلۡهُمۡ» (الأعراف ١٦٣) with its hamza: the naql is
    // Khalaf's alone, «وَسَلْ مَعْ فَسَلْ فَشَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '7:163:0') {
      return {37};
    }
    // Abu Ja'far's «خَطِيٓـَٰٔتُكُمۡ» (الأعراف ١٦١): «تُغْفَرْ خَطِيْئَاتُ حُمِّلَا
    // / كَوَرْشٍ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        at == '7:161:17') {
      return {116, 117};
    }
    // «وَٰعَدۡنَا» (البقرة ٥١، الأعراف ١٤٢، طه ٨٠): Abu Ja'far's without the
    // alif, «وَعَدْنَا اتْلُ»; Qalun's and Ibn Kathir's with it, «وَعَدْنَا
    // جَمِيعًا دُونَ مَا أَلِفٍ حَلَا».
    if (const {'2:51:1', '7:142:0', '20:80:6'}.contains(at)) {
      if (poem == Poem.durrah && qiraaOf(v.riwayaId).id == 'abu_jafar') {
        return {66};
      }
      if (poem == Poem.shatibiyya &&
          const {'qalun', 'bazzi', 'qunbul'}.contains(v.riwayaId)) {
        return {453};
      }
    }
    // Abu Ja'far's «بَصۡطَةٗ» (الأعراف ٦٩): «وَيَبْصُطْ بَصْطَةَ الْخَلْقِ يُعْتَلَا».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        v.surah == 7 &&
        v.ayah == 69 &&
        v.word == 21) {
      return {81};
    }
    // Abu Ja'far's «كَهَيَّةِ» (آل عمران ٤٩، المائدة ١١٠): «وَجُزْءًا ادْغِمْ كَهَيْئَهْ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        const {
          '3:49:15',
          '5:110:30',
        }.contains('${v.surah}:${v.ayah}:${v.word}')) {
      return {33};
    }
    // Abu Ja'far's «وَمَحْيَآيْ» (الأنعام ١٦٢): «وَغَيْرَ مَحْيَايَ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        v.surah == 6 &&
        v.ayah == 162 &&
        v.word == 4) {
      return {53};
    }
    if (poem == Poem.shatibiyya && _hisad(v)) return {675, 676};
    // «أُكْلُهُۥ» (الأنعام ١٤١) of Nafi' and Ibn Kathir: «ضَمَّ الاِسْكَانَ صِفْ وَحَيْثُمَا
    // أُكْلُهَا ذِكْرًا وَفي الْغَيْرِ ذُو حُلَا».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'warsh', 'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        v.surah == 6 &&
        v.ayah == 141 &&
        v.word == 10) {
      return {524};
    }
    // Ibn Kathir's «فَمُسۡتَقِرّٞ» (الأنعام ٩٨): «وَاكْسِرْ بِمُسْتَقَرْ رِ الْقَافَ حَقًّا».
    if (poem == Poem.shatibiyya &&
        qiraaOf(v.riwayaId).id == 'ibn_kathir' &&
        v.surah == 6 &&
        v.ayah == 98 &&
        v.word == 6) {
      return {656};
    }
    // Abu Ja'far's «يُنَجِّيكُم» (الأنعام ٦٣، ٦٤): «يُنْجِي فَثَقِّلَا بِثَانٍ أَتَى
    // وَالْخِفَّ فِي الْكُلِّ حُزْ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        v.surah == 6 &&
        (v.ayah == 63 || v.ayah == 64) &&
        v.word == 2) {
      return {106, 107};
    }
    // Abu Ja'far's «فَإِنَّهُۥ» (الأنعام ٥٤): «وَحُزْ فَتْحَ إِنَّهْ مَعْ فَإِنَّهْ».
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        v.surah == 6 &&
        v.ayah == 54 &&
        v.word == 24) {
      return {106};
    }
    // «إِنَّهُۥ مَنۡ عَمِلَ» and «فَإِنَّهُۥ» (الأنعام ٥٤): «وَإِنَّ بِفَتْحٍ عَمَّ
    // نَصْرًا وَبَعْدُ كَمْ نَمَا».
    if (poem == Poem.shatibiyya &&
        v.surah == 6 &&
        v.ayah == 54 &&
        (v.word == 13 || v.word == 24)) {
      return {641};
    }
    // «وَيَحْذِفُ مُسْتَهْزُونَ وَالْبَابَ»: his bab, before what the book quotes.
    final hamzaBab = _abuJafarHamzaBab(poem, v);
    if (hamzaBab.isNotEmpty) return hamzaBab;
    // The ya of the speaker before a hamza with a damma: «وَعَشْرٌ يَلِيهَا الْهَمْزُ
    // بِالضَّمِّ مُشْكِلًا فَعَنْ نَافِعٍ فَافْتَحْ»; Abu Ja'far: «كَقَالُونَ أُدْ».
    if (v.rule == 'ya_idafa' &&
        const {
          '3:36:17',
          '5:29:0',
          '5:115:9',
          '6:14:13',
          '7:156:12',
          '11:54:8',
          '12:59:11',
          '28:27:1',
          '39:11:1',
        }.contains('${v.surah}:${v.ayah}:${v.word}')) {
      if (poem == Poem.shatibiyya && v.riwayaId == 'qalun') return {405, 406};
      if (poem == Poem.durrah && qiraaOf(v.riwayaId).id == 'abu_jafar') {
        return {52};
      }
    }
    // Ibn Kathir's «يُنزِلَ» and its like: «وَيُنْزِلُ خَفِّفْهُ وَتُنْزِلُ مِثْلُهُ
    // وَنُنْزِلُ حَقٌّ»; of الأنعام with its own, and «يُنْزِلُ الْغَيْثَ».
    if (poem == Poem.shatibiyya &&
        const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
        v.description == 'بإسكان النون وتخفيف الزاي' &&
        RegExp('^[وفل]*[يتن]نزل').hasMatch(_letters(v.text))) {
      if (v.surah == 6 && v.ayah == 37) return {468, 469};
      if (v.surah == 31 && v.ayah == 34 || v.surah == 42 && v.ayah == 28) {
        return {470};
      }
      return {468};
    }
    // «طَٰٓئِرَۢا»: «وَفِي طَائِرًا طَيْرًا بِهَا وَعُقُودِهَا خُصُوصًا»; and Abu
    // Ja'far's, with «ٱلطَّٰٓئِرِ»: «قُلِ الطَّائِرِ اتْلُ طَائِرًا حُزْ».
    if (poem == Poem.shatibiyya &&
        const {'qalun', 'warsh'}.contains(v.riwayaId) &&
        const {'3:49:20', '5:110:36'}.contains(at)) {
      return {558};
    }
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        const {'3:49:16', '3:49:20', '5:110:31', '5:110:36'}.contains(at)) {
      return {87};
    }
    if (_nafiUdhn(poem, v)) return {617};
    if (_ibnKathirQuran(poem, v, hafs)) return {502};
    if (_abuJafarMinAjli(poem, v)) return {100};
    if (_abuJafarMuminan(poem, v)) return {96};
    if (_abuJafarAmani(poem, v, hafs)) return {66};
    if (_abuJafarSakinHa(poem, v)) return {18};
    if (_haAntum(poem, v)) return {559};
    if (_firstSakinOfSilah(poem, v)) return {495};
    if (_abuJafarFirstSakin(poem, v)) return {72, 73};
    if (_abuJafarYuzlamun(poem, v, hafs)) return {96};
    if (_abuJafarYadurrukum(poem, v)) return {88};
    if (_abuJafarKaayin(poem, v)) return {34};
    if (_abuJafarYahzun(poem, v, hafs)) return {91};
    if (poem == Poem.durrah &&
        qiraaOf(v.riwayaId).id == 'abu_jafar' &&
        v.rule == 'ha_antum') {
      return {34};
    }
    if (poem == Poem.durrah &&
        v.riwayaId == 'ibn_wardan' &&
        v.rule == 'naql' &&
        _letters(v.text) == 'مل') {
      return {36};
    }
    if (poem == Poem.shatibiyya) {
      if (v.surah == 4 && v.ayah == 24 && v.word == 10) return {597};
      if (v.surah == 3 && v.ayah == 146 && v.word == 3) return {571};
      if (_qalunTawrat(v)) return {546};
      if (const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
          v.rule == 'ha_antum' &&
          v.surah == 3 &&
          v.ayah == 73) {
        return {188};
      }
      if (const {'bazzi', 'qunbul'}.contains(v.riwayaId) &&
          _ibnAmirQuttilu(v)) {
        return {576, 577};
      }
    }
    return const {};
  }

  Set<int> _ruleVerses(Poem poem, Variant v, [String hafs = '']) {
    final reviewed = _reviewedVerses(poem, v, hafs);
    if (reviewed.isNotEmpty) return reviewed;
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
    // «وَأُحِلَّ» (النساء ٢٤): «وَضَمٌّ وَكَسْرٌ فِي أَحَلَّ صِحَابُهُ وُجُوهٌ».
    if (poem == Poem.shatibiyya &&
        v.surah == 4 &&
        v.ayah == 24 &&
        v.word == 10) {
      return {597};
    }
    // «وَلَا يُظۡلَمُونَ» (النساء ٧٧): «وَلَا يُظْلَمُوا أُدْ يَا».
    if (_abuJafarYuzlamun(poem, v, hafs)) return {96};
    if (_ibnKathirQuran(poem, v, hafs)) return {502};
    if (_abuJafarMinAjli(poem, v)) return {100};
    if (_firstSakinOfSilah(poem, v)) return {495};
    if (_abuJafarFirstSakin(poem, v)) return {72, 73};
    if (_abuJafarAmani(poem, v, hafs)) return {66};
    if (_abuJafarSakinHa(poem, v)) return {18};
    if (_haAntum(poem, v)) return {559};
    if (_abuJafarMuminan(poem, v)) return {96};
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
    final reviewed = _reviewedVerses(poem, v, hafs);
    if (reviewed.isNotEmpty) {
      return verses(poem).firstWhere((b) => reviewed.contains(b.n)).chapter;
    }
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
    if (_ibnKathirQuran(poem, v, hafs)) {
      return verses(poem).firstWhere((b) => b.n == 502).chapter;
    }
    if (_abuJafarMinAjli(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 100).chapter;
    }
    if (_firstSakinOfSilah(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 495).chapter;
    }
    if (_abuJafarFirstSakin(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 72).chapter;
    }
    if (_abuJafarAmani(poem, v, hafs)) {
      return verses(poem).firstWhere((b) => b.n == 66).chapter;
    }
    if (_abuJafarSakinHa(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 18).chapter;
    }
    if (_haAntum(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 559).chapter;
    }
    if (_abuJafarMuminan(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 96).chapter;
    }
    if (_abuJafarYadurrukum(poem, v)) {
      return verses(poem).firstWhere((b) => b.n == 88).chapter;
    }
    if (_abuJafarYuzlamun(poem, v, hafs)) {
      return verses(poem).firstWhere((b) => b.n == 96).chapter;
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

/// «يَحۡسِبُ» and its like, the future (أَيَحۡسِبُونَ، تَحۡسِبُهُمۡ): Qalun and Ibn
/// Kathir break its sin, Abu Ja'far opens it. Not those told by a bayt of
/// their own (وَلَا يَحۡسَبَنَّ in آل عمران، الأنفال ٥٩، النور ٥٧).
const _yahsibu = {
  '2:273:11',
  '3:78:6',
  '7:30:13',
  '14:42:1',
  '14:47:1',
  '18:18:0',
  '18:104:7',
  '23:55:0',
  '24:11:7',
  '24:15:10',
  '24:39:5',
  '25:44:1',
  '27:88:2',
  '33:20:0',
  '43:37:4',
  '43:80:1',
  '58:18:9',
  '59:14:14',
  '63:4:11',
  '75:3:0',
  '75:36:0',
  '90:5:0',
  '90:7:0',
  '104:3:0',
};

/// «بُيُوت» and its like (ٱلۡبُيُوتَ، بُيُوتِكُمۡ، بُيُوتِهِنَّ), every place: Qalun
/// and Ibn Kathir break its ba, Abu Ja'far joins it.
const _buyut = {
  '2:189:12',
  '2:189:20',
  '3:49:36',
  '3:154:54',
  '4:15:13',
  '7:74:16',
  '10:87:8',
  '10:87:10',
  '15:82:4',
  '16:68:8',
  '16:80:4',
  '16:80:11',
  '24:27:5',
  '24:27:7',
  '24:29:5',
  '24:36:1',
  '24:61:18',
  '24:61:20',
  '24:61:23',
  '24:61:26',
  '24:61:29',
  '24:61:32',
  '24:61:35',
  '24:61:38',
  '24:61:41',
  '24:61:59',
  '26:149:3',
  '27:52:1',
  '29:41:13',
  '33:13:16',
  '33:33:2',
  '33:34:4',
  '33:53:5',
  '43:33:10',
  '43:34:0',
  '59:2:33',
  '65:1:15',
};

/// «تَحۡسَبَنَّ، يَحۡسَبَنَّ» with a bayt of their own for Qalun and Ibn Kathir
/// (ghayb or khitab, the ba of يَحۡسَبُنَّهُمۡ), told beside the sin's.
const _yahsibannaShatibiyya = <String, Set<int>>{
  '3:169:1': {577},
  '3:178:1': {579},
  '3:180:1': {579},
  '3:188:1': {583, 584},
  '3:188:13': {583, 584},
  '8:59:1': {720},
  '24:57:1': {720},
};

/// The same for Abu Ja'far, in the Durrah.
const _yahsibannaDurrah = <String, Set<int>>{
  '3:169:1': {},
  '3:178:1': {},
  '3:180:1': {},
  '3:188:1': {90},
  '3:188:13': {90},
  '8:59:1': {119},
  '24:57:1': {171},
};

/// Khalaf al-'Ashir's «فَتَثَبَّتُواْ» (النساء ٩٤ مرتين، الحجرات ٦), the
/// Durrah silent: the Shatibiyya's bayts of Hamza's and al-Kisa'i's (the
/// user, 2026-11-14).
bool _khalafFatathabbatu(Variant v) =>
    const {'ishaq', 'idris'}.contains(v.riwayaId) &&
    const {
      '4:94:8',
      '4:94:32',
      '49:6:7',
    }.contains('${v.surah}:${v.ayah}:${v.word}');
