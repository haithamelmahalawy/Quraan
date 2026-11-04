import 'package:flutter/material.dart';

import 'hafs_font_marks.dart';

/// Colours of one appearance (light or dark) of the mushaf.
class MushafPalette {
  const MushafPalette({
    required this.brightness,
    required this.paper,
    required this.page,
    required this.ink,
    required this.frame,
    required this.green,
    required this.gold,
    required this.goldLight,
    required this.rose,
    required this.roseLight,
    required this.multi,
  });

  final Brightness brightness;

  /// Screen background around the page.
  final Color paper;

  /// Inside of the page frame.
  final Color page;
  final Color ink;
  final Color frame;

  /// Ornament colours of the Madinah mushaf border and surah banners.
  final Color green;
  final Color gold;
  final Color goldLight;

  /// The rose of the printed mushaf border and surah banners.
  final Color rose;
  final Color roseLight;

  /// Word read differently by more than one of the selected qiraat.
  final Color multi;

  static const light = MushafPalette(
    brightness: Brightness.light,
    paper: Color(0xFFFBF6E6),
    page: Color(0xFFFFFCF3),
    ink: Color(0xFF1B1B1B),
    frame: Color(0xFF8D6E3F),
    green: Color(0xFF2F6B4F),
    gold: Color(0xFFC9A54E),
    goldLight: Color(0xFFE9D9A6),
    rose: Color(0xFFB5475B),
    roseLight: Color(0xFFF6DADF),
    multi: Color(0xFF37474F),
  );

  static const dark = MushafPalette(
    brightness: Brightness.dark,
    paper: Color(0xFF101614),
    page: Color(0xFF17201C),
    ink: Color(0xFFEDE5CF),
    frame: Color(0xFFC8A96A),
    green: Color(0xFF5DBB8C),
    gold: Color(0xFFB8933F),
    goldLight: Color(0xFF3A3220),
    rose: Color(0xFFD98495),
    roseLight: Color(0xFF3B2329),
    multi: Color(0xFFB0BEC5),
  );
}

/// The palette in use; set from the app theme (see [MushafColors.use]).
abstract final class MushafColors {
  static MushafPalette _p = MushafPalette.light;

  static void use(Brightness brightness) => _p = brightness == Brightness.dark
      ? MushafPalette.dark
      : MushafPalette.light;

  static bool get isDark => _p.brightness == Brightness.dark;
  static Color get paper => _p.paper;
  static Color get page => _p.page;
  static Color get ink => _p.ink;
  static Color get frame => _p.frame;
  static Color get green => _p.green;
  static Color get gold => _p.gold;
  static Color get goldLight => _p.goldLight;
  static Color get rose => _p.rose;
  static Color get roseLight => _p.roseLight;
  static Color get multi => _p.multi;

  /// Tarqiq of the ra and taghliz of the lam (Warsh): orange.
  static Color get rule => tone(const Color(0xFFE8730C));

  /// A qiraa colour adjusted for the background (lighter on dark pages).
  static Color tone(Color c) =>
      isDark ? Color.lerp(c, const Color(0xFFFFFFFF), 0.38)! : c;
}

/// Mushaf text with a hair of ink around its strokes, so it reads as firmly
/// as the printed page (the ink of the print spreads slightly). The outline
/// is drawn evenly around every letter, so all words have the same weight
/// wherever they fall on the pixels (offset shadows did not).
class InkText extends StatelessWidget {
  const InkText(
    this.text, {
    super.key,
    required this.style,
    this.firmness = 1,
    this.parts,
    this.glowFinalAlif = false,
    this.glowStrength = 0,
  });

  final String text;

  /// The text in parts with their own colour (null: [style]'s), when some
  /// letters are coloured apart from the word. Joins [text].
  final List<(String, Color?)>? parts;
  final bool glowFinalAlif;
  final double glowStrength;

  /// Font, size and colour (ink by default); background and decoration are
  /// drawn once, under the outline.
  final TextStyle style;

  /// Share of the full outline: the fine rings of the ayah-end ornament
  /// fill in with the whole of it.
  final double firmness;

  /// Outline width: how much firmer than the font's own strokes.
  static double weight(double fontSize) => fontSize * 0.025;

