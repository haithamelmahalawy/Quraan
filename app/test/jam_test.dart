import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/jam.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/ui/jam_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(variants.available);
  });

  test('the twenty, Qalun first, each once in each ayah, in their order', () {
    expect(jamOrder.length, 20);
    expect(jamOrder.first, 'qalun');
    expect(jamOrder.last, 'idris');
    expect(jamName('duri_kisai'), 'الدوري عن الكسائي');
    for (final page in [1, 2, 158, 165]) {
      for (final ayah in quran.page(page)) {
        final readings = jamReadings(ayah, variants);
        final all = [for (final r in readings) ...r.riwayat];
        expect(
          all.toSet().length,
          all.length,
          reason: '${ayah.surah}:${ayah.number}',
        );
        expect(all.toSet(), jamOrder.toSet());
        // Each told with the first who reads it, and in the order of the ten.
        final leads = [for (final r in readings) jamOrder.indexOf(r.lead)];
        expect(leads, [...leads]..sort());
        for (final r in readings) {
          expect(
            r.riwayat,
            [...r.riwayat]..sort(
              (a, b) => jamOrder.indexOf(a).compareTo(jamOrder.indexOf(b)),
            ),
          );
          expect(r.words.length, ayah.words.length);
        }
      }
    }
  });

  test('مالك يوم الدين: the readers of «مَٰلِكِ» told apart from «مَلِكِ»', () {
    final ayah = quran.page(1).firstWhere((a) => a.surah == 1 && a.number == 4);
    final readings = jamReadings(ayah, variants);
    final hafs = readings.firstWhere((r) => r.riwayat.contains(hafsId));
    final qalun = readings.firstWhere((r) => r.riwayat.contains('qalun'));
    expect(qalun, isNot(same(hafs)));
    expect(qalun.lead, 'qalun');
    for (final r in readings) {
      // ignore: avoid_print
      print('1:4 ${r.lead}: ${r.words.join(' ')} | ${r.agreeing.join(',')}');
    }
  });

  testWidgets('the screen goes reading by reading, then ayah by ayah', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 1),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('jam-lead')), findsOneWidget);
    expect(find.text('قالون عن نافع'), findsOneWidget);
    expect(
      t
          .widget<IconButton>(find.byKey(const ValueKey('jam-previous')))
          .onPressed,
      isNull,
    );
    final first = quran.page(1).first;
    final count = jamReadings(first, variants).length;
    for (var i = 1; i < count; i++) {
      await t.tap(find.byKey(const ValueKey('jam-next')));
      await t.pump();
    }
    // The last reading of the first ayah, then the second ayah from Qalun.
    await t.tap(find.byKey(const ValueKey('jam-next')));
    await t.pump();
    expect(find.text('قالون عن نافع'), findsOneWidget);
    expect(
      t.widget<ChoiceChip>(find.byKey(const ValueKey('jam-ayah-1'))).selected,
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
  });
}
