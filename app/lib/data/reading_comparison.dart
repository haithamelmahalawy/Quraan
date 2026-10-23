import '../models/quran.dart';
import 'arabic.dart';
import 'reading_normalization.dart';
import 'variant_repository.dart';

/// Pronounced letters and vowels, independent of font spelling and the
/// position of tanween. Recitation marks remain separate usul annotations.
String readingTextKey(String text, {String? baseline}) {
  List<String> words(String s) =>
      madinahScript(s)
          .replaceAll(RegExp(r'ا(?=[ً-ٰٟۖ-ۭ]*۠)'), '')
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
  final own = words(text),
      reference = baseline == null ? <String>[] : words(baseline);
  return own.indexed
      .map((entry) {
        final (w, word) = entry;
        final letters = units(word);
        final base = reference.length == own.length
            ? units(reference[w])
            : <Unit>[];
        final aligned = _align(letters, base, word.contains('آ'));
        return letters.indexed
            .map((entry) {
              final (i, u) = entry;
              final h = aligned[i];
              // جزآء in partial quotations uses a madda on the long alif before
              // a separate hamza, not another hamza in addition to the final one.
              final letter =
                  word.contains('آ') &&
                      i > 0 &&
                      u.letter == 'ء' &&
                      u.seat == 'ا' &&
                      h?.letter == 'ا' &&
                      i + 1 < letters.length &&
                      letters[i + 1].letter == 'ء'
                  ? 'ا'
                  : u.letter;
              final fill = !u.vocalized && h?.letter == letter;
              return '$letter:${(fill ? h!.vowel : u.vowel) ?? ''}:'
                  '${(fill ? h!.tanween : u.tanween) ?? ''}:'
                  '${i > 0 && (fill ? h!.shadda : u.shadda) ? 'ّ' : ''}:'
                  '${u.marks.contains(0x06DC) ? 'سكت' : ''}';
            })
            .join('|');
      })
      .join(' ');
}

