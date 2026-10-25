import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

/// The user's notes on Ya'qub's riwayat (Ruways, Rawh) as the page draws
/// them.
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
    await variants.ensureLoaded(['ruways', 'rawh']);
    mutashabihat = await MutashabihatRepository.load();
  });

  Future<void> page(
    WidgetTester t,
    String displayed,
    int number, {
    bool compareHafs = false,
  }) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {displayed})
      ..displayed = displayed
      ..compareHafs = compareHafs;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: number,
              qcf: false,
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

  /// The letters drawn for Hafs word [w] of [s]:[a].
  String drawn(WidgetTester t, int s, int a, int w) {
    final word = find.byKey(ValueKey('word:$s:$a:$w'));
    if (word.evaluate().isEmpty) return '';
    return t
        .widgetList<RichText>(
          find.descendant(of: word, matching: find.byType(RichText)),
        )
        .map((r) => r.text.toPlainText())
        .join(' ');
  }

  List<Color?> spanColours(InlineSpan span) {
    final out = <Color?>[];
    span.visitChildren((s) {
      if (s is TextSpan && (s.text ?? '').trim().isNotEmpty) {
        out.add(s.style?.color ?? span.style?.color);
      }
      return true;
    });
    return out;
  }

  String letters(String s) => s.replaceAll(RegExp('[^ء-ي ]'), '');

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets('$riwaya: 2:165 «ولو ترى» on the page', (t) async {
      await page(t, riwaya, quran.ayah(2, 165).page);
      expect(letters(drawn(t, 2, 165, 17)), contains('ترى'));
    });

    testWidgets('$riwaya: 2:177 «ليس البرُّ» on the page', (t) async {
      await page(t, riwaya, quran.ayah(2, 177).page);
      // Raf': a damma on the ra (with its shadda, in either order).
      final text = drawn(t, 2, 177, 0);
      final ra = text.indexOf('ر');
      expect(ra, greaterThan(0));
      expect(text.substring(ra, ra + 3), contains('ُ'));
    });

    testWidgets('$riwaya: no description drawn as the words of the page', (
      t,
    ) async {
      for (final number in [25, 27, 32]) {
        await page(t, riwaya, number);
        final words = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('word:'),
        );
        for (final text in t.widgetList<RichText>(
          find.descendant(of: words, matching: find.byType(RichText)),
        )) {
          expect(
            text.text.toPlainText(),
            isNot(matches(RegExp('اشمام|إشمام|إظهار|اظهار|بالتاء|بكسر'))),
          );
        }
      }
    });
  }

  testWidgets('Hafs compared: «لَّيۡسَ ٱلۡبِرَّ» in full, with its vowels', (
    t,
  ) async {
    await page(t, 'rawh', quran.ayah(2, 177).page, compareHafs: true);
    final hafs = quran.ayah(2, 177).words.sublist(0, 2).join(' ');
    expect(find.textContaining(hafs, findRichText: true), findsWidgets);
  });

  testWidgets('Ruways idgham kabir: both words coloured', (t) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'ruways'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: quran.ayah(2, 20).page,
              qcf: false,
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
    // «لَذَهَبَ بِسَمۡعِهِمۡ» (2:20).
    Set<Color?> colours(int w) => {
      for (final r in t.widgetList<RichText>(
        find.descendant(
          of: find.byKey(ValueKey('word:2:20:$w')),
          matching: find.byType(RichText),
        ),
      ))
        ...spanColours(r.text),
    };
    final ink = colours(15);
    expect(colours(16), isNot(ink));
    expect(colours(17), colours(16));
  });
}
