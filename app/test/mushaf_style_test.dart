import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_style_sheet.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

/// «شكل المصحف»: the looks on a ring over the page; a look touched is put on
/// the mushaf at once; in one row, those for all, then the men's, the
/// girls', the children's (the user, 2026-11-14).
void main() {
  test('twenty-six looks, Madinah the first, each with its own name', () {
    expect(MushafStyle.values, hasLength(26));
    expect(MushafStyle.named('nothing'), MushafStyle.madinah);
    expect({for (final s in MushafStyle.values) s.nameAr}, hasLength(26));
    expect(ReaderSettings.memory(selected: const {}).mushafStyle, 'madinah');
  });

  test('the ring: for all, then men, girls, children; the children white', () {
    final looks = MushafStyleRing.looks;
    expect(looks, hasLength(26));
    expect(looks.first, MushafStyle.madinah);
    final order = [for (final l in looks) l.audience];
    expect(order, [
      ...order.where((a) => a == MushafAudience.all),
      ...order.where((a) => a == MushafAudience.men),
      ...order.where((a) => a == MushafAudience.girls),
      ...order.where((a) => a == MushafAudience.kids),
    ]);
    for (final audience in [
      MushafAudience.men,
      MushafAudience.girls,
      MushafAudience.kids,
    ]) {
      expect(order.where((a) => a == audience), hasLength(3));
    }
    for (final look in looks) {
      if (look.audience == MushafAudience.kids) {
        expect(look.page, const Color(0xFFFFFFFF), reason: look.name);
      }
    }
  });

  testWidgets('a look touched is put on the mushaf at once', (t) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: const {});
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MushafStyleRing(settings: settings)),
        ),
      ),
    );
    // No sorting of them: no chips.
    expect(find.byType(ChoiceChip), findsNothing);
    final emerald = find.byKey(const ValueKey('mushaf-style-emerald'));
    final before = t.getCenter(emerald).dx;
    await t.tap(emerald);
    await t.pumpAndSettle();
    // Put on at once, and brought to the front, the middle.
    expect(settings.mushafStyle, 'emerald');
    expect(t.getCenter(emerald).dx, isNot(closeTo(before, 5)));
    expect(t.getCenter(emerald).dx, closeTo(215, 5));
    // Turned on by a drag, the ring shows those further on.
    await t.drag(find.byType(MushafStyleRing), const Offset(300, 0));
    await t.pumpAndSettle();
    expect(settings.mushafStyle, 'emerald');
    expect(t.takeException(), isNull);
  });
}
