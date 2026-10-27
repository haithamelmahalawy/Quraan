import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  testWidgets('iqlab mim stays outside the letter at different scales', (
    t,
  ) async {
    for (final scale in [1.0, 1.8]) {
      for (final sign in ['ۢ', 'ۭ']) {
        const style = TextStyle(
          fontFamily: 'Hafs',
          fontSize: 40,
          height: 1,
          color: Colors.green,
        );
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(child: InkText('ءَايَٰتِ$sign', style: style)),
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
          text: const TextSpan(text: 'ءَايَٰتِ', style: style),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.linear(scale),
        )..layout();
        final baseline = 100 + measure.computeLineMetrics().single.baseline;
        expect(ys, isNotEmpty, reason: '$sign at $scale');
        if (sign == 'ۭ') {
          expect(
            ys.reduce((a, b) => a < b ? a : b),
            greaterThan(baseline + 40 * scale * .15),
          );
        } else {
          expect(
            ys.reduce((a, b) => a > b ? a : b),
            lessThan(baseline - 40 * scale * .65),
          );
        }
        raster!.dispose();
        picture.dispose();
        measure.dispose();
        expect(t.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'iqlab on ta remains clear in printed Quran sizes',
    tags: 'golden',
    (t) async {
      t.view.physicalSize = const Size(700, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('iqlab'),
                child: Container(
                  width: 650,
                  height: 650,
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final size in [18.0, 40.0, 72.0])
                        for (final word in [
                          'ءَايَٰتِۭ بَيِّنَٰتٖ',
                          'ءَايَٰتِۢ بَيِّنَٰتٖ',
                          'سَمِيعُۢ بَصِيرٌ',
                        ])
                          InkText(
                            word,
                            style: TextStyle(
                              fontFamily: 'Hafs',
                              fontSize: size,
                              height: 1,
                              color: Colors.black,
                            ),
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
        find.byKey(const ValueKey('iqlab')),
        matchesGoldenFile('goldens/iqlab_marks.png'),
      );
    },
  );

  testWidgets('the kasra under the hamza of a ya or waw is drawn apart', (
    t,
  ) async {
    for (final word in ['ٱللُّؤۡلُوِٕ', 'وَرَآيِٕ', 'ٱمۡرِيٕٖ']) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: InkText(
              word,
              style: const TextStyle(fontFamily: 'Hafs', fontSize: 40),
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(HafsFontMarks),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
        reason: word,
      );
    }
  });
}
