import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const ocr = MethodChannel('flutter_tesseract_ocr');

  test('raw camera pixels cross the channel without image files; model setup is cached and retryable', () async {
    final directory = await Directory.systemTemp.createTemp('quraan-ocr-test-');
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ocr, null);
      expect(
        directory.absolute.path,
        startsWith(Directory.systemTemp.absolute.path),
      );
      await directory.delete(recursive: true);
    });
    var pathReads = 0;
    final calls = <MethodCall>[];
    var failOcr = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async {
          expect(call.method, 'getApplicationDocumentsDirectory');
          return ++pathReads == 1 ? null : directory.path;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ocr, (call) async {
          calls.add(call);
          if (failOcr) throw PlatformException(code: 'ocr_error');
          return call.method == 'prepare' ? null : 'نص الصفحة';
        });
    // A setup failure must not poison the cached future for later scans.
    await expectLater(
      FlutterTesseractOcr.prepare(language: 'ara'),
      throwsA(anything),
    );
    final pixels = Uint8List.fromList([0, 255, 12, 200]);
    await Future.wait([
      FlutterTesseractOcr.prepare(language: 'ara'),
      FlutterTesseractOcr.extractPixels(
        pixels,
        width: 2,
        height: 2,
        language: 'ara',
        args: {'psm': '6'},
      ),
    ]);
    expect(pathReads, 2); // failed setup once, successful shared setup once
    expect(
      calls.map((c) => c.method),
      containsAll(['prepare', 'extractPixels']),
    );
    final sent =
        calls.singleWhere((c) => c.method == 'extractPixels').arguments as Map;
    expect(sent['pixels'], orderedEquals(pixels));
    expect(sent['width'], 2);
    expect(sent['height'], 2);
    expect(sent['language'], 'ara');
    expect(sent['imagePath'], isNull);
    expect(sent['args'], {'psm': '6'});
    expect(
      File('${directory.path}/tessdata/ara.traineddata').existsSync(),
      isTrue,
    );

    // Subsequent frames use the installed model without another path/model scan.
    expect(
      await FlutterTesseractOcr.extractPixels(
        pixels,
        width: 2,
        height: 2,
        language: 'ara',
      ),
      'نص الصفحة',
    );
    expect(pathReads, 2);
    expect(
      await directory.list().where((f) => f.path.endsWith('.png')).isEmpty,
      isTrue,
    );
    failOcr = true;
    await expectLater(
      FlutterTesseractOcr.extractPixels(pixels, width: 2, height: 2),
      throwsA(isA<PlatformException>()),
    );
    failOcr = false;
    expect(
      await FlutterTesseractOcr.extractPixels(pixels, width: 2, height: 2),
      'نص الصفحة',
    );
    await expectLater(
      FlutterTesseractOcr.extractPixels(pixels, width: 3, height: 2),
      throwsArgumentError,
    );
    expect(pathReads, 2);
  });
}
