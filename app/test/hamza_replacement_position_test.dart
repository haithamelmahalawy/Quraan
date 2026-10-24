import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/hamza_replacement_mark.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  testWidgets('replacement circle follows source hamza rather than waw or ya', (
    t,
  ) async {
    for (final scale in [1.0, 1.8]) {
      for (final font in [12.0, 36.0]) {
        for (final (text, original, letter, below) in [
          ('اَ۪وْ', 'أَ', 'ي', false),
          ('اِن', 'إِ', 'ي', true),
          ('اِلَىٰ', 'إِ', 'و', true),
          ('اَلَا', 'أَ', 'و', false),
          ('اَلَا', 'أَ', 'ي', false),
          ('اِن', 'إِ', 'و', true),
        ]) {
          final style = TextStyle(
            fontFamily: 'Hafs',
            fontSize: font,
            height: 1.4,
          );
          await t.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: HamzaReplacementMark(
                    text: text,
                    originalHamza: original,
                    letter: letter,
                    style: style,
                    color: Colors.purple,
                    builder: (shown, _) => Text(
                      shown,
                      style: style,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ),
            ),
          );
          final textFinder = find.descendant(
            of: find.byType(HamzaReplacementMark),
            matching: find.byType(Text),
          );
          final measure = TextPainter(
            text: TextSpan(text: t.widget<Text>(textFinder).data, style: style),
            textDirection: TextDirection.rtl,
            textScaler: TextScaler.linear(scale),
          )..layout();
          final baseline = measure.computeLineMetrics().single.baseline;
          final paint = find.descendant(
            of: find.byType(HamzaReplacementMark),
            matching: find.byType(CustomPaint),
          );
          late Offset center;
          expect(
            (Canvas c) => t
                .widget<CustomPaint>(paint)
                .foregroundPainter!
                .paint(c, t.getSize(paint)),
            paints..something((method, args) {
              if (method != #drawCircle) return false;
              center = args[0] as Offset;
              return true;
            }),
          );
          expect(
            center.dy,
            below
                ? greaterThan(baseline)
                : lessThan(baseline - font * scale * .5),
            reason: '$original replaced by $letter at $scale / $font',
          );
          expect(t.widget<Text>(textFinder).data, isNot(matches('[أإٕ۪ٔ]')));
          expect(t.takeException(), isNull);
          measure.dispose();
        }
      }
    }
  });
}
