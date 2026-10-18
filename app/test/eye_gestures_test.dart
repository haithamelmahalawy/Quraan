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
      d.feed(l, r, at: at);
      at = at.add(const Duration(milliseconds: 40));
    }
  }
  await Future<void>.delayed(const Duration(seconds: 1)); // sequence ends
  await sub.cancel();
  return seen;
}

const open = 0.95, shut = 0.05;

void main() {
  test('two blinks', () async {
    final g = await run([
      (open, open, 400),
      (shut, shut, 120), (open, open, 200),
      (shut, shut, 120), (open, open, 400),
    ]);
    expect(g.single, isA<DoubleBlink>());
  });

  test('one blink does nothing', () async {
    expect(await run([(open, open, 400), (shut, shut, 120), (open, open, 400)]),
        isEmpty);
  });

  test('three blinks do nothing', () async {
    final g = await run([
      (open, open, 400),
      (shut, shut, 120), (open, open, 200),
      (shut, shut, 120), (open, open, 200),
      (shut, shut, 120), (open, open, 400),
    ]);
    expect(g, isEmpty);
  });

  test('a wink does nothing', () async {
    expect(await run([(open, open, 400), (shut, open, 300), (open, open, 400)]),
        isEmpty);
  });
}
