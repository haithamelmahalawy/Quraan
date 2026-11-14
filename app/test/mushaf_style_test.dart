import 'dart:math' as math;

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

  test('the ring: for all, then men, girls, children; the children light', () {
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
        // Very light, warm rather than a glaring white (the user, 2026-11-14).
        expect(
          look.page.computeLuminance(),
          greaterThan(.95),
          reason: look.name,
        );
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

  // Under the finger, as the qurra's ring: dragged to the right, the look at
  // the left comes to the front (it ran the other way, the user,
  // 2026-11-14).
  testWidgets('dragged right, the look at the left comes to the front', (
    t,
  ) async {
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
    final emerald = find.byKey(const ValueKey('mushaf-style-emerald'));
    // The next after Madinah, at its left.
    expect(t.getCenter(emerald).dx, lessThan(200));
    await t.dragFrom(
      t.getCenter(find.byType(MushafStyleRing)) + const Offset(0, 50),
      const Offset(58, 0),
    );
    await t.pumpAndSettle();
    expect(t.getCenter(emerald).dx, closeTo(215, 5));
    expect(t.takeException(), isNull);
  });

  // Restful to the eye (the user, 2026-11-14): no page a glaring pure white,
  // every page very light, the frames not too bright.
  test('the looks are restful: no pure white page, no glaring frame', () {
    for (final look in MushafStyle.values) {
      expect(look.page, isNot(const Color(0xFFFFFFFF)), reason: look.name);
      expect(look.page.computeLuminance(), greaterThan(.85), reason: look.name);
      // Its purity: the strongest of its red, green and blue less the
      // weakest; a pastel or a deep shade is low, a vivid one high.
      final c = look.band;
      final rgb = [c.r, c.g, c.b];
      expect(
        rgb.reduce(math.max) - rgb.reduce(math.min),
        lessThan(.45),
        reason: '${look.name}: its band too bright',
      );
    }
  });
}
