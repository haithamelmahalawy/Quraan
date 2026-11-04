import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/quran.dart';
import 'arabic.dart';
import 'kharouf.dart';
import 'book_readings.dart';

/// Loads the per-riwaya difference files from `assets/data/qiraat/` and
/// answers "which selected riwayat read this Hafs word differently?".
///
/// File format (written by `tool/build_data.dart` from the KFGQPC texts and
/// `tool/build_quranpedia.dart` from the Quranpedia qiraat, or by hand):
/// ```json
/// {"riwaya": "warsh",
///  "variants": [[surah, ayah, word, count, "text", "f|h|u", "description"], ...]}
/// ```
/// `word` is the 0-based index of the Hafs word in the ayah, `count` the
/// number of Hafs words the reading replaces; the description is optional.
class VariantRepository {
  VariantRepository(this.available, [AssetBundle? bundle])
    : _bundle = bundle ?? rootBundle;

  static const _dir = 'assets/data/qiraat/';

  /// Riwaya ids that have a data file.
  final Set<String> available;
  final AssetBundle _bundle;
  final _loaded = <String, Map<int, List<Variant>>>{};
  final _loading = <String, Future<void>>{};
  final _sourceTexts = <String, Map<int, String>>{};

  /// Whether [riwayaId] can be selected.
  bool isAvailable(String riwayaId) => available.contains(riwayaId);

  static Future<VariantRepository> discover([AssetBundle? bundle]) async {
    final manifest = await AssetManifest.loadFromAssetBundle(
      bundle ?? rootBundle,
    );
    final ids = manifest
        .listAssets()
        .where((a) => a.startsWith(_dir) && a.endsWith('.json'))
        .map((a) => a.substring(_dir.length, a.length - '.json'.length))
        .toSet();
    return VariantRepository(ids, bundle);
  }

  bool isLoaded(String riwayaId) => _loaded.containsKey(riwayaId);

  Future<void> ensureLoaded(Iterable<String> riwayaIds) => Future.wait([
    for (final id in riwayaIds)
      if (available.contains(id) && !_loaded.containsKey(id))
        _loading.putIfAbsent(id, () => _load(id)),
  ]);

  Future<void> _load(String id) async {
    final raw = await _bundle.loadString('$_dir$id.json');
    if (id == 'warsh') {
      // A missing asset is allowed in isolated data fixtures. Production ships
      // the complete source; malformed text data must fail instead of hiding it.
      final source = await _bundle
          .loadString('assets/data/reading_texts/$id.json')
          .then<String?>((s) => s, onError: (_) => null);
      if (source != null) {
        _sourceTexts[id] = await compute(_indexSourceText, source);
      }
    }
    final book = await (_book ??= _bundle
        .loadString('assets/data/kharouf.json')
        .then<String?>((s) => s, onError: (_) => null));
    final quran = await (_quran ??= _bundle
        .loadString('assets/data/quran.json')
        .then<String?>((s) => s, onError: (_) => null));
    _loaded[id] = await compute(_index, (id, raw, book, quran));
  }

  /// The certified source (assets/data/kharouf.json), read once.
  Future<String?>? _book;

  /// The Hafs text (assets/data/quran.json), read once: the word after each
  /// reading, which the tanween at its end is written for.
  Future<String?>? _quran;

  /// Complete Quran text, independent of annotations. Empty means an actual
  /// source omission/joined continuation; null means no complete source loaded.
  String? sourceTextAt(String? riwaya, int surah, int ayah, int word) =>
      _sourceTexts[riwaya]?[key(surah, ayah, word)];

  /// Variants of [riwayaIds] that start at, or cover, the given Hafs word.
  Iterable<Variant> at(
    Iterable<String> riwayaIds,
    int surah,
    int ayah,
    int word,
  ) sync* {
    final k = key(surah, ayah, word);
    for (final id in riwayaIds) {
      final list = _loaded[id]?[k];
      if (list != null) yield* list;
    }
  }

