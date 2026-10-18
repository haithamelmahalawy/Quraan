import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../data/page_matcher.dart';

/// A camera frame copied out of the image stream: luminance (YUV, Android)
/// or BGRA (iOS) bytes.
class Frame {
  Frame.copy(CameraImage image, this.rotation)
      : width = image.width,
        height = image.height,
        bgra = image.format.group == ImageFormatGroup.bgra8888,
        bytesPerRow = image.planes.first.bytesPerRow,
        bytes = Uint8List.fromList(image.planes.first.bytes);

  final int width, height, bytesPerRow, rotation;
  final bool bgra;
  final Uint8List bytes;
}

/// Reads frames of a printed mushaf page and finds the page they show.
///
/// Each frame is turned into a black and white image (cropped to the guide
/// frame, 1100 px wide) on a background isolate, then read on the device by
/// Tesseract (Arabic, tessdata_fast) as one block of text. The recognition
/// is imperfect for Uthmani script, so the page is found by [PageMatcher]
/// from the words it does read.
class PageScanner {
  PageScanner(this.matcher);

  final PageMatcher matcher;
  String? _path;

  Future<({int page, double score})?> scan(Frame frame) async {
    _path ??= '${(await getTemporaryDirectory()).path}/scan_frame.png';
    final png = await compute(_toPng, frame);
    await File(_path!).writeAsBytes(png, flush: true);
    final text = await FlutterTesseractOcr.extractText(
      _path!,
      language: 'ara',
      args: {
        // One uniform block of text: the column mode (4) loses most lines
        // of a photographed mushaf page to its border and ornaments.
        'psm': '6',
        'preserve_interword_spaces': '1',
      },
    );
    return matcher.match(text);
  }
}

/// Black and white, upright, cropped to the guide frame, 1100 px wide.
Uint8List _toPng(Frame f) {
  var gray = img.Image(width: f.width, height: f.height, numChannels: 1);
  for (var y = 0; y < f.height; y++) {
    final row = y * f.bytesPerRow;
    for (var x = 0; x < f.width; x++) {
      final int v;
      if (f.bgra) {
        final i = row + x * 4;
        v = (f.bytes[i] * 29 + f.bytes[i + 1] * 150 + f.bytes[i + 2] * 77) >> 8;
      } else {
        v = f.bytes[row + x];
      }
      gray.setPixelR(x, y, v);
    }
  }
  if (f.rotation != 0) gray = img.copyRotate(gray, angle: f.rotation);
  // The guide frame covers the middle of the preview.
  final cw = (gray.width * 0.9).round(), ch = (gray.height * 0.72).round();
  gray = img.copyCrop(gray,
      x: (gray.width - cw) ~/ 2, y: (gray.height - ch) ~/ 2, width: cw, height: ch);
  // Letters must be about the size Tesseract and the threshold expect.
  gray = img.copyResize(gray, width: 1100, interpolation: img.Interpolation.linear);
  return img.encodePng(binarize(gray));
}

/// Adaptive threshold: a pixel is ink when it is darker than the mean of
/// the square around it (radius [r]) by more than [c]. Unlike one global
/// threshold, this copes with shadows and uneven light across the page.
@visibleForTesting
img.Image binarize(img.Image gray, {int r = 20, int c = 10}) {
  final w = gray.width, h = gray.height;
  // Integral image: sums of all pixels above and to the left.
  final sums = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0.0;
    for (var x = 0; x < w; x++) {
      row += gray.getPixel(x, y).r;
      sums[(y + 1) * (w + 1) + x + 1] = sums[y * (w + 1) + x + 1] + row;
    }
  }
  final out = img.Image(width: w, height: h, numChannels: 1);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
      final sum = sums[y1 * (w + 1) + x1] -
          sums[y0 * (w + 1) + x1] -
          sums[y1 * (w + 1) + x0] +
          sums[y0 * (w + 1) + x0];
      final mean = sum / ((x1 - x0) * (y1 - y0));
      out.setPixelR(x, y, gray.getPixel(x, y).r < mean - c ? 0 : 255);
    }
  }
  return out;
}
