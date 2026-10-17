import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../models/quran.dart';
import 'mushaf_decor.dart';
import 'theme.dart';

/// Builds the widget for one Hafs word at the given font size.
typedef WordBuilder = Widget Function(Ayah ayah, int word, double fontSize);

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
  });

  final List<MushafLine> lines;
  final bool centered;
  final QuranRepository quran;
  final WordBuilder wordBuilder;

  static const _probe = 20.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final fontSize = _fitFontSize(width);
      final lineHeight = fontSize * 2.05;
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
                      style: _style(fontSize),
                    ),
                  ),
                TextLine(:final words) => Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: centered
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      for (final (ayah, w) in words)
                        Padding(
                          padding: centered
                              ? EdgeInsets.symmetric(horizontal: fontSize * 0.12)
                              : EdgeInsets.zero,
                          child: _item(ayah, w, fontSize),
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
  Widget _item(Ayah ayah, int w, double fontSize) {
    final word = wordBuilder(ayah, w, fontSize);
    if (w != ayah.words.length - 1) return word;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        word,
        Text(
          ' ${_ayahMarker(ayah.number)}',
          textDirection: TextDirection.rtl,
          style: _style(fontSize),
        ),
      ],
    );
  }

  /// Largest font size at which every text line fits in [width] with at
  /// least a small gap between words.
  double _fitFontSize(double width) {
    var widest = 0.0;
    for (final line in lines) {
      if (line is! TextLine) continue;
      var w = 0.0;
      for (final (ayah, i) in line.words) {
        w += _measure(ayah.words[i]);
        if (i == ayah.words.length - 1) {
          w += _measure(' ${_ayahMarker(ayah.number)}');
        }
      }
      // Minimum word gap (and the padding of centred lines).
      w += line.words.length * _probe * 0.25;
      widest = math.max(widest, w);
    }
    if (widest == 0) return width / 16;
    // Al-Fatiha and the start of Al-Baqarah have short, centred lines.
    // 2% margin for rounding between measured and laid-out glyphs.
    return math.min(_probe * width * 0.98 / widest, width / 13);
  }

  static final _cache = <String, double>{};

  static double _measure(String text) => _cache.putIfAbsent(text, () {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _style(_probe)),
          textDirection: TextDirection.rtl,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });

  static TextStyle _style(double size) => TextStyle(
        fontFamily: 'Hafs',
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
