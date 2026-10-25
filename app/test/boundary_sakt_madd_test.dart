import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';
import 'package:qiraat_mushaf/ui/quran_word_text.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  test(
    'boundary spacing moves only separate sakt and preserves silent alif',
    () {
      expect(
        HafsFontMarks.boundarySpacing('مِنۡۜ أَمۡرِهِۦ'),
        'مِنۡ\u2009 أَمۡرِهِۦ',
      );
      expect(
        HafsFontMarks.boundarySpacing('إِلَٰهًۜا ءَاخَرَ'),
        'إِلَٰهًا\u2009 ءَاخَرَ',
      );
      for (final internal in ['وَٱلۡۜأَرۡضَ', 'شَيۡۜءٍ', 'شَيۡۜءٍ أَكۡبَرُ']) {
        expect(HafsFontMarks.boundarySpacing(internal), internal);
      }
    },
  );

  testWidgets(
    'separate sakt is painted over the inter-word gap at different sizes',
    (t) async {
      for (final size in [18.0, 40.0, 64.0]) {
        for (final sample in [
          'مِنۡۜ أَمۡرِهِۦ',
          'لَنَسۡـَٔلَنَّهُمۡۜ أَجۡمَعِينَ',
          'إِلَٰهًۜا ءَاخَرَ',
        ]) {
          final style = TextStyle(
            fontFamily: 'Hafs',
            fontSize: size,
            height: 1,
            color: Colors.green,
          );
          await t.pumpWidget(
            MaterialApp(
              home: Center(child: QuranWordText(sample, style: style)),
            ),
          );
          final paint = find.descendant(
            of: find.byType(HafsFontMarks),
            matching: find.byType(CustomPaint),
          );
          expect(paint, findsOneWidget);
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(100, 150);
          t
              .widget<CustomPaint>(paint)
              .foregroundPainter!
              .paint(canvas, t.getSize(paint));
          final picture = recorder.endRecording();
          final raster = await t.runAsync(() => picture.toImage(1000, 350));
          final data = await t.runAsync(
            () => raster!.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          final xs = <int>[], ys = <int>[];
          for (var i = 3; i < data!.lengthInBytes; i += 4) {
            if (data.getUint8(i) > 0) {
              xs.add((i ~/ 4) % 1000);
              ys.add((i ~/ 4) ~/ 1000);
            }
          }
          final shown = HafsFontMarks.boundarySpacing(sample);
          final measure = TextPainter(
            text: TextSpan(text: shown, style: style),
            textDirection: TextDirection.rtl,
          )..layout();
          final at = shown.indexOf('\u2009');
          final gap = measure
              .getBoxesForSelection(
                TextSelection(baseOffset: at, extentOffset: at + 1),
              )
              .single;
          expect(xs, isNotEmpty);
          final left = xs.reduce((a, b) => a < b ? a : b),
              right = xs.reduce((a, b) => a > b ? a : b);
          expect(
            (left + right) / 2,
            closeTo(100 + (gap.left + gap.right) / 2, size * .08),
          );
          expect(
            ys.reduce((a, b) => a > b ? a : b),
            lessThan(
              150 + measure.computeLineMetrics().single.baseline - size * .60,
            ),
          );
          raster!.dispose();
          picture.dispose();
          measure.dispose();
          expect(t.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('madd is raised clear of fatha and dagger alif', (t) async {
    for (final sample in ['جَآءَ', 'مَلَٰٓئِكَةُ', 'ٱسۡتَوَىٰٓ']) {
      const style = TextStyle(
        fontFamily: 'Hafs',
        fontSize: 40,
        height: 1,
        color: Colors.green,
      );
      await t.pumpWidget(
        MaterialApp(
          home: Center(child: QuranWordText(sample, style: style)),
        ),
      );
      final paint = find.descendant(
        of: find.byType(HafsFontMarks),
        matching: find.byType(CustomPaint),
      );
      expect(paint, findsOneWidget);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(100, 150);
      t
          .widget<CustomPaint>(paint)
          .foregroundPainter!
          .paint(canvas, t.getSize(paint));
      final picture = recorder.endRecording();
      final raster = await t.runAsync(() => picture.toImage(500, 300));
      final data = await t.runAsync(
        () => raster!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final ys = <int>[];
      for (var i = 3; i < data!.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 0) ys.add((i ~/ 4) ~/ 500);
      }
      final measure = TextPainter(
        text: TextSpan(text: sample.replaceAll('ٓ', ''), style: style),
        textDirection: TextDirection.rtl,
      )..layout();
      expect(ys, isNotEmpty);
      expect(
        ys.reduce((a, b) => a > b ? a : b),
        lessThan(
          150 +
              measure.computeLineMetrics().single.baseline -
              40 * (sample.contains('ٰ') ? .95 : .78),
        ),
      );
      raster!.dispose();
      picture.dispose();
      measure.dispose();
      expect(t.takeException(), isNull);
    }
  });
}
