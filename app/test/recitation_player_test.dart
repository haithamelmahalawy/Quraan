import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/audio_numbering.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/recitations.dart';
import 'package:qiraat_mushaf/services/ayah_player.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/ayah_sheet.dart';
import 'package:qiraat_mushaf/ui/recitation_player.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import 'helpers/test_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranRepository quran;
  late Recitations recitations;

  setUpAll(() async {
    (quran, recitations) = await (
      QuranRepository.load(),
      Recitations.load(),
    ).wait;
  });

  testWidgets(
    'audio remains controllable after dismissing the listening sheet',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2100);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final audio = TestAudio();
      final player = AyahPlayer.withPlayer(audio, AudioNumbering.load)
        ..continuous = false;
      addTearDown(player.dispose);
      final settings = ReaderSettings.memory()..listenRiwaya = 'hafs';
      final navigator = GlobalKey<NavigatorState>();

      Future<void> openSheet() => showModalBottomSheet<void>(
        context: navigator.currentState!.overlay!.context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: MushafColors.paper,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (context, controller) => PrimaryScrollController(
            controller: controller,
            child: AyahSheet(
              ayah: quran.ayah(2, 5),
              quran: quran,
              settings: settings,
              player: player,
              recitations: recitations,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: buildTheme(MushafPalette.light),
          builder: (context, child) {
            MushafColors.use(Theme.of(context).brightness);
            return RecitationPlayerHost(
              player: player,
              quran: quran,
              onOpen: openSheet,
              child: child!,
            );
          },
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: openSheet,
                child: const Text('فتح الاستماع والتفسير'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح الاستماع والتفسير'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byTooltip('استماع').first);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(audio.playing, isTrue);
      expect(find.byKey(const ValueKey('mini-recitation-player')), findsOne);

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(audio.playing, isTrue);
      expect(find.byType(AyahSheet), findsNothing);
      expect(find.byKey(const ValueKey('mini-recitation-player')), findsOne);

      await tester.tap(find.byTooltip('إيقاف مؤقت'));
      await tester.pump();
      expect(audio.playing, isFalse);
      expect(player.current, isNotNull);
      expect(find.byTooltip('متابعة التلاوة'), findsOne);

      final slider = find.byKey(const ValueKey('recitation-seek-bar'));
      final rect = tester.getRect(slider);
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * 0.2, rect.center.dy),
      );
      await gesture.moveTo(
        Offset(rect.left + rect.width * 0.8, rect.center.dy),
      );
      await tester.pump();
      expect(audio.seeks, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(audio.seeks, hasLength(1));
      expect(audio.seeks.single.inMilliseconds, inInclusiveRange(7000, 9000));
      expect(audio.playing, isFalse);

      await tester.tap(find.byTooltip('متابعة التلاوة'));
      await tester.pump();
      expect(audio.playing, isTrue);
      expect(audio.urls, hasLength(1));

      await tester.tap(find.byTooltip('إغلاق المشغّل'));
      await tester.pump();
      expect(audio.playing, isFalse);
      expect(player.current, isNull);
      expect(
        find.byKey(const ValueKey('mini-recitation-player')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