  /// Every reading of a loaded [riwayaId], each once, in mushaf order.
  List<Variant> allOf(String riwayaId) {
    final list = _loaded[riwayaId];
    if (list == null) return const [];
    final keys = list.keys.toList()..sort();
    return {for (final k in keys) ...list[k]!}.toList();
  }

  static int key(int surah, int ayah, int word) =>
      surah * 1000000 + ayah * 1000 + word;
}

/// The signs of stopping over a word (ۖ ۗ ۘ ۙ ۚ ۛ), not the small seen.
final _stopSigns = RegExp('[ۖ-ۛ]');

Map<int, String> _indexSourceText(String raw) {
  final json = jsonDecode(raw) as Map;
  final words = [
    for (final a in json['ayahs'] as List)
      for (final (w, text) in (a[2] as List).indexed)
        (surah: a[0] as int, ayah: a[1] as int, word: w, text: text as String),
  ];
  final index = <int, String>{};
  String? followingWord;
  int? followingSurah;
  for (final w in words.reversed) {
    index[VariantRepository.key(w.surah, w.ayah, w.word)] = madinahScript(
      w.text,
      followingWord: followingSurah == w.surah ? followingWord : null,
    );
    if (w.text.isNotEmpty) {
      followingWord = w.text;
      followingSurah = w.surah;
    }
  }
  return index;
}

/// Indexes a riwaya file by every Hafs word each variant covers, with
/// what the certified source says of the riwaya ([book]): its readings
/// marked certified, and those it states but the file lacks added.
Map<int, List<Variant>> _index((String, String, String?, String?) input) {
  final (id, raw, book, quran) = input;
  final json = jsonDecode(raw) as Map<String, dynamic>;
  // The Hafs words of each ayah (surah * 1000 + ayah).
  final hafs = <int, List<String>>{
    if (quran != null)
      for (final a in (jsonDecode(quran) as Map)['ayahs'] as List)
        (a[0] as int) * 1000 + (a[1] as int): (a[4] as String).split(' '),
  };
  // The Hafs word after [count] words from [word]; at the end of a surah the
  // basmala, which the mushaf joins it to (مُّؤۡصَدَةُۢ); null without the text.
  String? after(int surah, int ayah, int word, int count) {
    final words = hafs[surah * 1000 + ayah];
    if (words == null) return null;
    if (word + count < words.length) return words[word + count];
    return hafs[surah * 1000 + ayah + 1]?.first ?? 'بِسۡمِ';
  }

  // The stop signs of the Hafs page on a reading's words, whatever its
  // source wrote: صلى، قلى، م، لا، ج and the paired dots, on each word.
  String hafsStops(String text, int surah, int ayah, int word, int count) {
    final own = text.replaceAll(_stopSigns, '');
    final words = hafs[surah * 1000 + ayah];
    if (words == null || own.isEmpty) return own;
    String signs(int w) => w < words.length
        ? _stopSigns.allMatches(words[w]).map((m) => m[0]).join()
        : '';
    final parts = own.split(' ');
    if (parts.length == count) {
      return [for (final (i, p) in parts.indexed) '$p${signs(word + i)}']
          .join(' ');
    }
    return '$own${signs(word + count - 1)}';
  }

  final index = <int, List<Variant>>{};
  // Ya'qub's riwayat (Ruways, Rawh) only: their reviewed rules below.
  final yaqub = id == 'ruways' || id == 'rawh';
  for (final v in json['variants'] as List) {
    // A few readings of the source give their description as the text
    // (بتفخيم الراء والسكت على الساكن قبل الهمزة): not to be drawn as the
    // words of the page.
    if (_isDescription(v[4] as String, voweled: yaqub) &&
        (v.length < 7 || v[6] == '')) {
      v as List;
      final description = v[4] as String;
      v[4] = '';
      v.length < 7 ? v.addAll([description]) : v[6] = description;
    }
    // The length of the separated and connected madd is known of each
    // riwaya: not told, nor coloured, at each word (فاذكروني «بالقصر»).
    final rule = v.length > 7 ? v[7] as String : '';
    if (yaqub && v.length > 6 && (rule.isEmpty || rule.startsWith('madd'))) {
      final description = v[6] as String;
      final kept = _withoutMadd(description);
      if (kept.isEmpty && description.isNotEmpty) continue;
      v[6] = kept;
    }
    final variant = Variant(
      riwayaId: id,
      surah: v[0] as int,
      ayah: v[1] as int,
      word: v[2] as int,
      count: v[3] as int,
      // Read in the script of the Madinah page around it, the tanween as
      // it is written before the next word.
      text: tanweenBefore(
        madinahScript(
          hafsStops(
            v[4] as String,
            v[0] as int,
            v[1] as int,
            v[2] as int,
            v[3] as int,
          ),
        ),
        after(v[0] as int, v[1] as int, v[2] as int, v[3] as int),
      ),
      kind: VariantKind.fromCode(v[5] as String),
      description: v.length > 6 ? v[6] as String : '',
      rule: v.length > 7 ? v[7] as String : '',
      bookWujuh: v.length > 8 ? (v[8] as Map)['wujuh'] as String? ?? '' : '',
      stopOnly: v.length > 8 && (v[8] as Map)['stopOnly'] == true,
      stopText: v.length > 8
          ? madinahScript((v[8] as Map)['stopText'] as String? ?? '')
          : '',
      marginText: v.length > 8
          ? tanweenBefore(
              madinahScript((v[8] as Map)['marginText'] as String? ?? ''),
              after(v[0] as int, v[1] as int, v[2] as int, v[3] as int),
            )
          : '',
      ownWays: v.length > 8 && (v[8] as Map)['ownWays'] == true,
      omission: v.length > 8 && (v[8] as Map)['omission'] == true,
      hamesh: v.length > 8 && (v[8] as Map)['hamesh'] == true,
      usulText: v.length > 8 ? (v[8] as Map)['context'] as String? ?? '' : '',
      usulWays: v.length > 8
          ? ((v[8] as Map)['ways'] as List? ?? const []).cast<String>()
          : const [],
    );
    // Idgham kabir merges the word into the next one (ٱلۡكِتَٰبَ بِّٱلۡحَقِّ):
    // both are coloured, the note stays with the first.
    final kabir =
        yaqub &&
        variant.count == 1 &&
        (variant.rule == 'idgham_kabir' ||
            RegExp('الإدغام فيما بعدها|الإدغام الكبير|إدغام كبير')
                .hasMatch(variant.description));
    for (
      var w = variant.word;
      w < variant.word + variant.count + (kabir ? 1 : 0);
      w++
    ) {
      index
          .putIfAbsent(
            VariantRepository.key(variant.surah, variant.ayah, w),
            () => [],
          )
          .add(variant);
    }
  }
  // Independently reviewed source files replace their old annotations. Mixing
  // in the legacy book here would restore removed rules and wrong attributions.
  if (book != null &&
      json['reviewedUsul'] != true &&
      json['reviewedFarsh'] != true) {
    _certify(id, index, book);
  }
  return index;
}

