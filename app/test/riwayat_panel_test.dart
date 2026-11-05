import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/riwayat_panel.dart';

void main() {
  Qiraa of(String id) =>
      qiraat.firstWhere((q) => q.riwayat.any((r) => r.id == id));
  final nafi = of('warsh');
  Finder qari(Qiraa q) => find.byKey(ValueKey('qari-check-${q.id}'));
  Finder check(String id) => find.byKey(ValueKey('riwaya-check-$id'));
  Finder show(String id) => find.byKey(ValueKey('riwaya-show-$id'));
  Finder inFront(Qiraa q) => find.byKey(ValueKey('riwayat-front-${q.id}'));
  final toggle = find.byKey(const ValueKey('riwayat-panel-toggle'));
  final panel = find.byKey(const ValueKey('riwayat-panel'));
  final ring = find.byKey(const ValueKey('riwayat-ring'));
  final mushaf = find.byKey(const ValueKey('mushaf'));

  Future<void> pump(
    WidgetTester t,
    ReaderSettings settings, {
    bool open = true,
  }) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RiwayatPanel(
              settings: settings,
              variants: VariantRepository({'warsh', 'qalun', 'bazzi'}),
              child: const SizedBox.expand(key: ValueKey('mushaf')),
            ),
          ),
        ),
      ),
    );
    if (open) {
      await t.tap(toggle);
      await t.pumpAndSettle();
    }
  }

  /// Turns the ring by dragging until [q] is in front.
  Future<void> turnTo(WidgetTester t, Qiraa q) async {
    for (var i = 0; i < qiraat.length && inFront(q).evaluate().isEmpty; i++) {
      await t.timedDrag(ring, const Offset(45, 0), const Duration(seconds: 1));
      await t.pumpAndSettle();
    }
    expect(inFront(q), findsOneWidget);
  }

  testWidgets('the arrow lets it down from the top, and sends it back up', (
    t,
  ) async {
    await pump(t, ReaderSettings.memory(), open: false);
    expect(panel, findsNothing);
    expect(t.getSize(mushaf).height, 900);
    // At the top, clear of the middle where the page's «الأصول» is.
    expect(t.getTopLeft(toggle).dy, 0);
    expect((t.getCenter(toggle).dx - 200).abs(), greaterThan(40));
    await t.tap(toggle);
    await t.pumpAndSettle();
    // Above the mushaf, which grows shorter by as much, as wide as it was.
    expect(t.getTopLeft(panel).dy, 0);
    expect(t.getTopLeft(mushaf).dy, RiwayatPanel.height);
    expect(t.getSize(mushaf).height, 900 - RiwayatPanel.height);
    expect(t.getSize(mushaf).width, 400);
    // The arrow stays, under it, to send it back up.
    expect(t.getTopLeft(toggle).dy, RiwayatPanel.height);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(panel, findsNothing);
    expect(t.getSize(mushaf).height, 900);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('one qari in front, bold and larger; the others fainter', (
    t,
  ) async {
    await pump(t, ReaderSettings.memory());
    await turnTo(t, qiraat.first);
    expect(inFront(qiraat.first), findsOneWidget);
    double opacityOf(Qiraa q) => t
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey('qari-cell-${q.id}')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacityOf(qiraat.first), 1);
    expect(opacityOf(qiraat[1]), lessThan(.7));
    expect(opacityOf(qiraat[1]), greaterThan(opacityOf(qiraat[2])));
    final name = t.widget<Text>(
      find.descendant(
        of: inFront(qiraat.first),
        matching: find.text(qiraat.first.shortAr),
      ),
    );
    expect(name.style!.fontWeight, FontWeight.w900);
    // The next at the left, as the text runs.
    expect(
      t.getCenter(qari(qiraat[1])).dx,
      lessThan(t.getCenter(qari(qiraat.first)).dx),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'it turns round by dragging, to every qari, and back to the first',
    (t) async {
      await pump(t, ReaderSettings.memory());
      for (final q in [...qiraat, qiraat.first]) {
        await turnTo(t, q);
      }
      // The mushaf stays as it is: only the ring moves.
      expect(t.getSize(mushaf).height, 900 - RiwayatPanel.height);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a qari behind, tapped, comes to the front, unticked', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    await turnTo(t, qiraat.first);
    final next = qiraat[1];
    // Its part in sight, beside the one in front.
    await t.tapAt(
      t.getTopLeft(find.byKey(ValueKey('qari-cell-${next.id}'))) +
          const Offset(8, 30),
    );
    await t.pumpAndSettle();
    expect(inFront(next), findsOneWidget);
    expect(settings.selected, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('it opens with the qari of the riwaya shown in front', (t) async {
    final settings = ReaderSettings.memory(selected: {'bazzi'})
      ..displayed = 'bazzi';
    await pump(t, settings);
    expect(inFront(of('bazzi')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a qari ticks both his riwayat, and takes them off', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    await turnTo(t, nafi);
    await t.tap(qari(nafi));
    await t.pumpAndSettle();
    expect(settings.selected, {'qalun', 'warsh'});
    expect(t.widget<Checkbox>(qari(nafi)).value, isTrue);
    expect(t.widget<Checkbox>(check('warsh')).value, isTrue);
    expect(t.widget<Checkbox>(check('qalun')).value, isTrue);
    // The first of them shown, Hafs not being among them.
    expect(settings.displayed, 'qalun');
    await t.tap(qari(nafi));
    await t.pumpAndSettle();
    expect(settings.selected, isEmpty);
    expect(settings.displayed, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('one riwaya of the two shows the qari half ticked', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    await turnTo(t, nafi);
    await t.tap(check('warsh'));
    await t.pumpAndSettle();
    expect(settings.selected, {'warsh'});
    expect(t.widget<Checkbox>(qari(nafi)).value, isNull);
    await t.tap(qari(nafi));
    await t.pumpAndSettle();
    expect(settings.selected, {'qalun', 'warsh'});
    expect(t.takeException(), isNull);
  });

  testWidgets('one riwaya shown only: another takes its place', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    await turnTo(t, nafi);
    await t.tap(show('warsh'));
    await t.pumpAndSettle();
    expect(settings.displayed, 'warsh');
    expect(settings.selected, {'warsh'});
    expect(t.widget<Checkbox>(show('warsh')).value, isTrue);
    await t.tap(show('qalun'));
    await t.pumpAndSettle();
    expect(settings.displayed, 'qalun');
    expect(settings.selected, {'qalun', 'warsh'});
    expect(t.widget<Checkbox>(show('warsh')).value, isFalse);
    expect(t.widget<Checkbox>(show('qalun')).value, isTrue);
    // Tapped again it stays: something is always shown.
    await t.tap(show('qalun'));
    await t.pumpAndSettle();
    expect(settings.displayed, 'qalun');
    expect(t.takeException(), isNull);
  });

  testWidgets('taking off the one shown leaves another, or Hafs', (t) async {
    final settings = ReaderSettings.memory(selected: {'warsh', 'qalun'})
      ..displayed = 'warsh';
    await pump(t, settings);
    await t.tap(check('warsh'));
    await t.pumpAndSettle();
    expect(settings.displayed, 'qalun');
    await t.tap(check('qalun'));
    await t.pumpAndSettle();
    expect(settings.displayed, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('Hafs shown stays among the riwayat compared', (t) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await pump(t, settings);
    await turnTo(t, of(hafsId));
    await t.tap(show(hafsId));
    await t.pumpAndSettle();
    expect(settings.displayed, isNull);
    expect(settings.compareHafs, isTrue);
    expect(settings.selected, {'warsh'});
    expect(t.takeException(), isNull);
  });

  testWidgets('clearing all leaves Hafs alone', (t) async {
    final settings = ReaderSettings.memory(selected: {'warsh', 'qalun'})
      ..displayed = 'warsh';
    await pump(t, settings);
    await t.tap(find.byKey(const ValueKey('riwayat-clear')));
    await t.pumpAndSettle();
    expect(settings.selected, isEmpty);
    expect(settings.displayed, isNull);
    expect(settings.compareHafs, isFalse);
    expect(t.takeException(), isNull);
  });
}
