import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Pages that turn like the paper of a printed mushaf: dragging lifts the
/// sheet, which bends (its free edge leading) and turns over on the spine
/// (the right edge, as in an Arabic book), revealing the next page with the
/// shading and shadow of a real sheet.
///
/// Dragging to the right turns to the next page, to the left goes back.
class BookPager extends StatefulWidget {
  const BookPager({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    required this.onPageChanged,
    this.enabled = true,
    this.revision,
  });

  /// What the pages are drawn with: the pages built are kept until it
  /// changes (a turn builds only the page newly come near). Null: built
  /// again on every rebuild.
  final Object? revision;

  final int itemCount;
  final int initialIndex;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onPageChanged;

  /// False while the page is zoomed, so drags pan instead of turning.
  final bool enabled;

  @override
  State<BookPager> createState() => BookPagerState();
}

class BookPagerState extends State<BookPager>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;

  /// -1..1: positive while turning forward, negative while turning back.
  double _progress = 0;
  bool _dragCancelled = false;
  final _pointers = <int>{};
  late final AnimationController _settle = AnimationController(
    vsync: this,
    value: 0,
    lowerBound: -1,
    upperBound: 1,
  )..addListener(() => setState(() => _progress = _settle.value));

  /// The current page and its neighbours, painted so they can be pictured.
  final _keys = <int, GlobalKey>{};

  /// Picture of the sheet being turned, and which page it shows.
  ui.Image? _sheet;
  int? _sheetOf;

  int get index => _index;

  @override
  void dispose() {
    _refresh?.cancel();
    _settle.dispose();
    _dropSheet();
    super.dispose();
  }

  GlobalKey _keyOf(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  /// The pages as built, kept while the sheet turns: the turn repaints
  /// every frame, and the same widget is not built again.
  final _built = <int, Widget>{};

  @override
  void didUpdateWidget(BookPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision == null || widget.itemCount != oldWidget.itemCount) {
      _built.clear();
      _stale.clear();
    } else if (widget.revision != oldWidget.revision) {
      // The page in sight at once; its neighbours a moment later, one a
      // frame: the three at once were a second's freeze on a weak phone
      // with every riwaya chosen.
      _built.remove(_index);
      _stale
        ..addAll(_built.keys)
        ..remove(_index);
      _refreshLater();
    }
  }

  /// Neighbours still drawn as before the last change, built again soon.
  final _stale = <int>{};
  Timer? _refresh;

  void _refreshLater() {
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _stale.isEmpty) return;
      // Not while a sheet turns: after it.
      if (_progress != 0) return _refreshLater();
      final i = _stale.first;
      _stale.remove(i);
      setState(() => _built.remove(i));
      if (_stale.isNotEmpty) _refreshLater();
    });
  }

  /// A picture of page [i] as displayed (it must be the current page or a
  /// neighbour). The caller owns the image.
  ui.Image? capture(int i, {double? pixelRatio}) {
    final box = _keys[i]?.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.hasSize) return null;
    try {
      return box.toImageSync(
        pixelRatio: pixelRatio ?? View.of(context).devicePixelRatio,
      );
    } catch (_) {
      return null;
    }
  }

  /// Shows [index] at once (index, surah, mutashabih).
  void jumpTo(int index) {
    if (index == _index) return;
    _settle.stop();
    _dropSheet();
    setState(() {
      _index = index.clamp(0, widget.itemCount - 1);
      _progress = 0;
    });
    widget.onPageChanged(_index);
  }

  /// Turns one page with the animation (+1 next, -1 previous).
  Future<void> turn(int direction) async {
    if (!_canTurn(direction) || _settle.isAnimating) return;
    _takeSheet(direction);
    _settle.value = _progress;
    final completed = await _animateTo(
      direction.toDouble(),
      const Duration(milliseconds: 260),
      Curves.easeOutCubic,
    );
    if (mounted && completed) _commit(direction);
  }

  bool _canTurn(int direction) =>
      direction > 0 ? _index < widget.itemCount - 1 : _index > 0;

  /// Pictures the sheet that turns: the current page going forward, the
  /// previous page coming back.
  void _takeSheet(int direction) {
    final page = direction > 0 ? _index : _index - 1;
    if (_sheetOf == page && _sheet != null) return;
    _dropSheet();
    // A transient turning sheet needs fewer pixels than the resting page.
    _sheet = capture(
      page,
      pixelRatio: math.min(View.of(context).devicePixelRatio, 1.5),
    );
    _sheetOf = page;
  }

  void _dropSheet() {
    _sheet?.dispose();
    _sheet = null;
    _sheetOf = null;
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (_dragCancelled || _pointers.length > 1) return;
    _settle.stop();
    var p = _progress + 1.5 * d.primaryDelta! / width;
    if (!_canTurn(1)) p = math.min(p, 0);
    if (!_canTurn(-1)) p = math.max(p, 0);
    p = p.clamp(-1.0, 1.0);
    if (p != 0) _takeSheet(p.sign.toInt());
    setState(() => _progress = p);
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    if (_dragCancelled) return;
    final v = d.primaryVelocity ?? 0;
    final direction = _progress == 0 ? 0 : _progress.sign.toInt();
    final complete =
        direction != 0 &&
        (v * direction >= 300 ||
            (_progress.abs() >= 0.16 && v * direction > -300));
    _settle.value = _progress;
    if (complete) {
      final completed = await _animateTo(
        direction.toDouble(),
        Duration(
          milliseconds: (220 * (1 - _progress.abs())).round().clamp(70, 220),
        ),
        Curves.easeOutCubic,
      );
      if (mounted && completed) _commit(direction);
    } else {
      await _onDragCancel();
    }
  }

  Future<void> _onDragCancel() async {
    _settle.value = _progress;
    final completed = await _animateTo(
      0,
      const Duration(milliseconds: 140),
      Curves.easeOutCubic,
    );
    if (mounted && completed) setState(_dropSheet);
  }

  Future<bool> _animateTo(double target, Duration duration, Curve curve) async {
    try {
      await _settle
          .animateTo(target, duration: duration, curve: curve)
          .orCancel;
      return true;
    } on TickerCanceled {
      // A new gesture or jump owns the page now; do not commit the old turn.
      return false;
    }
  }

  void _commit(int direction) {
    HapticFeedback.lightImpact();
    setState(() {
      _index += direction;
      _progress = 0;
      _settle.value = 0;
    });
    _dropSheet();
    widget.onPageChanged(_index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Each page keeps its state (and its picture key) while it is near.
        // Keyed by the page, a page moved among the layers as they turn is
        // moved as it is: taken out and put back by its picture's key alone,
        // it would be built again (with all its readings) on every turn.
        Widget page(int i, {bool show = true, bool preserveHitTest = false}) =>
            Offstage(
              key: ValueKey('page:$i'),
              offstage: !show && !preserveHitTest,
              child: Opacity(
                opacity: show ? 1 : 0,
                child: RepaintBoundary(
                  key: _keyOf(i),
                  child: KeyedSubtree(
                    key: ValueKey(i),
                    child: _built[i] ??= widget.itemBuilder(context, i),
                  ),
                ),
              ),
            );

        _built.removeWhere((i, _) => (i - _index).abs() > 1);
        _stale.removeWhere((i) => (i - _index).abs() > 1);
        // A neighbour turned to before it was built again: now.
        if (_stale.remove(_index)) _built.remove(_index);
        final prev = _index > 0 ? _index - 1 : null;
        final next = _index < widget.itemCount - 1 ? _index + 1 : null;
        final sheet = _sheet;
        final List<Widget> layers;
        if (_progress > 0) {
          // The current page turns away, the next one lies beneath.
          layers = [
            if (next != null) page(next),
            if (prev != null) page(prev, show: false),
            // Keep the same page under both fingers while its picture
            // turns. A second finger can cancel the turn and begin zoom.
            page(_index, show: sheet == null, preserveHitTest: true),
            if (sheet != null)
              _Curl(image: sheet, progress: _progress)
            else
              _SpineShadow(strength: 1 - _progress),
          ];
        } else if (_progress < 0) {
          // The previous page comes back down over the current one.
          layers = [
            page(_index),
            if (next != null) page(next, show: false),
            if (prev != null) page(prev, show: sheet == null),
            if (sheet != null) _Curl(image: sheet, progress: 1 + _progress),
          ];
        } else {
          // At rest the neighbours lie beneath, painted, ready to be pictured.
          layers = [
            if (prev != null) page(prev),
            if (next != null) page(next),
            page(_index),
          ];
        }

        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            if (widget.enabled)
              HorizontalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    HorizontalDragGestureRecognizer
                  >(
                    HorizontalDragGestureRecognizer.new,
                    (recognizer) => recognizer
                      ..gestureSettings = const DeviceGestureSettings(
                        touchSlop: 10,
                      )
                      ..minFlingDistance = 8
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = (_) {
                        _dragCancelled = _pointers.length > 1;
                        _settle.stop();
                      }
                      ..onUpdate = (d) {
                        _onDragUpdate(d, width);
                      }
                      ..onEnd = _onDragEnd
                      ..onCancel = _onDragCancel,
                  ),
          },
          child: Listener(
            onPointerDown: (event) {
              _pointers.add(event.pointer);
              if (_pointers.length < 2) return;
              // A second finger owns zoom even when the first finger had
              // already lifted the turning sheet. Never commit that turn.
              _dragCancelled = true;
              _settle.stop();
              setState(() {
                _progress = 0;
                _dropSheet();
              });
            },
            onPointerUp: (event) => _pointers.remove(event.pointer),
            onPointerCancel: (event) {
              _pointers.remove(event.pointer);
              if (!widget.enabled) return;
              // A recognized drag can receive onEnd on cancellation.
              _dragCancelled = true;
              _onDragCancel();
            },
            child: Stack(fit: StackFit.expand, children: layers),
          ),
        );
      },
    );
  }
}

