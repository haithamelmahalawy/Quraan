import 'package:flutter/material.dart';

abstract final class MushafColors {
  static const paper = Color(0xFFFBF6E6);
  static const ink = Color(0xFF1B1B1B);
  static const frame = Color(0xFF8D6E3F);

  /// Ornament colours of the Madinah mushaf border and surah banners.
  static const green = Color(0xFF2F6B4F);
  static const gold = Color(0xFFC9A54E);
  static const goldLight = Color(0xFFE9D9A6);

  /// Word read differently by more than one of the selected qiraat.
  static const multi = Color(0xFF37474F);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MushafColors.green,
    surface: MushafColors.paper,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: MushafColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: MushafColors.paper,
      foregroundColor: MushafColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
  );
}
