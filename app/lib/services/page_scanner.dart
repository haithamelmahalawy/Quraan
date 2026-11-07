import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../data/page_matcher.dart';
import '../state/reader_settings.dart' show ScanMode;
import 'number_reader.dart';

typedef ScanImage = ({int width, int height, Uint8List pixels});
typedef PageMatch = ({int page, double score});

/// A part of the upright frame read alone: its centre and width as
/// fractions of the frame's, and its height in proportion to its width.
typedef ScanBox = ({double x, double y, double width, double aspect});

/// Where the page number is aimed: a small circle near the bottom.
const ScanBox numberBox = (x: .5, y: .84, width: .28, aspect: 1);

/// Where a line is aimed: a strip across the middle.
const ScanBox lineBox = (x: .5, y: .5, width: .92, aspect: .12);

/// CameraX delivers sensor-oriented YUV even when the phone is turned.
int scanFrameRotation(int sensor, DeviceOrientation orientation) {
  final device = switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return (sensor - device + 360) % 360;
}

/// A camera frame copied out of the image stream: luminance (YUV, Android)
/// or BGRA (iOS) bytes.
class Frame {
  Frame.copy(CameraImage image, this.rotation)
    : width = image.width,
      height = image.height,
      bgra = image.format.group == ImageFormatGroup.bgra8888,
      bytesPerRow = image.planes.first.bytesPerRow,
      bytes = Uint8List.fromList(image.planes.first.bytes);

  @visibleForTesting
  Frame.raw({
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotation,
    required this.bgra,
    required this.bytes,
  });

  final int width, height, bytesPerRow, rotation;
  final bool bgra;
  final Uint8List bytes;
}

/// Reads frames of a printed mushaf page and finds the page they show.
///
/// Read a short central band first; a few distinctive lines are enough to
/// identify a page. Fall back to the full guide when the band is inconclusive.
/// Android sends luminance directly to the reusable OCR engine, without PNG
/// encoding, disk writes or image decoding. Preprocessing runs off the UI thread.
class PageScanner {
  PageScanner(this.matcher, {this.read});

  final PageMatcher matcher;
  final Future<String> Function(ScanImage)? read;
  String? _path;
  Completer<void>? _busy;

  /// The page number last read, «?» for a digit not read; null when none
  /// was seen: shown, so that what is read can be seen.
  String? lastNumber;

  Future<void> get idle => _busy?.future ?? Future<void>.value();

  /// Start loading Arabic while the camera opens, rather than on its first frame.
  Future<void> warmUp() async {
    if (read == null && Platform.isAndroid) {
      await FlutterTesseractOcr.prepare(language: 'ara');
    }
  }

  /// The page [frame] shows, read as [mode] says: the page number alone
  /// (score 0: to be read the same twice), one line, or the page.
  Future<PageMatch?> scan(Frame frame, {ScanMode mode = ScanMode.page}) async {
    // Never queue stale frames when a camera session is reopened during a read.
    if (_busy != null) return null;
    final busy = _busy = Completer<void>();
    try {
      if (mode == ScanMode.number) return await _byNumber(frame);
      if (mode == ScanMode.line) {
        final image = await compute(_prepareBox, (frame, lineBox, 1100));
        return matcher.match(await (read ?? _recognize)(image), lines: 1);
      }
      for (final quick in [true, false]) {
        final image = await compute(_prepare, (frame, quick));
        final text = await (read ?? _recognize)(image);
        final found = matcher.match(text);
        if (found != null) return found;
      }
      return null;
    } finally {
      _busy = null;
      busy.complete();
    }
  }

