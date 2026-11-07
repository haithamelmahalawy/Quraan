import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/page_matcher.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/services/page_scanner.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PageMatcher matcher;
  late String pageText;
  final frame = Frame.raw(
    width: 120,
    height: 180,
    bytesPerRow: 120,
    rotation: 0,
    bgra: false,
    bytes: Uint8List(120 * 180)..fillRange(0, 120 * 180, 240),
  );

  setUpAll(() {
    final quran = QuranRepository.parse(
      File('assets/data/quran.json').readAsStringSync(),
    );
    matcher = PageMatcher(quran);
    pageText = quran.page(175).take(3).map((a) => a.words.join(' ')).join('\n');
    expect(matcher.match(pageText)?.page, 175);
  });

  test(
    'a clear band identifies the page without reading the full image',
    () async {
      final reads = <ScanImage>[];
      final scanner = PageScanner(
        matcher,
        read: (image) async {
          reads.add(image);
          return pageText;
        },
      );
      expect((await scanner.scan(frame))?.page, 175);
      expect(reads, hasLength(1));
      expect(reads.single.height, prepareFrame(frame, quick: true).height);
      expect(reads.single.pixels.every((v) => v == 255), isTrue);
    },
  );

  test(
    'the page number: a small patch near the bottom, digits alone',
    () async {
      final reads = <ScanImage>[];
      final scanner = PageScanner(
        matcher,
        read: (image) async {
          reads.add(image);
          return '١٨٨\n';
        },
      );
      final found = await scanner.scan(frame, mode: ScanMode.number);
      expect(found?.page, 188);
      // Read once more before it is taken: the score says so.
      expect(found?.score, 0);
      expect(reads, hasLength(1));
      expect(reads.single.width, 200);
      expect(reads.single.height, 200);
      final page = prepareFrame(frame).pixels.length;
      expect(reads.single.pixels.length, lessThan(page));
      // No number, or one outside the mushaf: nothing.
      final none = PageScanner(matcher, read: (_) async => '٩٩٩');
      expect(await none.scan(frame, mode: ScanMode.number), isNull);
    },
  );

  test('a line: one strip across the middle, read once', () async {
    final reads = <ScanImage>[];
    final line = pageText.split('\n').first;
    final scanner = PageScanner(
      matcher,
      read: (image) async {
        reads.add(image);
        return line;
      },
    );
    expect((await scanner.scan(frame, mode: ScanMode.line))?.page, 175);
    expect(reads, hasLength(1));
    expect(reads.single.width, 1100);
    expect(reads.single.height, (1100 * lineBox.aspect).round());
  });

  test(
    'the boxes lie where the screen draws them, upright whatever the turn',
    () {
      final turned = Frame.raw(
        width: 180,
        height: 120,
        bytesPerRow: 180,
        rotation: 90,
        bgra: false,
        bytes: Uint8List(180 * 120),
      );
      final box = prepareBox(turned, numberBox, 50);
      expect(box.width, 50);
      expect(box.height, 50);
      // A dark mark where the circle is drawn, at the middle of its patch.
      final bytes = Uint8List(120 * 180)..fillRange(0, 120 * 180, 240);
      for (var y = 146; y < 157; y++) {
        for (var x = 55; x < 66; x++) {
          bytes[y * 120 + x] = 10;
        }
      }
      final marked = prepareBox(
        Frame.raw(
          width: 120,
          height: 180,
          bytesPerRow: 120,
          rotation: 0,
          bgra: false,
          bytes: bytes,
        ),
        numberBox,
        50,
      );
      expect(marked.pixels[25 * 50 + 25], lessThan(60));
      expect(marked.pixels[2 * 50 + 2], greaterThan(200));
    },
  );

  test(
    'an unclear band falls back to the full guide on the same frame',
    () async {
      final reads = <ScanImage>[];
      final scanner = PageScanner(
        matcher,
        read: (image) async {
          reads.add(image);
          return reads.length == 1 ? 'نص غير واضح' : pageText;
        },
      );
      expect((await scanner.scan(frame))?.page, 175);
      expect(reads, hasLength(2));
      expect(reads.first.width, reads.last.width);
      expect(
        reads.first.pixels.length,
        lessThan(reads.last.pixels.length * .4),
      );
      expect(reads.last.height, prepareFrame(frame).height);
    },
  );

  test('noise in both passes does not open an unrelated page', () async {
    final noise = File('test/fixtures/ocr_noise.txt').readAsStringSync();
    var reads = 0;
    final scanner = PageScanner(
      matcher,
      read: (_) async {
        reads++;
        return noise;
      },
    );
    expect(await scanner.scan(frame), isNull);
    expect(reads, 2);
  });

  test('a reopened camera cannot queue frames behind an active read', () async {
    final started = Completer<void>();
    final text = Completer<String>();
    var reads = 0;
    final scanner = PageScanner(
      matcher,
      read: (_) {
        reads++;
        started.complete();
        return text.future;
      },
    );
    final first = scanner.scan(frame);
    await started.future;
    var idle = false;
    unawaited(scanner.idle.then((_) => idle = true));
    expect(await scanner.scan(frame), isNull);
    expect(reads, 1);
    expect(idle, isFalse);
    text.complete(pageText);
    expect((await first)?.page, 175);
    await scanner.idle;
    expect(idle, isTrue);
  });

  test(
    'OCR failures release the scanner so the next frame can succeed',
    () async {
      var reads = 0;
      final scanner = PageScanner(
        matcher,
        read: (_) async {
          if (++reads == 1) throw PlatformException(code: 'ocr_error');
          return pageText;
        },
      );
      await expectLater(scanner.scan(frame), throwsA(isA<PlatformException>()));
      await scanner.idle;
      expect((await scanner.scan(frame))?.page, 175);
    },
  );

  test(
    'the quick band keeps text width while processing under 40% of the pixels',
    () {
      for (final rotation in [0, 90, 180, 270]) {
        final oriented = Frame.raw(
          width: frame.width,
          height: frame.height,
          bytesPerRow: frame.bytesPerRow,
          rotation: rotation,
          bgra: false,
          bytes: frame.bytes,
        );
        final full = prepareFrame(oriented);
        final quick = prepareFrame(oriented, quick: true);
        expect(quick.width, full.width);
        expect(quick.pixels.length, lessThan(full.pixels.length * .4));
      }
    },
  );

  test('rotated padded YUV and BGRA frames produce the same upright luminance', () {
    const w = 8, h = 12, yStride = 12, bgraStride = 40;
    final yuv = Uint8List(yStride * h)..fillRange(0, yStride * h, 255);
    final bgra = Uint8List(bgraStride * h)..fillRange(0, bgraStride * h, 255);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final value = 20 + x * 10 + y * 12;
        yuv[y * yStride + x] = value;
        for (var c = 0; c < 3; c++) {
          bgra[y * bgraStride + x * 4 + c] = value;
        }
      }
    }
    for (final rotation in [0, 90, 180, 270]) {
      final y = prepareFrame(
        Frame.raw(
          width: w,
          height: h,
          bytesPerRow: yStride,
          rotation: rotation,
          bgra: false,
          bytes: yuv,
        ),
        quick: true,
      );
      final b = prepareFrame(
        Frame.raw(
          width: w,
          height: h,
          bytesPerRow: bgraStride,
          rotation: rotation,
          bgra: true,
          bytes: bgra,
        ),
        quick: true,
      );
      expect(y.width, b.width);
      expect(y.height, b.height);
      expect(y.pixels, orderedEquals(b.pixels));
      // Rotation preserves direction, without sampling the bright row padding.
      expect(y.pixels.first < y.pixels.last, rotation == 0 || rotation == 270);
      expect(y.pixels.reduce((a, b) => a > b ? a : b), lessThan(230));
    }
  });

  test('adaptive threshold keeps thin ink under uneven lighting', () {
    const w = 80, h = 100;
    final pixels = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        pixels[y * w + x] = 100 + x;
      }
      pixels[y * w + 39] = 0;
      pixels[y * w + 40] = 0;
    }
    binarize(pixels, w, h);
    expect(pixels[50 * w + 39], 0);
    expect(pixels[50 * w + 5], 255);
    expect(pixels[50 * w + 75], 255);
  });

  test(
    'Android orientation accounts for both sensor mounting and device rotation',
    () {
      expect(scanFrameRotation(90, DeviceOrientation.portraitUp), 90);
      expect(scanFrameRotation(90, DeviceOrientation.landscapeLeft), 0);
      expect(scanFrameRotation(90, DeviceOrientation.landscapeRight), 180);
      expect(scanFrameRotation(90, DeviceOrientation.portraitDown), 270);
      expect(scanFrameRotation(270, DeviceOrientation.landscapeLeft), 180);
      expect(scanFrameRotation(270, DeviceOrientation.landscapeRight), 0);
    },
  );
}
