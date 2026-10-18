import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/quran.dart';
import 'mushaf_decor.dart';
import 'theme.dart';

/// Builds the widget for one word at the given font size.
typedef WordBuilder = Widget Function(Ayah ayah, int word, double fontSize);

/// What a Hafs word shows on the line: its text and font, or null when the
/// word is not shown (read as part of a longer replacement before it).
typedef WordDisplay = ({String text, String font})? Function(
  Ayah ayah,
  int word,
);

/// One line as laid out: a surah banner or basmala ([block]), or words.
typedef MushafRow = ({MushafLine? block, List<(Ayah, int)> words});

/// How a page is laid out in a box: its lines, the font size and the height
/// of each line, and the line each word is on.
class MushafLayout {
  MushafLayout._(this.rows, this.fontSize, this.lineHeight)
    : lineOf = {
        for (final (i, row) in rows.indexed)
          for (final (a, w) in row.words)
            VariantRepository.key(a.surah, a.number, w): i,
      };

  final List<MushafRow> rows;
  final double fontSize;
  final double lineHeight;

  /// Line index by word key ([VariantRepository.key]).
  final Map<int, int> lineOf;
}

/// A mushaf page filling its box, as one page of a mushaf printed for the
/// screen: the page's words (exactly those of the Madinah page) wrapped into
/// justified lines at the largest font that fills the height, in bold ink.
///
/// With [printed], the lines are those of the Madinah print instead: every
/// line starts and ends with the same words as the printed page, at the
/// largest font at which the longest line fits the width.
class MushafLines extends StatelessWidget {
  const MushafLines({
    super.key,
    required this.lines,
    required this.centered,
    required this.quran,
    required this.wordBuilder,
    required this.height,
    this.printed = false,
    this.display,
    this.marker,
  });

  final List<MushafLine> lines;
  final bool centered;
  final QuranRepository quran;
  final WordBuilder wordBuilder;

  /// The lines are spread evenly over this height, like a printed page.
  final double height;

  /// Keep the 15 lines of the Madinah print.
  final bool printed;

  /// Defaults to the Hafs word in the Hafs font.
  final WordDisplay? display;

  /// The ayah-end ornament; defaults to the number in the Hafs font.
  final ({String text, String font})? Function(Ayah ayah)? marker;

  ({String text, String font}) _marker(Ayah ayah) =>
      marker?.call(ayah) ??
      (text: ' ${_ayahMarker(ayah.number)}', font: 'Hafs');

  static const _probe = 20.0;

  /// Line pitch over font size of the wrapped page: the lines are close,
  /// as on a printed page, with room for the marks above and below.
  static const _pitch = 1.9;

  ({String text, String font})? _show(Ayah ayah, int w) =>
      display == null ? (text: ayah.words[w], font: 'Hafs') : display!(ayah, w);

