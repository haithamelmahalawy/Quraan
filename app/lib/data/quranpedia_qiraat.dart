import 'dart:math' as math;

import '../models/quran.dart';
import 'arabic.dart' as arabic;

/// Converts the qiraat of Quranpedia (الموسوعة القرآنية) onto the Hafs words.
///
/// Used by `tool/build_quranpedia.dart` to build the offline files of the
/// riwayat that have no KFGQPC text, from Quranpedia's official qiraat dump
/// (https://quranpedia.net/dumps), whose licence allows use inside apps.
/// Each ayah is in the shape of `GET /v1/ayah/{surah}/{ayah}/qiraat`.
class QuranpediaQiraat {
  static const source = 'الموسوعة القرآنية (quranpedia.net)';

  /// Quranpedia rawi id -> riwaya id of the catalogue.
  static const riwayaOf = {
    1: 'qalun', 2: 'warsh', 3: 'bazzi', 4: 'qunbul', 5: 'duri_abuamr', //
    6: 'susi', 7: 'hisham', 8: 'ibn_dhakwan', 9: 'shubah', 10: 'hafs',
    11: 'khalaf_hamzah', 12: 'khallad', 13: 'abul_harith', 14: 'duri_kisai',
    15: 'ibn_wardan', 16: 'ibn_jammaz', 17: 'ruways', 18: 'rawh',
    19: 'ishaq', 20: 'idris',
  };

  /// Converts a Quranpedia qiraat response into variants against the Hafs
  /// words of [ayah]. A reading across the ayah's end or start is split over
  /// it and the [previous] or [next] ayah, when given.
  /// [unmatched] is told of each entry whose words are not found.
  static List<Variant> convert(
    Ayah ayah,
    Object? json, {
    Ayah? previous,
    Ayah? next,
    void Function(Object entry)? unmatched,
  }) {
    final out = <Variant>[];
    final here = _Words(ayah);
    var from = 0;
    for (final entry in (json as List? ?? const [])) {
      final spans = _locate(
        here,
        entry['ayah_word'] as String? ?? '',
        from,
        previous: previous == null ? null : _Words(previous),
        next: next == null ? null : _Words(next),
      );
      if (spans == null) {
        // A word this text spells too differently.
        unmatched?.call(entry);
        continue;
      }
      final primary = spans.firstWhere((s) => s.words == here);
      from = primary.at + primary.count;
      // Hafs's own reading in this entry, written like the others.
      final hafsText = [
        for (final reading in entry['qiraat'] as List)
          if ((reading['rewayat'] as List).any(
            (r) => riwayaOf[(r['rawi'] as Map)['id']] == 'hafs',
          ))
            split((reading['qiraa_text'] as String).trim()).$1,
      ].firstOrNull;

      for (final reading in entry['qiraat'] as List) {
        final rewayat = [
          for (final r in reading['rewayat'] as List)
            riwayaOf[(r['rawi'] as Map)['id']],
        ];
        if (rewayat.contains('hafs')) continue; // the base text itself
        final (text, description) = split(
          (reading['qiraa_text'] as String).trim(),
        );
        for (final (span, part) in _assign(spans, primary, text, hafsText)) {
          final hafs = span.words.skeletons.sublist(
            span.at,
            span.at + span.count,
          );
          final kind = kindOf(part, description, hafs.join());
          for (final id in rewayat.whereType<String>()) {
            out.add(
              Variant(
                riwayaId: id,
                surah: span.words.ayah.surah,
                ayah: span.words.ayah.number,
                word: span.at,
                count: span.count,
                text: part,
                description: description,
                kind: kind,
              ),
            );
          }
        }
      }
    }
    return out;
  }

