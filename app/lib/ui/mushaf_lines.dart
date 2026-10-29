import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/arabic.dart';
import '../data/quran_repository.dart';
import '../models/quran.dart';
import 'mushaf_decor.dart';
import 'theme.dart';
import 'partition_marker.dart';
import 'hafs_font_marks.dart';

/// Builds the widget for one word at the given font size, drawn out by
/// [kashida] tatweels where its letters join.
typedef WordBuilder = Widget Function(
  Ayah ayah,
  int word,
  double fontSize,
  int kashida,
);

/// What a Hafs word shows on the line: its text and font, or null when the
/// word is not shown (read as part of a longer replacement before it).
typedef WordDisplay = ({String text, String font})? Function(
  Ayah ayah,
  int word,
);

/// A mushaf page drawn line by line exactly as printed: every line starts and
/// ends with the same words as the Madinah mushaf and is justified edge to
/// edge. The font size is the largest at which the longest line still fits.
class MushafLines extends StatelessWidget {
  const MushafLines({
    super.key,
    required this.lines,
    required this.centered,
    required this.quran,
    required this.wordBuilder,
    this.display,
    this.marker,
    this.wordMarker,
    this.height,
  });

  final List<MushafLine> lines;
  final bool centered;
  final QuranRepository quran;
  final WordBuilder wordBuilder;

  /// Defaults to the Hafs word in the Hafs font.
  final WordDisplay? display;

  /// The ayah-end ornament; defaults to the number in the Hafs font.
  final ({String text, String font})? Function(Ayah ayah)? marker;
  final ({String text, String font})? Function(Ayah ayah, int word)? wordMarker;

  ({String text, String font}) _marker(Ayah ayah) =>
      marker?.call(ayah) ??
      (text: ' ${_ayahMarker(ayah.number)}', font: 'Hafs');

  ({String text, String font})? _end(Ayah ayah, int word) => wordMarker != null
      ? wordMarker!(ayah, word)
      : word == ayah.words.length - 1
      ? _marker(ayah)
      : null;

  /// When given, the lines are spread evenly over this height (the page
  /// fills the screen, like a printed mushaf); otherwise each line is as
  /// tall as its text needs.
  final double? height;

  /// Font size and line height for [width] (and [height] when given).
  ({double fontSize, double lineHeight}) metrics(double width) {
    final fit = _fitFontSize(width);
    if (height == null || lines.isEmpty) {
      return (fontSize: fit, lineHeight: fit * 2.05);
    }
    // A line of the print each; the Shamarly surah headers take two.
    final lineHeight = height! / lines.fold(0, (n, l) => n + l.span);
    return (fontSize: math.min(fit, lineHeight / 1.45), lineHeight: lineHeight);
  }

  static const _probe = 20.0;

