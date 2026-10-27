import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/audio_numbering.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/recitations.dart';
import 'package:qiraat_mushaf/services/ayah_player.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/ayah_sheet.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import 'helpers/test_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the i\'rab of the ayah beside its tafsir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late QuranRepository quran;
    late Recitations recitations;
    await tester.runAsync(() async {
      (quran, recitations) = await (
        QuranRepository.load(),
        Recitations.load(),
      ).wait;
    });
    final player = AyahPlayer.withPlayer(TestAudio(), AudioNumbering.load);
    addTearDown(player.dispose);
    final settings = ReaderSettings.memory();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PrimaryScrollController(
              controller: ScrollController(),
              child: AyahSheet(
                ayah: quran.ayah(2, 2),
                quran: quran,
                settings: settings,
                player: player,
                recitations: recitations,
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
      }
    }

    await settle();
    expect(find.byKey(const ValueKey('tafsir-tab')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('e3rab-tab')));
    await settle();

    expect(settings.showE3rab, isTrue);
    expect(find.text('إعراب القرآن — الدعاس'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            '${w.textSpan?.toPlainText()}'.contains('مبتدأ'),
      ),
      findsOneWidget,
    );
    // Each word of the ayah on its line, its i'rab after it.
    final lines = tester
        .widget<SelectableText>(find.byKey(const ValueKey('e3rab-words')))
        .textSpan!
        .toPlainText()
        .split('\n');
    expect(lines.first, startsWith('ذلِكَ : ذا اسم إشارة'));
    expect(lines, hasLength(6));
    // The books of i'rab replace those of the tafsir.
    expect(find.text('المجتبى من مشكل الإعراب'), findsOneWidget);
    expect(find.text('التفسير الميسر'), findsNothing);
  });
}
