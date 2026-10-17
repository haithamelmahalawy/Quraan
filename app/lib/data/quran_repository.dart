import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran.dart';

/// Hafs base text, organised by mushaf page (Madinah mushaf, 604 pages) and,
/// when the layout is available, by the 15 lines of each page.
class QuranRepository {
  QuranRepository._(this.surahs, this._pages, this._lines, this._centered);

  static const pageCount = 604;

  final List<Surah> surahs;
  final List<List<Ayah>> _pages;
  final List<List<MushafLine>>? _lines;
  final Set<int> _centered;

  /// Ayahs on [page] (1-based).
  List<Ayah> page(int page) => _pages[page - 1];

  /// The printed lines of [page], or null without layout data.
  List<MushafLine>? lines(int page) => _lines?[page - 1];

  /// Pages whose lines are centred rather than justified (Al-Fatiha and the
  /// start of Al-Baqarah).
  bool isCentered(int page) => _centered.contains(page);

  Surah surah(int number) => surahs[number - 1];

  /// The basmala as written at the start of Al-Fatiha.
  String get basmala => _pages[0].first.words.join(' ');

  static Future<QuranRepository> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final (raw, layout) = await (
      b.loadString('assets/data/quran.json'),
      b.loadString('assets/data/layout.json').then<String?>((s) => s,
          onError: (_) => null),
    ).wait;
    return parse(raw, layout);
  }

  static QuranRepository parse(String raw, [String? layout]) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final surahs = [
      for (final s in json['surahs'] as List)
        Surah(
          number: s['n'] as int,
          nameAr: s['ar'] as String,
          nameEn: s['en'] as String,
          ayahCount: s['ayahs'] as int,
          startPage: s['page'] as int,
        ),
    ];
    final pages = List.generate(pageCount, (_) => <Ayah>[]);
    for (final a in json['ayahs'] as List) {
      final ayah = Ayah(
        surah: a[0] as int,
        number: a[1] as int,
        page: a[2] as int,
        juz: a[3] as int,
        words: (a[4] as String).split(' '),
      );
      pages[ayah.page - 1].add(ayah);
    }
    if (layout == null) return QuranRepository._(surahs, pages, null, {});

    final centered = <int>{};
    final lines = <List<MushafLine>>[];
    final pageList = (jsonDecode(layout) as Map<String, dynamic>)['pages'] as List;
    for (var p = 0; p < pageList.length; p++) {
      final ayahs = pages[p];
      final out = <MushafLine>[];
      for (final line in pageList[p] as List) {
        if (line == 'c') {
          centered.add(p + 1);
          continue;
        }
        final l = line as List;
        switch (l[0]) {
          case 's':
            out.add(SurahNameLine(l[1] as int));
          case 'b':
            out.add(BasmalaLine(l[1] as int));
          case 'a':
            final ref = l.skip(1).cast<int>().toList();
            out.add(TextLine(_words(
                ayahs, (ref[0], ref[1], ref[2]), (ref[3], ref[4], ref[5]))));
        }
      }
      lines.add(out);
    }
    return QuranRepository._(surahs, pages, lines, centered);
  }

  /// Words of [ayahs] from [from] to [to] inclusive, as (ayah, word index).
  static List<(Ayah, int)> _words(
      List<Ayah> ayahs, (int, int, int) from, (int, int, int) to) {
    final out = <(Ayah, int)>[];
    var inside = false;
    for (final a in ayahs) {
      for (var w = 0; w < a.words.length; w++) {
        if (a.surah == from.$1 && a.number == from.$2 && w == from.$3) {
          inside = true;
        }
        if (inside) out.add((a, w));
        if (a.surah == to.$1 && a.number == to.$2 && w == to.$3) return out;
      }
    }
    return out;
  }
}

/// One printed line of a mushaf page.
sealed class MushafLine {
  const MushafLine();
}

class SurahNameLine extends MushafLine {
  const SurahNameLine(this.surah);
  final int surah;
}

class BasmalaLine extends MushafLine {
  const BasmalaLine(this.surah);
  final int surah;
}

class TextLine extends MushafLine {
  const TextLine(this.words);

  /// The Hafs words on the line, in reading order.
  final List<(Ayah, int)> words;
}
