import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';
import 'package:qiraat_mushaf/ui/word_swap.dart';

/// Another riwaya chosen: only the words it changes move, as the reader
/// chose (the user, 2026-11-25).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;

  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    mutashabihat = await MutashabihatRepository.load();
    await variants.ensureLoaded(variants.available);
  });

  test('faded at first in the app, still in tests', () {
    expect(ReaderSettings.memory().wordSwap, WordSwap.none);
  });

  for (final style in [WordSwap.fade, WordSwap.slide, WordSwap.flip]) {
    testWidgets('switching the riwaya swaps only the changed words: $style', (
      t,
    ) async {
      t.view.physicalSize = const Size(1080, 2000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final settings = ReaderSettings.memory(selected: {'khallad', 'shubah'})
        ..displayed = 'khallad'
        ..wordSwap = style;
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(MushafPalette.light),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              // Built again on every change, as the reader screen does.
              body: ListenableBuilder(
                listenable: settings,
                builder: (_, _) => MushafPage(
                  page: 2,
                  quran: quran,
                  variants: variants,
                  mutashabihat: mutashabihat,
                  settings: settings,
                  onWordTap: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      int moving() => find
          .descendant(
            of: find.byType(WordSwapper),
            matching: find.byType(KeyedSubtree),
          )
          .evaluate()
          .length;
      final still = moving();
      settings.displayed = 'shubah';
      await t.pump();
      await t.pump(WordSwapper.duration ~/ 2);
      // The old word and the new one together, for the changed words only.
      final during = moving();
      expect(during, greaterThan(still));
      expect(during - still, lessThan(still));
      await t.pumpAndSettle();
      expect(moving(), still);
    });
  }
}
