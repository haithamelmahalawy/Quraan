import 'dart:math' as math;

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

/// The motif along the frame's band.
enum FrameMotif {
  rosette,
  star,
  diamond,
  ring,
  flower,
  dots,
  leaf,
  square,
  chevron,
  knot,
}

/// Whom a look of the mushaf suits, its name among them.
enum MushafAudience {
  all('الكل'),
  girls('للبنات'),
  kids('للأطفال'),
  men('للرجال');

  const MushafAudience(this.nameAr);

  final String nameAr;
}

/// A look of the mushaf the reader picks (the user, 2026-11-14): its frame,
/// the motif along it, and the page and the screen around it. The reading
/// colours stay the same in all, their meaning with them.
enum MushafStyle {
  madinah(
    'المدينة',
    FrameMotif.rosette,
    paper: Color(0xFFFBF6E6),
    page: Color(0xFFFFFCF3),
    band: Color(0xFFF6DADF),
    motif: Color(0xFFB5475B),
    accent: Color(0xFFC9A54E),
  ),
  emerald(
    'زمرّدي',
    FrameMotif.star,
    paper: Color(0xFFF1F4EC),
    page: Color(0xFFFBFCF5),
    band: Color(0xFFD9E8DC),
    motif: Color(0xFF2E6B53),
    accent: Color(0xFFB8963E),
  ),
  lapis(
    'لازوردي',
    FrameMotif.diamond,
    paper: Color(0xFFF0F3F7),
    page: Color(0xFFFCFCF9),
    band: Color(0xFFDCE5F0),
    motif: Color(0xFF2D4E7A),
    accent: Color(0xFFC2A15A),
  ),
  antique(
    'عتيق',
    FrameMotif.ring,
    paper: Color(0xFFEFE5D1),
    page: Color(0xFFF8F0DE),
    band: Color(0xFFE4D2B3),
    motif: Color(0xFF7A4E2D),
    accent: Color(0xFFA8843F),
  ),
  violet(
    'بنفسجي هادئ',
    FrameMotif.flower,
    paper: Color(0xFFF5F1F6),
    page: Color(0xFFFDFBFC),
    band: Color(0xFFE9DEEE),
    motif: Color(0xFF6E4A7E),
    accent: Color(0xFFBFA05A),
  ),
  calm(
    'هادئ',
    FrameMotif.dots,
    paper: Color(0xFFEEF1EE),
    page: Color(0xFFFAFBF8),
    band: Color(0xFFE3E9E4),
    motif: Color(0xFF5F7369),
    accent: Color(0xFF9DAA9F),
  ),
  turquoise(
    'فيروزي',
    FrameMotif.knot,
    paper: Color(0xFFEEF5F4),
    page: Color(0xFFFBFDFC),
    band: Color(0xFFD4EBE8),
    motif: Color(0xFF1F7A78),
    accent: Color(0xFFC6A55A),
  ),
  burgundy(
    'عنّابي',
    FrameMotif.leaf,
    paper: Color(0xFFF6F0EE),
    page: Color(0xFFFEFBF8),
    band: Color(0xFFEFDCDD),
    motif: Color(0xFF7B2D3B),
    accent: Color(0xFFC29A4E),
  ),
  olive(
    'زيتوني',
    FrameMotif.square,
    paper: Color(0xFFF2F2E8),
    page: Color(0xFFFCFCF4),
    band: Color(0xFFE5E8D0),
    motif: Color(0xFF5E6B2E),
    accent: Color(0xFFB59A4A),
  ),
  sand(
    'رملي',
    FrameMotif.chevron,
    paper: Color(0xFFF6EFE3),
    page: Color(0xFFFDF8EE),
    band: Color(0xFFF0E1C8),
    motif: Color(0xFFA0703A),
    accent: Color(0xFF8C6A3E),
  ),
  ink(
    'حِبري',
    FrameMotif.star,
    paper: Color(0xFFEFF1F5),
    page: Color(0xFFFBFBFA),
    band: Color(0xFFDEE2EA),
    motif: Color(0xFF2B3A55),
    accent: Color(0xFFB89A5C),
  ),
  // The page lighter than the screen and the hamesh around it, its frame
  // deep, its motifs gold; the page and the hamesh light enough for their
  // words to read clearly (the user, 2026-11-14).
  pinkBook(
    'وردي',
    FrameMotif.flower,
    paper: Color(0xFFF3E0E6),
    page: Color(0xFFFFFAF8),
    band: Color(0xFFA9566F),
    motif: Color(0xFFFBE3EC),
    accent: Color(0xFFF2C46B),
  ),
  royal(
    'ملكي',
    FrameMotif.star,
    paper: Color(0xFFDCE3EE),
    page: Color(0xFFFFFDF6),
    band: Color(0xFF1F2F4F),
    motif: Color(0xFFD9B865),
    accent: Color(0xFFE8CF8A),
  ),
  emeraldDeep(
    'زمرّد غامق',
    FrameMotif.rosette,
    paper: Color(0xFFDDEBE3),
    page: Color(0xFFFDFCF4),
    band: Color(0xFF0F4D3A),
    motif: Color(0xFFD6B45E),
    accent: Color(0xFFE6CD86),
  ),
  burgundyDeep(
    'عنّابي ملكي',
    FrameMotif.leaf,
    paper: Color(0xFFF0E1DF),
    page: Color(0xFFFFFAF4),
    band: Color(0xFF5A1A2A),
    motif: Color(0xFFD7B266),
    accent: Color(0xFFE9CE8C),
  ),
  walnut(
    'بني ذهبي',
    FrameMotif.ring,
    paper: Color(0xFFEBE0CE),
    page: Color(0xFFFCF6E8),
    band: Color(0xFF3E2A1C),
    motif: Color(0xFFD4AE5E),
    accent: Color(0xFFE6C987),
  ),
  tile(
    'كاشي فيروزي',
    FrameMotif.diamond,
    paper: Color(0xFFDCEDEB),
    page: Color(0xFFFFFEF8),
    band: Color(0xFF0E6E6E),
    motif: Color(0xFFF4F1E4),
    accent: Color(0xFFE2C275),
  ),
  // For girls, for children and for men (the user, 2026-11-14). The
  // children's: cheerful colours alone, the page white and the motifs the
  // mushaf's own, nothing to lessen its reverence.
  lilac(
    'ليلكي',
    FrameMotif.flower,
    audience: MushafAudience.girls,
    paper: Color(0xFFF0E9F2),
    page: Color(0xFFFFFCFA),
    band: Color(0xFF9A7FA6),
    motif: Color(0xFFFCEFFF),
    accent: Color(0xFFE9C77A),
  ),
  peach(
    'خوخي',
    FrameMotif.rosette,
    audience: MushafAudience.girls,
    paper: Color(0xFFF5E9E2),
    page: Color(0xFFFFFBF7),
    band: Color(0xFFCF9C88),
    motif: Color(0xFFFFF1EA),
    accent: Color(0xFFD8AE58),
  ),
  blossom(
    'زهري',
    FrameMotif.leaf,
    audience: MushafAudience.girls,
    paper: Color(0xFFFCE6ED),
    page: Color(0xFFFFF9FB),
    band: Color(0xFFF4BFD0),
    motif: Color(0xFFB0476E),
    accent: Color(0xFFC9A04E),
  ),
  kidsSky(
    'سماء صافية',
    FrameMotif.star,
    audience: MushafAudience.kids,
    paper: Color(0xFFE3EFF6),
    page: Color(0xFFFFFEF9),
    band: Color(0xFF6FA4C8),
    motif: Color(0xFFFFFFFF),
    accent: Color(0xFFF5C542),
  ),
  kidsGarden(
    'بستان',
    FrameMotif.flower,
    audience: MushafAudience.kids,
    paper: Color(0xFFE6F0E2),
    page: Color(0xFFFFFEF8),
    band: Color(0xFF79A97F),
    motif: Color(0xFFFFF7D6),
    accent: Color(0xFFF2B84B),
  ),
  kidsSun(
    'مشمس',
    FrameMotif.rosette,
    audience: MushafAudience.kids,
    paper: Color(0xFFF8EFDC),
    page: Color(0xFFFFFDF6),
    band: Color(0xFFD2AD72),
    motif: Color(0xFFFFFFFF),
    accent: Color(0xFF4A9FD8),
  ),
  charcoal(
    'فحمي',
    FrameMotif.star,
    audience: MushafAudience.men,
    paper: Color(0xFFE3E5E8),
    page: Color(0xFFFCFCFA),
    band: Color(0xFF353B43),
    motif: Color(0xFFC9A86A),
    accent: Color(0xFF9AA3AD),
  ),
  desert(
    'صحراوي',
    FrameMotif.square,
    audience: MushafAudience.men,
    paper: Color(0xFFECE2D0),
    page: Color(0xFFFCF7EC),
    band: Color(0xFF6B5A44),
    motif: Color(0xFFE2CDA4),
    accent: Color(0xFFC7A96E),
  ),
  forest(
    'غابة',
    FrameMotif.knot,
    audience: MushafAudience.men,
    paper: Color(0xFFE0E8E1),
    page: Color(0xFFFBFCF7),
    band: Color(0xFF2E4A3A),
    motif: Color(0xFFC8B27A),
    accent: Color(0xFFA9BFAE),
  );

