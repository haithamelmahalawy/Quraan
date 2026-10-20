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
  final places =
      ((jsonDecode(book) as Map<String, dynamic>)['riwayat'] as Map)[id]
          as List?;
  if (places == null) return;
  for (final p in places) {
    final (surah, ayah, word, count) = (
      p[0] as int,
      p[1] as int,
      p[2] as int,
      p[3] as int,
    );
    final keys = [
      for (var w = word; w < word + count; w++)
        VariantRepository.key(surah, ayah, w),
    ];
    var found = false;
    for (final k in keys) {
      final list = index[k];
      if (list == null) continue;
      found = true;
      for (final v in [...list]) {
        if (v.certified || v.rule.isNotEmpty) continue;
        // The same reading is listed at every word it covers.
        final certified = v.withCertified();
        for (var w = v.word; w < v.word + v.count; w++) {
          final at = index[VariantRepository.key(v.surah, v.ayah, w)]!;
          at[at.indexOf(v)] = certified;
        }
      }
    }
    // A farsh reading the book states and the riwaya file lacks.
    if (!found && p[6] == 'farsh') {
      final how = p[5] as String;
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
      );
      for (final k in keys) {
        (index[k] ??= []).add(variant);
      }
    }
  }
}

/// Text without a vowel that tells of a reading rather than writes it.
bool _isDescription(String text) =>
    !RegExp('[ً-ْ]').hasMatch(text) &&
    RegExp(
      r'(^|\s)(ب|و)?(ال)?(سكت|تفخيم|ترقيق|إدغام|ادغام|تحقيق|تسهيل|إمالة|تقليل|'
      r'توسط|تسكين|إسكان|اسكان|إظهار|اظهار|جر|رفع|نصب|ضم|فتح|كسر|ياء|غنة|إبدال|ابدال|'
      r'نقل|صلة|قصر|قصرالبدل|إخفاء|اخفاء|حذف|مد|إشمام|اشمام|امالة|ادغم)(\s|$)',
    ).hasMatch(text);
