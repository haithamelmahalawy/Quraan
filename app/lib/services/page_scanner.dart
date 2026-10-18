import 'dart:io';

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
/// Each frame is turned into a small greyscale image (cropped to the guide
/// frame, at most 1100 px wide) on a background isolate, then read on the
/// device by Tesseract (Arabic, tessdata_fast). The recognition is imperfect
/// for Uthmani script, so the page is found by [PageMatcher] from the words
/// it does read.
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
        'psm': '4', // a single column of text of variable sizes
        'preserve_interword_spaces': '1',
      },
    );
    return matcher.match(text);
  }
}

/// Greyscale, upright, cropped to the guide frame, at most 1100 px wide.
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
  if (gray.width > 1100) gray = img.copyResize(gray, width: 1100);
  return img.encodePng(gray);
}