  @override
  Widget build(BuildContext context) {
    final small = style.fontFamily == 'Hafs'
        ? smallHamzaAlifParts(parts ?? [(text, null)])
        : null;
    if (small != null) return _drawSmallAlif(small);
    if (style.fontFamily == 'Hafs' &&
        HafsFontMarks.needsAdjustment(parts?.map((p) => p.$1).join() ?? text)) {
      return HafsFontMarks(
        parts: parts ?? [(text, null)],
        style: style,
        builder: (placed) => _draw(context, placed),
      );
    }
    return _draw(context, parts);
  }

  /// The word of [smallHamzaAlifParts], its outline and fill as [_draw]'s.
  Widget _drawSmallAlif(List<(String, Color?, bool)> small) {
    final color = style.color ?? MushafColors.ink;
    final size = style.fontSize ?? 14;
    TextStyle sized(TextStyle s, bool isSmall) => isSmall
        ? s.copyWith(
            fontSize: size * smallHamzaAlifScale,
            height: (style.height ?? 1) / smallHamzaAlifScale,
          )
        : s;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (final (t, c, isSmall) in small)
                TextSpan(
                  text: t,
                  style: sized(
                    TextStyle(
                      fontFamily: style.fontFamily,
                      fontSize: size,
                      height: style.height,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = weight(size) * firmness
                        ..strokeJoin = StrokeJoin.round
                        ..color = c ?? color,
                    ),
                    isSmall,
                  ),
                ),
            ],
          ),
          textDirection: TextDirection.rtl,
        ),
        Text.rich(
          TextSpan(
            style: style.copyWith(color: color),
            children: [
              for (final (t, c, isSmall) in small)
                TextSpan(
                  text: t,
                  style: sized(style.copyWith(color: c ?? color), isSmall),
                ),
            ],
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _draw(BuildContext context, List<(String, Color?)>? parts) {
    final color = style.color ?? MushafColors.ink;
    // QCF glyphs already contain the complete engraved word. A second
    // stroked pass can corrupt their cached glyph masks on GPU backends.
    if (style.fontFamily?.startsWith('QCF_') ?? false) {
      return parts == null
          ? Text(
              text,
              textDirection: TextDirection.rtl,
              style: style.copyWith(color: color),
            )
          : Text.rich(
              TextSpan(
                style: style.copyWith(color: color),
                children: [
                  for (final (s, c) in parts)
                    TextSpan(
                      text: s,
                      style: TextStyle(color: c ?? color),
                    ),
                ],
              ),
              textDirection: TextDirection.rtl,
            );
    }
    TextStyle outline(Color c) => TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      height: style.height,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = weight(style.fontSize ?? 14) * firmness
        ..strokeJoin = StrokeJoin.round
        ..color = c,
    );
    if (parts != null) {
      var glowAt = glowFinalAlif
          ? parts.lastIndexWhere((p) => p.$1.startsWith('ى'))
          : -1;
      if (glowFinalAlif && glowAt < 0) {
        glowAt = parts.lastIndexWhere((p) => p.$1.startsWith('ا'));
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Text.rich(
            TextSpan(
              children: [
                for (final (t, c) in parts)
                  TextSpan(text: t, style: outline(c ?? color)),
              ],
            ),
            textDirection: TextDirection.rtl,
          ),
          Text.rich(
            TextSpan(
              style: style.copyWith(color: color),
              children: [
                for (final (i, (t, c)) in parts.indexed)
                  TextSpan(
                    text: t,
                    style: TextStyle(
                      color: c ?? color,
                      shadows: i == glowAt && glowStrength > 0
                          ? [
                              Shadow(
                                color: (c ?? color).withValues(
                                  alpha: glowStrength * .8,
                                ),
                                blurRadius: 8 * glowStrength,
                              ),
                            ]
                          : null,
                    ),
                  ),
              ],
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(text, textDirection: TextDirection.rtl, style: outline(color)),
        Text(
          text,
          textDirection: TextDirection.rtl,
          style: style.copyWith(color: color),
        ),
      ],
    );
  }
}

ThemeData buildTheme(MushafPalette p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.green,
    brightness: p.brightness,
    surface: p.paper,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: p.brightness,
    scaffoldBackgroundColor: p.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.ink,
      elevation: 0,
      centerTitle: true,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.paper),
  );
}
