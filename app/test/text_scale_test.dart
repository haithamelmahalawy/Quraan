import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

/// The mushaf lines are fitted unscaled: a phone set to a larger text size
/// (an Honor X7d) drew them past the frame.
void main() {
  testWidgets('a larger system text size keeps the lines inside the frame', (
    t,
  ) async {
    late QuranRepository quran;
    late VariantRepository variants;
    late MutashabihatRepository m;
    await t.runAsync(() async {
      for (final e in {'Hafs': 'hafs.18'}.entries) {
        await (FontLoader(
          e.key,
        )..addFont(rootBundle.load('assets/fonts/${e.value}.ttf'))).load();
      }
      quran = await QuranRepository.load();
      variants = await VariantRepository.discover();
      await variants.ensureLoaded(['warsh']);
      m = await MutashabihatRepository.load();
    });
    t.view.physicalSize = const Size(412, 900);
    t.view.devicePixelRatio = 1;
    final theme = buildTheme(MushafPalette.light);
    await t.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MushafPage(
                page: 522,
                quran: quran,
                variants: variants,
                mutashabihat: m,
                settings: ReaderSettings.memory(
                  selected: {'warsh'},
                  mode: DisplayMode.replace,
                ),
                onWordTap: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // An overflowing line would have thrown.
    expect(t.takeException(), isNull);
  });
}
