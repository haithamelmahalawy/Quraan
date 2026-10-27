import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'notes of one line rise into the room above, not below the page',
    (t) async {
      late QuranRepository quran;
      late VariantRepository variants;
      late MutashabihatRepository mutashabihat;
      await t.runAsync(() async {
        await (FontLoader(
          'Hafs',
        )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
        quran = await QuranRepository.load();
        variants = await VariantRepository.discover();
        await variants.ensureLoaded(['hisham', 'ibn_dhakwan']);
        mutashabihat = await MutashabihatRepository.load();
      });
      t.view.physicalSize = const Size(1080, 2000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(MushafPalette.light),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: MushafPage(
                page: 504,
                qcf: false,
                quran: quran,
                variants: variants,
                mutashabihat: mutashabihat,
                settings: ReaderSettings.memory(
                  selected: {'hisham', 'ibn_dhakwan'},
                )..marginLayout = MarginLayout.sequential,
                onWordTap: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      final side = find.byKey(const ValueKey('sequential-left-margin'));
      // نتقبل … أحسن … ونتجاوز (46:16), three notes of one line.
      for (final w in [2, 4, 7]) {
        expect(
          find.descendant(
            of: side,
            matching: find.byKey(ValueKey('margin-reference:46:16:$w')),
          ),
          findsOneWidget,
          reason: '46:16:$w',
        );
      }
      for (final e
          in find
              .descendant(
                of: side,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w.key is ValueKey<String> &&
                      (w.key as ValueKey<String>).value.startsWith(
                        'margin-reference:',
                      ),
                ),
              )
              .evaluate()) {
        final key = (e.widget.key as ValueKey<String>).value;
        final p = key.split(':').skip(1).toList();
        final word = find.byKey(ValueKey('word:${p[0]}:${p[1]}:${p[2]}'));
        expect(
          (t.getTopLeft(find.byKey(e.widget.key!)).dy - t.getTopLeft(word).dy)
              .abs(),
          lessThan(105),
          reason: key,
        );
      }
      expect(t.takeException(), isNull);
    },
  );
}