void _certify(String id, Map<int, List<Variant>> index, String book) {
  final json = jsonDecode(book) as Map<String, dynamic>;
  // Farsh the book says this riwaya reads as Hafs: the file's farsh
  // readings there are not shown (the book is the certified source). Not
  // for Ibn 'Amir: his files are reviewed word by word, and the book's one
  // comparison of a word (the ayn of «وَعُيُونٍ») would hide another of its
  // readings (the tanween before «ٱدۡخُلُوهَا»).
  for (final e
      in const {'hisham', 'ibn_dhakwan'}.contains(id)
          ? const []
          : json['entries'] as List) {
    if (e[4] != 'farsh') continue;
    final readings = (e[5] as List).cast<List>();
    bool reads(List g) =>
        (g[1] as List).contains(id) || (g[2] as List).contains(id);
    final asHafs = readings.any(
      (g) => bookReadingAsHafs(g, readings) && (g[1] as List).contains(id),
    );
    final other = readings.any(
      (g) => !bookReadingAsHafs(g, readings) && reads(g),
    );
    if (!asHafs || other) continue;
    for (var w = e[2] as int; w < (e[2] as int) + (e[3] as int); w++) {
      index[VariantRepository.key(e[0] as int, e[1] as int, w)]?.removeWhere(
        (v) =>
            v.kind == VariantKind.farsh &&
            v.rule.isEmpty &&
            // Warsh's idgham in the word (لَتَّخَذتَّ): the book tells it
            // apart from the word's farsh, which it reads as Hafs.
            !(id == 'warsh' && v.description.startsWith('بإدغام')) &&
            // Nor its tanween in wasl, apart from the word (وَعُيُونٍ).
            !(id == 'warsh' && v.description == 'بالضم في الوصل'),
      );
    }
  }
  final places = (json['riwayat'] as Map)[id] as List?;
  if (places == null) return;
  for (final p in places) {
    final (surah, ayah, word, count) = (
      p[0] as int,
      p[1] as int,
      p[2] as int,
      p[3] as int,
    );
    final how = withoutPageReference(p[5] as String);
    final wujuh = withoutPageReference(p.length > 7 ? p[7] as String : '');
    // A note without written text or an explanation cannot establish a lexical
    // omission. E.g. a margin reminder of Warsh's badal on رؤوف at 24:20.
    if ((p[4] as String).isEmpty && how.isEmpty && wujuh.isEmpty) continue;
    // بِشَرَرٖ (المرسلات 32): the book's note on its ra is told in the usul.
    if (id == 'warsh' && surah == 77 && ayah == 32) continue;
    // لِأَهَبَ (مريم 19): the book's ya is the ibdal told in the usul.
    if (id == 'warsh' && surah == 19 && ayah == 19 && word == 5) continue;
    // تَشَآءُۖ أَنتَ (الأعراف 155): the pair is told once, on أَنتَ.
    if (id == 'warsh' && surah == 7 && ayah == 155 && word == 32) continue;
    // مَنۡۜ رَاقٖ (القيامة 27): told in ترك السكت alone.
    if (id == 'warsh' && surah == 75 && ayah == 27 && word == 1) continue;
    final keys = [
      for (var w = word; w < word + count; w++)
        VariantRepository.key(surah, ayah, w),
    ];
    var found = false;
    for (final k in keys) {
      final list = index[k];
      if (list == null) continue;
      for (final v in [...list]) {
        if (v.rule.isNotEmpty) {
          if (v.rule == 'ya_zaida' && _matchesUsul(v, how)) found = true;
          // Written naql examples remain usul; a duplicate lexical row
          // would colour the whole word and hide its separate badal.
          if (v.rule == 'naql' &&
              // Its own word, or within the words the book quotes
              // (تُبۡتُ ٱلۡـَٰٔنَ «بالنقل»).
              v.word >= word &&
              v.word + v.count <= word + count &&
              RegExp(r'^ب?النقل(?: في الحالين)?$')
                  .hasMatch(how.replaceAll(RegExp('[ً-ٰٟ]'), '').trim())) {
            found = true;
          }
          // Warsh's أَرَءَيۡتَ, its two faces told in the usul: the book quotes it
          // (أفرأيت) in its farsh.
          if (v.rule == 'tasheel_word' &&
              v.description.contains('ألفًا خالصة مع المد المشبع للساكنين')) {
            found = true;
          }
          // ٱلسَّمَآءَ أَن (الحج 65), its two faces told in the usul: the book
          // quotes the two words joined.
          if (id == 'warsh' &&
              surah == 22 &&
              ayah == 65 &&
              v.rule == 'tasheel_pair') {
            found = true;
          }
          // Do not duplicate an existing rule as a lexical book variant.
          if ((p[4] as String).isEmpty && _matchesUsul(v, how)) found = true;
          // Nafi''s «ٱلنَّبِيٓءُ» and its bab, told in the usul; the book's
          // «مع المد المتصل» with it is the madd of the added hamza.
          // And «وَٱلصَّٰبِـِٔينَ» without it.
          if (v.rule == 'hamza_zaida' || v.rule == 'hamza_hadhf') found = true;
          // Nor the riwaya's own hamza turned to a letter, which the book
          // writes out (يُوَدِّهِ، تَامَنْهُ): told in the usul.
          if (const {
                'ibdal_single',
                'ibdal_waw',
                'ibdal_ya',
              }.contains(v.rule) &&
              // One word, though the book quotes the next with it
              // (نُوتِهِ مِنۡهَا).
              (v.count == count || !(p[4] as String).contains(' ')) &&
              _bare(v.text) == _bare(p[4] as String)) {
            found = true;
          }
          // Or its word among the words the book quotes (إلا أن تاتيهم).
          final quoted = (p[4] as String).trim().split(RegExp(r'\s+'));
          if (const {
                'ibdal_single',
                'ibdal_waw',
                'ibdal_ya',
              }.contains(v.rule) &&
              v.count == 1 &&
              quoted.length == count &&
              v.word - word >= 0 &&
              v.word - word < count &&
              _bare(v.text) == _bare(quoted[v.word - word])) {
            found = true;
          }
          continue;
        }
        found = true;
        if (v.certified) continue;
        // The same reading is listed at every word it covers.
        final certified = v.withCertified(how, p[6] == 'farsh', wujuh);
        for (var w = v.word; w < v.word + v.count; w++) {
          final at = index[VariantRepository.key(v.surah, v.ayah, w)]!;
          final i = at.indexOf(v);
          if (i >= 0) at[i] = certified;
        }
      }
    }
    // The book often anchors a two-hamza note at the first word (جاء,
    // السماء), whereas the generated rule belongs to the second hamza.
    // The same convention occurs before ءآمنتم. Do not backfill that
    // general-rule explanation as an independent lexical variant.
    if (!found && (p[4] as String).isEmpty) {
      final next = index[VariantRepository.key(surah, ayah, word + 1)];
      found = next?.any((v) => v.isUsul && _matchesUsul(v, how)) ?? false;
    }
    // The damma that parts two quiescents, which the book tells as farsh
    // (قلُ ادعوا، بضم التنوين وصلاً): told in the usul «التقاء الساكنين».
    if (!found && (how.isEmpty || how.contains('ضم'))) {
      found = keys.any(
        (k) => index[k]?.any((v) => v.rule == 'first_sakin') ?? false,
      );
    }
    // A farsh reading the book states and the riwaya file lacks. Ibn 'Amir's
    // files have its farsh written in, reviewed: the book's notes (stopping
    // on the hamza, ishmam, two hamzas) are their usul, not farsh.
    if (!found &&
        p[6] == 'farsh' &&
        !const {'hisham', 'ibn_dhakwan'}.contains(id)) {
      final variant = Variant(
        riwayaId: id,
        surah: surah,
        ayah: ayah,
        word: word,
        count: count,
        text: madinahScript(p[4] as String),
        kind: VariantKind.farsh,
        description: how,
        rule: 'kharouf',
        certified: true,
        bookHow: how,
        bookFarsh: true,
        bookWujuh: wujuh,
      );
      for (final k in keys) {
        (index[k] ??= []).add(variant);
      }
    }
  }
}