  /// The spans a reading's [text] goes on, with its words for each: across
  /// two ayahs, each part that differs from Hafs goes on its own ayah
  /// (الرَّحِيمِ مَلِكِ: مَلِكِ on مَٰلِكِ of the next ayah; مَرْفِقاً وَتَرَى:
  /// مَرْفِقاً on مِّرۡفَقٗا of the previous one); a reading that differs in
  /// neither part (an idgham, a ghunna) stays on the [primary] span. Parts
  /// are compared with [hafsText], Hafs's reading written the same way, or
  /// else by their letters with the KFGQPC words.
  static List<(_Span, String)> _assign(
    List<_Span> spans,
    _Span primary,
    String text,
    String? hafsText,
  ) {
    final words = text.split(RegExp(r'\s+'));
    if (spans.length == 1 || text.isEmpty || words.length != spans.last.to) {
      return [(primary, text)];
    }
    final hafsWords = hafsText?.split(RegExp(r'\s+'));
    bool differs(_Span s) {
      final part = words.sublist(s.from, s.to);
      if (hafsWords != null && hafsWords.length == words.length) {
        String plain(List<String> ws) => ws.join(' ').replaceAll('ـ', '');
        return plain(part) != plain(hafsWords.sublist(s.from, s.to));
      }
      return _spelling(part.join()) !=
          _spelling(s.words.ayah.words.sublist(s.at, s.at + s.count).join());
    }

    final differing = [
      for (final s in spans)
        if (differs(s)) (s, words.sublist(s.from, s.to).join(' ')),
    ];
    return differing.isNotEmpty
        ? differing
        : [(primary, words.sublist(primary.from, primary.to).join(' '))];
  }

  /// Letters with the alefs (dagger and wasla alef too, which [skeleton]
  /// drops), to tell مَٰلِكِ from مَلِكِ.
  static String _spelling(String words) {
    final b = StringBuffer();
    for (final c in words.runes) {
      if (c == 0x0670 ||
          c == 0x0671 ||
          c == 0x0623 ||
          c == 0x0625 ||
          c == 0x0622) {
        b.write('ا');
      } else if (c == 0x0649) {
        b.write('ي');
      } else if (c >= 0x0621 && c <= 0x064A && c != 0x0640) {
        b.writeCharCode(c);
      }
    }
    return b.toString();
  }

  /// Where the Quranpedia [words] lie: within the ayah of [here], preferably
  /// from [from] on (entries come in reading order), or across its end (its
  /// first words end it: الرَّحِيمِ مَالِكِ) or its start (its last words
  /// begin it: مِّرْفَقًا وَتَرَى), the rest in [next] or [previous].
  static List<_Span>? _locate(
    _Words here,
    String words,
    int from, {
    _Words? previous,
    _Words? next,
  }) {
    final parts = words.trim().split(RegExp(r'\s+'));
    final whole = here.find(words, from) ?? here.find(words, 0);
    if (whole != null) {
      return [
        (words: here, at: whole.$1, count: whole.$2, from: 0, to: parts.length),
      ];
    }
    for (var n = parts.length - 1; n >= 1; n--) {
      final head = here.find(parts.take(n).join(' '), 0, least: 2);
      if (head != null && head.$1 + head.$2 == here.length) {
        final rest = next?.find(parts.skip(n).join(' '), 0);
        return [
          (words: here, at: head.$1, count: head.$2, from: 0, to: n),
          if (rest != null && rest.$1 == 0)
            (words: next!, at: 0, count: rest.$2, from: n, to: parts.length),
        ];
      }
      final tail = here.find(
        parts.skip(parts.length - n).join(' '),
        0,
        least: 2,
      );
      if (tail != null && tail.$1 == 0) {
        final k = parts.length - n;
        final rest = previous?.find(parts.take(k).join(' '), 0);
        return [
          if (rest != null && rest.$1 + rest.$2 == previous!.length)
            (words: previous, at: rest.$1, count: rest.$2, from: 0, to: k),
          (words: here, at: 0, count: tail.$2, from: k, to: parts.length),
        ];
      }
    }
    return null;
  }

  static String _loose(String skeleton) =>
      skeleton.replaceAll(RegExp('[وي]'), '');

  /// First run of Hafs words from [from] whose letters spell [phrase]
  /// (word breaks may differ: يَٰعِبَادِ / يَا عِبَادِ); (index, word count).
  static (int, int)? _find(List<String> hafs, String phrase, int from) {
    if (phrase.isEmpty) return null;
    for (var i = from; i < hafs.length; i++) {
      var joined = '';
      for (var k = i; k < hafs.length && joined.length < phrase.length; k++) {
        joined += hafs[k];
        if (joined == phrase) return (i, k - i + 1);
      }
    }
    return null;
  }

