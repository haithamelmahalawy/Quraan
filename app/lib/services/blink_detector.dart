import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Detects a deliberate double blink with the front camera, and estimates
/// how far down the screen the reader is looking.
///
/// Frames are analysed on the device by ML Kit face detection; nothing is
/// recorded, stored or sent anywhere. ML Kit gives no eye direction, so the
/// gaze is estimated from two signals that both fall when looking lower:
/// the head's pitch and the eyelids' openness. It is a single number, made
/// meaningful by a two-point calibration (first line / last line).
class BlinkDetector {
  final _doubleBlinks = StreamController<double?>.broadcast();

  /// Fires for every double blink, with the gaze just before it (null when
  /// no face was seen then).
  Stream<double?> get doubleBlinks => _doubleBlinks.stream;

  /// The current (smoothed) gaze value; null without a face.
  final gaze = ValueNotifier<double?>(null);

  CameraController? _camera;
  FaceDetector? _faces;
  bool _busy = false;
  bool _running = false;

  // Blink state machine.
  bool _closed = false;
  DateTime? _closedAt;
  DateTime? _lastBlink;
  DateTime? _firstBlinkAt;

  // Recent gaze values, to read the gaze from before the blink.
  final _history = <(DateTime, double)>[];

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
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
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
    gaze.value = null;
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
    gaze.dispose();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || !_running) return;
    final input = _toInputImage(image);
    if (input == null) return;
    _busy = true;
    try {
      final faces = await _faces?.processImage(input) ?? const [];
      if (faces.isNotEmpty) {
        _onFace(faces.first);
      } else {
        gaze.value = null;
      }
    } on PlatformException catch (e) {
      debugPrint('blink detector: $e');
    } finally {
      _busy = false;
    }
  }

  void _onFace(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) return;
    final now = DateTime.now();

    // Gaze: head pitch (degrees, up positive) plus eyelid openness, both
    // lower when looking further down the page. Only from open eyes.
    final pitch = face.headEulerAngleX;
    if (pitch != null && left > 0.5 && right > 0.5) {
      final raw = pitch + 20 * (left + right) / 2;
      final g = gaze.value == null ? raw : gaze.value! * 0.7 + raw * 0.3;
      gaze.value = g;
      _history
        ..add((now, g))
        ..removeWhere((h) => now.difference(h.$1).inMilliseconds > 3000);
    }

    // A blink is a short close (60–600 ms) followed by an open; two blinks
    // within 900 ms make a double blink.
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
        _doubleBlinks.add(_gazeBefore(_firstBlinkAt!));
      } else {
        _lastBlink = now;
        _firstBlinkAt = _closedAt;
      }
    }
  }

  /// Average gaze over the moments before [t] (before the eyes started to
  /// close for the first blink).
  double? _gazeBefore(DateTime t) {
    final values = [
      for (final (at, g) in _history)
        if (at.isBefore(t.subtract(const Duration(milliseconds: 80))) &&
            t.difference(at).inMilliseconds < 900)
          g,
    ];
    if (values.isEmpty) return gaze.value;
    return values.reduce((a, b) => a + b) / values.length;
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
        camera.description.sensorOrientation);
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
