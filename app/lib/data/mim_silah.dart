import '../models/quran.dart';
import 'variant_repository.dart';

/// The riwayat that join the mim al-jam' with a waw (صلة ميم الجمع).
const mimSilahRiwayat = {
  'qalun',
  'bazzi',
  'qunbul',
  'ibn_wardan',
  'ibn_jammaz',
};

/// A word starting with a mim doubled by Hafs's idgham of the mim before it.
final _mimShadda = RegExp(r'^م[ً-ْ]*ّ[ً-ْ]*');

/// A word ending in a mim joined with its waw (لَكُمُۥ).
final _endsInSilah = RegExp(r'مُۥ[ۖ-ۭ]*$');

/// The silah of a mim al-jam' (لَكُمُۥ مِنۡ) keeps the mim after it apart:
/// Hafs's shadda of the idgham (لَكُم مِّنۡ) dropped, for Qalun, Ibn Kathir
/// and Abu Ja'far, at each word of [text], which starts at the word [from] of
/// [ayah].
String withMimSilah(
  VariantRepository repository,
  String? id,
  Ayah ayah,
  int from,
  String text,
) {
  if (id == null || !mimSilahRiwayat.contains(id)) return text;
  final words = text.split(' ');
  var changed = false;
  for (var i = 0; i < words.length; i++) {
    final w = from + i;
    if (w == 0 || !_mimShadda.hasMatch(words[i])) continue;
    final silah = i > 0
        ? _endsInSilah.hasMatch(words[i - 1])
        : mimSilahAt(repository, id, ayah, w - 1);
    if (!silah) continue;
    words[i] = words[i].replaceFirstMapped(
      _mimShadda,
      (m) => m[0]!.replaceFirst('ّ', ''),
    );
    changed = true;
  }
  return changed ? words.join(' ') : text;
}

/// [id] reads the mim al-jam' that ends the word [w] of [ayah] with its silah.
bool mimSilahAt(VariantRepository repository, String id, Ayah ayah, int w) =>
    repository
        .at([id], ayah.surah, ayah.number, w)
        .any(
          (v) =>
              v.word + v.count - 1 == w &&
              v.description.contains('صلة ميم الجمع'),
        );
