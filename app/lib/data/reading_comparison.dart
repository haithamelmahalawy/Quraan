import '../models/quran.dart';
import 'arabic.dart';
import 'reading_normalization.dart';
import 'mim_silah.dart';
import 'variant_repository.dart';

/// Pronounced letters and vowels, independent of font spelling and the
/// position of tanween. Recitation marks remain separate usul annotations.
/// The key of a reading's text, for comparing it with another's. The non-joiner
/// marks a reading written as Hafs's but read otherwise (لَأَتَوْهَا): it differs.
String readingTextKey(String text, {String? baseline}) {
  final key = _textKey(text, baseline: baseline);
  return text.contains('\u200c') ? '$key:read-otherwise' : key;
}

String _textKey(String text, {String? baseline}) {
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
              // A bare nun or mim inside the word is sakin, hidden in the
              // letter after it (يَغُرَّنكَ): not Hafs's vowel (يَغُرَّنَّكَ).
              // A word written without vowels (ونقول) tells nothing by it.
              // So too at its end where Hafs doubles it (أَن لَّعۡنَتُ for أَنَّ).
              final hidden =
                  (letter == 'ن' || letter == 'م') &&
                  i > 0 &&
                  (i + 1 < letters.length || (h?.shadda ?? false)) &&
                  letters.any((l) => l.vocalized);
              final fill = !u.vocalized && !hidden && h?.letter == letter;
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

/// [text] without the silah of a ha at a word's end (عَمِلَتۡهُۥ، بِهِۦ): told
/// in the usul (هاء الكناية), no difference of the word.
String withoutHaSilah(String text) => text.replaceAllMapped(
  RegExp('ه([ُِ])[ۥۦ]ٓ?(?=[ۖ-ۜ]*( |\$))'),
  (m) => 'ه${m[1]}',
);

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
  // A comparison's silah of the ha is told in the usul: Ibn Kathir's
  // «عَمِلَتۡهُۥ» with the others' «عَمِلَتۡهُ».
  final text = v.rule == 'comparison' ? withoutHaSilah(v.text) : v.text;
  return 'farsh:${v.count}:${readingTextKey(text, baseline: baseline)}:$marks:'
      '${v.description.startsWith('بوجهين') ? _descriptionKey(v.description) : ''}:'
      '${v.text.isEmpty ? _descriptionKey(v.description) : ''}:'
      '${_descriptionKey(v.bookWujuh)}';
}

bool _writtenIdgham(Variant v) =>
    const {'idgham', 'idgham_saghir', 'idgham_kabir'}.contains(v.rule) &&
    v.text.isNotEmpty &&
    !v.stopOnly;

/// Ya' al-idafa (عَهۡدِيَ، بَيۡتِي): a written difference of the words,
/// compared like the farsh in every riwaya.
bool _yaIdafaRule(Variant v) =>
    v.rule == 'ya_idafa' && v.text.isNotEmpty && !v.stopOnly;

/// How a reading reads its ya' al-idafa, by its description: 'sukun' or
/// 'fath'; null when it says nothing of it. The texts do not always write
/// the sukun of the ya (بَيۡتِي), so its vowel cannot be told from them.
String? _yaIdafa(Variant v) {
  final m = RegExp(r'(^|\s|و)ب?(إسكان|اسكان|فتح) (ال)?ياء( الإضافة)?(\s|$|،)')
      .firstMatch(v.description);
  if (m == null) return null;
  return m[2] == 'فتح' ? 'fath' : 'sukun';
}

bool _lexical(Variant v) =>
    (v.inHamesh ||
        // «اتخذتم، أخذتم»: told in the usul alone, shaded where it differs.
        _writtenIdgham(v) && v.description != 'بإدغام الذال في التاء' ||
        _yaIdafaRule(v)) &&
    !v.isMarginNote &&
    !v.readsAsHafs;

/// Ibn 'Amir's idgham across two words is told in the usul: it does not
/// join a farsh of one of its words into one note (وَلَقَد صَّدَقَ beside
/// «صَدَقَ بتخفيف الدال»).
bool _ibnAmirIdgham(Variant v) =>
    _writtenIdgham(v) && const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId);

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
          }
          .expand((v) => _bookWordDifferences(v, ayah))
          .where((v) => v.word < to && v.word + v.count > from)
          .toList();

