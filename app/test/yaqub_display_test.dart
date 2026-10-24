import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/hamza_replacement_mark.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['ruways', 'rawh', 'hisham', 'warsh']);
    mutashabihat = await MutashabihatRepository.load();
  });
  Future<void> page(WidgetTester t, String? displayed, {int number = 3}) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(
      selected: {'ruways', 'rawh', 'hisham', 'warsh'},
    )..displayed = displayed;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: number,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: settings,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  Finder word(int s, int a, int w) => find.byKey(ValueKey('word:$s:$a:$w'));
  Finder mark(Finder w) =>
      find.ancestor(of: w, matching: find.byType(HamzaReplacementMark));
  testWidgets(
    'Ruways main tasheel is marked; Hafs and Rawh retain their hamzas',
    (t) async {
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id);
        final target = word(2, 6, 5);
        expect(target, findsOneWidget);
        final footer = find.byKey(
          const ValueKey('usul-reference:تسهيل الهمزتين في كلمة:2:6:5:ruways'),
        );
        expect(footer, findsOneWidget);
        final marginMark = t.widget<HamzaReplacementMark>(
          find.descendant(
            of: footer,
            matching: find.byType(HamzaReplacementMark),
          ),
        );
        expect(marginMark.letter, isEmpty);
        expect(marginMark.originalHamza, startsWith('أ'));
        if (id == 'ruways') {
          final m = t.widget<HamzaReplacementMark>(mark(target));
          expect(m.letter, isEmpty);
          expect(m.offset, greaterThan(0));
          final ink = t.widget<InkText>(target);
          expect(ink.parts!.map((p) => p.$1).join(), isNot(contains('أَ')));
        } else {
          expect(mark(target), findsNothing);
          expect(t.widget<InkText>(target).text, contains('أَ'));
        }
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Ruways ibdal circle uses original hamza seat without changing Hafs',
    (t) async {
      final v = variants
          .at(['ruways'], 2, 13, 12)
          .singleWhere((v) => v.rule == 'ibdal_waw');
      expect(v.word, 12);
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id);
        final target = word(2, 13, 12);
        expect(target, findsOneWidget);
        if (id == 'ruways') {
          final m = t.widget<HamzaReplacementMark>(mark(target));
          expect(m.letter, 'و');
          expect(m.originalHamza, startsWith('أ'));
          expect(m.text, startsWith('أ'));
        } else {
          expect(mark(target), findsNothing);
          expect(t.widget<InkText>(target).text, startsWith('أ'));
        }
        expect(t.takeException(), isNull);
      }
    },
  );
}
