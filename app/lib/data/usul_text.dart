import '../models/quran.dart';
import 'arabic.dart';
import 'reading_comparison.dart';
import 'variant_repository.dart';

bool isYaqubSeparatedMadd(Variant reading) =>
    const {'ruways', 'rawh'}.contains(reading.riwayaId) &&
    reading.rule == 'madd_munfasil';

bool isYaqubMadd(Variant reading) =>
    const {'ruways', 'rawh'}.contains(reading.riwayaId) &&
    const {'madd_munfasil', 'madd_muttasil'}.contains(reading.rule);

/// Ordinary connected/separated madd is part of every narrator's profile,
/// not a word-level usul example. Keep compound hamza, imala, silah and
/// other actual rules, and keep exceptional madd such as badal and lin.
bool isRoutineMadd(Variant reading) {
  if (const {'madd_munfasil', 'madd_muttasil'}.contains(reading.rule) ||
      reading.isQasr) {
    return true;
  }
  if (!reading.isUsul ||
      reading.isImala ||
      reading.isBadal ||
      reading.isLinHamz) {
    return false;
  }
  if (reading.rule.isNotEmpty && reading.rule != 'kharouf') return false;
  final d = reading.shownDescription;
  if (!RegExp(r'(?:مد|قصر|المد|القصر).*?(?:المتصل|المنفصل)').hasMatch(d)) {
    return false;
  }
  return !RegExp(
    r'همز|صلة|إدغام|ادغام|إشمام|اشمام|نقل|ترقيق|تغليظ|إمالة|تقليل|البدل|اللين|سكت|إثبات|حذف|فتح|كسر|ضم|تخفيف|إظهار|اظهار|بالياء|بالتاء',
  ).hasMatch(d);
}

bool showYaqubYaIdafaExample(Variant reading, String reference) {
  if (!const {'ruways', 'rawh'}.contains(reading.riwayaId) ||
      reading.rule != 'ya_idafa') {
    return true;
  }
  final own = lettersOf(reading.text), other = lettersOf(reference);
  if (own.isEmpty || other.isEmpty) return false;
  return own.last.contains('َ') != other.last.contains('َ');
}

/// Writes Ya'qub's chosen idgham face without adding a sukun to the first
/// consonant. Both page words and the margin use this same transformation.
({String first, String second})? ruwaysKabirText(
  Variant reading,
  String first,
  String second,
) {
  if (!const {'ruways', 'rawh'}.contains(reading.riwayaId) ||
      reading.rule != 'idgham_kabir') {
    return null;
  }
  final a = lettersOf(first), b = lettersOf(second);
  if (a.isEmpty || b.isEmpty) return null;
  String doubled(String c) => '${c[0]}ّ${c.substring(1).replaceAll('ّ', '')}';
  if (reading.surah == 27 && reading.ayah == 36) {
    final ns = [
      for (final (i, c) in a.indexed)
        if (c.startsWith('ن')) i,
    ];
    if (ns.length >= 2 && ns.last == ns[ns.length - 2] + 1) {
      a[ns.last] = doubled(a[ns.last]);
      a.removeAt(ns[ns.length - 2]);
    }
    final waw = a.lastIndexWhere((c) => c.startsWith('و'));
    if (waw >= 0 && !a[waw].contains('ٓ')) a[waw] += 'ٓ';
    return (first: a.join(), second: second);
  }
  if (reading.surah == 34 && reading.ayah == 46 ||
      reading.surah == 53 && reading.ayah == 55) {
    // The doubled consonants are the two tas in تتفكروا، تتمارى, not the
    // first word's last letter.
    if (b.length >= 2 && b[0].startsWith('ت') && b[1].startsWith('ت')) {
      b[0] = 'ت';
      b[1] = doubled(b[1]);
    }
    return (first: first, second: b.join());
  }
  a[a.length - 1] = a.last[0];
  b[0] = doubled(b[0]);
  return (first: a.join(), second: b.join());
}

/// Marks Ruways's long stopping face on يا حسرتى; the ha itself belongs only
/// to the stopping example in the margin, never to the continuous page text.
String? ruwaysHasratiMaddText(Variant reading, String text) {
  if (reading.riwayaId != 'ruways' ||
      reading.surah != 39 ||
      reading.ayah != 56 ||
      reading.rule != 'ha_sakt' ||
      !reading.stopOnly) {
    return null;
  }
  return text.replaceFirstMapped(RegExp(r'([ىا]ٰ?)ٓ?$'), (m) => '${m[1]}ٓ');
}

/// Restricts the margin examples, without removing the written mim reading.
/// A broken ha qualifies without requiring it to become damma in Yaqub.
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
  return RegExp('[ْۡ]').hasMatch(original) || original.contains('ِ');
}

/// Qasr removes the final separated-madd sign, preserving any connected
/// madd inside the same word, and all vowels and silent carrier letters.
String withoutSeparatedMaddSign(String text) =>
    text.replaceFirst(RegExp(r'ٓ(?=[ً-ٰٟۖ-ۭ]*(?:ا[ْ۟۠][ً-ٰٟۖ-ۭ]*)?$)'), '');

