import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/poem_verse.dart';
import 'package:qiraat_mushaf/ui/reader_screen.dart';
import 'package:qiraat_mushaf/ui/reference_sheet.dart';
import 'package:qiraat_mushaf/ui/theme.dart';
import 'package:qiraat_mushaf/ui/variant_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Mushafs mushafs;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  late Manzumat poems;

  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    mushafs = await Mushafs.load();
    variants = VariantRepository({'warsh', 'ibn_wardan'});
    await variants.ensureLoaded(variants.available);
    mutashabihat = await MutashabihatRepository.load();
    poems = await Manzumat.load();
    await Kharouf.load();
  });

  Future<void> showReader(
    WidgetTester t, {
    int page = 3,
    Set<String> selected = const {'warsh'},
    String? displayed,
    bool compareHafs = false,
  }) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: selected)
      ..page = page
      ..displayed = displayed
      ..compareHafs = compareHafs
      ..qcfFont = false;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light).copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ReaderScreen(
            mushafs: mushafs,
            variants: variants,
            mutashabihat: mutashabihat,
            settings: settings,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> settleSources(WidgetTester t) async {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
    if (find.byType(VariantSheet).evaluate().isNotEmpty) {
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('word-reading-evidence')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(VariantSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
    }
  }

  Set<Key?> verseKeys(WidgetTester t, Finder within) => {
    for (final v in t.widgetList<PoemVerse>(
      find.descendant(of: within, matching: find.byType(PoemVerse)),
    ))
      v.key,
  };

  testWidgets('own usul examples open their own rule for every base reading', (
    t,
  ) async {
    for (final displayed in [null, 'warsh', 'ibn_wardan']) {
      await showReader(
        t,
        page: 2,
        selected: {'warsh', 'ibn_wardan'},
        displayed: displayed,
      );
      for (final (label, rule, verses) in [
        ('النقل', 'naql', [226]),
        ('مد البدل', 'badal', [171, 172]),
      ]) {
        final example = find.byKey(
          ValueKey('usul-reference:$label:2:4:9:warsh'),
        );
        await t.ensureVisible(example);
        await t.pumpAndSettle();
        await t.tap(example);
        await settleSources(t);
        final sheet = t.widget<ReferenceSheet>(find.byType(ReferenceSheet));
        expect(sheet.readings, isNotEmpty);
        expect(sheet.readings.every((v) => v.riwayaId == 'warsh'), isTrue);
        expect(sheet.readings.every((v) => v.rule == rule), isTrue);
        expect(verseKeys(t, find.byType(ReferenceSheet)), {
          for (final n in verses) ValueKey('shatibiyya-$n'),
        });
        Navigator.of(t.element(find.byType(ReferenceSheet))).pop();
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'one tap on a Quran word shows its Shatibiyya proof and commentary',
    (t) async {
      await showReader(t);
      await t.tap(find.byKey(const ValueKey('word:2:9:5')));
      await t.pump();
      expect(find.byType(VariantSheet), findsOneWidget);
      await settleSources(t);
      expect(find.byType(VariantSheet), findsOneWidget);
      expect(find.byType(ReferenceSheet), findsNothing);
      expect(find.byKey(const ValueKey('shatibiyya-445')), findsOneWidget);
      expect(find.byKey(const ValueKey('shatibiyya-446')), findsNothing);

      final explanation = poems.explanation(Poem.shatibiyya, 445)!.text;
      final help = find.byTooltip('شرح البيت 445');
      await t.ensureVisible(help);
      await t.pumpAndSettle();
      await t.tap(help);
      await t.pumpAndSettle();
      expect(find.text(explanation), findsOneWidget);

      t.view.physicalSize = const Size(860, 430);
      await t.pumpAndSettle();
      expect(find.text(explanation), findsOneWidget);
      expect(find.byKey(const ValueKey('shatibiyya-446')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('ana uhyii opens bayt 521 from both word and usul margin', (
    t,
  ) async {
    await showReader(t, page: 43);
    await t.tap(find.byKey(const ValueKey('word:2:258:20')));
    await settleSources(t);
    expect(verseKeys(t, find.byType(VariantSheet)), {
      const ValueKey('shatibiyya-521'),
    });
    Navigator.of(t.element(find.byType(VariantSheet))).pop();
    await t.pumpAndSettle();
    final margin = find.byKey(
      const ValueKey('usul-reference:مد أنا:2:258:20:warsh'),
    );
    await t.ensureVisible(margin);
    await t.pumpAndSettle();
    await t.tap(margin);
    await settleSources(t);
    expect(verseKeys(t, find.byType(ReferenceSheet)), {
      const ValueKey('shatibiyya-521'),
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('word and margin expose the same Shatibiyya and Durrah verses', (
    t,
  ) async {
    await showReader(t, page: 1, selected: {'warsh', 'ibn_wardan'});
    await t.tap(find.byKey(const ValueKey('word:1:4:0')));
    await t.pump();
    expect(find.byType(VariantSheet), findsOneWidget);
    await settleSources(t);
    final direct = verseKeys(t, find.byType(VariantSheet));
    expect(
      direct,
      containsAll([
        const ValueKey('shatibiyya-108'),
        const ValueKey('durrah-10'),
      ]),
    );
    Navigator.of(t.element(find.byType(VariantSheet))).pop();
    await t.pumpAndSettle();

    final margin = find.byKey(const ValueKey('margin-reference:1:4:0'));
    await t.ensureVisible(margin);
    await t.pumpAndSettle();
    await t.tap(margin);
    await settleSources(t);
    expect(find.byType(ReferenceSheet), findsOneWidget);
    expect(verseKeys(t, find.byType(ReferenceSheet)), direct);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'a word with two rules shows both proofs without another reading tap',
    (t) async {
      await showReader(t, page: 2);
      await t.tap(find.byKey(const ValueKey('word:2:4:9')));
      await t.pump();
      expect(find.byType(VariantSheet), findsOneWidget);
      await settleSources(t);
      final direct = verseKeys(t, find.byType(VariantSheet));
      expect(
        direct,
        containsAll([
          const ValueKey('shatibiyya-226'),
          const ValueKey('shatibiyya-171'),
          const ValueKey('shatibiyya-172'),
        ]),
      );
      expect(find.byType(ReferenceSheet), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'word details show Shatibiyya and Durrah evidence together',
    tags: 'golden',
    (t) async {
      await showReader(t, page: 1, selected: {'warsh', 'ibn_wardan'});
      await t.tap(find.byKey(const ValueKey('word:1:4:0')));
      await settleSources(t);
      await expectLater(
        find.byType(VariantSheet),
        matchesGoldenFile('goldens/word_poem_evidence.png'),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'the riwayat chosen on the frame, Hafs among them, one touched shown',
    (t) async {
      await showReader(
        t,
        selected: const {'ibn_wardan', 'warsh'},
        compareHafs: true,
      );
      final strip = find.byKey(const ValueKey('frame-riwayat')).hitTestable();
      expect(strip, findsOneWidget);
      // In the order of the Shatibiyya: Warsh, Hafs, then Ibn Wardan.
      final keys = [
        for (final e
            in find
                .descendant(of: strip, matching: find.byType(GestureDetector))
                .evaluate())
          (e.widget.key as ValueKey<String>).value,
      ];
      expect(keys, [
        'frame-riwaya-warsh',
        'frame-riwaya-hafs',
        'frame-riwaya-ibn_wardan',
      ]);
      await t.tap(
        find.byKey(const ValueKey('frame-riwaya-ibn_wardan')).hitTestable(),
      );
      await t.pumpAndSettle();
      final settings = t
          .widget<ReaderScreen>(find.byType(ReaderScreen))
          .settings;
      expect(settings.displayed, 'ibn_wardan');
      // Pressed back into the band, the others raised out of it.
      Size face(String id) =>
          t.getSize(find.byKey(ValueKey('frame-riwaya-$id')).hitTestable());
      expect(face('ibn_wardan').height, lessThan(face('warsh').height));
      await t.tap(
        find.byKey(const ValueKey('frame-riwaya-hafs')).hitTestable(),
      );
      await t.pumpAndSettle();
      expect(settings.displayed, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Hafs not chosen above: not on the frame', (t) async {
    await showReader(t, selected: const {'ibn_wardan', 'warsh'});
    final strip = find.byKey(const ValueKey('frame-riwayat')).hitTestable();
    final keys = [
      for (final e
          in find
              .descendant(of: strip, matching: find.byType(GestureDetector))
              .evaluate())
        (e.widget.key as ValueKey<String>).value,
    ];
    expect(keys, ['frame-riwaya-warsh', 'frame-riwaya-ibn_wardan']);
    expect(t.takeException(), isNull);
  });
}
