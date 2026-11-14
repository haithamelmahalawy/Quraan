import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
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
        // A second tap awaited first.
        await t.pump(kDoubleTapTimeout);
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
      // A second tap awaited first.
      await t.pump(kDoubleTapTimeout);
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
      // A second tap awaited first.
      await t.pump(kDoubleTapTimeout);
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
    // A second tap awaited first.
    await t.pump(kDoubleTapTimeout);
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
    // A second tap awaited first.
    await t.pump(kDoubleTapTimeout);
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
    // A second tap awaited first.
    await t.pump(kDoubleTapTimeout);
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
    // A second tap awaited first.
    await t.pump(kDoubleTapTimeout);
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
      // A second tap awaited first.
      await t.pump(kDoubleTapTimeout);
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
      // A second tap awaited first.
      await t.pump(kDoubleTapTimeout);
      await settleSources(t);
      await expectLater(
        find.byType(VariantSheet),
        matchesGoldenFile('goldens/word_poem_evidence.png'),
      );
      expect(t.takeException(), isNull);
    },
  );

  /// The wheel of the page in sight (its neighbours built beside it).
  Finder wheelOf() => find.byKey(const ValueKey('frame-riwayat')).hitTestable();

  Finder inWheel(Key key) =>
      find.descendant(of: wheelOf(), matching: find.byKey(key));

  /// The riwayat on the frame's wheel, from right to left as they stand.
  List<String> onWheel(WidgetTester t) {
    final found = find
        .descendant(
          of: wheelOf(),
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('frame-riwaya-'),
          ),
        )
        .evaluate()
        .toList();
    final keyed = [
      for (final e in found)
        (
          id: (e.widget.key as ValueKey<String>).value.substring(13),
          x: t.getCenter(find.byElementPredicate((x) => x == e)).dx,
        ),
    ]..sort((a, b) => b.x.compareTo(a.x));
    return [for (final k in keyed) k.id];
  }

  /// The riwaya in the wheel's circle.
  String inCircle(WidgetTester t) {
    final circle = t.getCenter(inWheel(const ValueKey('frame-riwayat-circle')));
    final ids = onWheel(t);
    return ids.firstWhere(
      (id) =>
          (t.getCenter(inWheel(ValueKey('frame-riwaya-$id'))).dx - circle.dx)
              .abs() <
          2,
    );
  }

  // The riwayat chosen on a wheel on the frame's upper band, in the order of
  // the Shatibiyya; the one in its circle is the one shown, and one tapped is
  // turned into it and shown (the user, 2026-11-14).
  testWidgets(
    'the riwayat chosen on the frame, Hafs among them, one touched shown',
    (t) async {
      await showReader(
        t,
        selected: const {'ibn_wardan', 'warsh'},
        compareHafs: true,
      );
      final settings = t
          .widget<ReaderScreen>(find.byType(ReaderScreen))
          .settings;
      expect(inWheel(const ValueKey('frame-riwayat-arrow')), findsOneWidget);
      // Warsh shown, in the circle; Hafs, then Ibn Wardan, after him round
      // the wheel, as the Shatibiyya orders them.
      expect(inCircle(t), settings.displayed ?? 'hafs');
      final ids = onWheel(t);
      final from = ids.indexOf('warsh');
      expect(
        [for (var i = 0; i < 3; i++) ids[(from + i) % 3]],
        ['warsh', 'hafs', 'ibn_wardan'],
      );
      await t.tap(inWheel(const ValueKey('frame-wheel-2')));
      await t.pumpAndSettle();
      expect(settings.displayed, 'ibn_wardan');
      expect(inCircle(t), 'ibn_wardan');
      await t.tap(inWheel(const ValueKey('frame-wheel-1')));
      await t.pumpAndSettle();
      expect(settings.displayed, isNull);
      expect(inCircle(t), 'hafs');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Hafs not chosen above: not on the frame', (t) async {
    await showReader(t, selected: const {'ibn_wardan', 'warsh'});
    expect(onWheel(t).toSet(), {'warsh', 'ibn_wardan'});
    expect(t.takeException(), isNull);
  });

  // All of them on the upper band's wheel, none on the lower; dragged, the
  // next comes into the circle and is shown, the page not turned (the user,
  // 2026-11-14).
  testWidgets('all the riwayat on the frame\'s wheel, turned by a drag', (
    t,
  ) async {
    final all = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (r.id != hafsId) r.id,
    ];
    await showReader(t, selected: all.toSet());
    final settings = t.widget<ReaderScreen>(find.byType(ReaderScreen)).settings;
    expect(find.byKey(const ValueKey('frame-riwayat-lower')), findsNothing);
    final before = inCircle(t);
    final wheel = wheelOf();
    final circle = t.getCenter(inWheel(const ValueKey('frame-riwayat-circle')));
    // The one to its left, a slot along, dragged into the circle.
    final next = onWheel(t)[onWheel(t).indexOf(before) + 1];
    final dx =
        circle.dx - t.getCenter(inWheel(ValueKey('frame-riwaya-$next'))).dx;
    await t.dragFrom(t.getCenter(wheel), Offset(dx, 0));
    await t.pumpAndSettle();
    expect(settings.page, 3);
    expect(inCircle(t), next);
    expect(settings.displayed, next);
    // In the order of the Shatibiyya: the next after the one shown.
    expect(all.indexOf(next), all.indexOf(before) + 1);
    expect(t.takeException(), isNull);
  });

  // A riwaya come into the circle under the finger is shown at once, the
  // finger not lifted; the next after it as well (the user, 2026-11-15).
  testWidgets('the riwaya passing into the circle shown before the finger '
      'is lifted', (t) async {
    final all = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (r.id != hafsId) r.id,
    ];
    await showReader(t, selected: all.toSet());
    final settings = t.widget<ReaderScreen>(find.byType(ReaderScreen)).settings;
    final before = inCircle(t);
    final ids = onWheel(t);
    final next = ids[ids.indexOf(before) + 1];
    final after = ids[ids.indexOf(before) + 2];
    final step =
        t.getCenter(inWheel(ValueKey('frame-riwaya-$before'))).dx -
        t.getCenter(inWheel(ValueKey('frame-riwaya-$next'))).dx;
    final finger = await t.startGesture(t.getCenter(wheelOf()));
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(Offset(step / 10, 0));
      await t.pump();
    }
    expect(settings.displayed, next);
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(Offset(step / 10, 0));
      await t.pump();
    }
    expect(settings.displayed, after);
    await finger.up();
    await t.pumpAndSettle();
    expect(settings.displayed, after);
    expect(inCircle(t), after);
    expect(settings.page, 3);
    expect(t.takeException(), isNull);
  });

  // Near a riwaya, a little below it and not right on it: a tap brings it
  // into the circle, a drag turns the wheel; the page not turned (the user,
  // 2026-11-15).
  testWidgets('a touch just below the riwayat turns the wheel, not the page', (
    t,
  ) async {
    final all = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (r.id != hafsId) r.id,
    ];
    await showReader(t, selected: all.toSet());
    final settings = t.widget<ReaderScreen>(find.byType(ReaderScreen)).settings;
    final before = inCircle(t);
    final ids = onWheel(t);
    final next = ids[ids.indexOf(before) + 1];
    final square = t.getRect(inWheel(ValueKey('frame-riwaya-$next')));
    // Tapped below it, clear of its square.
    await t.tapAt(Offset(square.center.dx, square.bottom + 10));
    await t.pumpAndSettle();
    expect(settings.displayed, next);
    expect(settings.page, 3);
    // Dragged along below them: the wheel turned, the page not.
    final circle = t.getRect(inWheel(const ValueKey('frame-riwayat-circle')));
    final after = onWheel(t)[onWheel(t).indexOf(next) + 1];
    final step =
        circle.center.dx -
        t.getCenter(inWheel(ValueKey('frame-riwaya-$after'))).dx;
    await t.dragFrom(
      Offset(circle.center.dx - 40, circle.bottom + 12),
      Offset(step, 0),
    );
    await t.pumpAndSettle();
    expect(settings.displayed, after);
    expect(settings.page, 3);
    expect(t.takeException(), isNull);
  });
}