  /// "(تَدْعُونَ) بالتاء" → reading "تَدْعُونَ", description "بالتاء";
  /// "يُكَذِّبون" → the reading alone; "بالإمالة" → the description alone.
  static (String, String) split(String raw) {
    final m = RegExp(r'^\(+([^()]+)\)+\s*(.*)$').firstMatch(raw);
    if (m != null) return (m[1]!.trim(), m[2]!.trim());
    return isDescription(raw) ? ('', raw) : (raw, '');
  }

  /// "بالإمالة", "بإسكان الهاء", "تشديد الذال" describe a reading;
  /// "يُكَذِّبون" is the reading itself.
  static bool isDescription(String text) =>
      RegExp(r'[0-9٠-٩]').hasMatch(text) ||
      RegExp(
        r'^(ب(ال|إ|ا|ضم|فتح|كسر|رفع|جزم|ين|غير|حذف|ترك|تنوين|تسهيل|تحقيق|تشديد|تخفيف|صلة|قصر|مد|نقل|سكت|روم|إشمام|همز)'
        r'|تشديد|تخفيف|إمالة|ادغام|إدغام|مع |دون |وقف|بين )',
      ).hasMatch(text);

  /// Layer of a reading: letters that differ from Hafs make it farsh;
  /// otherwise hamza or recitation rules by its description.
  static VariantKind kindOf(String text, String description, String hafs) {
    if (text.isNotEmpty && skeleton(text) != hafs) return VariantKind.farsh;
    final d = description.isEmpty ? text : description;
    if (RegExp(r'تسهيل|إبدال|بالإبدال|نقل|همزتين|بالهمز|دون همز|بتحقيق|مسهلة')
        .hasMatch(d)) {
      return VariantKind.hamza;
    }
    if (RegExp(
      r'إمالة|تقليل|الفتح|مد|قصر|صلة|إدغام|ادغام|إظهار|سكت|غنة|ترقيق|تفخيم|تغليظ|إشمام|روم',
    ).hasMatch(d)) {
      return VariantKind.usul;
    }
    return VariantKind.farsh;
  }

  /// Bare letters, to match a Quranpedia word against the KFGQPC Hafs word.
  static String skeleton(String word) => arabic.skeleton(word);
}

/// Hafs words of an entry: [count] words of an ayah from [at], on which the
/// entry's words [from] to [to] fall.
typedef _Span = ({_Words words, int at, int count, int from, int to});

/// The Hafs words of an ayah, to find Quranpedia words among them.
class _Words {
  _Words(this.ayah)
    : skeletons = [for (final w in ayah.words) QuranpediaQiraat.skeleton(w)] {
    // The texts spell some words differently, so each comparison is tried
    // in turn: as is; without the small waw and ya of the silah of Hafs
    // (إِنَّهُۥ / إِنَّهُ, بِهِۦ / بِهِ); without any waw and ya (أَدۡرَىٰكُم /
    // أَدْرَاكُم), only on three letters or more, since shorter remains
    // occur anywhere.
    final silah = RegExp('[ۥۦ]');
    _forms = [
      (skeletons, QuranpediaQiraat.skeleton, 1),
      (
        [
          for (final w in ayah.words)
            QuranpediaQiraat.skeleton(w.replaceAll(silah, '')),
        ],
        QuranpediaQiraat.skeleton,
        1,
      ),
      (
        [for (final s in skeletons) QuranpediaQiraat._loose(s)],
        (w) => QuranpediaQiraat._loose(QuranpediaQiraat.skeleton(w)),
        3,
      ),
    ];
  }

  final Ayah ayah;
  final List<String> skeletons;
  late final List<(List<String>, String Function(String), int)> _forms;

  int get length => skeletons.length;

  /// (index, word count) of the first run from [from] that spells [words],
  /// by the first comparison that finds one; at least [least] letters.
  (int, int)? find(String words, int from, {int least = 1}) {
    for (final (list, key, min) in _forms) {
      final p = key(words);
      if (p.length < math.max(min, least)) continue;
      final m = QuranpediaQiraat._find(list, p, from);
      if (m != null) return m;
    }
    return null;
  }
}
