import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/qurra_biographies.dart';
import '../data/qurra_graph.dart';

/// Camera coordinates, rather than a transform applied to flat UI cards.
class QurraGraphCamera extends ChangeNotifier {
  double yaw = -.12, pitch = .12, zoom = 1;
  Offset pan = Offset.zero;
  bool rotating = false;

  void orbit(double dx, double dy) {
    yaw = (yaw + dx) % (math.pi * 2);
    pitch = (pitch + dy).clamp(-1.35, 1.35);
    notifyListeners();
  }

  void frame(double scale, Offset offset) {
    zoom = scale.clamp(.6, 3.5);
    pan = offset;
    notifyListeners();
  }

  void setRotating(bool value) {
    if (rotating == value) return;
    rotating = value;
    notifyListeners();
  }

  void reset() {
    yaw = -.12;
    pitch = .12;
    zoom = 1;
    pan = Offset.zero;
    rotating = false;
    notifyListeners();
  }
}

typedef GraphScreenPoint = ({Offset point, double depth, double perspective});

/// A real yaw/pitch rotation followed by a perspective divide.
GraphScreenPoint projectQurraPoint(
  GraphPoint3 point,
  Size size,
  QurraGraphCamera camera,
) {
  final x = point.x * math.cos(camera.yaw) + point.z * math.sin(camera.yaw);
  final z = -point.x * math.sin(camera.yaw) + point.z * math.cos(camera.yaw);
  final y = point.y * math.cos(camera.pitch) - z * math.sin(camera.pitch);
  final depth = point.y * math.sin(camera.pitch) + z * math.cos(camera.pitch);
  final perspective = 7 / (7 + depth);
  final available = math.max(40.0, math.min(size.width - 44, size.height - 95));
  final unit = available / 7 * camera.zoom;
  return (
    point:
        Offset(size.width / 2, (size.height - 40) / 2) +
        camera.pan +
        Offset(x, y) * unit * perspective,
    depth: depth,
    perspective: perspective,
  );
}

Color qurraCityColor(RecitationCity? city) => switch (city) {
  RecitationCity.madinah => const Color(0xFF45C8A0),
  RecitationCity.makkah => const Color(0xFFE7B45E),
  RecitationCity.kufa => const Color(0xFFB29AF4),
  RecitationCity.basra => const Color(0xFF48C9DF),
  RecitationCity.damascus => const Color(0xFF699FF1),
  RecitationCity.baghdad => const Color(0xFFE78BAA),
  RecitationCity.egypt => const Color(0xFFF2A779),
  RecitationCity.raqqa => const Color(0xFF81D3CA),
  null => const Color(0xFF56DAB0),
};

class QurraGraphView extends StatefulWidget {
  const QurraGraphView({
    super.key,
    required this.graph,
    required this.camera,
    required this.onSelect,
    this.selected,
  });
  final QurraGraph graph;
  final QurraGraphCamera camera;
  final ValueChanged<QurraGraphNode> onSelect;
  final String? selected;

  @override
  State<QurraGraphView> createState() => _QurraGraphViewState();
}

