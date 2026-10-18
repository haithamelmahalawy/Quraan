import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/services/blink_detector.dart';

/// Feeds eye readings 40 ms apart (25 frames per second): each step is
/// (left, right) open probabilities held for [ms].
Future<List<EyeGesture>> run(List<(double, double, int)> steps) async {
  final d = BlinkDetector();
  final seen = <EyeGesture>[];
  final sub = d.gestures.listen(seen.add);
  var at = DateTime(2026);
  for (final (l, r, ms) in steps) {
    for (var k = 0; k < ms; k += 40) {
      d.feed(l, r, pitch: 0, at: at);
      at = at.add(const Duration(milliseconds: 40));
    }
  }
  await Future<void>.delayed(const Duration(seconds: 1)); // sequence ends
  await sub.cancel();
  return seen;
}

const open = 0.95, shut = 0.05;

void main() {
  test('left wink, right wink', () async {
    final g = await run([
      (open, open, 400), (shut, open, 300), (open, open, 400),
      (open, shut, 300), (open, open, 400),
    ]);
    expect(g.map((e) => (e as Wink).left), [true, false]);
  });

  test('three blinks', () async {
    final g = await run([
      (open, open, 400),
      (shut, shut, 120), (open, open, 200),
      (shut, shut, 120), (open, open, 200),
      (shut, shut, 120), (open, open, 400),
    ]);
    expect(g.single, isA<TripleBlink>());
  });

  test('a natural blink does nothing, a deliberate one counts', () async {
    expect(await run([(open, open, 400), (shut, shut, 120), (open, open, 400)]),
        isEmpty);
    final g = await run([(open, open, 400), (shut, shut, 360), (open, open, 400)]);
    expect(g.single, isA<DeliberateBlink>());
  });

  test('a blink where one eye closes first is not a wink', () async {
    final g = await run([
      (open, open, 400), (shut, open, 40), (shut, shut, 120), (open, open, 400),
    ]);
    expect(g.whereType<Wink>(), isEmpty);
  });
}
