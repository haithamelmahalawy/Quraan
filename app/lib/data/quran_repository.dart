import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran.dart';

/// A printed mushaf whose pages and lines the Hafs text follows.
enum MushafEdition {
  /// The Madinah mushaf (KFGQPC), 604 pages.
  madani('مصحف المدينة'),

  /// The Shamarly mushaf, the Egyptian print, 522 pages (from page 2).
  shamarly('مصحف الشمرلي');

  const MushafEdition(this.nameAr);
  final String nameAr;
}

/// Hafs base text, organised by the pages of a printed mushaf ([edition])
/// and, when the layout is available, by the 15 lines of each page.
class QuranRepository {
  QuranRepository._(
    this.edition,
    this.surahs,
    this._pages,
    this._lines,
    this._centered,
    this._pageOf, {
    required this.firstPage,
  });

  final MushafEdition edition;
  final List<Surah> surahs;
  final List<List<Ayah>> _pages;
  final List<List<MushafLine>>? _lines;
  final Set<int> _centered;
  final Map<(int, int), int> _pageOf;

  /// The number of the first page (the Shamarly print opens on page 2).
  final int firstPage;
  int get lastPage => firstPage + _pages.length - 1;
  int get pageCount => _pages.length;

  /// Ayahs on [page], in order; an ayah running over a page is on both.
  List<Ayah> page(int page) => _pages[page - firstPage];

  /// The printed lines of [page], or null without layout data.
  List<MushafLine>? lines(int page) => _lines?[page - firstPage];

  /// Pages whose lines are centred rather than justified (Al-Fatiha and the
  /// start of Al-Baqarah).
  bool isCentered(int page) => _centered.contains(page);

  /// The page the mushaf opens on at the right, as it lies open: its first
  /// page and every other one after it.
  bool isRightPage(int page) => (page - firstPage).isEven;

  /// The page where an ayah starts.
  int pageOf(int surah, int ayah) => _pageOf[(surah, ayah)]!;

  Surah surah(int number) => surahs[number - 1];

  /// Ayah [number] of [surah].
  Ayah ayah(int surah, int number) =>
      page(pageOf(surah, number))
          .firstWhere((a) => a.surah == surah && a.number == number);

  /// The basmala as written at the start of Al-Fatiha.
  String get basmala => _pages[0].first.words.join(' ');

  static Future<QuranRepository> load([
    AssetBundle? bundle,
    MushafEdition edition = MushafEdition.madani,
  ]) async {
    final b = bundle ?? rootBundle;
    Future<String?> optional(String key) =>
        b.loadString(key).then<String?>((s) => s, onError: (_) => null);
    final raw = await b.loadString('assets/data/quran.json');
    if (edition == MushafEdition.shamarly) {
      return parseShamarly(
          raw, (await optional('assets/data/layout_shamarly.json'))!);
    }
    final (layout, qcf) = await (
      optional('assets/data/layout.json'),
      optional('assets/data/qcf_v2.json'),
    ).wait;
    return parse(raw, layout, qcf);
  }

  static List<Surah> _surahs(Map<String, dynamic> json) => [
        for (final s in json['surahs'] as List)
          Surah(
            number: s['n'] as int,
            nameAr: s['ar'] as String,
            nameEn: s['en'] as String,
            ayahCount: s['ayahs'] as int,
            startPage: s['page'] as int,
          ),
      ];

  static List<Ayah> _ayahs(Map<String, dynamic> json) => [
        for (final a in json['ayahs'] as List)
          Ayah(
            surah: a[0] as int,
            number: a[1] as int,
            page: a[2] as int,
            juz: a[3] as int,
            words: (a[4] as String).split(' '),
          ),
      ];

