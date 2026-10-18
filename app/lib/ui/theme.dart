import 'package:flutter/material.dart';

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

  static void use(Brightness brightness) => _p =
      brightness == Brightness.dark ? MushafPalette.dark : MushafPalette.light;

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

  /// A qiraa colour adjusted for the background (lighter on dark pages).
  static Color tone(Color c) =>
      isDark ? Color.lerp(c, const Color(0xFFFFFFFF), 0.38)! : c;
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
