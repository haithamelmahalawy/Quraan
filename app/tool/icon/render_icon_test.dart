// Draws the app icon, «خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖ» (Maryam 12) in the Hafs
// Uthmanic font, to tool/icon/*.png:
//
//   flutter test tool/icon/render_icon_test.dart
//   dart run flutter_launcher_icons
//
// icon.png is the whole icon (iOS, older Android); foreground.png is the
// calligraphy alone for Android's adaptive icons, whose
// background is the same green (see flutter_launcher_icons in pubspec.yaml).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const green = Color(0xFF1F5A40);
const deepGreen = Color(0xFF123827);
const gold = Color(0xFFD9B45A);
const cream = Color(0xFFF6E7B8);

/// The words of 19:12 as in the KFGQPC Hafs text.
const line1 = 'خُذِ ٱلۡكِتَٰبَ';
const line2 = 'بِقُوَّةٖ';

void main() {
  testWidgets('render the app icon', (tester) async {
    await (FontLoader('Hafs')
          ..addFont(rootBundle.load('assets/fonts/hafs.18.ttf')))
        .load();
    tester.view
      ..physicalSize = const Size(1024, 1024)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (name, full) in [('icon', true), ('foreground', false)]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(dimension: 1024, child: _Icon(full: full)),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('tool/icon/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List(), flush: true);
      });
    }
  });
}

class _Icon extends StatelessWidget {
  const _Icon({required this.full});

  /// With its background and frame; otherwise the calligraphy alone, within
  /// the adaptive icon (flutter_launcher_icons insets it into the safe zone).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(line1, full ? 205 : 250),
        _line(line2, full ? 235 : 285),
      ],
    );
    if (!full) {
      return Center(child: text);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [green, deepGreen],
          radius: 0.9,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: gold, width: 10),
            borderRadius: BorderRadius.circular(150),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: gold.withAlpha(150), width: 4),
                borderRadius: BorderRadius.circular(132),
              ),
              child: Center(child: text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String text, double size) => Text(
        text,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: size,
          height: 1.25,
          fontWeight: FontWeight.bold,
          color: cream,
          shadows: [
            Shadow(color: Colors.black.withAlpha(120), offset: const Offset(0, 8), blurRadius: 18),
          ],
        ),
      );
}
