import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'online_qiraat.dart';

/// Loads the per-riwaya difference files from `assets/data/qiraat/` and
/// answers "which selected riwayat read this Hafs word differently?".
///
/// File format (written by `tool/build_data.dart`, or by hand):
/// ```json
/// {"riwaya": "warsh",
///  "variants": [[surah, ayah, word, count, "text", "f|h|u", "description"], ...]}
/// ```
/// `word` is the 0-based index of the Hafs word in the ayah, `count` the
/// number of Hafs words the reading replaces; the description is optional.
///
/// Riwayat without a data file are read online, ayah by ayah, from
/// [OnlineQiraat] when it is given.
class VariantRepository {
  VariantRepository(this.available, [AssetBundle? bundle, this.online])
      : _bundle = bundle ?? rootBundle;

  static const _dir = 'assets/data/qiraat/';

  /// Riwaya ids that have a data file.
  final Set<String> available;
  final AssetBundle _bundle;
  final OnlineQiraat? online;
  final _loaded = <String, Map<int, List<Variant>>>{};
  final _loading = <String, Future<void>>{};

  /// Online variants per word key, and the ayahs already fetched.
  final _online = <int, List<Variant>>{};
  final _fetched = <int, Future<void>>{};

  /// Riwayat that are read online (no offline file).
  late final Set<String> onlineIds = online == null
      ? const {}
      : {
          for (final q in qiraat)
            for (final r in q.riwayat)
              if (r.id != hafsId && !available.contains(r.id)) r.id,
        };

  bool isOnline(String riwayaId) => onlineIds.contains(riwayaId);

  /// Whether [riwayaId] can be selected (offline file or online source).
  bool isAvailable(String riwayaId) =>
      available.contains(riwayaId) || isOnline(riwayaId);

  /// Fetches the online riwayat for [ayahs] (cached per ayah). Completes
  /// with an error when the network fails; what was fetched stays usable.
  Future<void> ensureAyahs(Iterable<Ayah> ayahs) async {
    if (online == null || onlineIds.isEmpty) return;
    Object? failure;
    await Future.wait([
      for (final a in ayahs)
        _fetched
            .putIfAbsent(key(a.surah, a.number, 0), () => _fetch(a))
            .catchError((Object e) {
          _fetched.remove(key(a.surah, a.number, 0));
          failure = e;
        }),
    ]);
    if (failure != null) throw failure!;
  }

  Future<void> _fetch(Ayah ayah) async {
    for (final v in await online!.fetch(ayah)) {
      if (!onlineIds.contains(v.riwayaId)) continue; // offline text wins
      for (var w = v.word; w < v.word + v.count; w++) {
        _online.putIfAbsent(key(v.surah, v.ayah, w), () => []).add(v);
      }
    }
  }

  static Future<VariantRepository> discover(
      [AssetBundle? bundle, OnlineQiraat? online]) async {
    final manifest =
        await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
    final ids = manifest
        .listAssets()
        .where((a) => a.startsWith(_dir) && a.endsWith('.json'))
        .map((a) => a.substring(_dir.length, a.length - '.json'.length))
        .toSet();
    return VariantRepository(ids, bundle, online);
  }

  bool isLoaded(String riwayaId) =>
      _loaded.containsKey(riwayaId) || isOnline(riwayaId);

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
    final online = _online[k];
    if (online != null) {
      yield* online.where((v) => riwayaIds.contains(v.riwayaId));
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
