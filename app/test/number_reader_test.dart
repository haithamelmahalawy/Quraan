import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/services/number_reader.dart';
import 'package:qiraat_mushaf/services/page_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [number] drawn in its ornament (the Hafs font's), in a ring, small or
  /// zoomed in, then made black and white as the camera's circle is.
  Future<ScanImage> drawn(String number, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, 320, 320),
        Paint()..color = Colors.white,
      )
      ..drawCircle(
        const Offset(160, 160),
        120,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    final text = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: size,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    text.paint(canvas, Offset(160 - text.width / 2, 160 - text.height / 2));
    final image = await recorder.endRecording().toImage(320, 320);
    final rgba = (await image.toByteData())!.buffer.asUint8List();
    final pixels = Uint8List(320 * 320);
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = rgba[i * 4];
    }
    binarize(pixels, 320, 320, r: 40, c: 14);
    return (width: 320, height: 320, pixels: pixels);
  }

  testWidgets('every zero found, whatever the size, the ornament left out', (
    t,
  ) async {
    await t.runAsync(() async {
      await (FontLoader(
        'Hafs',
      )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
      for (final number in [
        '٢٠٦',
        '٢٠٥',
        '١٠٠',
        '٦٠٤',
        '١',
        '٥٥',
        '٣٨٨',
        '٤٧',
        '٣٠',
      ]) {
        for (final size in [40.0, 90.0]) {
          final pieces = numberPieces(await drawn(number, size));
          expect(
            pieces?.map((p) => p == null ? '0' : 'D').join(),
            number.runes.map((r) => r == 0x0660 ? '0' : 'D').join(),
            reason: '$number at $size',
          );
        }
      }
    });
  });

  testWidgets('the digits read one by one where read together they were not', (
    t,
  ) async {
    await t.runAsync(() async {
      await (FontLoader(
        'Hafs',
      )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
      final image = await drawn('٢٠٦', 60);
      final answers = ['٢', '٢', '٦'];
      expect(
        await readPageNumber(
          image,
          all: (_) async => answers.removeAt(0),
          one: (_) async => answers.removeAt(0),
        ),
        '206',
      );
      // A digit unread: a «?» in its place, no page rather than a wrong one.
      expect(
        await readPageNumber(
          image,
          all: (_) async => '٢',
          one: (_) async => '',
        ),
        '?0?',
      );
    });
  });
}
