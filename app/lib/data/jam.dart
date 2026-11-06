import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'variant_repository.dart';

/// The twenty riwayat of the ten, in their order: Qalun first, Idris last.
/// A reading in «الجمع» is told with the first of those who read it.
final jamOrder = [
  for (final q in qiraat)
    for (final r in q.riwayat) r.id,
];

/// «قالون عن نافع»: a riwaya named with its qari.
String jamName(String riwaya) {
  final qari = qiraaOf(riwaya).shortAr;
  // After «عن»: «أبي عمرو»، «أبي جعفر».
  return '${riwayaById(riwaya).nameAr} عن ${qari.replaceFirst(RegExp('^أبو '), 'أبي ')}';
}

/// One reading of an ayah in «الجمع»: the riwayat that read the whole ayah
/// alike, in their order, its words as they write them, and where they differ
/// from Hafs.
class JamReading {
  JamReading(this.riwayat, this.words, this.differences);

  /// Who read it so; the first is the one it is read with.
  final List<String> riwayat;

  /// The ayah's words, as the first of [riwayat] writes them.
  final List<String> words;

  /// The rows of the first of [riwayat], by the word they tell.
  final Map<int, List<Variant>> differences;

  String get lead => riwayat.first;

  /// The others who read it alike, named in the hamesh.
  List<String> get agreeing => riwayat.skip(1).toList();
}

/// The readings of [ayah] by the twenty riwayat, each once: a riwaya that
/// reads it all alike with one before it (its farsh and its usul) is told
/// with that one, not read again.
List<JamReading> jamReadings(
  Ayah ayah,
  VariantRepository variants, {
  Iterable<String>? riwayat,
}) {
  final readings = <String, JamReading>{};
  for (final id in riwayat ?? jamOrder) {
    final rows = <int, List<Variant>>{};
    final words = <String>[];
    final sign = StringBuffer();
    for (var w = 0; w < ayah.words.length; w++) {
      final at = [
        if (id != hafsId)
          for (final v in variants.at([id], ayah.surah, ayah.number, w))
            // What is read in the wasl; a stop alone is not the ayah's reading.
            if (v.word == w && !v.stopOnly) v,
      ];
      if (at.isNotEmpty) rows[w] = at;
      words.add(_wordOf(ayah.words[w], at));
      for (final v in at) {
        sign
          ..write(w)
          ..write(':')
          ..write(_plain(v.text))
          ..write(':')
          ..write(
            v.text.isEmpty ? (v.rule.isEmpty ? v.description : v.rule) : '',
          )
          ..write(';');
      }
    }
    final key = sign.toString();
    final same = readings[key];
    if (same != null) {
      same.riwayat.add(id);
    } else {
      readings[key] = JamReading([id], words, rows);
    }
  }
  return readings.values.toList();
}

/// The word as the riwaya writes it: its farsh, else its hamza, else its usul
/// written out; Hafs's where it writes none.
String _wordOf(String hafs, List<Variant> rows) {
  for (final kind in [VariantKind.farsh, VariantKind.hamza]) {
    for (final v in rows) {
      if (v.kind == kind && v.text.isNotEmpty) return v.text;
    }
  }
  for (final v in rows) {
    if (v.text.isNotEmpty) return v.text;
  }
  return hafs;
}

/// A word's letters and marks, without the stops' signs over it.
String _plain(String text) => text.replaceAll(RegExp('[ۖ-ۜ۩‏]'), '');
