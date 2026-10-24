import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  test('joined wasl signs are converted without confusing the naql alif', () {
    for (final (before, after) in [
      ('اُ۟عْبُدُواْ', 'ٱعۡبُدُواْ'),
      ('اِ۟سْجُدُواْ', 'ٱسۡجُدُواْ'),
      ('اُ۟سْكُنَ', 'ٱسۡكُنَ'),
      ('وَاُ۟عْبُدُواْ', 'وَٱعۡبُدُواْ'),
      ('ا۟جِيبُ', 'اجِيبُ'),
    ]) {
      expect(madinahScript(before), after);
    }
  });

  test('fathatan is placed on the final alif with its own colour', () {
    for (final before in ['فِرَٰشٗا', 'فِرَٰشاٗ', 'فِرَٰشًا', 'فِرَٰشاً']) {
      final parts = HafsFontMarks.positionedParts([(before, Colors.green)]);
      expect(parts.map((p) => p.$1).join(), 'فِرَٰشاً');
      expect(parts.every((p) => p.$2 == Colors.green), isTrue);
    }
  });

  test('font mark repairs keep hamzas and their vowels in one colour run', () {
    for (final cluster in ['أَ', 'إِ', 'أُ', 'ؤُ', 'ئِ', 'ءَ', 'أَ', 'إِ']) {
      final parts = HafsFontMarks.positionedParts([
        (cluster, Colors.blue),
        ('لۡقَ۪ىٰٓ', Colors.black),
      ]);
      expect(parts.first, (cluster, Colors.blue));
      expect(parts.map((p) => p.$1).join(), '$clusterلۡقَ۪ىٰٓ');
    }
  });

  testWidgets('the raised madd remains visible when a cluster has two marks', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: InkText(
            'ٱسۡتَوَىٰٓ',
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: 72,
              color: Colors.black,
              height: 1,
            ),
          ),
        ),
      ),
    );
    final paint = find.descendant(
      of: find.byType(HafsFontMarks),
      matching: find.byType(CustomPaint),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(0, 100);
    t
        .widget<CustomPaint>(paint)
        .foregroundPainter!
        .paint(canvas, t.getSize(paint));
    final picture = recorder.endRecording();
    final raster = await t.runAsync(() => picture.toImage(400, 300));
    final pixels = await t.runAsync(
      () => raster!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final ink = <Offset>[];
    for (var i = 3; i < pixels!.lengthInBytes; i += 4) {
      if (pixels.getUint8(i) > 0) {
        ink.add(
          Offset(((i ~/ 4) % 400).toDouble(), ((i ~/ 4) ~/ 400).toDouble()),
        );
      }
    }
    expect(ink.length, greaterThan(40));
    final height =
        ink.map((p) => p.dy).reduce((a, b) => a > b ? a : b) -
        ink.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    expect(
      height,
      lessThan(14),
      reason: 'Only the madd is painted; the carrier alif is clipped away.',
    );
    raster!.dispose();
    picture.dispose();
  });

  testWidgets(
    'shayan preserves the lin ya and following hamza',
    tags: 'golden',
    (t) async {
      t.view.physicalSize = const Size(650, 400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final word in ['شَيۡـٔٗا', madinahScript('شَئْاٗ')])
                    InkText(
                      word,
                      parts: [
                        for (final cluster in lettersOf(word))
                          (
                            cluster,
                            cluster.startsWith('ي') ? MushafColors.green : null,
                          ),
                      ],
                      style: const TextStyle(
                        fontFamily: 'Hafs',
                        fontSize: 96,
                        height: 1.2,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/shayan_typography.png'),
      );
    },
  );

  testWidgets('fathatan on alif and madd above dagger alif', tags: 'golden', (
    t,
  ) async {
    t.view.physicalSize = const Size(700, 1300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('typography'),
              child: Container(
                width: 650,
                height: 1250,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final text in [
                      'فِرَٰشٗا',
                      'فِرَٰشاٗ',
                      'ٱسۡتَوَىٰٓ',
                      'ٱسۡتَوَىٰٓ',
                      'ٱعْبُدُواْ',
                      'ٱسْجُدُواْ',
                      'ٱسْكُنَ',
                    ])
                      InkText(
                        text,
                        style: const TextStyle(
                          fontFamily: 'Hafs',
                          fontSize: 72,
                          height: 1.2,
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
      find.byKey(const ValueKey('typography')),
      matchesGoldenFile('goldens/mushaf_typography.png'),
    );
  });
}