/// The turning sheet: the page picture laid on a strip mesh that bends over
/// the spine like paper, shaded by its angle, its back showing once a strip
/// passes upright, with its shadow on the page beneath.
class _Curl extends StatelessWidget {
  const _Curl({required this.image, required this.progress});

  final ui.Image image;

  /// 0 lying flat (not turned) .. 1 turned over.
  final double progress;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _CurlPainter(image, progress, Theme.of(context).brightness),
      size: Size.infinite,
    ),
  );
}

class _CurlPainter extends CustomPainter {
  _CurlPainter(this.image, this.t, this.brightness);

  final ui.Image image;
  final double t;
  final Brightness brightness;

  static const _strips = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final scale = image.width / w; // image pixels per logical pixel
    final turn = t.clamp(0.0, 1.0);

    // Angle of the sheet at distance s from the spine. The paper rolls from
    // its free edge: a part starts to lift only when the fold reaches it,
    // so the sheet stays flat near the spine while its edge curls over.
    double angle(double s) {
      final x = (turn * 1.8 - 0.8 * (1 - s / w)).clamp(0.0, 1.0);
      return math.pi * x * x * (3 - 2 * x); // smoothstep
    }

    // Walk the sheet from the spine (x = w) to its free edge.
    final xs = <double>[w], zs = <double>[0], angles = <double>[];
    final ds = w / _strips;
    for (var i = 0; i < _strips; i++) {
      final a = angle((i + 0.5) * ds);
      angles.add(a);
      xs.add(xs.last - ds * math.cos(a));
      zs.add(zs.last + ds * math.sin(a));
    }