  /// The Madinah mushaf: every page ends with an ayah.
  static QuranRepository parse(String raw, [String? layout, String? qcf]) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final surahs = _surahs(json);
    final ayahs = _ayahs(json);
    final pages = List.generate(604, (_) => <Ayah>[]);
    final glyphs = qcf == null
        ? null
        : (jsonDecode(qcf) as Map<String, dynamic>)['ayahs'] as List;
    for (final (i, ayah) in ayahs.indexed) {
      if (glyphs != null) {
        ayah
          ..glyphs = (glyphs[i][0] as List).cast<String>()
          ..endGlyph = glyphs[i][1] as String;
      }
      pages[ayah.page - 1].add(ayah);
    }
    final pageOf = {for (final a in ayahs) (a.surah, a.number): a.page};
    final (lines, centered) = layout == null
        ? (null, <int>{})
        : _layout(layout, 1, (p) => pages[p - 1]);
    return QuranRepository._(
        MushafEdition.madani, surahs, pages, lines, centered, pageOf,
        firstPage: 1);
  }

  /// The Shamarly mushaf (layout from tool/shamarly): its pages are made of
  /// the words on their lines, and may start or end inside an ayah.
  static QuranRepository parseShamarly(String raw, String layout) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final ayahs = _ayahs(json);
    final index = {for (final (i, a) in ayahs.indexed) (a.surah, a.number): i};
    final data = jsonDecode(layout) as Map<String, dynamic>;
    final first = data['first'] as int;
    final pageList = data['pages'] as List;

    // Each page: the ayahs from its first word to its last.
    final pages = <List<Ayah>>[];
    final pageOf = <(int, int), int>{};
    for (final (p, page) in pageList.indexed) {
      final refs = [
        for (final l in page as List)
          if (l is List && l[0] == 'a') l.skip(1).cast<int>().toList(),
      ];
      final from = index[(refs.first[0], refs.first[1])]!;
      final to = index[(refs.last[3], refs.last[4])]!;
      pages.add(ayahs.sublist(from, to + 1));
      for (var i = from; i <= to; i++) {
        // The page where the ayah starts: its first word is on it.
        if (i > from || refs.first[2] == 0) {
          pageOf.putIfAbsent((ayahs[i].surah, ayahs[i].number), () => first + p);
        }
      }
    }
    final surahs = [
      for (final s in _surahs(json))
        Surah(
          number: s.number,
          nameAr: s.nameAr,
          nameEn: s.nameEn,
          ayahCount: s.ayahCount,
          startPage: pageOf[(s.number, 1)]!,
        ),
    ];
    final (lines, centered) = _layout(layout, first, (p) => pages[p - first]);
    return QuranRepository._(
        MushafEdition.shamarly, surahs, pages, lines, centered, pageOf,
        firstPage: first);
  }

  /// The lines of every page of a layout file (assets/data/layout.json).
  static (List<List<MushafLine>>, Set<int>) _layout(
      String layout, int first, List<Ayah> Function(int page) ayahsOf) {
    final centered = <int>{};
    final lines = <List<MushafLine>>[];
    final pageList =
        (jsonDecode(layout) as Map<String, dynamic>)['pages'] as List;
    for (var p = 0; p < pageList.length; p++) {
      final ayahs = ayahsOf(first + p);
      final out = <MushafLine>[];
      for (final line in pageList[p] as List) {
        if (line == 'c') {
          centered.add(first + p);
          continue;
        }
        final l = line as List;
        switch (l[0]) {
          case 's':
            out.add(SurahNameLine(l[1] as int, span: l.length > 2 ? l[2] as int : 1));
          case 'b':
            out.add(BasmalaLine(l[1] as int));
          case 'e':
            out.add(const TextLine([]));
          case 'a':
            final ref = l.skip(1).cast<int>().toList();
            out.add(TextLine(_words(
                ayahs, (ref[0], ref[1], ref[2]), (ref[3], ref[4], ref[5]))));
        }
      }
      lines.add(out);
    }
    return (lines, centered);
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

  /// The printed lines it takes.
  int get span => 1;
}

class SurahNameLine extends MushafLine {
  const SurahNameLine(this.surah, {this.span = 1});
  final int surah;

  /// Two lines in the Shamarly print.
  @override
  final int span;
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

/// The printed mushafs the app shows, with the same Hafs text.
class Mushafs {
  Mushafs(this.madani, this.shamarly);

  final QuranRepository madani, shamarly;

  QuranRepository of(MushafEdition edition) =>
      edition == MushafEdition.shamarly ? shamarly : madani;

  static Future<Mushafs> load([AssetBundle? bundle]) async {
    final (madani, shamarly) = await (
      QuranRepository.load(bundle),
      QuranRepository.load(bundle, MushafEdition.shamarly),
    ).wait;
    return Mushafs(madani, shamarly);
  }

  /// The page of [to] for [page] of [from]: where the first ayah starting
  /// on that page starts.
  int convert(int page, MushafEdition from, MushafEdition to) {
    final source = of(from);
    final ayahs = source.page(page);
    final a = ayahs.firstWhere(
      (a) => source.pageOf(a.surah, a.number) == page,
      orElse: () => ayahs.first,
    );
    return of(to).pageOf(a.surah, a.number);
  }
}