/// The wording beside «ٱلتقاء الساكنين»: «بضم نون التنوين وصلًا», «بضم النون
/// وصلًا», as the row tells it, without the chapter's name.
String firstSakinNote(String description) {
  final told = description
      .replaceFirst(' لالتقاء الساكنين', '')
      .replaceFirst(RegExp(r'\s*وصلاً$'), '')
      .replaceFirst(RegExp(r'\s*وصلًا$'), '')
      .trim();
  return '$told وصلًا';
}

/// Ha of tanbih and ya of nida joined in the rasm to a hamza (هَٰٓؤُلَآءِ،
/// هَٰٓأَنتُمۡ، يَٰٓأَيُّهَا، يَٰٓـَٔادَمُ) carry a separated madd within one word.
final _joinedSeparatedMadd = RegExp(
  r'^((?:[أوف]َ)?[هي]َٰ)ٓ'
  r'(?=ـ?[ءأإؤئٔ])',
);

String withoutJoinedSeparatedMaddSign(String text) =>
    text.replaceFirstMapped(_joinedSeparatedMadd, (m) => m[1]!);

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
  Ayah? nextAyah,
}) {
  Iterable<Variant> at(Ayah a, int w) =>
      variants.at([reading.riwayaId], a.surah, a.number, w);

  if (reading.riwayaId == 'ruways' && reading.rule == 'idgham_kabir') {
    final context = reading.usulText.split(RegExp(r'\s+'));
    if (context.length == 2) {
      String actual(int w, String fallback) =>
          at(ayah, w)
              .where(
                (v) =>
                    v.word == w &&
                    v.count == 1 &&
                    v.canReplaceText &&
                    v.text.isNotEmpty,
              )
              .firstOrNull
              ?.text ??
          fallback;
      final pair = ruwaysKabirText(
        reading,
        actual(reading.word, context.first),
        actual(reading.word + 1, context.last),
      );
      if (pair != null) return madinahScript('${pair.first} ${pair.second}');
    }
  }

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
    return v.isImala && !v.fathPreferred ? withImalaSign(text, v.text) : text;
  }

  final hafs = ayah.words
      .sublist(reading.word, reading.word + reading.count)
      .join(' ');
  final target = example(reading, hafs);
  if (reading.isSakt && reading.count == 1 && !target.contains(' ')) {
    // Sakt at a word boundary must show the hamza word as well. Internal
    // sakt (al/شيء) stays a single word, even if another hamza follows.
    final following = reading.word + 1 < ayah.words.length ? ayah : nextAyah;
    final nextWord = following == ayah ? reading.word + 1 : 0;
    final boundary = RegExp(r'ۜ(?:[اى][ً-ٰٟۖ-ۭ]*)?$').hasMatch(target);
    if (boundary &&
        following != null &&
        RegExp(r'^[ءأإؤئآ]').hasMatch(following.words[nextWord])) {
      var second = readingText(
        variants,
        reading.riwayaId,
        following,
        nextWord,
        nextWord + 1,
      );
      // Some legacy quotations list alternatives from different places
      // (إليهم، عليهم). Select this word, never append unrelated examples.
      final pieces = second.split(RegExp(r'[\s،,]+'));
      if (pieces.length != 1) {
        final baseline = following.words[nextWord];
        final own = pieces
            .where((t) => skeleton(t) == skeleton(baseline))
            .firstOrNull;
        second = completeReadingVowels(own ?? baseline, baseline);
      }
      return madinahScript('$target $second');
    }
  }
  // Abu Ja'far's ikhfa of the nun before kha and ghayn is of two words
  // (قَوۡلًا غَيۡرَ): the one it is hidden before as well.
  if (reading.rule == 'ikhfa' && reading.count == 1 && !target.contains(' ')) {
    final following = reading.word + 1 < ayah.words.length ? ayah : nextAyah;
    final nextWord = following == ayah ? reading.word + 1 : 0;
    if (following != null) {
      final second = readingText(
        variants,
        reading.riwayaId,
        following,
        nextWord,
        nextWord + 1,
      );
      if (RegExp('^[خغ]').hasMatch(second)) {
        return madinahScript('$target $second');
      }
    }
  }
  if (reading.usulText.isEmpty) return target;
  final context = reading.usulText.split(RegExp(r'\s+'));
  // A context opening with the word itself gives what follows it (the
  // sakin of «قُلُوبِهِمِ ٱلۡعِجۡلَ»): the reading, then those words; never
  // the Hafs word again before it.
  if (context.length > reading.count &&
      skeleton(context.first) == skeleton(ayah.words[reading.word])) {
    return madinahScript([target, ...context.skip(reading.count)].join(' '));
  }
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
      if (actual.isImala && !actual.fathPreferred) {
        text = withImalaSign(text, actual.text);
      }
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