  const MushafStyle(
    this.nameAr,
    this.motifShape, {
    this.audience = MushafAudience.all,
    required this.paper,
    required this.page,
    required this.band,
    required this.motif,
    required this.accent,
  });

  final String nameAr;
  final FrameMotif motifShape;

  /// Whom it suits: all, or girls, children or men.
  final MushafAudience audience;

  /// The look saved by [name]; Madinah's when none is.
  static MushafStyle named(String name) =>
      values.asNameMap()[name] ?? MushafStyle.madinah;

  /// The screen around the page and the page itself, in the light.
  final Color paper;
  final Color page;

  /// The frame: its band, the motif along it, and its rules and dots.
  final Color band;
  final Color motif;
  final Color accent;

  /// The frame's colours on [p]: in the dark, the band sunk into the page
  /// and the motif lightened.
  ({Color band, Color motif, Color accent}) frameOn(MushafPalette p) =>
      p.brightness == Brightness.dark
      ? (
          band: Color.lerp(motif, p.page, 0.8)!,
          motif: Color.lerp(motif, const Color(0xFFFFFFFF), 0.32)!,
          accent: Color.lerp(accent, p.page, 0.1)!,
        )
      : (band: band, motif: motif, accent: accent);

  /// [p] with this look's screen and page, in the light.
  MushafPalette on(MushafPalette p) => p.brightness == Brightness.dark
      ? p
      : MushafPalette(
          brightness: p.brightness,
          paper: paper,
          page: page,
          ink: p.ink,
          frame: p.frame,
          green: p.green,
          gold: p.gold,
          goldLight: p.goldLight,
          rose: p.rose,
          roseLight: p.roseLight,
          multi: p.multi,
        );
}

