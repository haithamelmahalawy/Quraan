import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/riwayat_panel.dart';

void main() {
  final nafi = qiraat.firstWhere((q) => q.riwayat.any((r) => r.id == 'warsh'));
  Finder qari() => find.byKey(ValueKey('qari-check-${nafi.id}'));
  Finder check(String id) => find.byKey(ValueKey('riwaya-check-$id'));
  Finder show(String id) => find.byKey(ValueKey('riwaya-show-$id'));
  final openIt = find.byKey(const ValueKey('riwayat-panel-open'));
  final closeIt = find.byKey(const ValueKey('riwayat-panel-close'));
  final panel = find.byKey(const ValueKey('riwayat-panel'));
  final mushaf = find.byKey(const ValueKey('mushaf'));

  Future<void> pump(
    WidgetTester t,
    ReaderSettings settings, {
    bool open = true,
    ValueNotifier<bool?>? margin,
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
              marginSide: margin,
              child: const SizedBox.expand(key: ValueKey('mushaf')),
            ),
          ),
        ),
      ),
    );
    if (open) {
      await t.tap(openIt);
      await t.pumpAndSettle();
    }
  }

  testWidgets('the arrow is at the right, the mushaf whole beside the list', (
    t,
  ) async {
    await pump(t, ReaderSettings.memory(), open: false);
    expect(t.getSize(mushaf).width, 400);
    expect(t.getTopRight(openIt).dx, 400);
    expect(panel, findsNothing);
    await t.tap(openIt);
    await t.pumpAndSettle();
    // Smaller by as much as the list, which is at the right.
    expect(t.getSize(mushaf).width, 400 - RiwayatPanel.width);
    expect(t.getTopRight(panel).dx, 400);
    expect(t.getTopRight(mushaf).dx, t.getTopLeft(panel).dx);
    expect(RiwayatPanel.width, lessThan(140));
    // As large again once closed, and called again at any time.
    await t.tap(closeIt);
    await t.pumpAndSettle();
    expect(t.getSize(mushaf).width, 400);
    await t.tap(openIt);
    await t.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the arrow stays, at the list\'s edge, to close it', (t) async {
    await pump(t, ReaderSettings.memory());
    expect(closeIt, findsOneWidget);
    expect(openIt, findsNothing);
    // On the side of the mushaf, within the list.
    expect(
      t.getTopLeft(closeIt).dx,
      moreOrLessEquals(t.getTopLeft(panel).dx, epsilon: 1),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('the list opens across from the hamesh, both in sight', (
    t,
  ) async {
    final side = ValueNotifier<bool?>(true);
    await pump(t, ReaderSettings.memory(), open: false, margin: side);
    // The hamesh at the right: the arrow at the left, and the page whole.
    expect(t.getTopLeft(openIt).dx, 0);
    expect(t.getSize(mushaf).width, 400);
    await t.tap(openIt);
    await t.pumpAndSettle();
    expect(t.getTopLeft(panel).dx, 0);
    expect(t.getTopLeft(mushaf).dx, RiwayatPanel.width);
    expect(t.getTopRight(mushaf).dx, 400);
    expect(t.getSize(mushaf).width, 400 - RiwayatPanel.width);
    // The arrow at the list's edge, on the side of the mushaf.
    expect(
      t.getTopRight(closeIt).dx,
      moreOrLessEquals(t.getTopRight(panel).dx, epsilon: 1),
    );
    // The hamesh at the left: the list at the right.
    side.value = false;
    await t.pumpAndSettle();
    expect(t.getTopRight(panel).dx, 400);
    expect(t.getTopLeft(mushaf).dx, 0);
    expect(t.getSize(mushaf).width, 400 - RiwayatPanel.width);
    // No hamesh: at the right too.
    side.value = null;
    await t.pumpAndSettle();
    expect(t.getTopRight(panel).dx, 400);
    expect(t.getSize(mushaf).width, 400 - RiwayatPanel.width);
    await t.tap(closeIt);
    await t.pumpAndSettle();
    expect(t.getSize(mushaf).width, 400);
    expect(t.getTopRight(openIt).dx, 400);
    expect(t.takeException(), isNull);
  });

  testWidgets('a qari ticks both his riwayat, and takes them off', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    await t.tap(qari());
    await t.pumpAndSettle();
    expect(settings.selected, {'qalun', 'warsh'});
    expect(t.widget<Checkbox>(qari()).value, isTrue);
    expect(t.widget<Checkbox>(check('warsh')).value, isTrue);
    expect(t.widget<Checkbox>(check('qalun')).value, isTrue);
    // The first of them shown, Hafs not being among them.
    expect(settings.displayed, 'qalun');
    await t.tap(qari());
    await t.pumpAndSettle();
    expect(settings.selected, isEmpty);
    expect(settings.displayed, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('one riwaya of the two shows the qari half ticked', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
    await t.tap(check('warsh'));
    await t.pumpAndSettle();
    expect(settings.selected, {'warsh'});
    expect(t.widget<Checkbox>(qari()).value, isNull);
    await t.tap(qari());
    await t.pumpAndSettle();
    expect(settings.selected, {'qalun', 'warsh'});
    expect(t.takeException(), isNull);
  });

  testWidgets('one riwaya shown only: another takes its place', (t) async {
    final settings = ReaderSettings.memory();
    await pump(t, settings);
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
    await t.dragUntilVisible(show(hafsId), panel, const Offset(0, -100));
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
    await t.dragUntilVisible(
      find.byKey(const ValueKey('riwayat-clear')),
      panel,
      const Offset(0, -200),
    );
    await t.tap(find.byKey(const ValueKey('riwayat-clear')));
    await t.pumpAndSettle();
    expect(settings.selected, isEmpty);
    expect(settings.displayed, isNull);
    expect(settings.compareHafs, isFalse);
    expect(t.takeException(), isNull);
  });
}
