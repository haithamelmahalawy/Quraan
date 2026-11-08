import 'dart:convert';

import 'package:flutter/services.dart';

import 'audio_numbering.dart';

/// A sheikh's recitation of a whole riwaya, recorded ayah by ayah.
class Reciter {
  const Reciter(
    this.id,
    this.name,
    this.server, {
    this.numbering = 'kufi',
    this.ends = const {},
  });

  final int id;
  final String name;

  /// The counting system used by these audio files (not the displayed mushaf).
  final String numbering;

  /// Base of the files: `<server><sss><aaa>.mp3`.
  final String server;

  /// Where the ayah ends, in ms, in the files that go on past it into the
  /// ayat after it (`"surah:native ayah"`): played up to there only.
  final Map<String, int> ends;

  /// The end of the native ayah [ayah]'s own recording in its file, when the
  /// file holds more.
  Duration? endOf(int surah, int ayah) => switch (ends['$surah:$ayah']) {
    final ms? => Duration(milliseconds: ms),
    null => null,
  };

  /// [ayah] is a native recording number; map displayed verses before calling.
  Uri ayah(int surah, int ayah) => Uri.parse(
    '$server${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3',
  );
}

/// The reciters of each riwaya (`assets/data/reciters.json`, built by
/// `tool/build_tafsir.dart` from Quranpedia's list of recitations).
class Recitations {
  Recitations._(this._byRiwaya);

  final Map<String, List<Reciter>> _byRiwaya;

  static Future<Recitations> load([AssetBundle? bundle]) async {
    final json = jsonDecode(
      await (bundle ?? rootBundle).loadString('assets/data/reciters.json'),
    ) as Map<String, dynamic>;
    return Recitations._({
      for (final MapEntry(:key, :value)
          in (json['riwayat'] as Map<String, dynamic>).entries)
        key: [
          for (final r in value as List)
            Reciter(
              r['id'] as int,
              r['name'] as String,
              r['server'] as String,
              numbering:
                  r['numbering'] as String? ?? AudioNumbering.systemFor(key),
              ends: {
                for (final MapEntry(:key, :value)
                    in (r['ends'] as Map<String, dynamic>? ?? const {}).entries)
                  key: value as int,
              },
            ),
        ],
    });
  }

  List<Reciter> of(String riwaya) => _byRiwaya[riwaya] ?? const [];
}