/// The letters of [text], without vowels and marks.
String _bare(String text) =>
    text.replaceAll(RegExp('[ً-ٰۖ-ۭـ]'), '').replaceAll('ٱ', 'ا');

/// Whether a generated rule already covers the book's general-rule note.
bool _matchesUsul(Variant v, String how) {
  // The ishmam the riwaya's rule tells (سِيٓءَ «بإشمام كسرة السين الضم»).
  if (v.rule == 'ishmam' && how.contains('إشمام')) return true;
  if (v.isLinHamz) {
    final plain = how.replaceAll(RegExp('[ً-ٰٟ]'), '').trim();
    // The book also records madd faces in its farsh section. They are
    // already covered by this word's lin rule, not a lexical difference.
    if (RegExp(
      r'^(?:وله في «[^»]+» )?ب?(?:التوسط|توسط)'
      r'(?: اللين ومده| والمد| والطول)'
      r'(?: على (?:حرف )?اللين(?: الواقع بعده? همزة)?| في حرف اللين| في الحالين| وصلا ووقفا)?$',
    ).hasMatch(plain)) {
      return true;
    }
    if (v.rule == 'lin_hamz_sawat' &&
        plain.startsWith('وله مع اللين قبله أربعة أوجه') &&
        plain.contains('البدل')) {
      return true;
    }
  }
  // Warsh's: the book may only quote the word with its ya (نكيري).
  if (v.rule == 'ya_zaida' &&
      (RegExp('وصل|وقف|الحالين|الياء').hasMatch(how) ||
          how.isEmpty && v.riwayaId == 'warsh')) {
    return true;
  }
  if (v.isBadal && how.contains('البدل')) return true;
  if ((v.rule == 'naql' || v.rule == 'naql_source') && how.contains('نقل')) {
    return true;
  }
  if (const {'ibdal_waw', 'ibdal_ya', 'ibdal_single'}.contains(v.rule) &&
      RegExp(v.riwayaId == 'warsh' ? 'إبدال|ابدال|أبدل' : 'إبدال|ابدال')
          .hasMatch(how)) {
    return true;
  }
  if (const {
        'tasheel_pair',
        'tasheel_word',
        'ha_antum',
        'hamza_wasl',
      }.contains(v.rule) &&
      RegExp(
        v.riwayaId == 'warsh'
            ? 'تسهيل|سهلها|إبدالها|^ف?سهل'
            : 'تسهيل|سهلها|إبدالها',
      ).hasMatch(how)) {
    return true;
  }
  if (v.isImala && RegExp('تقليل|إمالة').hasMatch(how)) return true;
  // Warsh's lam made heavy (ٱلصَّلَوٰةَ) or ra made light: told by its rule, not
  // again as farsh («بتفخيم اللام حيث وقعت»). «ولا ترقق راؤه» still tells.
  if (v.isTarqiqOrTaghliz &&
      RegExp('تفخيم اللام|فخم اللام|تغليظ|غلظ|ترقيق الراء|رقق').hasMatch(how) &&
      !how.contains('لا ترقق')) {
    return true;
  }
  return false;
}

