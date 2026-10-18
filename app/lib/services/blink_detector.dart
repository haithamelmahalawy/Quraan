import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Detects a deliberate double blink with the front camera.
///
/// Frames are analysed on the device by ML Kit face detection (eye-open
/// probabilities); nothing is recorded, stored or sent anywhere.
class BlinkDetector {
  final _doubleBlinks = StreamController<void>.broadcast();

  /// Fires once for every double blink.
  Stream<void> get doubleBlinks => _doubleBlinks.stream;

  CameraController? _camera;
  FaceDetector? _faces;
  bool _busy = false;
  bool _running = false;

  // Blink state machine.
  bool _closed = false;
  DateTime? _closedAt;
  DateTime? _lastBlink;

  bool get isRunning => _running;

  /// Starts the front camera; throws [CameraException] when the camera is
  /// unavailable or permission is denied.
  Future<void> start() async {
    if (_running) return;
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => throw CameraException('no-front-camera', 'No front camera'),
    );
    final camera = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );
    await camera.initialize();
    _faces = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // eye-open probabilities
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.2,
      ),
    );
    _camera = camera;
    _running = true;
    await camera.startImageStream(_onFrame);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    final camera = _camera;
    _camera = null;
    try {
      await camera?.stopImageStream();
    } on CameraException {
      // Already stopped.
    }
    await camera?.dispose();
    await _faces?.close();
    _faces = null;
  }

  Future<void> dispose() async {
    await stop();
    await _doubleBlinks.close();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || !_running) return;
    final input = _toInputImage(image);
    if (input == null) return;
    _busy = true;
    try {
      final faces = await _faces?.processImage(input) ?? const [];
      if (faces.isNotEmpty) _onEyes(faces.first);
    } on PlatformException catch (e) {
      debugPrint('blink detector: $e');
    } finally {
      _busy = false;
    }
  }

  /// A blink is a short close (60–600 ms) followed by an open; two blinks
  /// within 900 ms make a double blink.
  void _onEyes(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) return;
    final now = DateTime.now();
    if (!_closed && left < 0.3 && right < 0.3) {
      _closed = true;
      _closedAt = now;
    } else if (_closed && left > 0.6 && right > 0.6) {
      _closed = false;
      final shut = now.difference(_closedAt!);
      if (shut.inMilliseconds < 60 || shut.inMilliseconds > 600) return;
      final last = _lastBlink;
      if (last != null && now.difference(last).inMilliseconds < 900) {
        _lastBlink = null;
        _doubleBlinks.add(null);
      } else {
        _lastBlink = now;
      }
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;
    final sensor = camera.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(
      // Portrait reading: the sensor orientation is the image rotation.
      Platform.isIOS ? sensor : sensor % 360,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
