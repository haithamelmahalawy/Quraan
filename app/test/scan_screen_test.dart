import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/riwayat_panel.dart';
import 'package:qiraat_mushaf/ui/scan_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  setUpAll(() async {
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
  });

  testWidgets('the riwayat chosen as in the mushaf; the page number first', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'qalun'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ScanScreen(
            quran: quran,
            variants: variants,
            mutashabihat: MutashabihatRepository.empty,
            settings: settings,
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    // «الرواة» of the mushaf, not a row of chips.
    expect(find.byType(RiwayatPanel), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    // Read by the page number unless told otherwise.
    expect(settings.scanMode, ScanMode.number);
    expect(
      find.text('ضع رقم الصفحة داخل الدائرة أسفل الشاشة، ولك أن تقرّبه.'),
      findsOneWidget,
    );
    await t.tap(find.text(ScanMode.line.labelAr));
    await t.pump();
    expect(settings.scanMode, ScanMode.line);
    expect(
      find.text('ضع سطرًا من منتصف الصفحة داخل المستطيل.'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