/// Text without a vowel that tells of a reading rather than writes it.
/// [description] without what it says of the length of a madd (بالقصر،
/// ومدها 4 حركات، ومد المتصل 6 حركات): «بإسكان الياء ومدها 4 حركات» →
/// «بإسكان الياء»; empty when that is all it says.
String _withoutMadd(String description) {
  final madd = RegExp(
    r'^(ب|مع )?(ال)?(قصر|مد|توسط|إشباع)(ها|ه)?'
    r'( (المنفصل|المتصل|اللين|الألف|الياء|الواو))?'
    r'( \d+ ?حركات| حركتين| (أربع|ست|ثلاث|خمس) حركات)?'
    r'( وصلاً| وقفاً)?$',
  );
  final clauses = description
      .split(RegExp(r'\s+و(?=\S)|،\s*'))
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  final kept = clauses.where((c) => !madd.hasMatch(c)).toList();
  if (kept.length == clauses.length) return description;
  return kept.join(' و');
}

bool _isDescription(String text, {bool voweled = false}) {
  const words =
      r'(ب|و)?(ال)?(سكت|تفخيم|ترقيق|إدغام|ادغام|تحقيق|تسهيل|إمالة|تقليل|'
      r'توسط|تسكين|إسكان|اسكان|إظهار|اظهار|جر|بجر|رفع|نصب|ضم|فتح|كسر|ياء|غنة|'
      r'إبدال|ابدال|نقل|صلة|قصر|قصرالبدل|إخفاء|اخفاء|حذف|مد|إشمام|اشمام|امالة|'
      r'ادغم|تشديد|تخفيف|زيادة|إثبات|اثبات)';
  // Without vowels, any such word tells of a reading.
  if (!RegExp('[ً-ْ]').hasMatch(text) &&
      RegExp('(^|\\s)$words(\\s|\$)').hasMatch(text)) {
    return true;
  }
  // With them (اشمام القاف ضماً واظهار اللام الأولى): a phrase opening with
  // such a word.
  final first = text.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '').split(' ');
  return voweled &&
      first.length > 1 &&
      RegExp('^$words\$').hasMatch(first.first);
}
