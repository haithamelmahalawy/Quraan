import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/audio_numbering.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/recitations.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/services/ayah_player.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/ayah_sheet.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import 'helpers/test_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran, shamarly;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  late Recitations recitations;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    shamarly = await QuranRepository.load(null, MushafEdition.shamarly);
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(variants.available);
    mutashabihat = await MutashabihatRepository.load();
    recitations = await Recitations.load();
  });

  Future<void> settleSheet(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await t.pump();
  }

  Future<void> page(
    WidgetTester t,
    ReaderSettings settings, {
    int number = 1,
    bool landscape = false,
    QuranRepository? repository,
    WordTap? onHold,
  }) async {
    t.view.physicalSize = landscape
        ? const Size(1800, 1000)
        : const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MushafPage(
            page: number,
            quran: repository ?? quran,
            variants: variants,
            mutashabihat: mutashabihat,
            settings: settings,
            qcf: true,
            onWordTap: (_, _) {},
            onAyahWordTap: onHold,
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets(
    'Warsh Fatiha draws seven native ends including the internal split',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..displayed = 'warsh';
      for (final landscape in [false, true]) {
        for (final layout in MarginLayout.values) {
          settings.marginLayout = layout;
          await page(t, settings, landscape: landscape);
          final lines = t
              .widgetList<MushafLines>(find.byType(MushafLines))
              .first;
          expect(lines.wordMarker!(quran.ayah(1, 1), 3), isNull);
          expect(lines.wordMarker!(quran.ayah(1, 2), 3)?.text.trim(), '١');
          expect(lines.wordMarker!(quran.ayah(1, 7), 3)?.text.trim(), '٦');
          final markers = t
              .widgetList<InkText>(find.byType(InkText))
              .where((w) => RegExp(r'^[٠-٩]+$').hasMatch(w.text.trim()))
              .map((w) => w.text.trim())
              .toList();
          expect(markers, ['١', '٢', '٣', '٤', '٥', '٦', '٧']);
          expect(t.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'Baqarah Warsh merges the first two Hafs anchors and keeps the clicked word',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..displayed = 'warsh';
      int? held;
      await page(t, settings, number: 2, onHold: (_, word) => held = word);
      final lines = t.widget<MushafLines>(find.byType(MushafLines));
      expect(lines.wordMarker!(quran.ayah(2, 1), 0), isNull);
      final a = quran.ayah(2, 2);
      expect(lines.wordMarker!(a, a.words.length - 1)?.text.trim(), '١');
      await t.longPress(find.byKey(const ValueKey('word:2:2:2')));
      expect(held, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Shamarly uses the selected narration boundaries too', (t) async {
    final settings = ReaderSettings.memory(selected: {'ruways'})
      ..displayed = 'ruways';
    await page(t, settings, number: 2, repository: shamarly);
    final lines = t.widgetList<MushafLines>(find.byType(MushafLines)).first;
    expect(lines.wordMarker, isNotNull);
    expect(lines.wordMarker!(shamarly.ayah(1, 7), 3)?.text.trim(), '٦');
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'sheet selects only the tapped Warsh half and plays its native file',
    (t) async {
      final audio = TestAudio();
      final player = AyahPlayer.withPlayer(audio, AudioNumbering.load)
        ..continuous = false;
      addTearDown(player.dispose);
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..displayed = 'warsh'
        ..listenRiwaya = 'warsh';
      t.view.physicalSize = const Size(1080, 2200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AyahSheet(
              ayah: quran.ayah(1, 7),
              word: 4,
              quran: quran,
              variants: variants,
              settings: settings,
              player: player,
              recitations: recitations,
            ),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settleSheet(t);
      expect(
        find.text('سورة ${quran.surah(1).nameAr} • الآية 7'),
        findsOneWidget,
      );
      final text = t
          .widget<Text>(find.byKey(const ValueKey('selected-verse-text')))
          .data!;
      expect(text, startsWith('غَيۡرِ'));
      expect(text, isNot(contains('أَنۡعَمۡتَ')));
      await t.tap(find.byTooltip('استماع').first);
      await settleSheet(t);
      expect(audio.urls.single, endsWith('/001007.mp3'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Warsh display with Hafs selected plays the merged verse without skipping',
    (t) async {
      final audio = TestAudio();
      final player = AyahPlayer.withPlayer(audio, AudioNumbering.load)
        ..continuous = false;
      addTearDown(player.dispose);
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..displayed = 'warsh'
        ..listenRiwaya = 'hafs';
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AyahSheet(
              ayah: quran.ayah(2, 2),
              word: 2,
              quran: quran,
              variants: variants,
              settings: settings,
              player: player,
              recitations: recitations,
            ),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settleSheet(t);
      expect(
        find.text('سورة ${quran.surah(2).nameAr} • الآية 1'),
        findsOneWidget,
      );
      final text = t
          .widget<Text>(find.byKey(const ValueKey('selected-verse-text')))
          .data!;
      expect(skeleton(text.split(' ').first), 'لم');
      expect(text, contains('ٱلۡكِتَٰبُ'));
      await t.scrollUntilVisible(
        find.byTooltip('استماع'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.byTooltip('استماع').first);
      await settleSheet(t);
      expect(audio.urls.single, endsWith('/002001.mp3'));
      audio.complete();
      await settleSheet(t);
      expect(audio.urls.last, endsWith('/002002.mp3'));
      expect(
        find.text('سورة ${quran.surah(2).nameAr} • الآية 1'),
        findsOneWidget,
      );
      audio.complete();
      await settleSheet(t);
      expect(player.current, isNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Warsh Fatiha native numbering preview', tags: 'golden', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await page(t, settings);
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p1_warsh_native_numbering.png'),
    );
  });

  testWidgets('Bazzi and Qunbul draw their different Naba boundaries', (
    t,
  ) async {
    final a = quran.ayah(78, 40);
    final at = a.words.indexWhere((w) => skeleton(w) == skeleton('قريبا'));
    for (final riwaya in ['bazzi', 'qunbul']) {
      final settings = ReaderSettings.memory(selected: {riwaya})
        ..displayed = riwaya;
      await page(t, settings, number: quran.pageOf(78, 40));
      final lines = t.widgetList<MushafLines>(find.byType(MushafLines)).first;
      expect(
        lines.wordMarker!(a, at)?.text.trim(),
        riwaya == 'bazzi' ? '٤٠' : null,
      );
      expect(
        lines.wordMarker!(a, a.words.length - 1)?.text.trim(),
        riwaya == 'bazzi' ? '٤١' : '٤٠',
      );
      expect(t.takeException(), isNull);
    }
  });
}
