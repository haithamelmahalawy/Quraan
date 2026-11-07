import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/page_matcher.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/services/number_reader.dart';
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

  /// A page number drawn as the camera sees it, in the circle: its digits
  /// (bars [digits] wide) and zeros (dots) from left to right, inside the
  /// ring of its ornament, dark on a light page.
  Frame numbered(List<int?> digits) {
    const w = 400, h = 600;
    final bytes = Uint8List(w * h)..fillRange(0, w * h, 230);
    void ink(int x0, int y0, int x1, int y1) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          bytes[y * w + x] = 30;
        }
      }
    }

    // The circle's middle: (200, 504); the ring around the number.
    for (var a = 0.0; a < 2 * pi; a += .01) {
      final x = (200 + 46 * cos(a)).round(), y = (504 + 46 * sin(a)).round();
      ink(x - 1, y - 1, x + 2, y + 2);
    }
    var x = 200 - 12 * digits.length;
    for (final d in digits) {
      if (d == null) {
        ink(x + 4, 500, x + 12, 508); // ٠
      } else {
        ink(x + 2, 488, x + 2 + d, 520);
      }
      x += 24;
    }
    return Frame.raw(
      width: w,
      height: h,
      bytesPerRow: w,
      rotation: 0,
      bgra: false,
      bytes: bytes,
    );
  }

  test('the number in its ornament: its digits apart, its zero a dot', () {
    final image = prepareBox(numbered([6, null, 10]), numberBox, 320);
    binarize(image.pixels, image.width, image.height, r: 40, c: 14);
    final pieces = numberPieces(image)!;
    expect(pieces, hasLength(3));
    expect(pieces[0], isNotNull);
    expect(pieces[1], isNull);
    expect(pieces[2], isNotNull);
    // The digits alone for the reader: no ring, no zero.
    final alone = glyphsAlone(image, [pieces[0]!, pieces[2]!]);
    expect(blobsOf(alone), hasLength(2));
  });

  test('٢٠٦ is page 206, not 2: the zero told by its shape', () async {
    final reads = <ScanImage>[];
    final scanner = PageScanner(
      matcher,
      read: (image) async {
        reads.add(image);
        return '٢٦';
      },
    );
    final found = await scanner.scan(
      numbered([6, null, 10]),
      mode: ScanMode.number,
    );
    expect(found?.page, 206);
    // Read once more before it is taken: the score says so.
    expect(found?.score, 0);
    // One read, of the two digits alone.
    expect(reads, hasLength(1));
    expect(blobsOf(reads.single), hasLength(2));
  });

  test('a digit lost when read together: read one by one', () async {
    final answers = ['٥', '٢', '٥'];
    final scanner = PageScanner(
      matcher,
      read: (_) async => answers.removeAt(0),
    );
    final found = await scanner.scan(
      numbered([6, null, 10]),
      mode: ScanMode.number,
    );
    expect(found?.page, 205);
    expect(answers, isEmpty);
  });

  test('no number, or none of the mushaf: nothing', () async {
    final scanner = PageScanner(matcher, read: (_) async => '٩٩٩');
    expect(await scanner.scan(frame, mode: ScanMode.number), isNull);
    expect(
      await scanner.scan(numbered([6, 6, 6]), mode: ScanMode.number),
      isNull,
    );
    // Page 2: the digit alone.
    final two = PageScanner(matcher, read: (_) async => '٢');
    expect((await two.scan(numbered([8]), mode: ScanMode.number))?.page, 2);
  });
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