/// The palette in use; set from the app theme (see [MushafColors.use]).
abstract final class MushafColors {
  static MushafPalette _p = MushafPalette.light;
  static MushafStyle _style = MushafStyle.madinah;

  static void use(
    Brightness brightness, [
    MushafStyle style = MushafStyle.madinah,
  ]) {
    _style = style;
    _p = style.on(
      brightness == Brightness.dark ? MushafPalette.dark : MushafPalette.light,
    );
  }

  /// The look of the mushaf in use.
  static MushafStyle get style => _style;

  /// The frame's colours, of the look in use.
  static ({Color band, Color motif, Color accent}) get frameColors =>
      _style.frameOn(_p);

  /// Words in the frame's colours on the page (a surah's name in its
  /// banner): the darker of them on a light page, the lighter on a dark
  /// one, so that they read (a deep frame's gold motif was lost on white,
  /// the user, 2026-11-14).
  static Color get frameInk {
    final f = frameColors;
    final motifDarker = f.motif.computeLuminance() < f.band.computeLuminance();
    final own = isDark == motifDarker ? f.band : f.motif;
    // Drawn towards the ink till it reads easily on the page (a soft blue
    // frame's name was faint).
    double contrast(Color c) {
      final a = c.computeLuminance(), b = _p.page.computeLuminance();
      return (math.max(a, b) + .05) / (math.min(a, b) + .05);
    }

    for (var t = 0.0; t <= 1; t += .1) {
      final c = Color.lerp(own, _p.ink, t)!;
      if (contrast(c) >= 4.5) return c;
    }
    return _p.ink;
  }

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
    if (style.fontFamily == 'Hafs' &&
        (hafsDrawable(text) != text ||
            (parts?.any((p) => hafsDrawable(p.$1) != p.$1) ?? false))) {
      return InkText(
        hafsDrawable(text),
        style: style,
        firmness: firmness,
        parts: parts == null
            ? null
            : [for (final (s, c) in parts!) (hafsDrawable(s), c)],
        glowFinalAlif: glowFinalAlif,
        glowStrength: glowStrength,
      );
    }
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
