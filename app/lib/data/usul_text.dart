import '../models/quran.dart';
import 'arabic.dart';
import 'variant_repository.dart';

bool isYaqubSeparatedMadd(Variant reading) =>
    const {'ruways', 'rawh'}.contains(reading.riwayaId) &&
    reading.rule == 'madd_munfasil';

bool isYaqubMadd(Variant reading) =>
    const {'ruways', 'rawh'}.contains(reading.riwayaId) &&
    const {'madd_munfasil', 'madd_muttasil'}.contains(reading.rule);

/// Restricts the margin examples, without removing the written mim reading.
/// The comparison is with Hafs's ha, rather than the mim's own vowel.
bool showYaqubMimExample(Variant reading, String hafs) {
  if (!const {'ruways', 'rawh'}.contains(reading.riwayaId) ||
      reading.rule != 'mim_jam') {
    return true;
  }
  String ha(String text) {
    final clusters = lettersOf(text);
    return clusters.length >= 2 && clusters[clusters.length - 2].startsWith('ه')
        ? clusters[clusters.length - 2]
        : '';
  }

  final original = ha(hafs);
  return RegExp('[ْۡ]').hasMatch(original) ||
      (original.contains('ِ') && ha(reading.text).contains('ُ'));
}

/// Qasr removes the final separated-madd sign, preserving any connected
/// madd inside the same word, and all vowels and silent carrier letters.
String withoutSeparatedMaddSign(String text) =>
    text.replaceFirst(RegExp(r'ٓ(?=[ً-ٰٟۖ-ۭ]*(?:ا[ْ۟۠][ً-ٰٟۖ-ۭ]*)?$)'), '');

/// The source's bare initial alif records the ibdal face. A long ibdal before
/// a sakin needs its madd sign; a facilitated/retained hamza must stay intact.
String? hamzaPairMaddText(Variant reading, String source) {
  if (reading.riwayaId != 'warsh' ||
      reading.rule != 'tasheel_pair' ||
      !reading.usulWays.any(
        (way) =>
            way.contains('إبدال الهمزة الثانية ألفًا') &&
            way.contains('المد المشبع'),
      )) {
    return null;
  }
  final letters = lettersOf(source);
  if (letters.isEmpty || !RegExp(r'^آ?$').hasMatch(letters.first)) return null;
  return ['آ', ...letters.skip(1)].join();
}

/// A margin example is always written in its own narrator's reading,
/// independently of the narrator selected for the main page. The stored
/// context identifies a boundary; it is not the text to display unchanged.
String usulReadingText(
  Variant reading,
  Ayah ayah,
  VariantRepository variants, {
  Ayah? previousAyah,
}) {
  Iterable<Variant> at(Ayah a, int w) =>
      variants.at([reading.riwayaId], a.surah, a.number, w);

  String example(Variant v, String hafs) {
    if (v.stopOnly && v.stopText.isNotEmpty) return v.stopText;
    final actual = v.text.isNotEmpty
        ? v
        : at(ayah, v.word)
              .where(
                (other) =>
                    other.word == v.word &&
                    other.count == v.count &&
                    other.text.isNotEmpty,
              )
              .firstOrNull;
    var text = actual?.text ?? hafs;
    final source = variants.sourceTextAt(
      v.riwayaId,
      ayah.surah,
      ayah.number,
      v.word,
    );
    if (source != null) text = hamzaPairMaddText(v, source) ?? text;
    // The small vowel belongs to the riwaya's spelling as on the main page.
    text = withNaqlVowel(text, hafs);
    text = _silah(text, v.shownDescription);
    if (actual != null && actual != v) {
      text = _silah(text, actual.shownDescription);
    }
    if (v.isStoppingTaqlil) return text.replaceAll(RegExp('[۪ٜ]'), '');
    return v.isImala ? withImalaSign(text, v.text) : text;
  }

  final hafs = ayah.words
      .sublist(reading.word, reading.word + reading.count)
      .join(' ');
  final target = example(reading, hafs);
  if (reading.usulText.isEmpty) return target;
  final context = reading.usulText.split(RegExp(r'\s+'));
  final prefixLength = context.length - reading.count;
  if (prefixLength <= 0) return target;
  final prefix = <String>[];
  for (var i = 0; i < prefixLength; i++) {
    var a = ayah;
    var w = reading.word - prefixLength + i;
    if (w < 0 && previousAyah != null) {
      a = previousAyah;
      w += a.words.length;
    }
    if (w < 0) {
      prefix.add(context[i]);
      continue;
    }
    final actual = at(a, w)
        .where((v) => v.word == w && v.count == 1 && v.text.isNotEmpty)
        .firstOrNull;
    var text = actual == null
        ? context[i]
        : withNaqlVowel(actual.text, a.words[w]);
    if (actual != null) {
      text = _silah(text, actual.shownDescription);
      if (actual.isImala) text = withImalaSign(text, actual.text);
    }
    prefix.add(text);
  }
  return madinahScript([...prefix, target].join(' '));
}

/// Description-only sources sometimes write ميم الجمع with a damma alone.
/// Show the small waw explicitly, and preserve the vowel on an unlinked ha.
String _silah(String text, String description) {
  final d = description.replaceAll(RegExp('[ً-ٰٟ]'), '');
  final mim =
      RegExp(r'صلة (ميم الجمع|الميم)').hasMatch(d) &&
      !RegExp(r'(بلا|دون|عدم|ترك) صلة (ميم الجمع|الميم)').hasMatch(d);
  final ha = RegExp(r'صلة (هاء الضمير|الهاء)').hasMatch(d);
  final unlinkedHa = RegExp(
    r'(بلا|دون|عدم|ترك) صلة (هاء الضمير|الهاء)|بقصر الهاء',
  ).hasMatch(d);
  return text
      .split(' ')
      .map((word) {
        if (mim) {
          word = word.replaceFirstMapped(
            RegExp(r'م[ُْۡ]?([ۖ-ۜ]?)$'),
            (m) => 'مُۥ${m[1]}',
          );
        }
        if (unlinkedHa) {
          word = word.replaceAllMapped(RegExp(r'(ه[ُِ])[ۦۥ]ٓ?'), (m) => m[1]!);
        } else if (ha) {
          word = word.replaceFirstMapped(
            RegExp(r'ه([ُِ])([ۖ-ۜ]?)$'),
            (m) => 'ه${m[1]}${m[1] == 'ِ' ? 'ۦ' : 'ۥ'}${m[2]}',
          );
        }
        return word;
      })
      .join(' ');
}
