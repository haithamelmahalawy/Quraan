import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/guide_depth.dart';

void main() {
  testWidgets('raised cards leave vertical scrolling available', (t) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              for (var i = 0; i < 12; i++)
                GuideDepthSurface(
                  accent: Colors.teal,
                  child: SizedBox(
                    height: 140,
                    child: Center(child: Text('Card $i')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await t.drag(find.text('Card 1'), const Offset(0, -220));
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(150));
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion preserves card geometry and nested controls', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: GuideDepthSurface(
                  accent: Colors.teal,
                  child: SizedBox(
                    height: 140,
                    child: Center(
                      child: TextButton(
                        onPressed: () => taps++,
                        child: const Text('Open biography'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final before = t.getRect(find.text('Open biography'));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(before.center);
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Open biography')), before);
    await t.tap(find.text('Open biography'));
    await t.pumpAndSettle();
    expect(taps, 1);
    expect(t.getRect(find.text('Open biography')), before);
    await mouse.removePointer();
    expect(t.takeException(), isNull);
  });
}