  /// The layout of the page in [width] × [height].
  MushafLayout layout(double width) {
    if (printed || lines.isEmpty) {
      final rows = [
        for (final line in lines)
          switch (line) {
            TextLine(:final words) => (block: null, words: words),
            _ => (block: line, words: const <(Ayah, int)>[]),
          },
      ];
      final fit = _fitFontSize(rows, width);
      final lineHeight = rows.isEmpty ? height : height / rows.length;
      return MushafLayout._(rows, math.min(fit, lineHeight / 1.75), lineHeight);
    }
    // The largest font at which the wrapped lines fill no more than the
    // height (more lines as the font grows).
    var lo = 8.0, hi = math.min(width / 7, height / _pitch);
    var rows = _wrap(width, lo);
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      final r = _wrap(width, mid);
      if (r.length * mid * _pitch <= height) {
        lo = mid;
        rows = r;
      } else {
        hi = mid;
      }
    }
    return MushafLayout._(rows, lo, height / rows.length);
  }

  /// Width of a word at the probe size, with its ayah-end ornament when it
  /// closes the ayah; null when it is not shown.
  double? _itemWidth(Ayah ayah, int w) {
    final shown = _show(ayah, w);
    final closes = w == ayah.words.length - 1;
    if (shown == null && !closes) return null;
    var width = shown == null ? 0.0 : _measure(shown.text, shown.font);
    if (closes) {
      final end = _marker(ayah);
      width += _measure(end.text, end.font);
    }
    return width;
  }

  /// Space between words at the probe size.
  double _gap(Ayah ayah, int w) =>
      math.max(_measure(' ', _show(ayah, w)?.font ?? 'Hafs'), _probe * 0.25);

  /// The page's words wrapped into lines of [width] at [fontSize]; the
  /// surah banners and basmalas keep a line each.
  List<MushafRow> _wrap(double width, double fontSize) {
    final scale = fontSize / _probe;
    final rows = <MushafRow>[];
    var words = <(Ayah, int)>[];
    var used = 0.0;
    void flush() {
      if (words.isNotEmpty) rows.add((block: null, words: words));
      words = [];
      used = 0;
    }

    for (final line in lines) {
      if (line is! TextLine) {
        flush();
        rows.add((block: line, words: const []));
        continue;
      }
      for (final (a, w) in line.words) {
        final item = _itemWidth(a, w);
        if (item == null) {
          words.add((a, w)); // not shown, but on this line for the hamesh
          continue;
        }
        // A gap for every word (centred and closing lines pad each word),
        // plus a pixel: laid-out text widths are rounded up.
        final add = (item + _gap(a, w)) * scale + 1;
        if (used > 0 && used + add > width * 0.99) flush();
        used += add;
        words.add((a, w));
      }
    }
    flush();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final page = layout(constraints.maxWidth);
        final fontSize = page.fontSize;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in page.rows.indexed)
              SizedBox(
                height: page.lineHeight,
                child: switch (row.block) {
                  SurahNameLine(:final surah) => SurahBanner(
                    title: 'سورة ${quran.surah(surah).nameAr}',
                    fontSize: fontSize * 0.95,
                    height: null,
                  ),
                  BasmalaLine() => Center(
                    child: Text(
                      quran.basmala,
                      textDirection: TextDirection.rtl,
                      style: _style(fontSize, 'Hafs'),
                    ),
                  ),
                  _ => _textRow(
                    row.words,
                    fontSize,
                    // A wrapped line closing the page or a surah keeps its
                    // natural spacing instead of being spread to the edge.
                    justified:
                        !centered &&
                        (printed ||
                            (i + 1 < page.rows.length &&
                                page.rows[i + 1].block == null)),
                  ),
                },
              ),
          ],
        );
      },
    );
  }

  Widget _textRow(
    List<(Ayah, int)> words,
    double fontSize, {
    required bool justified,
  }) {
    final items = [for (final (ayah, w) in words) ?_item(ayah, w, fontSize)];
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : justified
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: justified
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(horizontal: fontSize * 0.12),
            child: item,
          ),
      ],
    );
  }

  /// A word, followed by the ayah-end marker when it closes its ayah.
  Widget? _item(Ayah ayah, int w, double fontSize) {
    final shown = _show(ayah, w) != null;
    final closes = w == ayah.words.length - 1;
    if (!shown && !closes) return null;
    final end = _marker(ayah);
    final marker = Text(
      end.text,
      textDirection: TextDirection.rtl,
      style: _style(fontSize, end.font),
    );
    if (!shown) return marker;
    final word = wordBuilder(ayah, w, fontSize);
    if (!closes) return word;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [word, marker],
    );
  }

  /// Largest font size at which every printed line fits in [width] with the
  /// font's own word spacing. The printed-mushaf fonts are made so that
  /// every full line then fills the width, as in the print: the words keep
  /// their natural spacing instead of being spread apart.
  double _fitFontSize(List<MushafRow> rows, double width) {
    var widest = 0.0;
    for (final row in rows) {
      if (row.block != null) continue;
      var w = 0.0;
      var items = 0;
      String? font;
      for (final (ayah, i) in row.words) {
        final item = _itemWidth(ayah, i);
        if (item == null) continue;
        w += item;
        font ??= _show(ayah, i)?.font;
        items++;
      }
      // Word spacing: the font's space; centred lines pad every word.
      w += centered
          ? items * _probe * 0.25
          : math.max(0, items - 1) *
                math.max(_measure(' ', font ?? 'Hafs'), _probe * 0.08);
      widest = math.max(widest, w);
    }
    if (widest == 0) return width / 16;
    // A small margin for rounding between measured and laid-out glyphs;
    // Al-Fatiha and the start of Al-Baqarah have short, centred lines.
    return math.min(_probe * width * 0.995 / widest, width / 13);
  }

  static final _cache = <String, double>{};

  static double _measure(String text, String font) =>
      _cache.putIfAbsent('$font|$text', () {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _style(_probe, font)),
          textDirection: TextDirection.rtl,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });

  static TextStyle _style(double size, String font) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: FontWeight.bold,
    height: 1.0,
    color: MushafColors.ink,
    shadows: inkSpread(MushafColors.ink, size),
  );
}

String _ayahMarker(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
