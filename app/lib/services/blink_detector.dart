import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// An eye gesture recognised by [BlinkDetector].
sealed class EyeGesture {
  const EyeGesture();
}

/// Two blinks in a row.
class DoubleBlink extends EyeGesture {
  const DoubleBlink();
}

/// What the camera sees of the reader's eyes.
enum EyeState { noFace, open, closed }

/// Recognises a double blink with the front camera.
///
/// Frames are analysed on the device by ML Kit face detection (eye-open
/// probabilities only); nothing is recorded, stored or sent anywhere.
class BlinkDetector {
  final _gestures = StreamController<EyeGesture>.broadcast();

  Stream<EyeGesture> get gestures => _gestures.stream;

  /// The eyes now, so the reader can see that the camera follows them.
  final eyes = ValueNotifier(EyeState.noFace);

  /// Counts every blink seen.
  final blinks = ValueNotifier(0);

  CameraController? _camera;
  FaceDetector? _faces;
  bool _busy = false;
  bool _running = false;

  // Both eyes closed (a blink in progress).
  DateTime? _closedAt;

  // Blinks of the current sequence, judged once it pauses.
  int _blinks = 0;
  Timer? _sequenceEnd;

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
      // Sharp enough for ML Kit to judge open and closed eyes.
      ResolutionPreset.medium,
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
    _sequenceEnd?.cancel();
    _blinks = 0;
    _closedAt = null;
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
    await _gestures.close();
    eyes.dispose();
    blinks.dispose();
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
        eyes.value = EyeState.noFace;
      }
    } on PlatformException catch (e) {
      debugPrint('blink detector: $e');
    } finally {
      _busy = false;
    }
  }

  static const _shut = 0.35, _open = 0.55;

  /// The longest pause between the two blinks of a double blink.
  static const _pause = Duration(milliseconds: 900);

  void _onFace(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) {
      eyes.value = EyeState.noFace;
      return;
    }
    if (kDebugMode) {
      debugPrint('eyes ${left.toStringAsFixed(2)} ${right.toStringAsFixed(2)}');
    }
    feed(left, right, at: DateTime.now());
  }

  /// One reading of the eyes (open probabilities).
  @visibleForTesting
  void feed(double left, double right, {required DateTime at}) {
    // Both eyes shut: a blink in progress.
    if (left < _shut && right < _shut) {
      eyes.value = EyeState.closed;
      _closedAt ??= at;
      return;
    }
    eyes.value = EyeState.open;
    // A blink ends when both eyes are open again.
    final closedAt = _closedAt;
    if (closedAt != null && left > _open && right > _open) {
      _closedAt = null;
      _onBlink(at.difference(closedAt));
    }
  }

  /// Collects blinks into a sequence and judges it after a pause of
  /// [_pause]: exactly two blinks make a double blink.
  void _onBlink(Duration shut) {
    if (shut.inMilliseconds < 50 || shut.inMilliseconds > 1200) return;
    blinks.value++;
    _blinks++;
    _sequenceEnd?.cancel();
    _sequenceEnd = Timer(_pause, () {
      if (_blinks == 2) _gestures.add(const DoubleBlink());
      _blinks = 0;
    });
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.description.sensorOrientation,
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
