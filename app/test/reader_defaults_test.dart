import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reader opened for the first time: the lamp lit, the mutashabihat not
/// shaded, the light mushaf, Hafs among the riwayat (the user, 2026-11-15).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'first opened: the lamp lit, no mutashabihat, the light mushaf',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await ReaderSettings.load();
      expect(s.diffAlert, DiffAlert.glow);
      expect(s.showMutashabihat, isFalse);
      expect(s.themeMode, ThemeMode.light);
      expect(s.compareHafs, isTrue);
      // The reader's own choice kept: the lamp put out stays out.
      s.diffAlert = null;
      expect(s.diffAlert, isNull);
      final again = await ReaderSettings.load();
      expect(again.diffAlert, isNull);
    },
  );
}