  ({String text, String font})? _show(Ayah ayah, int w) =>
      display == null ? (text: ayah.words[w], font: 'Hafs') : display!(ayah, w);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (:fontSize, :lineHeight) = metrics(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              SizedBox(
                height: lineHeight * line.span,
                child: switch (line) {
                  SurahNameLine(:final surah) => SurahBanner(
                    title: 'سورة ${quran.surah(surah).nameAr}',
                    fontSize: fontSize * 0.95,
                    height: null,
                  ),
                  BasmalaLine() => Center(
                    child: InkText(
                      quran.basmala,
                      style: _style(fontSize, 'Hafs'),
                    ),
                  ),
                  TextLine(:final words, centered: final short) => _textLine(
                    words,
                    fontSize,
                    constraints.maxWidth,
                    short,
                  ),
                },
              ),
          ],
        );
      },
    );
  }

  Widget _textLine(
    List<(Ayah, int)> words,
    double pageSize,
    double width, [
    bool short = false,
  ]) {
    // Every word and line shares the page's font size. The longest line
    // has already constrained that size in _fitFontSize.
    final fontSize = pageSize;
    final centered = this.centered || short;
    final kashida = centered
        ? const <int, int>{}
        : _kashida(words, fontSize, width);
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        for (final (i, (ayah, w)) in words.indexed)
          if (_item(ayah, w, fontSize, kashida[i] ?? 0) case final item?)
            Padding(
              padding: centered
                  ? EdgeInsets.symmetric(horizontal: fontSize * 0.12)
                  : EdgeInsets.zero,
              child: item,
            ),
      ],
    );
  }

  /// How many kashidas each word of a justified line takes (by its index in
  /// [words]): the room the line leaves at [fontSize] is filled by drawing
  /// out the joins of its longest words in the Hafs font, as the print
  /// does, rather than by spreading the words apart.
  Map<int, int> _kashida(
    List<(Ayah, int)> words,
    double fontSize,
    double width,
  ) {
    final scale = fontSize / _probe;
    var natural = 0.0;
    var items = 0;
    final slots = <int, int>{};
    final lengths = <int, int>{};
    String? stretchFont;
    for (final (i, (ayah, w)) in words.indexed) {
      final shown = _show(ayah, w);
      if (shown != null) {
        natural += _measure(shown.text, shown.font) * scale;
        if (w == 0 && (ayah.rubStart != null || ayah.juzStart)) {
          natural += _measure('۞', 'Hafs') * .8 * scale;
        }
        items++;
        // Letters to draw out, not the page glyphs of the Madinah print.
        if (!shown.font.startsWith('QCF_')) {
          stretchFont ??= shown.font;
          final letters = lettersOf(shown.text);
          final n = kashidaSlots(letters).length;
          if (n > 0) {
            slots[i] = n;
            lengths[i] = letters.length;
          }
        }
      }
      if (_end(ayah, w) case final end?) {
        natural += _measure(end.text, end.font) * scale;
      }
    }
    if (slots.isEmpty) return const {};
    // Words keep at least a narrow space between them.
    natural += math.max(0, items - 1) * fontSize * 0.18;
    final tatweelWidth = _measure(tatweel, stretchFont ?? 'Hafs') * scale;
    if (tatweelWidth <= 0) return const {};
    var count = ((width * 0.985 - natural) / tatweelWidth).floor();
    if (count <= 0) return const {};
    // As the print: one or two words drawn out, the longest first, at one
    // join each; more joins only on a line with much room.
    final order = slots.keys.toList()
      ..sort((a, b) => lengths[b]!.compareTo(lengths[a]!));
    final out = <int, int>{};
    for (var joins = 1; count > 0 && joins <= 1; joins++) {
      for (final i in order) {
        if (count == 0) break;
        final int most = kashidaPerJoin * math.min(joins, slots[i]!);
        final int add = math.min(count, most - (out[i] ?? 0));
        if (add <= 0) continue;
        out[i] = (out[i] ?? 0) + add;
        count -= add;
      }
    }
    return out;
  }

  /// A word, followed by the ayah-end marker when it closes its ayah.
  Widget? _item(Ayah ayah, int w, double fontSize, int kashida) {
    final shown = _show(ayah, w) != null;
    final end = _end(ayah, w);
    final closes = end != null;
    if (!shown && !closes) return null;
    final marker = InkText(
      end?.text ?? '',
      style: _style(fontSize, end?.font ?? 'Hafs'),
      firmness: 0.35,
    );
    if (!shown) return marker;
    Widget word = wordBuilder(ayah, w, fontSize, kashida);
    if (w == 0 && (ayah.rubStart != null || ayah.juzStart)) {
      word = Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          PartitionMarker(
            key: ValueKey('partition:${ayah.surah}:${ayah.number}'),
            ayah: ayah,
            fontSize: fontSize,
          ),
          word,
        ],
      );
    }
    if (!closes) return word;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [word, marker],
    );
  }

  /// Largest font size at which every text line fits in [width] with the
  /// font's own word spacing. The printed-mushaf fonts are made so that
  /// every full line then fills the width, as in the print: the words keep
  /// their natural spacing instead of being spread apart.
  double _fitFontSize(double width) {
    final widths = [
      for (final line in lines)
        if (line is TextLine) _naturalWidth(line.words),
    ].where((w) => w > 0).toList()..sort();
    if (widths.isEmpty) return width / 16;
    // Fit the longest printed line once for the entire page; shrinking
    // individual lines would make adjacent words appear different sizes.
    final widest = widths.last;
    final size = _probe * width * 0.995 / widest;
    // Al-Fatiha and the start of Al-Baqarah have short, centred lines.
    return math.min(size, width / 13);
  }

  /// Width of [words] at the probe size with the font's own word spacing
  /// (centred lines pad every word).
  double _naturalWidth(List<(Ayah, int)> words) {
    var w = 0.0;
    var items = 0;
    String? font;
    for (final (ayah, i) in words) {
      final shown = _show(ayah, i);
      if (shown != null) {
        w += _measure(shown.text, shown.font);
        if (i == 0 && (ayah.rubStart != null || ayah.juzStart)) {
          w += _measure('۞', 'Hafs') * .8;
        }
        font ??= shown.font;
        items++;
      }
      if (_end(ayah, i) case final end?) {
        w += _measure(end.text, end.font);
      }
    }
    return w +
        (centered
            ? items * _probe * 0.25
            : math.max(0, items - 1) *
                  math.max(_measure(' ', font ?? 'Hafs'), _probe * 0.08));
  }

  static final _cache = <String, double>{};

  static double _measure(String text, String font) =>
      _cache.putIfAbsent('$font|$text', () {
        final painter = TextPainter(
          text: TextSpan(
            text: font == 'Hafs' ? HafsFontMarks.boundarySpacing(text) : text,
            style: _style(_probe, font),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });

  static TextStyle _style(double size, String font) => TextStyle(
    fontFamily: font,
    fontSize: size,
    height: 1.0,
    color: MushafColors.ink,
  );
}

String _ayahMarker(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
