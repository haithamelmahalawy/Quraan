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
    'page 22 uses one font when Warsh comparison needs editable letters',
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
      // The print's words where Hafs's are drawn, the editable font only
      // for Warsh's (the user, 2026-11-21: the two mixed).
      expect(engraved, findsWidgets);
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
      // Hafs alone in the print's words, the ۞ its word's own (the user,
      // 2026-11-21): the name told by the word, no marker drawn again.
      final w = t.widget(marker);
      expect(
        w is PartitionMarker
            ? PartitionMarker.label(w.ayah)
            : (w as Tooltip).message,
        'بداية الجزء 2',
      );
      expect(t.takeException(), isNull, reason: '$id');
      final words = t
          .widgetList<InkText>(
            find.byWidgetPredicate(
              (w) =>
                  w is InkText &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('word:'),
            ),
          )
          .toList();
      expect(words, isNotEmpty);
      // The print's words, the editable font for a word with a reading of
      // its own, a little smaller (the user, 2026-11-21).
      final fonts = words.map((w) => w.style.fontFamily).toSet();
      expect(fonts.difference({'QCF_P22', 'Hafs'}), isEmpty, reason: '$id');
      if (id == null) expect(fonts, {'QCF_P22'});
      for (final font in fonts) {
        expect(
          words
              .where((w) => w.style.fontFamily == font)
              .map((w) => w.style.fontSize)
              .toSet(),
          hasLength(1),
          reason: '$id $font',
        );
      }
    }
  });
  testWidgets('engraved QCF words still use a single fill pass', (t) async {
    final glyph = quran.ayah(2, 142).glyphs![1];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InkText(
            glyph,
            style: TextStyle(fontFamily: QcfFonts.family(22), fontSize: 36),
          ),
        ),
      ),
    );
    expect(
      find.descendant(of: find.byType(InkText), matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    "Khalaf's idgham across an ayah's end doubles the next ayah's waw",
    (t) async {
      t.view.physicalSize = const Size(685, 960);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
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
                settings: ReaderSettings.memory(selected: {'khalaf_hamzah'})
                  ..displayed = 'khalaf_hamzah',
                onWordTap: (_, _) {},
                qcf: true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      // «... ۝ وَّكَذَٰلِكَ» (البقرة ١٤٢-١٤٣): in the Hafs font, its waw doubled,
      // not the print's glyph (the user, 2026-11-23).
      final word = t.widget<InkText>(
        find.byKey(const ValueKey('word:2:143:0')),
      );
      expect(word.style.fontFamily, 'Hafs');
      expect(word.parts?.first.$1, contains('ّ'));
    },
  );
}