/// Book quotations include unchanged context. Keep that context in the source,
/// but only expose the actual changed words as comparison spans. Unequal word
/// counts and readings with additional faces retain their complete spans.
Iterable<Variant> _bookWordDifferences(Variant v, Ayah ayah) sync* {
  final words = v.text.trim().split(RegExp(r'\s+'));
  if (v.rule != 'kharouf' ||
      v.count <= 1 ||
      v.bookWujuh.isNotEmpty ||
      words.length != v.count ||
      v.word < 0 ||
      v.word + v.count > ayah.words.length) {
    yield v;
    return;
  }
  for (var i = 0; i < words.length; i++) {
    final baseline = ayah.words[v.word + i];
    if (readingTextKey(words[i], baseline: baseline) ==
        readingTextKey(baseline)) {
      continue;
    }
    yield Variant(
      riwayaId: v.riwayaId,
      surah: v.surah,
      ayah: v.ayah,
      word: v.word + i,
      count: 1,
      text: words[i],
      kind: v.kind,
      description: v.description,
      rule: v.rule,
      certified: v.certified,
      bookHow: v.bookHow,
      bookFarsh: v.bookFarsh,
      stopOnly: v.stopOnly,
      stopText: v.stopText,
      marginText: v.marginText,
      ownWays: v.ownWays,
      omission: v.omission,
      usulText: v.usulText,
      usulWays: v.usulWays,
      hamesh: v.hamesh,
    );
  }
}

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
  return withMimSilah(
    repository,
    id,
    ayah,
    from,
    _apply(ayah, _rows(repository, id, ayah, from, to), from, to),
  );
}

/// How Hafs reads the last ya of the word [w]: 'fath' (وَجۡهِيَ) or 'sukun'
/// (إِنِّيٓ); null without one.
String? _hafsYa(Ayah ayah, int w) {
  if (w < 0 || w >= ayah.words.length) return null;
  final word = ayah.words[w].replaceAll(RegExp('[ۖ-ۜ]'), '');
  final at = word.lastIndexOf('ي');
  if (at < 0) return null;
  final marks = RegExp('^[ً-ٰٟ۟-ۭ]*').firstMatch(word.substring(at + 1))![0]!;
  return marks.contains('َ') ? 'fath' : 'sukun';
}

