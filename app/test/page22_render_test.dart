import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/services/qcf_fonts.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/partition_marker.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    await (FontLoader(QcfFonts.family(22))..addFont(
          Future.value(
            ByteData.sublistView(
              File('test/fixtures/qcf_p22.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded([
      for (final q in qiraat)
        for (final r in q.riwayat) r.id,
    ]);
    mutashabihat = await MutashabihatRepository.load();
  });
  testWidgets(
    'page 22 Hafs with Warsh comparison in the real QCF page font',
    tags: 'golden',
    (t) async {
      t.view.physicalSize = const Size(685, 960);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final theme = buildTheme(MushafPalette.light);
      await t.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MushafPage(
                page: 22,
                quran: quran,
                variants: variants,
                mutashabihat: mutashabihat,
                settings: ReaderSettings.memory(selected: {'warsh'}),
                onWordTap: (_, _) {},
                qcf: true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final engraved = find.byWidgetPredicate(
        (w) =>
            w is InkText && (w.style.fontFamily?.startsWith('QCF_') ?? false),
      );
      expect(engraved, findsWidgets);
      for (final word in engraved.evaluate()) {
        expect(
          find.descendant(
            of: find.byWidget(word.widget),
            matching: find.byType(Text),
          ),
          findsOneWidget,
          reason: 'QCF words must have one fill pass',
        );
      }
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile('goldens/p22_hafs_warsh_qcf.png'),
      );
    },
  );
  testWidgets('page 22 keeps the juz boundary for every displayed reading', (
    t,
  ) async {
    t.view.physicalSize = const Size(685, 960);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final id in [
      null,
      for (final q in qiraat)
        for (final r in q.riwayat) r.id,
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(MushafPalette.light),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MushafPage(
                page: 22,
                quran: quran,
                variants: variants,
                mutashabihat: mutashabihat,
                settings: ReaderSettings.memory(selected: {?id})
                  ..displayed = id,
                onWordTap: (_, _) {},
                qcf: true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final marker = find.byKey(const ValueKey('partition:2:142'));
      expect(marker, findsOneWidget, reason: '$id');
      expect(
        PartitionMarker.label(t.widget<PartitionMarker>(marker).ayah),
        'بداية الجزء 2',
      );
      expect(t.takeException(), isNull, reason: '$id');
    }
  });
}