    // Perspective, seen from in front of the page centre.
    final f = 5 * w;
    Offset project(double x, double y, double z) {
      final k = f / (f - z);
      return Offset(w / 2 + (x - w / 2) * k, h / 2 + (y - h / 2) * k);
    }

    // The sheet's shadow on the page beneath, by its free edge.
    final edgeX = xs.last;
    if (edgeX < w) {
      final reach = 50 + 90 * math.sin(math.pi * turn);
      final shadow = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withAlpha((90 * (1 - turn)).round()),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(edgeX - reach, 0, edgeX, h));
      canvas.drawRect(Rect.fromLTRB(edgeX - reach, 0, edgeX, h), shadow);
    }

    final frontPos = <Offset>[], frontTex = <Offset>[], frontColors = <Color>[];
    final backPos = <Offset>[], backColors = <Color>[];
    final paper = brightness == Brightness.dark
        ? const Color(0xFF2A2F2C)
        : const Color(0xFFF1E9D6);
    for (var i = 0; i < _strips; i++) {
      final a = angles[i];
      final p0t = project(xs[i], 0, zs[i]),
          p1t = project(xs[i + 1], 0, zs[i + 1]);
      final p0b = project(xs[i], h, zs[i]),
          p1b = project(xs[i + 1], h, zs[i + 1]);
      final quad = [p0t, p1t, p1b, p0t, p1b, p0b];
      // Light falls from the front: darker as the strip turns away.
      final light = (0.55 + 0.45 * math.cos(a).abs()).clamp(0.0, 1.0);
      if (math.cos(a) >= 0) {
        final u0 = (w - i * ds) * scale, u1 = (w - (i + 1) * ds) * scale;
        final vh = h * scale;
        frontPos.addAll(quad);
        frontTex.addAll([
          Offset(u0, 0),
          Offset(u1, 0),
          Offset(u1, vh),
          Offset(u0, 0),
          Offset(u1, vh),
          Offset(u0, vh),
        ]);
        final c = Color.fromARGB(
          255,
          (255 * light).round(),
          (255 * light).round(),
          (255 * light).round(),
        );
        frontColors.addAll(List.filled(6, c));
      } else {
        // The back of the sheet (its paper), past upright.
        backPos.addAll(quad);
        backColors.addAll(
          List.filled(6, Color.lerp(Colors.black, paper, light)!),
        );
      }
    }

    if (frontPos.isNotEmpty) {
      canvas.drawVertices(
        ui.Vertices(
          VertexMode.triangles,
          frontPos,
          textureCoordinates: frontTex,
          colors: frontColors,
        ),
        BlendMode.modulate,
        Paint()
          ..shader = ImageShader(
            image,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          )
          ..filterQuality = FilterQuality.medium,
      );
    }
    if (backPos.isNotEmpty) {
      canvas.drawVertices(
        ui.Vertices(VertexMode.triangles, backPos, colors: backColors),
        BlendMode.dst,
        Paint(),
      );
    }
  }

  @override
  bool shouldRepaint(_CurlPainter old) => old.t != t || old.image != image;
}

/// The shadow on the page below near the spine (when no picture of the
/// turning sheet could be taken).
class _SpineShadow extends StatelessWidget {
  const _SpineShadow({required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            stops: const [0, 0.35, 1],
            colors: [
              Colors.black.withAlpha((strength * 110).round()),
              Colors.black.withAlpha((strength * 25).round()),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