String _lexicalKey(Ayah ayah, List<Variant> rows, int from, int to) {
  final unresolved = [
    for (final v in rows.where(_lexical)) ...[
      if (!v.canReplaceText)
        '${v.word - from}:${v.count}:${_descriptionKey(v.shownDescription)}',
      if (v.bookWujuh.isNotEmpty)
        '${v.word - from}:${_descriptionKey(v.bookWujuh)}',
      // Read as Hafs reads it (إِنِّيٓ sakin, وَجۡهِيَ open), the ya is no
      // difference from him; it still is from those who read it otherwise.
      // Two faces differ from one of them, though written alike (فَنِعۡمَّا).
      // So a madd dropped though its alif is written (وَلَاْ أَدۡرَىٰكُمُۥ).
      if (v.description.startsWith('بوجهين') ||
          v.description.startsWith('بخلف') ||
          v.description.contains('بحذف المد'))
        '${v.word - from}:faces:${_descriptionKey(v.description)}',
      if (_yaIdafa(v) case final ya? when ya != _hafsYa(ayah, v.word))
        '${v.word - from}:ya:$ya',
    ],
  ]..sort();
  // A silah is told in the usul: no difference of the word here, or Hafs would
  // be noted against Abu Ja'far in «تُفَٰدُوهُمۡ» when another reads it otherwise.
  // So the silah of the ha (عَمِلَتۡهُۥ): Ibn Kathir's word is the others'.
  // And two hamzas of a word eased (ءَا۬عۡجَمِيّٞ of Qalun, with the idkhal):
  // told in their usul, no farsh beside the others'.
  final applied = withoutHaSilah(
    _apply(
      ayah,
      rows
          .where(
            (v) =>
                !v.stopOnly &&
                !(v.rule == 'tasheel_word' && v.text.contains('۬')),
          )
          .toList(),
      from,
      to,
    ).replaceAll(RegExp('مُۥٓ?(?=[ۖ-ۜ]*( |\$))'), 'مۡ'),
  );
  // Hafs's alif marked ۠ (ٱلظُّنُونَا۠) is dropped in wasl only: a reading
  // without it at all (ٱلظُّنُونَ) differs from him when stopping.
  final ownWords = applied.split(' ');
  final noStopAlif = [
    for (var w = from; w < to; w++)
      if (RegExp(r'ا[ً-ٰ]*۠[ۖ-ۭ]*$').hasMatch(ayah.words[w]) &&
          w - from < ownWords.length &&
          !RegExp(r'ا[ً-ٰ۠-ۭ]*$').hasMatch(ownWords[w - from]))
        '${w - from}:no-stop-alif',
    // A letter of the rasm left unread (رَءُو۟فٞ: its waw) where Hafs reads it.
    for (var w = from; w < to; w++)
      if (w - from < ownWords.length &&
          '۟'.allMatches(ownWords[w - from]).length >
              '۟'.allMatches(ayah.words[w]).length)
        '${w - from}:unread-letter',
    // Hafs's sad with the small sin (ٱلۡمُصَۣيۡطِرُونَ) is read with either; a
    // plain sad is that one way only.
    for (var w = from; w < to; w++)
      if (RegExp('ص[ً-ْ]*[ۣۜ]').hasMatch(ayah.words[w]) &&
          w - from < ownWords.length &&
          RegExp('ص(?![ً-ْ]*[ۣۜ])').hasMatch(ownWords[w - from]))
        '${w - from}:sad-only',
  ];
  return '${readingTextKey(applied, baseline: ayah.words.sublist(from, to).join(' '))}#${[...unresolved, ...noStopAlif].join(';')}';
}

/// The displayed narrator's own rules at [word] that [id] does not read:
/// [compareReadings] looks only from [id] to the displayed one, so a reader
/// with no row (Hafs, al-Bazzi in «وَٱلصَّٰبِـِٔينَ») would seem to read as him.
List<Variant> displayedRulesNotReadBy({
  required VariantRepository repository,
  required Ayah ayah,
  required int word,
  required String? displayed,
  required String id,
}) {
  final own = _rows(
    repository,
    id,
    ayah,
    word,
    word + 1,
  ).where((v) => v.isUsul).map(readingVariantKey).toSet();
  return [
    for (final v in _rows(repository, displayed, ayah, word, word + 1))
      if (v.isUsul &&
          !v.isMarginNote &&
          !v.readsAsHafs &&
          !own.contains(readingVariantKey(v)))
        v,
  ];
}

/// What to cite for [readings]: a word with a farsh is cited for its farsh
/// alone, every reader's, not for the usul in it (يَضِرۡكُمُۥ: not its silah;
/// يُجۡبَىٰٓ: not Ibn Kathir's qasr).
List<Variant> citedReadings(List<Variant> readings) {
  bool farsh(Variant v) => !v.isUsul && v.rule != 'comparison';
  final withFarsh = {
    for (final v in readings)
      if (farsh(v)) v.word,
  };
  return [
    for (final v in readings)
      if (!v.isUsul || !withFarsh.contains(v.word)) v,
  ];
}

/// The body of a word as written: a hamza on a seat is its seat, a hamza alone
/// a letter of its own. A rule that adds or drops a letter changes it
/// (ٱلنَّبِيٓـِٕينَ); a naql, an ibdal, an idgham, a silah or a madd do not.
String _bodyKey(String text) => text
    .replaceAll('ٰ', 'ا')
    .replaceAll(RegExp('[ٱآأإ]'), 'ا')
    .replaceAll('ؤ', 'و')
    .replaceAll(RegExp('[ئىیے]'), 'ي')
    // A hamza on the line or on a kashida, no seat of its own.
    .replaceAll(RegExp('ـ[ً-ٓ]*[ٕٔ]'), 'ء')
    .replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');

