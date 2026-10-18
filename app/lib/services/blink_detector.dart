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

/// One eye closed while the other stays open.
class Wink extends EyeGesture {
  const Wink({required this.left});

  /// The reader's left eye (as reported by the face detector).
  final bool left;
}

/// Three blinks in a row; [gaze] is where the reader looked before them.
class TripleBlink extends EyeGesture {
  const TripleBlink(this.gaze);
  final double? gaze;
}

/// One deliberate blink: the eyes held shut a little longer than a natural
/// blink (natural blinks, ~100 ms, are ignored).
class DeliberateBlink extends EyeGesture {
  const DeliberateBlink();
}

/// Recognises eye gestures with the front camera, and estimates how far
/// down the screen the reader is looking.
///
/// Frames are analysed on the device by ML Kit face detection; nothing is
/// recorded, stored or sent anywhere. ML Kit gives no eye direction, so the
/// gaze is estimated from two signals that both fall when looking lower:
/// the head's pitch and the eyelids' openness. It is a single number, made
/// meaningful by a two-point calibration (first line / last line).
class BlinkDetector {
  final _gestures = StreamController<EyeGesture>.broadcast();

  Stream<EyeGesture> get gestures => _gestures.stream;

  /// The current (smoothed) gaze value; null without a face.
  final gaze = ValueNotifier<double?>(null);

  CameraController? _camera;
  FaceDetector? _faces;
  bool _busy = false;
  bool _running = false;

  // Both eyes closed (a blink in progress).
  DateTime? _closedAt;

  // One eye closed (a wink in progress); cancelled if the other closes.
  bool? _winkLeft;
  DateTime? _winkAt;

  // Blinks of the current sequence, judged once it pauses.
  final _blinks = <Duration>[];
  DateTime? _sequenceStart;
  Timer? _sequenceEnd;

  // Recent gaze values, to read the gaze from before the blinks.
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
    _sequenceEnd?.cancel();
    _blinks.clear();
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

  static const _shut = 0.3, _open = 0.6;

  void _onFace(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) return;
    feed(left, right, pitch: face.headEulerAngleX, at: DateTime.now());
  }

  /// One reading of the eyes (open probabilities) and head pitch.
  @visibleForTesting
  void feed(double left, double right, {double? pitch, required DateTime at}) {
    final now = at;
    _trackGaze(pitch, left, right, now);

    final leftShut = left < _shut, rightShut = right < _shut;
    final leftOpen = left > _open, rightOpen = right > _open;

    // Both eyes shut: a blink (this also cancels a wink in progress).
    if (leftShut && rightShut) {
      _winkLeft = null;
      _closedAt ??= now;
      return;
    }
    // A blink ends when both eyes are open again.
    final closedAt = _closedAt;
    if (closedAt != null) {
      if (leftOpen && rightOpen) {
        _closedAt = null;
        _onBlink(now.difference(closedAt), closedAt);
      }
      return;
    }
    // One eye shut while the other is clearly open: a wink starts.
    if (_winkLeft == null) {
      if (leftShut && right > 0.7) {
        _winkLeft = true;
        _winkAt = now;
      } else if (rightShut && left > 0.7) {
        _winkLeft = false;
        _winkAt = now;
      }
      return;
    }
    // The wink ends when the winking eye opens; the other must stay open.
    final winkLeft = _winkLeft!;
    if ((winkLeft ? right : left) < _open) {
      _winkLeft = null; // the other eye moved: not a clean wink
      return;
    }
    if (winkLeft ? leftOpen : rightOpen) {
      final held = now.difference(_winkAt!).inMilliseconds;
      _winkLeft = null;
      if (held >= 120 && held <= 1200) _gestures.add(Wink(left: winkLeft));
    }
  }

  /// Collects blinks into a sequence and judges it after a short pause:
  /// three (or more) blinks, or one deliberate blink.
  void _onBlink(Duration shut, DateTime startedAt) {
    if (shut.inMilliseconds < 50 || shut.inMilliseconds > 1200) return;
    if (_blinks.isEmpty) _sequenceStart = startedAt;
    _blinks.add(shut);
    _sequenceEnd?.cancel();
    _sequenceEnd = Timer(const Duration(milliseconds: 650), () {
      final blinks = List.of(_blinks);
      final start = _sequenceStart!;
      _blinks.clear();
      if (blinks.length >= 3) {
        _gestures.add(TripleBlink(_gazeBefore(start)));
      } else if (blinks.length == 1 && blinks.single.inMilliseconds >= 250) {
        _gestures.add(const DeliberateBlink());
      }
    });
  }

  /// Gaze: head pitch (degrees, up positive) plus eyelid openness, both
  /// lower when looking further down the page. Only from open eyes.
  void _trackGaze(double? pitch, double left, double right, DateTime now) {
    if (pitch == null || left <= 0.5 || right <= 0.5) return;
    final raw = pitch + 20 * (left + right) / 2;
    final g = gaze.value == null ? raw : gaze.value! * 0.7 + raw * 0.3;
    gaze.value = g;
    _history
      ..add((now, g))
      ..removeWhere((h) => now.difference(h.$1).inMilliseconds > 4000);
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
