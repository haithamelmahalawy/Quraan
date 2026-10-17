import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One place of a mutashabih: usually one ayah, sometimes two or three
/// consecutive ones, with the words it shares with the other places.
class MutashabihPlace {
  const MutashabihPlace(this.parts);

  final List<({int surah, int ayah, Set<int> words})> parts;

  int get surah => parts.first.surah;
  int get ayah => parts.first.ayah;

  String get key => parts.map((p) => '${p.surah}:${p.ayah}').join('+');

  bool contains(int surah, int ayah) =>
      parts.any((p) => p.surah == surah && p.ayah == ayah);
}

/// Verbally similar ayahs (mutashabihat lafziyya) from Quran Mutashabihat
/// Data (Waqar144, CC0), after Qari Idrees Al-Asim.
class MutashabihatRepository {
  MutashabihatRepository._(this._groups, this._byWord);

  final List<List<MutashabihPlace>> _groups;
  final Map<int, List<int>> _byWord;

  static const empty = MutashabihatRepository._empty();
  const MutashabihatRepository._empty()
      : _groups = const [],
        _byWord = const {};

  static int _key(int surah, int ayah, int word) =>
      surah * 1000000 + ayah * 1000 + word;

  /// Whether the word is part of a phrase repeated in a similar ayah.
  bool isShared(int surah, int ayah, int word) =>
      _byWord.containsKey(_key(surah, ayah, word));

  /// Every place similar to the one containing this word; the place the word
  /// belongs to comes first.
  List<MutashabihPlace> placesFor(int surah, int ayah, int word) {
    final ids = _byWord[_key(surah, ayah, word)] ?? const [];
    final here = <MutashabihPlace>[];
    final others = <String, MutashabihPlace>{};
    for (final id in ids) {
      for (final place in _groups[id]) {
        if (place.contains(surah, ayah)) {
          if (here.isEmpty) here.add(place);
        } else {
          others.putIfAbsent(place.key, () => place);
        }
      }
    }
    return [...here, ...others.values];
  }

  static Future<MutashabihatRepository> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle)
          .loadString('assets/data/mutashabihat.json');
      return parse(raw);
    } on FlutterError {
      return empty;
    }
  }

  static MutashabihatRepository parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final groups = <List<MutashabihPlace>>[];
    final byWord = <int, List<int>>{};
    for (final g in json['groups'] as List) {
      final id = groups.length;
      final places = <MutashabihPlace>[];
      for (final o in g as List) {
        final parts = [
          for (final p in o as List)
            (
              surah: p[0] as int,
              ayah: p[1] as int,
              words: (p[2] as List).cast<int>().toSet(),
            ),
        ];
        places.add(MutashabihPlace(parts));
        for (final p in parts) {
          for (final w in p.words) {
            final list = byWord.putIfAbsent(_key(p.surah, p.ayah, w), () => []);
            if (!list.contains(id)) list.add(id);
          }
        }
      }
      groups.add(places);
    }
    return MutashabihatRepository._(groups, byWord);
  }
}