/// A rule of the displayed reader that changes the body of a word (النَّبِيٓـِٕينَ،
/// يَاتِي، لَبِتُّ): a reader who does not read by it has another word, shown in
/// the hamesh with what he reads. Only there: the word keeps its colour on the
/// page, as the rule's.
List<Variant> otherBodyNotes(
  VariantRepository repository,
  Ayah ayah,
  int word,
  String? displayed,
  Iterable<String> ids,
  List<Variant> told,
) {
  if (displayed == null || word >= ayah.words.length) return const [];
  final rules = _rows(repository, displayed, ayah, word, word + 1).where(
    (v) =>
        v.isUsul &&
        !v.isMarginNote &&
        !v.readsAsHafs &&
        !v.stopOnly &&
        v.text.isNotEmpty &&
        v.word == word &&
        v.count == 1 &&
        v.rule != 'ya_zaida' &&
        !v.rule.startsWith('naql') &&
        !v.description.contains('نقل') &&
        !v.rule.startsWith('tasheel') &&
        // A hamza eased: its body is not told by the letters written for it.
        !RegExp('[۪۬]').hasMatch(v.text) &&
        !RegExp('تسهيل|تخفيف').hasMatch(v.description),
  );
  if (rules.isEmpty) return const [];
  // An idgham too: its letter merged, told by the shadda it leaves.
  int shaddas(String t) => RegExp('ّ').allMatches(t).length;
  // A hamza added on a seat of the word's own letter (أَنۢبِئَآءَ، هُزُؤٗا).
  int hamzas(String t) => RegExp('[ءأإآؤئٕٔ]').allMatches(t).length;
  bool changes(Variant v, String other) =>
      _bodyKey(v.text) != _bodyKey(other) ||
      v.rule == 'hamza_zaida' && hamzas(v.text) > hamzas(other) ||
      v.rule.startsWith('idgham') &&
          shaddas(v.text.substring(1)) != shaddas(other.substring(1)) ||
      // «أَنَا» read with its alif joined, where the other drops it (أَنَا۠).
      _anaMaddDropped(v, other);

  return [
    for (final id in ids)
      if (!told.any(
        (v) =>
            v.riwayaId == id &&
            v.inHamesh &&
            v.word <= word &&
            word < v.word + v.count,
      ))
        if (readingText(repository, id, ayah, word, word + 1) case final other
            when other.isNotEmpty && rules.any((v) => changes(v, other)))
          Variant(
            riwayaId: id,
            surah: ayah.surah,
            ayah: ayah.number,
            word: word,
            count: 1,
            text: other,
            kind: VariantKind.farsh,
            rule: 'comparison',
            description: rules.any((v) => _anaMaddDropped(v, other))
                ? 'بحذف الألف وصلاً'
                : '',
          ),
  ];
}

/// The displayed reader's «أَنَا» read with its alif joined (مد أنا), the
/// other's written as Hafs's, its alif not read joined (أَنَا۠).
bool _anaMaddDropped(Variant v, String other) =>
    v.rule == 'ana_madd' && other.contains('۠') && !v.text.contains('۠');

