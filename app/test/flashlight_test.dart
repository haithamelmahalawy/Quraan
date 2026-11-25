import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/flashlight.dart';
import 'package:qiraat_mushaf/ui/reader_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

/// «الكشاف» dragged over a word read otherwise shows its panel of every
/// chosen riwaya's difference (the user, 2026-11-26).
void main() {
  testWidgets('the flashlight over a differing word', (t) async {
    late Mushafs mushafs;
    late VariantRepository variants;
    late MutashabihatRepository mut;
    await t.runAsync(() async {
      await (FontLoader(
        'Hafs',
      )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
      mushafs = await Mushafs.load();
      variants = await VariantRepository.discover();
      mut = await MutashabihatRepository.load();
      await variants.ensureLoaded(['khallad', 'ibn_dhakwan']);
    });
    t.view.physicalSize = const Size(412, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = ReaderSettings.memory(selected: {'khallad', 'ibn_dhakwan'})
      ..page = 3;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ReaderScreen(
            mushafs: mushafs,
            variants: variants,
            mutashabihat: mut,
            settings: s,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final lamp = find.byKey(const ValueKey('flashlight'));
    expect(lamp, findsOneWidget);
    expect(find.byKey(const ValueKey('flashlight-panel')), findsNothing);
    // «يَكۡذِبُونَ» (البقرة ١٠): Khallad and Ibn Dhakwan read it otherwise.
    final word = find.byWidgetPredicate(
      (w) =>
          w is MetaData &&
          w.metaData is WordTag &&
          (w.metaData as WordTag).ayah.number == 10 &&
          (w.metaData as WordTag).word == 11,
    );
    expect(word, findsOneWidget);
    final target = t.getCenter(word);
    final from = t.getCenter(lamp);
    // The beam's tip is above the lamp's head.
    final gesture = await t.startGesture(from);
    // In small steps, as a finger moves, toward where the beam's tip (its
    // top, at its middle) is on the word.
    for (var i = 0; i < 120; i++) {
      final at = t.getTopLeft(lamp);
      final tip = at + const Offset(Flashlight.width / 2, 1);
      final left = target - tip;
      if (left.distance < 1) break;
      await gesture.moveBy(
        left.distance > 12 ? left / left.distance * 12 : left,
      );
      await t.pump();
    }
    await gesture.up();
    await t.pump();
    expect(find.byKey(const ValueKey('flashlight-panel')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flashlight-panel')),
        matching: find.textContaining('ابن ذكوان'),
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
}
