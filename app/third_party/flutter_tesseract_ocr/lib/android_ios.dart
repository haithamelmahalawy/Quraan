// part of flutter_tesseract_ocr;
// ignore_for_file: constant_identifier_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class FlutterTesseractOcr {
  static const String TESS_DATA_CONFIG = 'assets/tessdata_config.json';
  static const String TESS_DATA_PATH = 'assets/tessdata';
  static const MethodChannel _channel = MethodChannel('flutter_tesseract_ocr');
  static Future<String>? _data;

  /// Load the model on the native worker before the first camera frame arrives.
  static Future<void> prepare({required String language}) async {
    await _channel.invokeMethod<void>('prepare', {
      'tessData': await _loadTessData(),
      'language': language,
    });
  }

  /// Android: one byte of luminance per pixel, passed without an image file.
  static Future<String> extractPixels(Uint8List pixels,
      {required int width,
      required int height,
      String? language,
      Map? args}) async {
    if (width <= 0 || height <= 0 || pixels.length != width * height) {
      throw ArgumentError('Expected tightly packed luminance pixels');
    }
    return await _channel.invokeMethod<String>('extractPixels', {
          'pixels': pixels,
          'width': width,
          'height': height,
          'tessData': await _loadTessData(),
          'language': language,
          'args': args,
        }) ??
        '';
  }

  /// image to  text
  ///```
  /// String _ocrText = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractText(String imagePath,
      {String? language, Map? args}) async {
    assert(await File(imagePath).exists(), true);
    final String tessData = await _loadTessData();
    final String extractText =
        await _channel.invokeMethod('extractText', <String, dynamic>{
      'imagePath': imagePath,
      'tessData': tessData,
      'language': language,
      'args': args,
    });
    return extractText;
  }

  /// image to  html text(hocr)
  ///```
  /// String _ocrHocr = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractHocr(String imagePath,
      {String? language, Map? args}) async {
    assert(await File(imagePath).exists(), true);
    final String tessData = await _loadTessData();
    final String extractText =
        await _channel.invokeMethod('extractHocr', <String, dynamic>{
      'imagePath': imagePath,
      'tessData': tessData,
      'language': language,
      'args': args,
    });
    return extractText;
  }

  /// getTessdataPath
  ///```
  /// print(await FlutterTesseractOcr.getTessdataPath())
  ///```
  static Future<String> getTessdataPath() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');
    return tessdataDirectory;
  }

  static Future<String> _loadTessData() =>
      _data ??= _installTessData().catchError((Object error) {
        _data = null;
        throw error;
      });

  static Future<String> _installTessData() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');

    if (!await Directory(tessdataDirectory).exists()) {
      await Directory(tessdataDirectory).create();
    }
    await _copyTessDataToAppDocumentsDirectory(tessdataDirectory);
    return appDirectory.path;
  }

  static Future _copyTessDataToAppDocumentsDirectory(
      String tessdataDirectory) async {
    final String config = await rootBundle.loadString(TESS_DATA_CONFIG);
    Map<String, dynamic> files = jsonDecode(config);
    for (var file in files["files"]) {
      if (!await File('$tessdataDirectory/$file').exists()) {
        final ByteData data = await rootBundle.load('$TESS_DATA_PATH/$file');
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File('$tessdataDirectory/$file').writeAsBytes(bytes);
      }
    }
  }
}