/// Everything to cite for the word tapped on the page: the displayed reader's
/// rows, what the others differ in, and, where the word is read otherwise by
/// any of them, every selected reader's own reading, those who read it as Hafs
/// or as the displayed reader too (ٱلۡبُيُوتَ of Abu Ja'far).
List<Variant> wordEvidence({
  required VariantRepository repository,
  required Ayah ayah,
  required int word,
  required String? displayed,
  required Iterable<String> selected,
  required Iterable<String> compared,
}) {
  final out = <Variant>[
    if (displayed != null)
      ...repository.at([displayed], ayah.surah, ayah.number, word),
    ...compareReadings(
      repository: repository,
      ayah: ayah,
      word: word,
      displayed: displayed,
      selected: compared,
    ),
  ];
  final ids = {
    ?displayed,
    ...selected.where((id) => id == 'hafs' || repository.isLoaded(id)),
    ...compared,
  };
  // A rule that changes the word's body (وَيَسۡتَنۢبُونَكَ without its hamza)
  // is cited as a farsh is: every reader with his own reading, as the hamesh
  // writes the others' word beside it.
  bool changesBody(String id) => otherBodyNotes(
    repository,
    ayah,
    word,
    id,
    ids.where((other) => other != id),
    const [],
  ).isNotEmpty;
  final lexical = {
    for (final id in ids)
      id: [
        for (final v in _rows(repository, id, ayah, word, word + 1))
          if (_lexical(v) ||
              v.word == word &&
                  v.isUsul &&
                  v.text.isNotEmpty &&
                  !v.isMarginNote &&
                  !v.readsAsHafs &&
                  !v.stopOnly &&
                  changesBody(id))
            v,
      ],
  };
  if (lexical.values.every((rows) => rows.isEmpty)) return out;
  bool has(String id) => out.any(
    (v) => v.riwayaId == id && (v.inHamesh || v.rule == 'comparison'),
  );
  for (final id in ids) {
    for (final v in lexical[id]!) {
      if (!out.contains(v)) out.add(v);
    }
    if (!has(id) && lexical[id]!.isEmpty) {
      out.add(
        Variant(
          riwayaId: id,
          surah: ayah.surah,
          ayah: ayah.number,
          word: word,
          count: 1,
          text: readingText(repository, id, ayah, word, word + 1),
          kind: VariantKind.farsh,
          rule: 'comparison',
        ),
      );
    }
  }
  return out;
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
  bool sharedWrittenIdgham(Variant v) {
    if (!_writtenIdgham(v)) {
      return false;
    }
    final from = v.word, to = v.word + v.count;
    final actual = readingText(repository, displayed, ayah, from, to);
    final hafs = ayah.words.sublist(from, to).join(' ');
    return readingTextKey(actual, baseline: hafs) ==
            readingTextKey(v.text, baseline: hafs) &&
        readingTextKey(actual, baseline: hafs) != readingTextKey(hafs);
  }

  final result = <Variant>[
    for (final id in ids)
      for (final v in _rows(repository, id, ayah, word, word + 1))
        if (v.isMarginNote ||
            v.isUsul &&
                !baseRules.contains(readingVariantKey(v)) &&
                !sharedWrittenIdgham(v))
          v,
  ];

  // Overlapping spans must be compared as one unit. Adjacent independent
  // words keep their own notes, as in فجزاء / مثل.
  var from = word, to = word + 1;
  var expanded = true;
  final narrators = {displayed ?? 'hafs', ...ids};
  bool joinsFarsh(Variant v) =>
      _ibnAmirIdgham(v) &&
      _rows(
        repository,
        v.riwayaId,
        ayah,
        v.word,
        v.word + v.count,
      ).any((o) => o != v && _lexical(o) && !_writtenIdgham(o));
  while (expanded) {
    expanded = false;
    for (final id in narrators) {
      for (final v in _rows(repository, id, ayah, from, to).where(_lexical)) {
        if (v.word < 0 || v.word + v.count > ayah.words.length) continue;
        if (joinsFarsh(v)) continue;
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
      id: _rows(repository, id, ayah, from, to)
          .where(_lexical)
          .where(
            (v) => !joinsFarsh(v) || v.word >= from && v.word + v.count <= to,
          )
          .toList(),
  };
  if (lexical.values.every((rows) => rows.isEmpty)) return result;
  final baseKey = _lexicalKey(
    ayah,
    _rows(repository, displayed, ayah, from, to),
    from,
    to,
  );
  for (final id in ids) {
    final own = lexical[id]!;
    if (_lexicalKey(ayah, _rows(repository, id, ayah, from, to), from, to) ==
        baseKey) {
      continue;
    }
    if (own.length == 1 &&
        own.single.word == from &&
        own.single.count == to - from) {
      if (!result.contains(own.single)) result.add(own.single);
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
        description: <String>{
          ...own.map((v) => v.description).where((d) => d.isNotEmpty),
          // What the shown riwaya leaves out, this one reads (هُوَ, الحديد 24).
          if (own.isEmpty)
            for (final v in lexical[displayed ?? 'hafs'] ?? const <Variant>[])
              if (v.description == 'بحذف هو') 'بزيادة هو',
        }.join('، '),
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