  /// The page by its number alone, read piece by piece: the ornament around
  /// it left out, each zero (a dot, which the reader loses) told by its
  /// shape, the other digits read without it. Taken when read the same
  /// twice in a row (score 0).
  Future<PageMatch?> _byNumber(Frame frame) async {
    final image = await compute(_prepareNumber, frame);
    final number = await readPageNumber(
      image,
      all: read ?? (i) => _recognize(i, digits: true),
      one: read ?? (i) => _recognize(i, digits: true, single: true),
    );
    lastNumber = number;
    final page = number == null || number.contains('?')
        ? null
        : matcher.pageNumber(number);
    return page == null ? null : (page: page, score: 0.0);
  }

  Future<String> _recognize(
    ScanImage image, {
    bool digits = false,
    bool single = false,
  }) async {
    // The engine keeps what it is told between reads: the list of letters
    // is given every time, empty (all) for text. The digits without zero:
    // the zeros are told apart before.
    final args = {
      'psm': single ? '10' : (digits ? '7' : '6'),
      'preserve_interword_spaces': '1',
      'tessedit_do_invert': '0',
      'tessedit_char_whitelist': digits ? '١٢٣٤٥٦٧٨٩123456789' : '',
    };
    if (Platform.isAndroid) {
      return FlutterTesseractOcr.extractPixels(
        image.pixels,
        width: image.width,
        height: image.height,
        language: 'ara',
        args: args,
      );
    }
    // The iOS plugin accepts file images. Keep the same partial-page strategy.
    _path ??=
        '${(await getTemporaryDirectory()).path}/scan_${identityHashCode(this)}.png';
    final png = await compute(_toPng, image);
    await File(_path!).writeAsBytes(png);
    return FlutterTesseractOcr.extractText(_path!, language: 'ara', args: args);
  }
}

ScanImage _prepareBox((Frame, ScanBox, int) input) {
  final (frame, box, width) = input;
  final image = prepareBox(frame, box, width);
  binarize(image.pixels, image.width, image.height, r: width < 400 ? 12 : 20);
  return image;
}

ScanImage _prepare((Frame, bool) input) {
  final image = prepareFrame(input.$1, quick: input.$2);
  final (:width, :height, :pixels) = image;
  binarize(pixels, width, height);
  return image;
}

Uint8List _toPng(ScanImage image) {
  final (:width, :height, :pixels) = image;
  return img.encodePng(
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      numChannels: 1,
    ),
    level: 1, // black and white compresses well even at the fastest level
  );
}

/// The frame's luminance, turned upright (clockwise by [Frame.rotation]),
/// cropped to the guide frame (the middle 90% × 72%) and scaled to 1100 px
/// wide, in one pass: each pixel is sampled from the camera's bytes.
@visibleForTesting
ScanImage prepareFrame(Frame f, {bool quick = false}) {
  final (rw, rh) = _upright(f);
  final cw = rw * 0.9, ch = rh * (quick ? 0.28 : 0.72);
  return _sample(f, (rw - cw) / 2, (rh - ch) / 2, cw, ch, 1100);
}

/// The part [box] of the upright frame, [width] pixels wide.
@visibleForTesting
ScanImage prepareBox(Frame f, ScanBox box, int width) {
  final (rw, rh) = _upright(f);
  final cw = rw * box.width;
  final ch = math.min(cw * box.aspect, rh.toDouble());
  final cx = (rw * box.x - cw / 2).clamp(0.0, rw - cw);
  final cy = (rh * box.y - ch / 2).clamp(0.0, rh - ch);
  return _sample(f, cx, cy, cw, ch, width);
}

(int, int) _upright(Frame f) {
  final turned = f.rotation == 90 || f.rotation == 270;
  return turned ? (f.height, f.width) : (f.width, f.height);
}

