import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/stopping_taqlil_mark.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  testWidgets(
    'stopping taqlil paints a small ring and centered dot below final alif',
    (t) async {
      const text = 'أَذًى';
      const style = TextStyle(fontFamily: 'Hafs', fontSize: 40, height: 1);
      for (final scale in [1.0, 1.8]) {
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: StoppingTaqlilMark(
                  text: text,
                  style: style,
                  color: Colors.green,
                  child: const Text(
                    text,
                    style: style,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        );
        final paint = find.descendant(
          of: find.byType(StoppingTaqlilMark),
          matching: find.byType(CustomPaint),
        );
        late Offset center;
        late double radius;
        expect(
          (Canvas canvas) => t
              .widget<CustomPaint>(paint)
              .foregroundPainter!
              .paint(canvas, t.getSize(paint)),
          paints
            ..something((method, args) {
              if (method != #drawCircle) return false;
              center = args[0] as Offset;
              radius = args[1] as double;
              return (args[2] as Paint).style == PaintingStyle.stroke;
            })
            ..something(
              (method, args) =>
                  method == #drawCircle &&
                  args[0] == center &&
                  (args[1] as double) < radius / 2 &&
                  (args[2] as Paint).style == PaintingStyle.fill,
            ),
        );
        final measure = TextPainter(
          text: const TextSpan(text: text, style: style),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.linear(scale),
        )..layout();
        final at = text.lastIndexOf('ى');
        final box = measure
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + 1),
            )
            .single;
        expect(center.dx, closeTo((box.left + box.right) / 2, .1));
        expect(
          center.dy - radius,
          greaterThan(measure.computeLineMetrics().single.baseline),
        );
        expect(radius, lessThan(40 * scale * .1));
        measure.dispose();
        expect(t.takeException(), isNull);
      }
    },
  );
}
