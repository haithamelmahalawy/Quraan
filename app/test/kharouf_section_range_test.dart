import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/theme.dart';
import 'package:qiraat_mushaf/ui/variant_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Hisham's «وَلَقَد جَّآءَكُم» (البقرة ٩٢) opens from «وَلَقَدۡ»: the book's notes
  // of «جَآءَكُم» too, Ibn Dhakwan's imala with the idgham (the user,
  // 2026-11-16).
  testWidgets('the book\'s notes of every word of a reading (ja\'akum)', (
    tester,
  ) async {
    late QuranRepository quran;
    late VariantRepository variants;
    await tester.runAsync(() async {
      await (FontLoader(
        'Hafs',
      )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
      await Manzumat.load();
      await Kharouf.load();
      quran = await QuranRepository.load();
      variants = await VariantRepository.discover();
      await variants.ensureLoaded(['hisham', 'ibn_dhakwan']);
    });
    final s = ReaderSettings.memory(selected: {'hisham', 'ibn_dhakwan'})
      ..displayed = 'hisham'
      ..compareHafs = true;
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final theme = buildTheme(MushafPalette.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: VariantSheet(
              ayah: quran.ayah(2, 92),
              word: 1,
              surahName: 'البقرة',
              settings: s,
              variants: variants,
              surahNames: [for (final x in quran.surahs) x.nameAr],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    final texts = [
      for (final r in tester.widgetList<RichText>(find.byType(RichText)))
        r.text.toPlainText(),
    ];
    expect(
      texts.any((t) => t.contains('الصغير') && t.contains('هشام')),
      isTrue,
    );
    // The reader first, then a colon and his reading (the user, 2026-11-20).
    expect(texts.any((t) => t.startsWith('ابن ذكوان: ')), isTrue);
  });
}
