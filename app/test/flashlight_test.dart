import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/flashlight.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reader_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

/// «الكشاف» dragged over a word read otherwise shows its panel of every
/// chosen riwaya's difference (the user, 2026-11-26).
void main() {
  modes();
  ten();
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
    // The lamp held is its body; the beam above it.
    final gesture = await t.startGesture(from);
    // In small steps, as a finger moves, toward where the beam's lowest light
    // (at the lens) is on the word: any part of the beam lights it (the
    // user, 2026-11-26).
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
    // Off the word, to the page's top: put away at once (the user,
    // 2026-11-26).
    final off = await t.startGesture(t.getCenter(lamp));
    for (var i = 0; i < 40; i++) {
      await off.moveBy(const Offset(0, -20));
      await t.pump();
    }
    await off.up();
    await t.pump();
    expect(find.byKey(const ValueKey('flashlight-panel')), findsNothing);
    // Held: the three ways, the chosen one kept (the user, 2026-11-26).
    await t.longPress(lamp);
    await t.pumpAndSettle();
    for (final mode in FlashMode.values) {
      expect(find.byKey(ValueKey('flash-mode:${mode.name}')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('flash-mode:shown')));
    await t.pumpAndSettle();
    expect(s.flashMode, FlashMode.shown);
    expect(t.takeException(), isNull);
  });
}

/// The flashlight's modes: «يَكۡذِبُونَ» (البقرة ١٠), Hafs shown, Ibn Dhakwan's
/// farsh: nothing of the shown alone, the hamesh's with all and the hamesh
/// (the user, 2026-11-26).
void modes() {
  test('the modes filter the panel', () async {
    final mushafs = await Mushafs.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['khallad', 'ibn_dhakwan']);
    final quran = mushafs.of(MushafEdition.madani);
    final s = ReaderSettings.memory(selected: {'khallad', 'ibn_dhakwan'});
    Widget? panel(FlashMode mode) {
      s.flashMode = mode;
      return flashlightPanel(
        ayah: quran.ayah(2, 10),
        word: 11,
        quran: quran,
        variants: variants,
        settings: s,
        onWordTap: (_, _) {},
      );
    }

    expect(panel(FlashMode.all), isNotNull);
    expect(panel(FlashMode.hamesh), isNotNull);
    expect(panel(FlashMode.shown), isNull);
  });
}

/// «العشر»: every riwaya of the ten, chosen or not (the user, 2026-11-26).
void ten() {
  testWidgets('«العشر» tells the readers not chosen', (t) async {
    late Mushafs mushafs;
    late VariantRepository variants;
    await t.runAsync(() async {
      await (FontLoader(
        'Hafs',
      )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
      mushafs = await Mushafs.load();
      variants = await VariantRepository.discover();
      await variants.ensureLoaded(variants.available);
    });
    final quran = mushafs.of(MushafEdition.madani);
    final s = ReaderSettings.memory(selected: {'khallad', 'ibn_dhakwan'})
      ..flashMode = FlashMode.ten;
    final panel = flashlightPanel(
      ayah: quran.ayah(2, 10),
      word: 11,
      quran: quran,
      variants: variants,
      settings: s,
      onWordTap: (_, _) {},
    );
    expect(panel, isNotNull);
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(child: SingleChildScrollView(child: panel)),
        ),
      ),
    );
    // Nafi', Ibn Kathir and the others, not chosen, read «يُكَذِّبُونَ»,
    // grouped by their qari.
    expect(find.textContaining('نافع', findRichText: true), findsWidgets);
    // The chosen ones left as they were.
    expect(s.selected, {'khallad', 'ibn_dhakwan'});
  });
}