Map<int, Unit> _align(List<Unit> own, List<Unit> base, bool quotedMadd) {
  bool matches(int i, int j) =>
      own[i].letter == base[j].letter ||
      quotedMadd &&
          i > 0 &&
          own[i].letter == 'ء' &&
          own[i].seat == 'ا' &&
          base[j].letter == 'ا' &&
          i + 1 < own.length &&
          own[i + 1].letter == 'ء';
  final lengths = List.generate(
    own.length + 1,
    (_) => List.filled(base.length + 1, 0),
  );
  for (var i = own.length - 1; i >= 0; i--) {
    for (var j = base.length - 1; j >= 0; j--) {
      lengths[i][j] = matches(i, j)
          ? 1 + lengths[i + 1][j + 1]
          : (lengths[i + 1][j] > lengths[i][j + 1]
                ? lengths[i + 1][j]
                : lengths[i][j + 1]);
    }
  }
  final aligned = <int, Unit>{};
  var i = 0, j = 0;
  while (i < own.length && j < base.length) {
    if (matches(i, j)) {
      aligned[i++] = base[j++];
    } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return aligned;
}

String _descriptionKey(String s) =>
    s.replaceAll(RegExp('[ً-ٰٟ]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Group equal readings by their actual vowels, not just bare letters or
/// a generic description such as "بضم الميم".
String readingVariantKey(Variant v, {String? baseline}) {
  final marks = units(madinahScript(v.text)).indexed
      .expand(
        (e) => e.$2.marks
            .where((m) => const {0x06EA, 0x06ED, 0x065C, 0x06EC}.contains(m))
            .map((m) => '${e.$1}:$m'),
      )
      .join(';');
  if (v.isUsul || v.isMarginNote) {
    return 'rule:${v.count}:${v.shownDescription.isNotEmpty ? _descriptionKey(v.shownDescription) : '${v.rule}:${readingTextKey(v.text)}:$marks'}';
  }
  return 'farsh:${v.count}:${readingTextKey(v.text, baseline: baseline)}:$marks:'
      '${v.text.isEmpty ? _descriptionKey(v.description) : ''}:'
      '${_descriptionKey(v.bookWujuh)}';
}

bool _lexical(Variant v) => v.inHamesh && !v.isMarginNote && !v.readsAsHafs;

List<Variant> _rows(
  VariantRepository repository,
  String? id,
  Ayah ayah,
  int from,
  int to,
) => id == null || id == 'hafs'
    ? []
    : {
        for (var w = from; w < to; w++)
          ...repository.at([id], ayah.surah, ayah.number, w),
      }.toList();

String _apply(Ayah ayah, List<Variant> rows, int from, int to) {
  final text = <String>[];
  for (var w = from; w < to;) {
    final replacements =
        rows
            .where(
              (v) => v.word == w && v.word + v.count <= to && v.canReplaceText,
            )
            .toList()
          ..sort((a, b) {
            if (_lexical(a) != _lexical(b)) return _lexical(a) ? -1 : 1;
            return b.count.compareTo(a.count);
          });
    final v = replacements.firstOrNull;
    if (v == null) {
      text.add(ayah.words[w++]);
    } else {
      if (v.text.isNotEmpty) text.add(v.text);
      w += v.count;
    }
  }
  return madinahScript(text.join(' '));
}

/// The actual reading of a Hafs-aligned span, including omissions and
/// multiword readings. Complete aligned source text takes priority.
String readingText(
  VariantRepository repository,
  String? id,
  Ayah ayah,
  int from,
  int to,
) {
  final source = [
    for (var w = from; w < to; w++)
      repository.sourceTextAt(id, ayah.surah, ayah.number, w),
  ];
  if (source.every((s) => s != null)) {
    return source.whereType<String>().where((s) => s.isNotEmpty).join(' ');
  }
  return _apply(ayah, _rows(repository, id, ayah, from, to), from, to);
}

String _lexicalKey(Ayah ayah, List<Variant> rows, int from, int to) {
  final unresolved = [
    for (final v in rows) ...[
      if (!v.canReplaceText)
        '${v.word - from}:${v.count}:${_descriptionKey(v.shownDescription)}',
      if (v.bookWujuh.isNotEmpty)
        '${v.word - from}:${_descriptionKey(v.bookWujuh)}',
    ],
  ]..sort();
  return '${readingTextKey(_apply(ayah, rows, from, to), baseline: ayah.words.sublist(from, to).join(' '))}#${unresolved.join(';')}';
}

/// Compare each selected narrator with the displayed narrator. A missing
/// lexical delta means agreement with Hafs, rather than no comparison.
/// Usul keep their separate annotations; shared explicit rules are omitted.
List<Variant> compareReadings({
  required VariantRepository repository,
  required Ayah ayah,
  required int word,
  required String? displayed,
  required Iterable<String> selected,
}) {
  if (displayed != null && !repository.isLoaded(displayed)) return [];
  final ids = selected
      .where(
        (id) =>
            id != (displayed ?? 'hafs') &&
            (id == 'hafs' || repository.isLoaded(id)),
      )
      .toSet();
  if (ids.isEmpty) return [];
  final base = _rows(repository, displayed, ayah, word, word + 1);
  final baseRules = base.where((v) => v.isUsul).map(readingVariantKey).toSet();
  final result = <Variant>[
    for (final id in ids)
      for (final v in _rows(repository, id, ayah, word, word + 1))
        if (v.isMarginNote ||
            v.isUsul && !baseRules.contains(readingVariantKey(v)))
          v,
  ];

  // Overlapping spans must be compared as one unit. Adjacent independent
  // words keep their own notes, as in فجزاء / مثل.
  var from = word, to = word + 1;
  var expanded = true;
  final narrators = {displayed ?? 'hafs', ...ids};
  while (expanded) {
    expanded = false;
    for (final id in narrators) {
      for (final v in _rows(repository, id, ayah, from, to).where(_lexical)) {
        if (v.word < 0 || v.word + v.count > ayah.words.length) continue;
        if (v.word < from) {
          from = v.word;
          expanded = true;
        }
        if (v.word + v.count > to) {
          to = v.word + v.count;
          expanded = true;
        }
      }
    }
  }
  final lexical = {
    for (final id in narrators)
      id: _rows(repository, id, ayah, from, to).where(_lexical).toList(),
  };
  if (lexical.values.every((rows) => rows.isEmpty)) return result;
  final baseKey = _lexicalKey(ayah, lexical[displayed ?? 'hafs']!, from, to);
  for (final id in ids) {
    final own = lexical[id]!;
    if (_lexicalKey(ayah, own, from, to) == baseKey) continue;
    if (own.length == 1 &&
        own.single.word == from &&
        own.single.count == to - from) {
      result.add(own.single);
      continue;
    }
    result.add(
      Variant(
        riwayaId: id,
        surah: ayah.surah,
        ayah: ayah.number,
        word: from,
        count: to - from,
        text: readingText(repository, id, ayah, from, to),
        kind: VariantKind.farsh,
        rule: 'comparison',
        description: own
            .map((v) => v.description)
            .where((d) => d.isNotEmpty)
            .toSet()
            .join('، '),
        bookWujuh: own
            .map((v) => v.bookWujuh)
            .where((d) => d.isNotEmpty)
            .toSet()
            .join('، '),
      ),
    );
  }
  return result;
}
