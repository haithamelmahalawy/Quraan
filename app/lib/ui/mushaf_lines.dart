import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../models/quran.dart';
import 'mushaf_decor.dart';
import 'theme.dart';

/// Builds the widget for one word at the given font size.
typedef WordBuilder = Widget Function(Ayah ayah, int word, double fontSize);

/// What a Hafs word shows on the line: its text and font, or null when the
/// word is not shown (read as part of a longer replacement before it).
typedef WordDisplay = ({String text, String font})? Function(Ayah ayah, int word);

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

  ({String text, String font}) _marker(Ayah ayah) =>
      marker?.call(ayah) ?? (text: ' ${_ayahMarker(ayah.number)}', font: 'Hafs');

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
    final lineHeight = height! / lines.length;
    return (fontSize: math.min(fit, lineHeight / 1.75), lineHeight: lineHeight);
  }

  static const _probe = 20.0;

  ({String text, String font})? _show(Ayah ayah, int w) =>
      display == null ? (text: ayah.words[w], font: 'Hafs') : display!(ayah, w);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final (:fontSize, :lineHeight) = metrics(constraints.maxWidth);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            SizedBox(
              height: lineHeight,
              child: switch (line) {
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
                TextLine(:final words) => Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: centered
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      for (final (ayah, w) in words)
                        if (_item(ayah, w, fontSize) case final item?)
                          Padding(
                            padding: centered
                                ? EdgeInsets.symmetric(
                                    horizontal: fontSize * 0.12)
                                : EdgeInsets.zero,
                            child: item,
                          ),
                    ],
                  ),
              },
            ),
        ],
      );
    });
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

  /// Largest font size at which every text line fits in [width] with at
  /// least a small gap between words.
  double _fitFontSize(double width) {
    var widest = 0.0;
    for (final line in lines) {
      if (line is! TextLine) continue;
      var w = 0.0;
      var items = 0;
      for (final (ayah, i) in line.words) {
        final shown = _show(ayah, i);
        if (shown != null) {
          w += _measure(shown.text, shown.font);
          items++;
        }
        if (i == ayah.words.length - 1) {
          final end = _marker(ayah);
          w += _measure(end.text, end.font);
        }
      }
      // Minimum word gap (and the padding of centred lines).
      w += items * _probe * 0.25;
      widest = math.max(widest, w);
    }
    if (widest == 0) return width / 16;
    // 2% margin for rounding between measured and laid-out glyphs; Al-Fatiha
    // and the start of Al-Baqarah have short, centred lines.
    return math.min(_probe * width * 0.98 / widest, width / 13);
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
        height: 1.0,
        color: MushafColors.ink,
      );
}

String _ayahMarker(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
