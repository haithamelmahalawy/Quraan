import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'page_scanner.dart' show ScanImage;

/// A piece of ink: its bounds and its pixels.
typedef Blob = ({int left, int top, int right, int bottom, List<int> pixels});

/// The pieces of ink of [image] (black, 0), each its pixels joined by their
/// sides and corners.
@visibleForTesting
List<Blob> blobsOf(ScanImage image) {
  final (:width, :height, :pixels) = image;
  final seen = Uint8List(width * height);
  final out = <Blob>[];
  final stack = <int>[];
  for (var start = 0; start < pixels.length; start++) {
    if (pixels[start] != 0 || seen[start] == 1) continue;
    final points = <int>[];
    var left = width, top = height, right = -1, bottom = -1;
    seen[start] = 1;
    stack.add(start);
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      points.add(p);
      final x = p % width, y = p ~/ width;
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final q = ny * width + nx;
          if (pixels[q] == 0 && seen[q] == 0) {
            seen[q] = 1;
            stack.add(q);
          }
        }
      }
    }
    out.add((
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      pixels: points,
    ));
  }
  return out;
}

int _height(Blob b) => b.bottom - b.top + 1;
int _width(Blob b) => b.right - b.left + 1;

/// The page number's pieces from left to right, as it is written: a digit's
/// ink, or null for a zero (٠, a small full dot on the digits' line, which
/// the reader loses); null when no number stands out. Not the ornament
/// around it (it holds the others), nor what the circle cuts at its edge,
/// nor specks.
@visibleForTesting
List<Blob?>? numberPieces(ScanImage image) {
  final w = image.width, h = image.height;
  final all = [
    for (final b in blobsOf(image))
      if (b.left > 0 &&
          b.top > 0 &&
          b.right < w - 1 &&
          b.bottom < h - 1 &&
          b.pixels.length >= 4)
        b,
  ];
  bool holds(Blob a, Blob b) =>
      !identical(a, b) &&
      a.left <= b.left &&
      a.right >= b.right &&
      a.top <= b.top &&
      a.bottom >= b.bottom;
  final pieces = [
    for (final b in all)
      if (!all.any((c) => holds(b, c))) b,
  ];
  if (pieces.isEmpty) return null;
  final tallest = pieces.map(_height).reduce(math.max);
  final glyphs = [
    for (final b in pieces)
      if (_height(b) >= tallest * .45) b,
  ];
  // The digits' line: where they stand.
  final top = glyphs.map((b) => b.top).reduce(math.min);
  final bottom = glyphs.map((b) => b.bottom).reduce(math.max);

  // Digits one above another are no page number.
  final middle = (top + bottom) / 2;
  if (!glyphs.every((b) => b.top <= middle && b.bottom >= middle)) {
    return null;
  }
  // A zero: small (a fifth to a half of a digit), round and full, on the
  // line, a digit's height at most from the digits or the zeros beside
  // them (١٠٠: the second beside the first).
  final dots = [
    for (final b in pieces)
      if (_height(b) < tallest * .45 &&
          _height(b) >= tallest * .2 &&
          _width(b) <= _height(b) * 2 &&
          _height(b) <= _width(b) * 2 &&
          b.pixels.length >= _width(b) * _height(b) * .45 &&
          (b.top + b.bottom) / 2 >= top &&
          (b.top + b.bottom) / 2 <= bottom)
        b,
  ];
  final zeros = <Blob>[];
  var left = glyphs.map((b) => b.left).reduce(math.min);
  var right = glyphs.map((b) => b.right).reduce(math.max);
  for (var added = true; added;) {
    added = false;
    for (final b in dots) {
      if (zeros.contains(b)) continue;
      if (b.right >= left - tallest && b.left <= right + tallest) {
        zeros.add(b);
        left = math.min(left, b.left);
        right = math.max(right, b.right);
        added = true;
      }
    }
  }
  final ordered = [...glyphs, ...zeros]
    ..sort((a, b) => (a.left + a.right).compareTo(b.left + b.right));
  if (ordered.length > 3) return null;
  return [
    for (final b in ordered)
      if (zeros.contains(b)) null else b,
  ];
}

/// [glyphs] alone, black on white, cropped to them with a margin: nothing
/// else of [image] for the reader to see.
@visibleForTesting
ScanImage glyphsAlone(ScanImage image, List<Blob> glyphs) {
  final left = glyphs.map((b) => b.left).reduce(math.min);
  final right = glyphs.map((b) => b.right).reduce(math.max);
  final top = glyphs.map((b) => b.top).reduce(math.min);
  final bottom = glyphs.map((b) => b.bottom).reduce(math.max);
  final pad = ((bottom - top + 1) * .3).ceil();
  final w = right - left + 1 + 2 * pad, h = bottom - top + 1 + 2 * pad;
  final pixels = Uint8List(w * h)..fillRange(0, w * h, 255);
  for (final b in glyphs) {
    for (final p in b.pixels) {
      final x = p % image.width - left + pad;
      final y = p ~/ image.width - top + pad;
      pixels[y * w + x] = 0;
    }
  }
  return (width: w, height: h, pixels: pixels);
}

/// The digits 1 to 9 of [text], Arabic-Indic or Western, as Western ones.
String nonZeroDigits(String text) => [
  for (final c in text.runes)
    if (c >= 0x31 && c <= 0x39)
      String.fromCharCode(c)
    else if (c >= 0x0661 && c <= 0x0669)
      String.fromCharCode(c - 0x0661 + 0x31),
].join();

/// The page number in [image] (black and white), its digits read by [all]
/// together, or one by one by [one] where some were lost; its zeros told by
/// their shape. Null when it cannot be read whole.
Future<String?> readPageNumber(
  ScanImage image, {
  required Future<String> Function(ScanImage) all,
  required Future<String> Function(ScanImage) one,
}) async {
  final pieces = numberPieces(image);
  if (pieces == null) return null;
  final glyphs = [for (final p in pieces) ?p];
  if (glyphs.isEmpty) return null;
  var digits = nonZeroDigits(await all(glyphsAlone(image, glyphs)));
  if (digits.length != glyphs.length) {
    digits = '';
    for (final g in glyphs) {
      final d = nonZeroDigits(await one(glyphsAlone(image, [g])));
      if (d.length != 1) return null;
      digits += d;
    }
  }
  var i = 0;
  return [for (final p in pieces) p == null ? '0' : digits[i++]].join();
}
