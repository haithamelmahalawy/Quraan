import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Zoom the printed page without reflowing its letters. Two fingers take
/// priority immediately, including when the first finger began a scroll.
class MushafZoom extends StatefulWidget {
  const MushafZoom({
    super.key,
    required this.controller,
    required this.child,
    required this.onPinchChanged,
    this.onEdgeTurn,
  });

  /// Zoomed in, a drag carried on past the page's side: the page turned
  /// (1 the next, dragged to the right as the mushaf turns; -1 back).
  final ValueChanged<int>? onEdgeTurn;

  /// How far past the side a drag must go to turn the page.
  static const edgeTurn = 56.0;

  final TransformationController controller;
  final Widget child;
  final ValueChanged<bool> onPinchChanged;

  @override
  State<MushafZoom> createState() => _MushafZoomState();
}

class _MushafZoomState extends State<MushafZoom> {
  final _points = <int, Offset>{};
  _PinchPriorityGestureRecognizer? _recognizer;
  bool _pinching = false, _continuePan = false;
  Size _size = Size.zero;
  double _startSpan = 1, _startScale = 1;
  Offset _anchor = Offset.zero;

  /// How far the drag went on past the page's side, across.
  double _overflow = 0;

  double get _scale => widget.controller.value.getMaxScaleOnAxis();
  Offset get _translation {
    final v = widget.controller.value.getTranslation();
    return Offset(v.x, v.y);
  }

  void _setTransform(double scale, Offset translation) {
    final s = scale.clamp(1.0, 4.0);
    final x = translation.dx.clamp(_size.width * (1 - s), 0.0);
    final y = translation.dy.clamp(_size.height * (1 - s), 0.0);
    widget.controller.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, x)
      ..setEntry(1, 3, y);
  }

  /// Where the second of two quick taps came down.
  Offset? _doubleTapAt;

  /// How far two quick taps zoom in.
  static const doubleTapScale = 2.0;

  void _toggleZoom() {
    if (_scale > 1.001) {
      widget.controller.value = Matrix4.identity();
      return;
    }
    final at = _doubleTapAt ?? _size.center(Offset.zero);
    // The place tapped stays under the finger.
    _setTransform(doubleTapScale, at - at * doubleTapScale);
  }

  void _setPinching(bool value) {
    if (_pinching == value) return;
    setState(() => _pinching = value);
    widget.onPinchChanged(value);
  }

  void _begin(Offset focalPoint, double span) {
    _startSpan = math.max(1.0, span);
    _startScale = _scale;
    _anchor = (focalPoint - _translation) / _startScale;
    _setPinching(true);
  }

  void _update(Offset focalPoint, double span) {
    // Amplify the relative distance smoothly in both directions. Using a
    // ratio keeps the response independent of screen size and frame rate.
    var next = (_startScale * math.pow(span / _startSpan, 1.6)).clamp(1.0, 4.0);
    if (next < _scale && next < 1.015) next = 1;
    _setTransform(next, focalPoint - _anchor * next);
    // Rebase at the actual bounded transform. Reversing direction at
    // either zoom limit must respond immediately, without a dead range.
    _startSpan = math.max(.01, span);
    _startScale = _scale;
    _anchor = (focalPoint - _translation) / _startScale;
  }

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _points[event.pointer] = event.localPosition;
    if (_points.length >= 2) {
      _recognizer?.claimPinch();
      final p = _points.values.take(2).toList();
      _begin((p[0] + p[1]) / 2, (p[1] - p[0]).distance);
    }
  }

  void _move(PointerMoveEvent event) {
    final previous = _points[event.pointer];
    if (previous == null) return;
    _points[event.pointer] = event.localPosition;
    if (_points.length >= 2) {
      final p = _points.values.take(2).toList();
      _update((p[0] + p[1]) / 2, (p[1] - p[0]).distance);
    } else if (_continuePan && _scale > 1) {
      _setTransform(_scale, _translation + event.localPosition - previous);
    }
  }

  void _up(PointerEvent event) {
    _points.remove(event.pointer);
    if (_points.length >= 2) {
      final p = _points.values.take(2).toList();
      _begin((p[0] + p[1]) / 2, (p[1] - p[0]).distance);
    } else {
      _continuePan = _pinching && _points.length == 1;
      _setPinching(false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final previousSize = _size;
      _size = c.biggest;
      if (previousSize != Size.zero && previousSize != _size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _points.clear();
          _continuePan = false;
          widget.controller.value = Matrix4.identity();
          _setPinching(false);
        });
      }
      return ClipRect(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            GestureBinding.instance.pointerSignalResolver.register(event, (_) {
              final anchor = (event.localPosition - _translation) / _scale;
              final next = (_scale * math.exp(-event.scrollDelta.dy / 160))
                  .clamp(1.0, 4.0);
              _setTransform(next, event.localPosition - anchor * next);
            });
          },
          onPointerPanZoomStart: (event) => _begin(event.localPosition, 1),
          onPointerPanZoomUpdate: (event) =>
              _update(event.localPosition + event.localPan, event.scale),
          onPointerPanZoomEnd: (_) => _setPinching(false),
          child: AnimatedBuilder(
            animation: widget.controller,
            child: widget.child,
            builder: (context, child) => RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _PinchPriorityGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _PinchPriorityGestureRecognizer
                    >(
                      () => _recognizer = _PinchPriorityGestureRecognizer(),
                      (_) {},
                    ),
                // Two quick taps: zoomed in on the place tapped, or back to
                // the whole page when already zoomed (the user, 2026-11-12).
                DoubleTapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      DoubleTapGestureRecognizer
                    >(
                      () => DoubleTapGestureRecognizer(
                        supportedDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      (r) => r
                        ..onDoubleTapDown = (d) {
                          _doubleTapAt = d.localPosition;
                        }
                        ..onDoubleTap = _toggleZoom,
                    ),
                if (_scale > 1.001 && !_pinching)
                  PanGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        PanGestureRecognizer
                      >(
                        PanGestureRecognizer.new,
                        (r) => r
                          ..gestureSettings = const DeviceGestureSettings(
                            touchSlop: 6,
                          )
                          ..onStart = (_) {
                            _overflow = 0;
                          }
                          ..onUpdate = (d) {
                            final wanted = _translation.dx + d.delta.dx;
                            _setTransform(_scale, _translation + d.delta);
                            // What the side held back, the drag across only.
                            if (d.delta.dx.abs() >= d.delta.dy.abs()) {
                              _overflow += wanted - _translation.dx;
                            }
                          }
                          ..onEnd = (_) {
                            final over = _overflow;
                            _overflow = 0;
                            if (over.abs() >= MushafZoom.edgeTurn) {
                              widget.onEdgeTurn?.call(over > 0 ? 1 : -1);
                            }
                          },
                      ),
              },
              child: Transform(
                alignment: Alignment.topLeft,
                transform: widget.controller.value,
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Claims the two-finger gesture before taps, scrolling or page turning.
/// The surrounding listener also tracks a first finger that already won
/// another drag, so adding the second finger still starts a pinch.
class _PinchPriorityGestureRecognizer extends OneSequenceGestureRecognizer {
  _PinchPriorityGestureRecognizer()
    : super(supportedDevices: {PointerDeviceKind.touch});

  void claimPinch() => resolve(GestureDisposition.accepted);

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    resolvePointer(pointer, GestureDisposition.rejected);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'mushaf pinch';
}