class _QurraGraphViewState extends State<QurraGraphView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration? _lastTick;
  bool _reduceMotion = false;
  double _lastScale = 1;
  int _lastPointers = 0;
  Offset _lastFocal = Offset.zero;
  final _textCache = <String, TextPainter>{};
  List<_ProjectedNode> _layout = const [];
  String? _textSignature;

  @override
  void initState() {
    super.initState();
    widget.camera.addListener(_changed);
  }

  @override
  void didUpdateWidget(QurraGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera) {
      oldWidget.camera.removeListener(_changed);
      widget.camera.addListener(_changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  void _syncTicker() {
    final animate =
        widget.camera.rotating &&
        !_reduceMotion &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
    if (!animate && _ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous != null) {
      final seconds = math.min(
        .05,
        (elapsed - previous).inMicroseconds / 1000000,
      );
      widget.camera.orbit(seconds * .17, 0);
    }
  }

  void _changed() {
    _syncTicker();
    setState(() {});
  }

  void _clearTextCache() {
    for (final p in _textCache.values) {
      p.dispose();
    }
    _textCache.clear();
  }

  @override
  void dispose() {
    widget.camera.removeListener(_changed);
    _ticker.dispose();
    _clearTextCache();
    super.dispose();
  }

  void _pick(Offset point) {
    for (final p in _layout.reversed) {
      if (p.labelRect.contains(point) ||
          (point - p.screen.point).distance <= p.radius + 10) {
        widget.camera.setRotating(false);
        widget.onSelect(p.node);
        return;
      }
    }
  }

  TextPainter _label(
    QurraGraphNode node,
    bool dark,
    double scale,
    TextStyle style,
  ) {
    final id = '${node.id}:${node.label}';
    return _textCache.putIfAbsent(
      id,
      () => TextPainter(
        text: TextSpan(
          text: node.label,
          style: style.copyWith(
            fontSize: (node.kind == QurraNodeKind.reader ? 12.5 : 11.5) * scale,
            fontWeight: node.kind == QurraNodeKind.narrator
                ? FontWeight.w500
                : FontWeight.w700,
            color: dark ? const Color(0xFFF0F7F5) : const Color(0xFF193C38),
            height: 1.3,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 100 * scale),
    );
  }

  List<_ProjectedNode> _project(
    Size size,
    bool dark,
    double scale,
    TextStyle style,
  ) {
    final visible = <_ProjectedNode>[];
    // Place the city/reader labels first, then find room for narrator labels.
    final ordered = widget.graph.nodes.toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    for (final node in ordered) {
      final screen = projectQurraPoint(node.position, size, widget.camera);
      if (!screen.point.dx.isFinite || !screen.point.dy.isFinite) continue;
      if (!(Offset.zero & size).inflate(60).contains(screen.point)) continue;
      final text = _label(node, dark, scale, style);
      final radius =
          switch (node.kind) {
            QurraNodeKind.root => 12.0,
            QurraNodeKind.city => 9.0,
            QurraNodeKind.reader => 8.0,
            QurraNodeKind.narrator => 5.0,
          } *
          screen.perspective.clamp(.7, 1.4);
      final width = text.width + 10, height = text.height + 6;
      Rect? best;
      var score = double.infinity;
      for (final delta in [
        Offset(-width / 2, radius + 4),
        Offset(-width / 2, -radius - height - 4),
        Offset(radius + 5, -height / 2),
        Offset(-radius - width - 5, -height / 2),
        Offset(-width / 2, radius + 22),
        Offset(-width / 2, -radius - height - 22),
        Offset(radius + 18, 8),
        Offset(-radius - width - 18, 8),
        Offset(radius + 5, -height - 18),
        Offset(-radius - width - 5, -height - 18),
      ]) {
        final left = (screen.point.dx + delta.dx).clamp(
          4.0,
          math.max(4.0, size.width - width - 4),
        );
        final top = (screen.point.dy + delta.dy).clamp(
          4.0,
          math.max(4.0, size.height - height - 59),
        );
        final rect = Rect.fromLTWH(
          left.toDouble(),
          top.toDouble(),
          width,
          height,
        );
        var overlap = 0.0;
        for (final other in visible) {
          if (rect.inflate(2).overlaps(other.labelRect)) {
            final r = rect.inflate(2).intersect(other.labelRect);
            overlap += r.width * r.height;
          }
        }
        final candidate = overlap * 12 + (rect.center - screen.point).distance;
        if (candidate < score) {
          best = rect;
          score = candidate;
        }
      }
      visible.add(_ProjectedNode(node, screen, radius, text, best!));
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final style = Theme.of(context).textTheme.bodySmall!;
    final signature =
        '$dark:$scale:${style.fontFamily}:${widget.graph.nodes.map((n) => n.id).join()}';
    if (_textSignature != signature) {
      _clearTextCache();
      _textSignature = signature;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _layout = _project(size, dark, scale, style);
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(
                        event,
                        (_) {
                          widget.camera.frame(
                            widget.camera.zoom *
                                math.exp(-event.scrollDelta.dy * .0018),
                            widget.camera.pan,
                          );
                        },
                      );
                    }
                  },
                  child: GestureDetector(
                    key: const ValueKey('qurra-3d-canvas'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _pick(d.localPosition),
                    onScaleStart: (d) {
                      widget.camera.setRotating(false);
                      _lastScale = 1;
                      _lastPointers = d.pointerCount;
                      _lastFocal = d.localFocalPoint;
                    },
                    onScaleUpdate: (d) {
                      if (_lastPointers != d.pointerCount) {
                        _lastPointers = d.pointerCount;
                        _lastScale = d.scale;
                        _lastFocal = d.localFocalPoint;
                        return;
                      }
                      final delta = d.localFocalPoint - _lastFocal;
                      _lastFocal = d.localFocalPoint;
                      if (d.pointerCount >= 2) {
                        widget.camera.frame(
                          widget.camera.zoom * d.scale / _lastScale,
                          widget.camera.pan + delta,
                        );
                      } else {
                        widget.camera.orbit(delta.dx * .008, -delta.dy * .008);
                      }
                      _lastScale = d.scale;
                    },
                    child: CustomPaint(
                      size: size,
                      painter: _QurraGraphPainter(
                        widget.graph,
                        _layout,
                        widget.camera,
                        dark,
                        widget.selected,
                      ),
                    ),
                  ),
                ),
              ),
              for (final p in _layout)
                Positioned.fromRect(
                  rect: p.labelRect,
                  child: Semantics(
                    key: ValueKey('graph-node-${p.node.id}'),
                    button: true,
                    label: p.node.description,
                    onTap: () {
                      widget.camera.setRotating(false);
                      widget.onSelect(p.node);
                    },
                    child: const IgnorePointer(child: SizedBox.expand()),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Center(
                  child: Material(
                    color: dark
                        ? const Color(0xF022343C)
                        : const Color(0xF2F2F7F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: qurraCityColor(null).withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إعادة ضبط المنظور',
                          onPressed: widget.camera.reset,
                          icon: const Icon(Icons.center_focus_strong),
                        ),
                        IconButton(
                          tooltip: 'تصغير الشبكة',
                          onPressed: () => widget.camera.frame(
                            widget.camera.zoom / 1.2,
                            widget.camera.pan,
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'تكبير الشبكة',
                          onPressed: () => widget.camera.frame(
                            widget.camera.zoom * 1.2,
                            widget.camera.pan,
                          ),
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'تدوير يسارًا',
                          onPressed: () => widget.camera.orbit(-.25, 0),
                          icon: const Icon(Icons.rotate_left),
                        ),
                        IconButton(
                          tooltip: 'تدوير يمينًا',
                          onPressed: () => widget.camera.orbit(.25, 0),
                          icon: const Icon(Icons.rotate_right),
                        ),
                        IconButton(
                          tooltip: widget.camera.rotating
                              ? 'إيقاف الدوران'
                              : 'دوران تلقائي',
                          onPressed: _reduceMotion
                              ? null
                              : () => widget.camera.setRotating(
                                  !widget.camera.rotating,
                                ),
                          icon: Icon(
                            widget.camera.rotating
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectedNode {
  const _ProjectedNode(
    this.node,
    this.screen,
    this.radius,
    this.text,
    this.labelRect,
  );
  final QurraGraphNode node;
  final GraphScreenPoint screen;
  final double radius;
  final TextPainter text;
  final Rect labelRect;
}

class _QurraGraphPainter extends CustomPainter {
  _QurraGraphPainter(
    this.graph,
    this.nodes,
    this.camera,
    this.dark,
    this.selected,
  );
  final QurraGraph graph;
  final List<_ProjectedNode> nodes;
  final QurraGraphCamera camera;
  final bool dark;
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: dark
              ? const [Color(0xFF15353D), Color(0xFF0B1421)]
              : const [Color(0xFFF8FCF8), Color(0xFFDDEBE9)],
          radius: .85,
        ).createShader(rect),
    );
    for (var i = 0; i < 65; i++) {
      final point = Offset(
        (math.sin(i * 43.1) * .5 + .5) * size.width,
        (math.cos(i * 17.7) * .5 + .5) * size.height,
      );
      canvas.drawCircle(
        point,
        i % 4 == 0 ? 1.2 : .65,
        Paint()
          ..color = (dark ? Colors.white : const Color(0xFF287B78)).withAlpha(
            30,
          ),
      );
    }
    // These orbits rotate in the same world space as the nodes.
    for (final radius in [1.15, 2.0, 2.9]) {
      final path = Path();
      for (var i = 0; i <= 100; i++) {
        final t = i / 100 * math.pi * 2;
        final p = projectQurraPoint(
          GraphPoint3(math.cos(t) * radius, math.sin(t) * radius, 0),
          size,
          camera,
        ).point;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = (dark ? Colors.white : Colors.teal).withAlpha(25),
      );
    }
    final byId = {for (final p in nodes) p.node.id: p};
    for (final edge in graph.edges) {
      final a = byId[edge.from], b = byId[edge.to];
      if (a == null || b == null) continue;
      final active = selected == a.node.id || selected == b.node.id;
      final transmission = edge.kind == QurraEdgeKind.transmission;
      final identity = edge.kind == QurraEdgeKind.samePerson;
      final color = identity
          ? const Color(0xFFE4BC72)
          : qurraCityColor(b.node.city);
      final paint = Paint()
        ..color = color.withAlpha(
          active
              ? 245
              : transmission
              ? 125
              : 48,
        )
        ..strokeWidth = active
            ? 2.3
            : transmission
            ? 1.35
            : .8
        ..style = PaintingStyle.stroke;
      if (identity) {
        final delta = b.screen.point - a.screen.point;
        for (var i = 0.0; i < delta.distance; i += 9) {
          final from = a.screen.point + delta * (i / delta.distance);
          final to =
              a.screen.point +
              delta * (math.min(i + 4, delta.distance) / delta.distance);
          canvas.drawLine(from, to, paint);
        }
      } else {
        canvas.drawLine(a.screen.point, b.screen.point, paint);
      }
    }
    final depthOrder = nodes.toList()
      ..sort((a, b) => b.screen.depth.compareTo(a.screen.depth));
    for (final p in depthOrder) {
      final color = qurraCityColor(p.node.city);
      final center = p.screen.point, r = p.radius;
      final active = p.node.id == selected;
      canvas.drawCircle(
        center,
        r * (active ? 2.6 : 1.9),
        Paint()
          ..color = color.withAlpha(active ? 80 : 32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      final bounds = Rect.fromCircle(center: center, radius: r);
      if (p.node.kind == QurraNodeKind.city) {
        final path = Path()
          ..moveTo(center.dx, center.dy - r - 1)
          ..lineTo(center.dx + r + 1, center.dy)
          ..lineTo(center.dx, center.dy + r + 1)
          ..lineTo(center.dx - r - 1, center.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      } else {
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.4, -.5),
              colors: [
                Color.lerp(color, Colors.white, .7)!,
                color,
                Color.lerp(color, Colors.black, .6)!,
              ],
              stops: const [0, .5, 1],
            ).createShader(bounds),
        );
        canvas.drawCircle(
          center + Offset(-r * .28, -r * .34),
          r * .2,
          Paint()..color = Colors.white.withAlpha(155),
        );
      }
      if (active ||
          p.node.reader?.group == RecitationGroup.three &&
              p.node.kind == QurraNodeKind.reader) {
        canvas.drawCircle(
          center,
          r + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 2 : 1.4
            ..color = const Color(0xFFE9BF67),
        );
      }
    }
    for (final p in nodes) {
      if ((p.screen.point - p.labelRect.center).distance > 28) {
        canvas.drawLine(
          p.screen.point,
          p.labelRect.center,
          Paint()
            ..strokeWidth = .65
            ..color = qurraCityColor(p.node.city).withAlpha(90),
        );
      }
      final active = p.node.id == selected;
      final fill = dark ? const Color(0xFF102330) : const Color(0xFFF5FAF7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(p.labelRect, const Radius.circular(6)),
        Paint()..color = fill.withAlpha(active ? 255 : 228),
      );
      if (active) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(p.labelRect, const Radius.circular(6)),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFE9BF67),
        );
      }
      p.text.paint(canvas, p.labelRect.topLeft + const Offset(5, 3));
    }
  }

  @override
  bool shouldRepaint(covariant _QurraGraphPainter oldDelegate) => true;
}
