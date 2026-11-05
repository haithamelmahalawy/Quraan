import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/riwayat_panel.dart';

int _rowOf(double width) => RiwayatPanel.frontRowFor(width);

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
    Size size = const Size(400, 900),
  }) async {
    t.view.physicalSize = size;
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
      await t.timedDrag(ring, const Offset(135, 0), const Duration(seconds: 1));
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
    // At the top, in the middle.
    expect(t.getTopLeft(toggle).dy, 0);
    expect(t.getCenter(toggle).dx, moreOrLessEquals(200, epsilon: 1));
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

  testWidgets('three in the front row, the others behind by name, fainter', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await pump(t, settings);
    final n = qiraat.length;
    final at = qiraat.indexOf(nafi);
    final right = qiraat[(at - 1) % n], left = qiraat[(at + 1) % n];
    for (final q in [right, nafi, left]) {
      expect(inFront(q), findsOneWidget);
      expect(qari(q), findsOneWidget);
    }
    // In one row, the next at the left, all in sight on the screen.
    // Curving back: its ends higher up and smaller than its middle.
    expect(
      t.getCenter(inFront(left)).dy,
      lessThan(t.getCenter(inFront(nafi)).dy),
    );
    expect(
      t.getCenter(inFront(left)).dy,
      moreOrLessEquals(t.getCenter(inFront(right)).dy, epsilon: 1),
    );
    expect(
      t.getBottomLeft(inFront(left)).dy - t.getTopLeft(inFront(left)).dy,
      lessThan(
        t.getBottomLeft(inFront(nafi)).dy - t.getTopLeft(inFront(nafi)).dy,
      ),
    );
    expect(t.getCenter(qari(left)).dx, lessThan(t.getCenter(qari(nafi)).dx));
    expect(
      t.getCenter(qari(right)).dx,
      greaterThan(t.getCenter(qari(nafi)).dx),
    );
    expect(t.getTopLeft(inFront(left)).dx, greaterThanOrEqualTo(0));
    expect(t.getTopRight(inFront(right)).dx, lessThanOrEqualTo(400));
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
    final behind = qiraat[(at + 5) % n], beside = qiraat[(at + 2) % n];
    expect(opacityOf(nafi), 1);
    expect(opacityOf(beside), lessThan(1));
    expect(opacityOf(beside), greaterThan(opacityOf(behind)));
    // All of them in sight, none with check boxes but the three.
    for (final q in qiraat) {
      expect(find.text(q.shortAr), findsOneWidget);
    }
    expect(qari(beside), findsNothing);
    final name = t.widget<Text>(
      find.descendant(of: inFront(nafi), matching: find.text(nafi.shortAr)),
    );
    expect(name.style!.fontWeight, FontWeight.w900);
    expect(t.takeException(), isNull);
  });

  testWidgets('the front row holds as many as the width does', (t) async {
    expect(_rowOf(360), 3);
    expect(_rowOf(430), 3);
    expect(_rowOf(600), 5);
    expect(_rowOf(860), 7);
    // All ten at last, with none behind.
    expect(_rowOf(1400), qiraat.length);
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await pump(t, settings, size: const Size(860, 400));
    final n = qiraat.length;
    final at = qiraat.indexOf(nafi);
    // The qari shown in the middle, three each side.
    for (var by = -3; by <= 3; by++) {
      final q = qiraat[(at + by) % n];
      expect(inFront(q), findsOneWidget, reason: q.shortAr);
      expect(t.getTopLeft(inFront(q)).dx, greaterThanOrEqualTo(0));
      expect(t.getTopRight(inFront(q)).dx, lessThanOrEqualTo(860));
    }
    expect(inFront(qiraat[(at + 4) % n]), findsNothing);
    // A drag brings one on, and takes one off.
    await t.timedDrag(ring, const Offset(120, 0), const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(inFront(qiraat[(at + 4) % n]), findsOneWidget);
    expect(inFront(qiraat[(at - 3) % n]), findsNothing);
    expect(inFront(qiraat[(at - 2) % n]), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('all ten stand in front on a wide screen', (t) async {
    await pump(t, ReaderSettings.memory(), size: const Size(1400, 600));
    for (final q in qiraat) {
      expect(inFront(q), findsOneWidget, reason: q.shortAr);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('those at the ends of the front row still answer', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings, size: const Size(860, 400));
    // Each riwaya of the row's end, by a tap on its box where it is drawn.
    final n = qiraat.length;
    final shown = qiraat.indexWhere(
      (q) => q.riwayat.any((r) => r.id == hafsId),
    );
    final end = qiraat[(shown - 3) % n];
    await t.tap(qari(end));
    await t.pumpAndSettle();
    expect(settings.selected, contains("bazzi"));
    expect(t.takeException(), isNull);
  });

  testWidgets('a drag turns it by one, a longer one by more', (t) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await pump(t, settings);
    final n = qiraat.length;
    final at = qiraat.indexOf(nafi);
    // The width of one: the next comes in, nafi's right neighbour goes.
    await t.timedDrag(ring, const Offset(130, 0), const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(inFront(qiraat[(at + 2) % n]), findsOneWidget);
    expect(inFront(nafi), findsOneWidget);
    expect(inFront(qiraat[(at - 1) % n]), findsNothing);
    // And back.
    await t.timedDrag(ring, const Offset(-130, 0), const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(inFront(qiraat[(at - 1) % n]), findsOneWidget);
    // The width of three brings three.
    await t.timedDrag(ring, const Offset(390, 0), const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(inFront(qiraat[(at + 4) % n]), findsOneWidget);
    expect(inFront(nafi), findsNothing);
    await t.timedDrag(ring, const Offset(-390, 0), const Duration(seconds: 2));
    await t.pumpAndSettle();
    // A slight touch turns nothing.
    await t.timedDrag(ring, const Offset(8, 0), const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(inFront(nafi), findsOneWidget);
    expect(inFront(qiraat[(at - 1) % n]), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the arrow stands over the middle of the header', (t) async {
    final at = ValueNotifier<double?>(150);
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RiwayatPanel(
              settings: ReaderSettings.memory(),
              variants: VariantRepository({'warsh'}),
              arrowAt: at,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    expect(t.getCenter(toggle).dx, moreOrLessEquals(150, epsilon: 1));
    at.value = 260;
    await t.pump();
    expect(t.getCenter(toggle).dx, moreOrLessEquals(260, epsilon: 1));
    at.value = null;
    await t.pump();
    expect(t.getCenter(toggle).dx, moreOrLessEquals(200, epsilon: 1));
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

  testWidgets('a qari behind, tapped, comes to the front', (t) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await pump(t, settings);
    final behind = qiraat[(qiraat.indexOf(nafi) + 5) % qiraat.length];
    expect(inFront(behind), findsNothing);
    await t.tap(find.byKey(ValueKey('qari-cell-${behind.id}')));
    await t.pumpAndSettle();
    expect(inFront(behind), findsOneWidget);
    expect(settings.selected, {'warsh'});
    expect(t.takeException(), isNull);
  });

  testWidgets('it opens with the qari of the riwaya shown in front', (t) async {
    final settings = ReaderSettings.memory(selected: {'bazzi'})
      ..displayed = 'bazzi';
    await pump(t, settings);
    expect(inFront(of('bazzi')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('those chosen gather on the ring, the one tapped staying put', (
    t,
  ) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    final asim = of(hafsId);
    // Hafs's qari opens in the middle; tick his riwaya.
    expect(inFront(asim), findsOneWidget);
    final x = t.getCenter(check(hafsId)).dx;
    await t.tap(check(hafsId));
    await t.pumpAndSettle();
    expect(settings.compareHafs, isTrue);
    // He stays under the finger, though first on the ring now.
    expect(t.getCenter(check(hafsId)).dx, moreOrLessEquals(x, epsilon: 1));
    expect(inFront(asim), findsOneWidget);
    // Beside him now, the first of those not chosen: at his left.
    expect(inFront(nafi), findsOneWidget);
    expect(t.getCenter(inFront(nafi)).dx, lessThan(x));
    // Another chosen: the two next to each other, in the catalogue's order.
    final y = t.getCenter(check('warsh')).dx;
    await t.tap(check('warsh'));
    await t.pumpAndSettle();
    expect(settings.selected, {'warsh'});
    expect(t.getCenter(check('warsh')).dx, moreOrLessEquals(y, epsilon: 1));
    expect(
      t.getCenter(find.byKey(ValueKey('qari-cell-${asim.id}'))).dx,
      lessThan(y),
    );
    // Taken off, he goes back among the others, still under the finger.
    await t.tap(check('warsh'));
    await t.pumpAndSettle();
    expect(settings.selected, isEmpty);
    expect(t.getCenter(check('warsh')).dx, moreOrLessEquals(y, epsilon: 1));
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
