import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/quran.dart';

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
    final manifest =
        await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
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
    _loaded[id] = await compute(_index, (id, raw));
  }

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

/// Indexes a riwaya file by every Hafs word each variant covers.
Map<int, List<Variant>> _index((String, String) input) {
  final (id, raw) = input;
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final index = <int, List<Variant>>{};
  for (final v in json['variants'] as List) {
    final variant = Variant(
      riwayaId: id,
      surah: v[0] as int,
      ayah: v[1] as int,
      word: v[2] as int,
      count: v[3] as int,
      text: v[4] as String,
      kind: VariantKind.fromCode(v[5] as String),
      description: v.length > 6 ? v[6] as String : '',
    );
    for (var w = variant.word; w < variant.word + variant.count; w++) {
      index
          .putIfAbsent(
              VariantRepository.key(variant.surah, variant.ayah, w), () => [])
          .add(variant);
    }
  }
  return index;
}
