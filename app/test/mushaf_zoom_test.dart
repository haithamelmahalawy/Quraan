import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/mushaf_zoom.dart';

void main() {
  late TransformationController controller;
  late List<bool> pinches;
  var taps = 0;
  var doubles = 0;
  late List<int> turns;

  setUp(() {
    controller = TransformationController();
    pinches = [];
    taps = 0;
    doubles = 0;
    turns = [];
  });
  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester t) => t.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 500,
          child: MushafZoom(
            controller: controller,
            onPinchChanged: pinches.add,
            onEdgeTurn: turns.add,
            onDoubleTap: () => doubles++,
            child: GestureDetector(
              onTap: () => taps++,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );

  Future<(TestGesture, TestGesture)> fingers(WidgetTester t) async {
    final center = t.getCenter(find.byType(MushafZoom));
    final first = await t.startGesture(
      center - const Offset(60, 0),
      pointer: 1,
    );
    final second = await t.startGesture(
      center + const Offset(60, 0),
      pointer: 2,
    );
    await t.pump();
    return (first, second);
  }

  testWidgets('a four-pixel pinch responds immediately around the fingers', (
    t,
  ) async {
    await show(t);
    final (first, second) = await fingers(t);
    expect(pinches, [true]);
    final anchor = controller.toScene(const Offset(200, 250));
    await first.moveBy(const Offset(-4, 0));
    await second.moveBy(const Offset(4, 0));
    await t.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.08));
    expect(
      (controller.toScene(const Offset(200, 250)) - anchor).distance,
      lessThan(.001),
    );
    await first.moveBy(const Offset(4, 0));
    await second.moveBy(const Offset(-4, 0));
    await first.up();
    await second.up();
    await t.pump();
    expect(controller.value.getMaxScaleOnAxis(), 1);
    expect(pinches, [true, false]);
    expect(
      taps,
      0,
      reason: 'A pinch must not open the word below either finger.',
    );
    // The double tap's wait over.
    await t.pump(kDoubleTapTimeout);
    expect(t.takeException(), isNull);
  });

  testWidgets('zoomed in, a drag on past the side turns the page', (t) async {
    await show(t);
    // Zoomed in at the middle: the page can still be moved both ways.
    controller.value = Matrix4.identity()
      ..setEntry(0, 0, 2)
      ..setEntry(1, 1, 2)
      ..setEntry(0, 3, -200)
      ..setEntry(1, 3, -250);
    await t.pump();
    final center = t.getCenter(find.byType(MushafZoom));
    // Within the page: it only moves.
    await t.dragFrom(center, const Offset(120, 0));
    await t.pumpAndSettle();
    expect(turns, isEmpty);
    expect(controller.value.getTranslation().x, inExclusiveRange(-200, 0));
    // On to its left side and past it: the next page (dragged right).
    await t.dragFrom(center, const Offset(260, 0));
    await t.pumpAndSettle();
    expect(turns, [1]);
    expect(controller.value.getTranslation().x, 0);
    // Across to its right side and past it: back.
    await t.dragFrom(center, const Offset(-600, 0));
    await t.pumpAndSettle();
    expect(turns, [1, -1]);
    // Down the page: no turn.
    await t.dragFrom(center, const Offset(0, 300));
    await t.pumpAndSettle();
    expect(turns, [1, -1]);
  });

  testWidgets('zoom out is responsive and stays within the page bounds', (
    t,
  ) async {
    controller.value = Matrix4.identity()
      ..setEntry(0, 0, 3)
      ..setEntry(1, 1, 3)
      ..setEntry(0, 3, -400)
      ..setEntry(1, 3, -500);
    await show(t);
    final (first, second) = await fingers(t);
    await first.moveBy(const Offset(10, 0));
    await second.moveBy(const Offset(-10, 0));
    await t.pump();
    final scale = controller.value.getMaxScaleOnAxis();
    expect(scale, inExclusiveRange(1, 2.5));
    await first.moveBy(const Offset(-200, 0));
    await second.moveBy(const Offset(200, 0));
    await t.pump();
    expect(controller.value.getMaxScaleOnAxis(), 4);
    final offset = controller.value.getTranslation();
    expect(offset.x, inInclusiveRange(-1200, 0));
    expect(offset.y, inInclusiveRange(-1500, 0));
    await first.moveBy(const Offset(4, 0));
    await second.moveBy(const Offset(-4, 0));
    await t.pump();
    expect(
      controller.value.getMaxScaleOnAxis(),
      lessThan(3.95),
      reason: 'Reverse immediately after reaching maximum zoom.',
    );
    await first.up();
    await second.up();
    // The double tap's wait over.
    await t.pump(kDoubleTapTimeout);
    expect(t.takeException(), isNull);
  });

  testWidgets('the remaining finger can pan after a pinch', (t) async {
    await show(t);
    final (first, second) = await fingers(t);
    await first.moveBy(const Offset(-35, 0));
    await second.moveBy(const Offset(35, 0));
    await second.up();
    await t.pump();
    final before = controller.value.getTranslation();
    await first.moveBy(const Offset(-12, -9));
    await t.pump();
    final after = controller.value.getTranslation();
    expect(after.x, closeTo(before.x - 12, .001));
    expect(after.y, closeTo(before.y - 9, .001));
    await first.up();
    // The double tap's wait over.
    await t.pump(kDoubleTapTimeout);
    expect(t.takeException(), isNull);
  });

  testWidgets('reversing at the minimum zoom has no dead range', (t) async {
    await show(t);
    final (first, second) = await fingers(t);
    await first.moveBy(const Offset(20, 0));
    await second.moveBy(const Offset(-20, 0));
    await t.pump();
    expect(controller.value.getMaxScaleOnAxis(), 1);
    await first.moveBy(const Offset(-4, 0));
    await second.moveBy(const Offset(4, 0));
    await t.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.08));
    await first.up();
    await second.up();
    // The double tap's wait over.
    await t.pump(kDoubleTapTimeout);
    expect(t.takeException(), isNull);
  });

  testWidgets('finger replacement and cancellation do not jump the zoom', (
    t,
  ) async {
    await show(t);
    final (first, second) = await fingers(t);
    await first.moveBy(const Offset(-25, 0));
    final before = controller.value.clone();
    final third = await t.startGesture(
      t.getCenter(find.byType(MushafZoom)) + const Offset(0, 70),
      pointer: 3,
    );
    await t.pump();
    await first.up();
    await t.pump();
    expect(controller.value, before);
    await second.cancel();
    await third.cancel();
    await t.pump();
    expect(pinches.last, isFalse);
    // The double tap's wait over.
    await t.pump(kDoubleTapTimeout);
    expect(t.takeException(), isNull);
  });

  testWidgets('normal taps still open a word at the base size', (t) async {
    await show(t);
    await t.tap(find.byType(MushafZoom));
    // Once no second tap follows.
    await t.pump(kDoubleTapTimeout);
    expect(taps, 1);
    expect(pinches, isEmpty);
    expect(controller.value, Matrix4.identity());
  });

  testWidgets('two quick taps enlarge the page as full screen, not zoom', (
    t,
  ) async {
    await show(t);
    final at = t.getTopLeft(find.byType(MushafZoom)) + const Offset(100, 120);
    var clock = const Duration(seconds: 1);
    Future<void> tapAt(Duration time) async {
      final g = await t.createGesture();
      await g.down(at, timeStamp: time);
      await g.up(timeStamp: time + const Duration(milliseconds: 50));
      await t.pump();
    }

    Future<void> twice() async {
      clock += const Duration(seconds: 5);
      await tapAt(clock);
      await tapAt(clock + const Duration(milliseconds: 150));
      await t.pumpAndSettle();
    }

    await twice();
    expect(doubles, 1);
    // The place tapped is not zoomed in on: the panel's enlarging is used.
    expect(controller.value, Matrix4.identity());
    await twice();
    expect(doubles, 2);
    // Two taps apart are no double tap.

    await tapAt(const Duration(seconds: 100));
    await tapAt(const Duration(seconds: 101));
    expect(doubles, 2);
    await tapAt(const Duration(seconds: 101, milliseconds: 150));
    expect(doubles, 3);
  });

  testWidgets(
    'a word answers its tap at once, not after the wait of a double tap',
    (t) async {
      await show(t);
      final at = t.getTopLeft(find.byType(MushafZoom)) + const Offset(100, 120);
      await t.tapAt(at);
      // No wait for a second tap: the word's tap is told on lifting.
      await t.pump();
      expect(taps, 1);
      expect(doubles, 0);
    },
  );
}
