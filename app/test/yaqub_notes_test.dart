import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
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
    await variants.ensureLoaded(['ruways', 'rawh', 'shubah']);
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

  String letters(String s) =>
      s.replaceAll(RegExp('[^ء-ي ]'), '').replaceAll('ـ', '');

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets('$riwaya: 2:165 «ولو ترى» on the page', (t) async {
      await page(t, riwaya, quran.ayah(2, 165).page);
      expect(letters(drawn(t, 2, 165, 17)), contains('ترى'));
    });

    testWidgets('$riwaya: 2:177 «ليس البرُّ» on the page', (t) async {
      await page(t, riwaya, quran.ayah(2, 177).page);
      // Raf': a damma on the ra (with its shadda, in either order).
      final text = drawn(t, 2, 177, 1);
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

  testWidgets('Hafs compared: «البرَّ» with its vowels', (t) async {
    await page(t, 'rawh', quran.ayah(2, 177).page, compareHafs: true);
    final hafs = quran.ayah(2, 177).words[1];
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

  test('Rawh: the dhal merged into the ta, in the usul, as at 2:92', () {
    for (final (a, w) in [(80, 8), (92, 5)]) {
      final told = variants.at(['rawh'], 2, a, w).where((v) => v.word == w);
      expect(told.single.rule, 'idgham_saghir');
      expect(told.single.description, 'بإدغام الذال في التاء');
      expect(told.single.inHamesh, isFalse);
    }
    // 3:81 «وأخذتم» too; Ruways reads them as Hafs.
    expect(variants.at(['rawh'], 3, 81, 21).single.rule, 'idgham_saghir');
    expect(
      variants.at(['ruways'], 2, 80, 8).where((v) => v.word == 8),
      isEmpty,
    );
  });

  test(
    '2:93: Yaqub «قُلُوبِهِمِ ٱلۡعِجۡلَ», without the Hafs word again',
    () async {
      final quran = await QuranRepository.load();
      final v = variants
          .at(['rawh'], 2, 93, 16)
          .singleWhere((v) => v.rule == 'mim_jam');
      final text = usulReadingText(v, quran.ayah(2, 93), variants);
      expect(text.split(' '), hasLength(2));
      expect(text, isNot(contains(quran.ayah(2, 93).words[16])));
    },
  );

  test('Ruways shown, Hafs compared: «عهدي» and «بيتي» are told', () async {
    final quran = await QuranRepository.load();
    for (final (a, w) in [(124, 17), (125, 17)]) {
      final hafs = compareReadings(
        repository: variants,
        ayah: quran.ayah(2, a),
        word: w,
        displayed: 'ruways',
        selected: ['hafs'],
      ).where((v) => v.riwayaId == 'hafs');
      expect(hafs, isNotEmpty, reason: '2:$a');
    }
  });

  test('ya al-idafa compared in every riwaya (بيتي 2:125)', () async {
    final quran = await QuranRepository.load();
    final ayah = quran.ayah(2, 125);
    // Shu'bah shown: Hafs (بَيۡتِيَ) beside it.
    expect(
      compareReadings(
        repository: variants,
        ayah: ayah,
        word: 17,
        displayed: 'shubah',
        selected: ['hafs'],
      ).where((v) => v.riwayaId == 'hafs'),
      isNotEmpty,
    );
    // Hafs shown: both riwayat that read it with sukun.
    final others = compareReadings(
      repository: variants,
      ayah: ayah,
      word: 17,
      displayed: null,
      selected: ['shubah', 'ruways'],
    ).map((v) => v.riwayaId).toSet();
    expect(others, containsAll(['shubah', 'ruways']));
    // Ruways shown: Shu'bah reads it the same, nothing told.
    expect(
      compareReadings(
        repository: variants,
        ayah: ayah,
        word: 17,
        displayed: 'ruways',
        selected: ['shubah'],
      ).where((v) => v.riwayaId == 'shubah' && v.inHamesh),
      isEmpty,
    );
  });

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets('$riwaya shown: 2:165 «إِنَّ ... وَإِنَّ» drawn and coloured', (
      t,
    ) async {
      await page(t, riwaya, quran.ayah(2, 165).page);
      Set<Color?> colours(int w) => {
        for (final r in t.widgetList<RichText>(
          find.descendant(
            of: find.byKey(ValueKey('word:2:165:$w')),
            matching: find.byType(RichText),
          ),
        ))
          ...spanColours(r.text),
      };
      final ink = colours(22);
      for (final w in [23, 27]) {
        expect(drawn(t, 2, 165, w), contains('إِ'), reason: 'word $w');
        expect(colours(w), isNot(ink), reason: 'word $w');
      }
      expect(colours(17), isNot(ink), reason: 'ترى');
    });
  }

  testWidgets('Hafs shown: 2:229 «يُخَافَا» بضم الياء in the hamesh', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'rawh', 'ruways'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: quran.ayah(2, 229).page,
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
    expect(find.textContaining('يُخَافَا', findRichText: true), findsWidgets);
    expect(find.textContaining('بضم الياء', findRichText: true), findsWidgets);
  });

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets(
      '$riwaya shown: 2:240 «وَصِيَّةٌ» with tanween of damm, coloured',
      (t) async {
        await page(t, riwaya, quran.ayah(2, 240).page);
        final text = drawn(t, 2, 240, 5);
        expect(text, matches(RegExp('[ٌٞ]')));
        expect(text, isNot(matches(RegExp('[ًٗ]'))));
        Set<Color?> colours(int w) => {
          for (final r in t.widgetList<RichText>(
            find.descendant(
              of: find.byKey(ValueKey('word:2:240:$w')),
              matching: find.byType(RichText),
            ),
          ))
            ...spanColours(r.text),
        };
        expect(colours(5), isNot(colours(3)));
      },
    );
  }

  testWidgets('Ruways shown, Hafs compared: 2:254 notes beside their words', (
    t,
  ) async {
    await page(t, 'ruways', quran.ayah(2, 254).page, compareHafs: true);
    final ayah = quran.ayah(2, 254);
    // The words stay on the page: «ولا» after «خلة», «والكافرون» after «شفاعة».
    for (final w in [16, 18]) {
      expect(find.byKey(ValueKey('word:2:254:$w')), findsOneWidget);
    }
    for (final w in [12, 15, 17]) {
      final note = find.textContaining(ayah.words[w], findRichText: true);
      expect(note, findsWidgets, reason: ayah.words[w]);
      final y = t.getCenter(note.last).dy;
      final line = t.getCenter(find.byKey(ValueKey('word:2:254:$w'))).dy;
      expect((y - line).abs(), lessThan(200), reason: ayah.words[w]);
    }
  });

  test('an added alef is a dagger alef (2:251 دِفَٰعُ)', () {
    for (final id in ['rawh', 'ruways']) {
      final v = variants.at([id], 2, 251, 14).firstWhere((v) => v.word == 14);
      expect(v.text, contains('ٰ'));
      expect(v.text.replaceAll(RegExp('[ً-ٰ]'), ''), 'دفع');
    }
  });

  test(
    'Ruways shown: Hafs told at 2:282 «فتذكر» and «تجارة حاضرة» (farsh)',
    () async {
      final quran = await QuranRepository.load();
      final ayah = quran.ayah(2, 282);
      for (final w in [68, 98]) {
        final v = variants
            .at(['ruways'], 2, 282, w)
            .firstWhere((v) => v.word == w);
        expect(v.kind, VariantKind.farsh);
        expect(v.description, isNot(contains('تفخيم')));
        expect(
          compareReadings(
            repository: variants,
            ayah: ayah,
            word: w,
            displayed: 'ruways',
            selected: ['hafs'],
          ).where((v) => v.riwayaId == 'hafs'),
          isNotEmpty,
          reason: '$w',
        );
      }
      // «تجارة» with the dagger alef of the rasm.
      expect(variants.at(['ruways'], 2, 282, 98).first.text, contains('ٰ'));
    },
  );

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets('$riwaya: 3:28 «تَقِيَّةً» on the page and in the hamesh', (
      t,
    ) async {
      await page(t, riwaya, quran.ayah(3, 28).page, compareHafs: true);
      expect(letters(drawn(t, 3, 28, 20)), contains('تقية'));
      // Hafs «تُقَىٰةٗ» told beside it.
      expect(
        find.textContaining(quran.ayah(3, 28).words[20], findRichText: true),
        findsWidgets,
      );
    });
  }

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets('$riwaya: «زكرياءُ» with its hamza at 3:37 and 3:38', (
      t,
    ) async {
      await page(t, riwaya, quran.ayah(3, 38).page, compareHafs: true);
      for (final (a, w) in [(37, 8), (38, 2)]) {
        if (find.byKey(ValueKey('word:3:$a:$w')).evaluate().isEmpty) continue;
        expect(drawn(t, 3, a, w), contains('ء'), reason: '3:$a');
      }
    });
  }

  testWidgets('Hafs shown: «زكرياءُ» بزيادة الهمزة told for Yaqub', (t) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'rawh', 'ruways'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: quran.ayah(3, 38).page,
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
    expect(
      find.textContaining('بزيادة الهمزة', findRichText: true),
      findsWidgets,
    );
  });

  for (final riwaya in ['rawh', 'ruways']) {
    testWidgets('$riwaya: 3:120 «يَضِرۡكُمۡ» with the mim sakin', (t) async {
      await page(t, riwaya, quran.ayah(3, 120).page);
      final text = drawn(t, 3, 120, 13);
      expect(letters(text), contains('يضركم'));
      expect(text, isNot(contains('مُ')));
    });
  }

  testWidgets('Hafs shown: 3:130 «مُضَعَّفَةً» in the hamesh for Yaqub', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'rawh', 'ruways'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: quran.ayah(3, 130).page,
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
    expect(
      find.textContaining('بحذف الألف وتشديد العين', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('ruways: 3:167 «وَقِيلَ» the qaf coloured for the ishmam', (
    t,
  ) async {
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
              page: quran.ayah(3, 167).page,
              qcf: false,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: ReaderSettings.memory(selected: {'ruways'}),
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
    // Each letter with the colour it is drawn in (inherited from its parent).
    final parts = <(String, Color?)>[];
    void walk(InlineSpan span, Color? inherited) {
      final colour = span.style?.color ?? inherited;
      if (span is TextSpan) {
        if ((span.text ?? '').isNotEmpty) parts.add((span.text!, colour));
        for (final c in span.children ?? const <InlineSpan>[]) {
          walk(c, colour);
        }
      }
    }

    for (final r in t.widgetList<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('word:3:167:3')),
        matching: find.byType(RichText),
      ),
    )) {
      walk(r.text, null);
    }
    // The painted layer (after the outline).
    final waw = parts.lastWhere((p) => p.$1.startsWith('و'));
    final qaf = parts.lastWhere((p) => p.$1.contains('ق'));
    expect(qaf.$2, isNot(waw.$2));
  });

  test('3:154 «كُلُّهُۥ» برفع اللام', () {
    for (final id in ['rawh', 'ruways']) {
      final v = variants
          .at([id], 3, 154, 31)
          .firstWhere((v) => v.kind == VariantKind.farsh);
      expect(v.text, contains('لُّ'));
      expect(v.description, 'برفع اللام');
    }
  });
}
