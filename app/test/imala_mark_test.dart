import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';
import 'package:qiraat_mushaf/ui/quran_word_text.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  testWidgets(
    'imala remains visible below the ya dots at different text scales',
    (t) async {
      for (final scale in [1.0, 1.8]) {
        const style = TextStyle(
          fontFamily: 'Hafs',
          fontSize: 40,
          height: 1,
          color: Colors.green,
        );
        final word = withImalaSign('دِيَارِكُمْ');
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(child: QuranWordText(word, style: style)),
            ),
          ),
        );
        final paint = find.descendant(
          of: find.byType(HafsFontMarks),
          matching: find.byType(CustomPaint),
        );
        expect(paint, findsOneWidget);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..translate(0, 100);
        t
            .widget<CustomPaint>(paint)
            .foregroundPainter!
            .paint(canvas, t.getSize(paint));
        final picture = recorder.endRecording();
        final raster = await t.runAsync(() => picture.toImage(500, 400));
        final pixels = await t.runAsync(
          () => raster!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final ys = <int>[];
        for (var i = 3; i < pixels!.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) > 0) ys.add((i ~/ 4) ~/ 500);
        }
        final measure = TextPainter(
          text: TextSpan(text: 'دِيَارِكُمْ', style: style),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.linear(scale),
        )..layout();
        final baseline = measure.computeLineMetrics().single.baseline;
        expect(ys, isNotEmpty);
        expect(
          ys.reduce((a, b) => a < b ? a : b),
          greaterThan(100 + baseline + 40 * scale * .38),
        );
        raster!.dispose();
        picture.dispose();
        measure.dispose();
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'imala under the dots in Quran text and margin sizes',
    tags: 'golden',
    (t) async {
      t.view.physicalSize = const Size(760, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('imala-dots'),
                child: Container(
                  color: Colors.white,
                  width: 720,
                  height: 760,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final size in [16.0, 36.0, 72.0])
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final word in ['دِيَارِكُمْ', 'دِيَارِهِمْ'])
                              InkText(
                                withImalaSign(word),
                                style: TextStyle(
                                  fontFamily: 'Hafs',
                                  fontSize: size,
                                  height: 1,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final word in ['دِيَارِكُمْ', 'دِيَارِهِمْ'])
                            QuranWordText(
                              withImalaSign(word),
                              style: const TextStyle(
                                fontFamily: 'Hafs',
                                fontSize: 40,
                                height: 1,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('imala-dots')),
        matchesGoldenFile('goldens/imala_dots.png'),
      );
    },
  );
}
