import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/quran.dart';
import 'arabic.dart';

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
    final book = await (_book ??= _bundle
        .loadString('assets/data/kharouf.json')
        .then<String?>((s) => s, onError: (_) => null));
    _loaded[id] = await compute(_index, (id, raw, book));
  }

  /// The certified source (assets/data/kharouf.json), read once.
  Future<String?>? _book;

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

  static int key(int surah, int ayah, int word) =>
      surah * 1000000 + ayah * 1000 + word;
}

/// Indexes a riwaya file by every Hafs word each variant covers, with
/// what the certified source says of the riwaya ([book]): its readings
/// marked certified, and those it states but the file lacks added.
Map<int, List<Variant>> _index((String, String, String?) input) {
  final (id, raw, book) = input;
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final index = <int, List<Variant>>{};
  for (final v in json['variants'] as List) {
    // A few readings of the source give their description as the text
    // (بتفخيم الراء والسكت على الساكن قبل الهمزة): not to be drawn as the
    // words of the page.
    if (_isDescription(v[4] as String) && (v.length < 7 || v[6] == '')) {
      v as List;
      final description = v[4] as String;
      v[4] = '';
      v.length < 7 ? v.addAll([description]) : v[6] = description;
    }
    final variant = Variant(
      riwayaId: id,
      surah: v[0] as int,
      ayah: v[1] as int,
      word: v[2] as int,
      count: v[3] as int,
      // Read in the script of the Madinah page around it.
      text: madinahScript(v[4] as String),
      kind: VariantKind.fromCode(v[5] as String),
      description: v.length > 6 ? v[6] as String : '',
      rule: v.length > 7 ? v[7] as String : '',
      bookWujuh: v.length > 8 ? (v[8] as Map)['wujuh'] as String? ?? '' : '',
      stopOnly: v.length > 8 && (v[8] as Map)['stopOnly'] == true,
      usulText: v.length > 8 ? (v[8] as Map)['context'] as String? ?? '' : '',
      usulWays: v.length > 8
          ? ((v[8] as Map)['ways'] as List? ?? const []).cast<String>()
          : const [],
    );
    for (var w = variant.word; w < variant.word + variant.count; w++) {
      index
          .putIfAbsent(
            VariantRepository.key(variant.surah, variant.ayah, w),
            () => [],
          )
          .add(variant);
    }
  }
  if (book != null) _certify(id, index, book);
  return index;
}

void _certify(String id, Map<int, List<Variant>> index, String book) {
  final json = jsonDecode(book) as Map<String, dynamic>;
  // Farsh the book says this riwaya reads as Hafs: the file's farsh
  // readings there are not shown (the book is the certified source).
  for (final e in json['entries'] as List) {
    if (e[4] != 'farsh') continue;
    final readings = e[5] as List;
    bool reads(List g) =>
        (g[1] as List).contains(id) || (g[2] as List).contains(id);
    final asHafs = readings.any(
      (g) => (g[1] as List).contains('hafs') && (g[1] as List).contains(id),
    );
    final other = readings.any(
      (g) => !(g[1] as List).contains('hafs') && reads(g as List),
    );
    if (!asHafs || other) continue;
    for (var w = e[2] as int; w < (e[2] as int) + (e[3] as int); w++) {
      index[VariantRepository.key(e[0] as int, e[1] as int, w)]?.removeWhere(
        (v) => v.kind == VariantKind.farsh && v.rule.isEmpty,
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
    final how = p[5] as String;
    final wujuh = p.length > 7 ? p[7] as String : '';
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
          // Do not duplicate an existing rule as a lexical book variant.
          if ((p[4] as String).isEmpty && _matchesUsul(v, how)) found = true;
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
    // A farsh reading the book states and the riwaya file lacks.
    if (!found && p[6] == 'farsh') {
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

/// Whether a generated rule already covers the book's general-rule note.
bool _matchesUsul(Variant v, String how) {
  if (v.isBadal && how.contains('البدل')) return true;
  if ((v.rule == 'naql' || v.rule == 'naql_source') && how.contains('نقل')) {
    return true;
  }
  if (const {'ibdal_waw', 'ibdal_ya', 'ibdal_single'}.contains(v.rule) &&
      RegExp('إبدال|ابدال').hasMatch(how)) {
    return true;
  }
  if (const {
        'tasheel_pair',
        'tasheel_word',
        'ha_antum',
        'hamza_wasl',
      }.contains(v.rule) &&
      RegExp('تسهيل|إبدالها').hasMatch(how)) {
    return true;
  }
  if (v.isImala && RegExp('تقليل|إمالة').hasMatch(how)) return true;
  return false;
}

/// Text without a vowel that tells of a reading rather than writes it.
bool _isDescription(String text) =>
    !RegExp('[ً-ْ]').hasMatch(text) &&
    RegExp(
      r'(^|\s)(ب|و)?(ال)?(سكت|تفخيم|ترقيق|إدغام|ادغام|تحقيق|تسهيل|إمالة|تقليل|'
      r'توسط|تسكين|إسكان|اسكان|إظهار|اظهار|جر|رفع|نصب|ضم|فتح|كسر|ياء|غنة|إبدال|ابدال|'
      r'نقل|صلة|قصر|قصرالبدل|إخفاء|اخفاء|حذف|مد|إشمام|اشمام|امالة|ادغم)(\s|$)',
    ).hasMatch(text);