/// The upright frame's rectangle from ([cx], [cy]), [cw] × [ch], scaled to
/// [width] pixels wide.
ScanImage _sample(
  Frame f,
  double cx,
  double cy,
  double cw,
  double ch,
  int width,
) {
  final turned = f.rotation == 90 || f.rotation == 270;
  final scale = cw / width;
  final height = (ch / scale).round();

  // The luminance plane: the Y plane itself, or computed from BGRA.
  final Uint8List lum;
  final int stride;
  if (f.bgra) {
    lum = Uint8List(f.width * f.height);
    for (var y = 0; y < f.height; y++) {
      for (var x = 0; x < f.width; x++) {
        final i = y * f.bytesPerRow + x * 4;
        lum[y * f.width + x] =
            (f.bytes[i] * 29 + f.bytes[i + 1] * 150 + f.bytes[i + 2] * 77) >> 8;
      }
    }
    stride = f.width;
  } else {
    lum = f.bytes;
    stride = f.bytesPerRow;
  }

  // Each output column and row samples one camera column or row (which one
  // depends on the rotation), between two pixels: the first and the share
  // of the second.
  ({Int32List at, Float64List share}) axis(
    int count,
    double start,
    int size,
    bool reversed,
  ) {
    final at = Int32List(count), share = Float64List(count);
    for (var i = 0; i < count; i++) {
      var p = start + (i + 0.5) * scale - 0.5;
      if (reversed) p = size - 1 - p;
      p = p.clamp(0.0, size - 1.0);
      at[i] = math.min(p.floor(), size - 2);
      share[i] = p - at[i];
    }
    return (at: at, share: share);
  }

  final r = f.rotation;
  // Upright x runs along the camera's x (0, 180) or y (90, 270).
  final cols = axis(
    width,
    cx,
    turned ? f.height : f.width,
    r == 90 || r == 180,
  );
  final rows = axis(
    height,
    cy,
    turned ? f.width : f.height,
    r == 180 || r == 270,
  );

  final pixels = Uint8List(width * height);
  for (var oy = 0; oy < height; oy++) {
    for (var ox = 0; ox < width; ox++) {
      final int sx, sy;
      final double fx, fy;
      if (turned) {
        sx = rows.at[oy];
        fx = rows.share[oy];
        sy = cols.at[ox];
        fy = cols.share[ox];
      } else {
        sx = cols.at[ox];
        fx = cols.share[ox];
        sy = rows.at[oy];
        fy = rows.share[oy];
      }
      // Bilinear: the four camera pixels around the point.
      final i = sy * stride + sx;
      final a = lum[i],
          b = lum[i + 1],
          c = lum[i + stride],
          d = lum[i + stride + 1];
      final top = a + (b - a) * fx, bottom = c + (d - c) * fx;
      pixels[oy * width + ox] = (top + (bottom - top) * fy).round();
    }
  }
  return (width: width, height: height, pixels: pixels);
}

/// Adaptive threshold, in place: a pixel is ink (0) when it is darker than
/// the mean of the square around it (radius [r]) by more than [c], paper
/// (255) otherwise. Unlike one global threshold, this copes with shadows and
/// uneven light across the page.
@visibleForTesting
void binarize(Uint8List pixels, int w, int h, {int r = 20, int c = 10}) {
  // Integral image: sums of all pixels above and to the left.
  final stride = w + 1;
  final sums = Uint32List(stride * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0;
    for (var x = 0; x < w; x++) {
      row += pixels[y * w + x];
      sums[(y + 1) * stride + x + 1] = sums[y * stride + x + 1] + row;
    }
  }
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
      final sum =
          sums[y1 * stride + x1] -
          sums[y0 * stride + x1] -
          sums[y1 * stride + x0] +
          sums[y0 * stride + x0];
      final i = y * w + x;
      // pixel < mean - c, without dividing.
      pixels[i] = (pixels[i] + c) * (x1 - x0) * (y1 - y0) < sum ? 0 : 255;
    }
  }
}

/// The circle of the page number, 320 pixels square, in black and white:
/// the threshold's window wide, so that a digit drawn large (zoomed in)
/// stays filled, and its zero a dot, not a ring.
ScanImage _prepareNumber(Frame frame) {
  final image = prepareBox(frame, numberBox, 320);
  binarize(image.pixels, image.width, image.height, r: 40, c: 14);
  return image;
}
