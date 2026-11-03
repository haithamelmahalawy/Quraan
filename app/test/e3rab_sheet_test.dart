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

  testWidgets('the reasons of the chosen riwayat\'s readings', (tester) async {
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
    final settings = ReaderSettings.memory(selected: {'hisham', 'ruways'});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PrimaryScrollController(
              controller: ScrollController(),
              child: AyahSheet(
                ayah: quran.ayah(4, 5),
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
    await tester.tap(find.byKey(const ValueKey('tawjih-tab')));
    await settle();
    expect(settings.besideAyah, BesideAyah.tawjih);
    expect(find.text('حجة القراءات — ابن زنجلة'), findsOneWidget);
    String shown() => tester
        .widget<SelectableText>(find.byKey(const ValueKey('tawjih-text')))
        .textSpan!
        .toPlainText();
    // Ibn Amir (Hisham) is named; Hafs is of «الباقون».
    expect(shown(), contains('قرأ نافع وابن عامر'));
    expect(shown(), contains('الباقون'));
    // Ya'qub (Ruways) is not in the book of the seven.
    expect(find.textContaining('ليس فيه توجيه قراءة: رويس'), findsOneWidget);

    // The stops of the ayah, beside them (الوقف والابتداء).
    await tester.tap(find.byKey(const ValueKey('waqf-tab')));
    await settle();
    expect(settings.besideAyah, BesideAyah.waqf);
    expect(
      find.text('المكتفى في الوقف والابتدا — أبو عمرو الداني'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('waqf-text')))
          .textSpan!
          .toPlainText(),
      'ومثله ﴿معروفا﴾ [أي: كاف]',
    );
    // Its arrows point out, away from the ayah: right on the right, left
    // on the left, unmirrored by the sheet's right-to-left text.
    for (final (key, icon, right) in [
      ('previous-ayah', Icons.chevron_right_rounded, true),
      ('next-ayah', Icons.chevron_left_rounded, false),
    ]) {
      final arrow = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byIcon(icon),
      );
      expect(
        Directionality.of(tester.element(arrow)),
        TextDirection.ltr,
        reason: key,
      );
      final sheet = tester.getCenter(
        find.byKey(const ValueKey('selected-verse-text')),
      );
      expect(tester.getCenter(arrow).dx > sheet.dx, right, reason: key);
    }
    // The ayah after it, and its book with it; then back.
    String waqf() => tester
        .widget<SelectableText>(find.byKey(const ValueKey('waqf-text')))
        .textSpan!
        .toPlainText();
    await tester.tap(find.byKey(const ValueKey('next-ayah')));
    await settle();
    expect(find.textContaining('الآية 6'), findsOneWidget);
    expect(waqf(), startsWith('ومثله ﴿أن يكبروا﴾'));
    await tester.tap(find.byKey(const ValueKey('previous-ayah')));
    await settle();
    expect(find.textContaining('الآية 5'), findsOneWidget);
    expect(waqf(), 'ومثله ﴿معروفا﴾ [أي: كاف]');
  });
}
