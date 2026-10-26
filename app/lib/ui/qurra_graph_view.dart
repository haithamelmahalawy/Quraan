import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/qurra_biographies.dart';
import '../data/qurra_graph.dart';

/// Camera coordinates, rather than a transform applied to flat UI cards.
class QurraGraphCamera extends ChangeNotifier {
  static const startYaw = -.3, startPitch = .6;
  double yaw = startYaw, pitch = startPitch, zoom = 1;
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
    yaw = startYaw;
    pitch = startPitch;
    zoom = 1;
    pan = Offset.zero;
    rotating = false;
    notifyListeners();
  }
}

typedef GraphScreenPoint = ({Offset point, double depth, double perspective});

const _cameraDistance = 18.0;

/// Pixels per unit of the scene: it (radius about 5, from y -3.6 to 3.6)
/// fits the size at zoom 1, seen from above.
double qurraGraphUnit(Size size, double zoom) =>
    math.max(4.0, math.min(size.width / 12.5, size.height / 11)) * zoom;

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
  final perspective = _cameraDistance / (_cameraDistance + depth);
  final unit = qurraGraphUnit(size, camera.zoom);
  return (
    point:
        Offset(size.width / 2, size.height / 2 - .75 * unit) +
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

/// The readers on a ring around the ten qiraat, in their city's coloured
/// sector, their narrators hanging below them: a scene that turns in 3D.
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
  final _pointers = <int, Offset>{};
  _TreePinchRecognizer? _pinchRecognizer;
  Duration? _lastTick;
  bool _reduceMotion = false, _pinching = false;

  /// The city whose readers and narrators stand out, the others dimmed.
  RecitationCity? _focus;

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
      widget.camera.orbit(
        math.min(.05, (elapsed - previous).inMicroseconds / 1000000) * .25,
        0,
      );
    }
  }

  void _changed() {
    _syncTicker();
    setState(() {});
  }

  @override
  void dispose() {
    widget.camera.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _select(QurraGraphNode node) {
    widget.camera.setRotating(false);
    widget.onSelect(node);
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    widget.camera.setRotating(false);
    if (_pointers.length >= 2 && !_pinching) {
      _pinchRecognizer?.claim();
      setState(() => _pinching = true);
    }
  }

  void _move(PointerMoveEvent event) {
    final before = _pointers[event.pointer];
    if (before == null) return;
    final old = _pointers.values.take(2).toList();
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length >= 2) {
      final next = _pointers.values.take(2).toList();
      final span = (old[0] - old[1]).distance;
      if (span > 1) {
        widget.camera.frame(
          widget.camera.zoom * (next[0] - next[1]).distance / span,
          widget.camera.pan + (next[0] + next[1] - old[0] - old[1]) / 2,
        );
      }
    } else if (!_pinching) {
      // The front turns with the finger; dragging down looks from above.
      final delta = event.localPosition - before;
      widget.camera.orbit(-delta.dx * .008, delta.dy * .006);
    }
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty && _pinching) setState(() => _pinching = false);
  }

  void _wheel(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      widget.camera.frame(
        widget.camera.zoom * (event.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1),
        widget.camera.pan,
      );
    }
  }

  bool _inFocus(QurraGraphNode n) =>
      _focus == null ||
      n.kind == QurraNodeKind.root ||
      n.city == _focus ||
      n.reader?.city == _focus;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      1.3,
    );
    final cities = RecitationCity.values
        .where(
          (c) => widget.graph.nodes.any(
            (n) => n.kind == QurraNodeKind.city && n.city == c,
          ),
        )
        .toList();
    if (_focus != null && !cities.contains(_focus)) _focus = null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -.35),
          radius: 1.15,
          colors: dark
              ? const [Color(0xFF1C3A44), Color(0xFF0B171D)]
              : const [Color(0xFFFFFFFF), Color(0xFFE3ECE6)],
        ),
      ),
      child: Column(
        children: [
          _legend(cities, dark),
          Expanded(
            child: Listener(
              key: const ValueKey('qurra-3d-canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              onPointerSignal: _wheel,
              child: RawGestureDetector(
                gestures: {
                  _TreePinchRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _TreePinchRecognizer
                      >(_TreePinchRecognizer.new, (r) => _pinchRecognizer = r),
                },
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, c) => _scene(c.biggest, dark, textScale),
                  ),
                ),
              ),
            ),
          ),
          _toolbar(dark),
        ],
      ),
    );
  }

  Widget _scene(Size size, bool dark, double textScale) {
    final projected = {
      for (final n in widget.graph.nodes)
        n.id: projectQurraPoint(n.position, size, widget.camera),
    };
    // Far nodes first, so the near ones are drawn (and tapped) on top.
    final nodes = [
      ...widget.graph.nodes,
    ]..sort((a, b) => projected[b.id]!.depth.compareTo(projected[a.id]!.depth));
    // Cards grow with the scene, so their spacing holds on any screen.
    final unitScale = qurraGraphUnit(size, widget.camera.zoom) / 40;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ScenePainter(
              graph: widget.graph,
              projected: projected,
              camera: widget.camera,
              dark: dark,
              inFocus: _inFocus,
            ),
          ),
        ),
        for (final n in nodes)
          _placed(n, projected[n.id]!, dark, textScale * unitScale),
      ],
    );
  }

  Widget _placed(
    QurraGraphNode node,
    GraphScreenPoint p,
    bool dark,
    double scale,
  ) {
    final narrowCity =
        node.kind == QurraNodeKind.narrator && node.city != node.reader!.city;
    final (width, height) = switch (node.kind) {
      QurraNodeKind.root => (80.0, 80.0),
      QurraNodeKind.city => (100.0, 26.0),
      QurraNodeKind.reader => (86.0, 40.0),
      QurraNodeKind.narrator => (
        78.0,
        node.label.contains('\n') || narrowCity ? 40.0 : 28.0,
      ),
    };
    final s = (p.perspective * scale).clamp(.45, 2.6);
    // Nearer is brighter; a focus on one city dims the rest.
    final fade = ((p.depth + 6) / 12).clamp(0.0, 1.0);
    final opacity = (_inFocus(node) ? 1 - fade * .6 : .12).toDouble();
    return Positioned(
      left: p.point.dx - width * s / 2,
      top: p.point.dy - height * s / 2,
      width: width * s,
      height: height * s,
      child: Opacity(
        opacity: opacity,
        child: FittedBox(
          child: SizedBox(
            width: width,
            height: height,
            child: _node(node, dark, narrowCity),
          ),
        ),
      ),
    );
  }

  Widget _node(QurraGraphNode node, bool dark, bool narrowCity) {
    final color = qurraCityColor(
      node.kind == QurraNodeKind.narrator ? node.reader!.city : node.city,
    );
    final active = widget.selected == node.id;
    final ink = dark ? Colors.white : const Color(0xFF183F34);
    final soft = dark ? const Color(0xFFBFD2CD) : const Color(0xFF546E62);
    const gold = Color(0xFFC89A42);
    Widget tappable({
      required Widget child,
      required ShapeBorder shape,
      Gradient? gradient,
      Color? fill,
      double glow = 10,
    }) => Semantics(
      button: true,
      label: node.description,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          color: fill,
          gradient: gradient,
          shadows: [
            BoxShadow(
              color: (active ? gold : color).withAlpha(dark ? 110 : 90),
              blurRadius: active ? glow * 1.6 : glow,
            ),
          ],
        ),
        child: Material(
          key: ValueKey('graph-node-${node.id}'),
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _select(node),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: child),
              ),
            ),
          ),
        ),
      ),
    );
    final card = dark ? const Color(0xF2203A42) : const Color(0xF7FFFFFF);
    switch (node.kind) {
      case QurraNodeKind.root:
        return tappable(
          shape: CircleBorder(
            side: BorderSide(color: active ? gold : Colors.white70, width: 2),
          ),
          gradient: const RadialGradient(
            center: Alignment(-.35, -.4),
            colors: [Color(0xFFF6E3A8), Color(0xFFC89A42), Color(0xFF7A5718)],
            stops: [0, .55, 1],
          ),
          glow: 22,
          child: const Text(
            'القراءات\nالعشر',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E05),
            ),
          ),
        );
      case QurraNodeKind.city:
        return tappable(
          shape: StadiumBorder(
            side: BorderSide(color: active ? gold : color, width: 1.6),
          ),
          gradient: LinearGradient(
            colors: [color.withAlpha(dark ? 120 : 90), color.withAlpha(40)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 15, color: color),
              const SizedBox(width: 3),
              Text(
                node.city!.nameAr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ],
          ),
        );
      case QurraNodeKind.reader:
        final complementary = node.reader!.group == RecitationGroup.three;
        return tappable(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: active ? gold : color,
              width: active ? 2.2 : 1.6,
            ),
          ),
          fill: card,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                node.reader!.qiraa.shortAr,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Text(
                complementary ? 'من المتممين للعشرة' : 'من القراء السبعة',
                style: TextStyle(fontSize: 8.5, color: soft),
              ),
            ],
          ),
        );
      case QurraNodeKind.narrator:
        final lines = node.label.split('\n');
        return tappable(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(
              color: active ? gold : color.withAlpha(170),
              width: active ? 2 : 1,
            ),
          ),
          fill: card,
          glow: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                lines.first,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              if (lines.length > 1)
                Text(lines[1], style: TextStyle(fontSize: 9, color: soft)),
              // A narrator of another city than his reader's says so.
              if (narrowCity)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: qurraCityColor(node.city),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      node.city!.nameAr,
                      style: TextStyle(fontSize: 9, color: soft),
                    ),
                  ],
                ),
            ],
          ),
        );
    }
  }

  /// The cities and their colours; one tapped stands out from the others.
  Widget _legend(List<RecitationCity> cities, bool dark) => SizedBox(
    height: 44,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          for (final c in cities)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilterChip(
                key: ValueKey('graph-legend-${c.name}'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                selected: _focus == c,
                selectedColor: qurraCityColor(c).withAlpha(dark ? 110 : 80),
                side: BorderSide(color: qurraCityColor(c).withAlpha(150)),
                avatar: CircleAvatar(
                  radius: 5,
                  backgroundColor: qurraCityColor(c),
                ),
                label: Text(
                  '${c.nameAr} ${_count(c)}',
                  style: const TextStyle(fontSize: 12),
                ),
                tooltip: _focus == c
                    ? 'إظهار كل المدن'
                    : 'إبراز قراء ${c.nameAr} ورواتها',
                onSelected: (_) =>
                    setState(() => _focus = _focus == c ? null : c),
              ),
            ),
        ],
      ),
    ),
  );

  String _count(RecitationCity c) {
    final readers = widget.graph.nodes
        .where((n) => n.kind == QurraNodeKind.reader && n.city == c)
        .length;
    final narrators = widget.graph.nodes
        .where((n) => n.kind == QurraNodeKind.narrator && n.city == c)
        .length;
    return readers > 0 ? '• $readers' : '• رواة $narrators';
  }

  Widget _toolbar(bool dark) => Material(
    color: dark ? const Color(0xE6182E36) : const Color(0xE6E5EDE5),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'إعادة ضبط المنظور',
            onPressed: () => setState(() {
              _focus = null;
              widget.camera.reset();
            }),
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
            onPressed: () => widget.camera.orbit(-.35, 0),
            icon: const Icon(Icons.rotate_left),
          ),
          IconButton(
            tooltip: 'تدوير يمينًا',
            onPressed: () => widget.camera.orbit(.35, 0),
            icon: const Icon(Icons.rotate_right),
          ),
          IconButton(
            tooltip: widget.camera.rotating ? 'إيقاف الدوران' : 'دوران تلقائي',
            onPressed: _reduceMotion
                ? null
                : () => widget.camera.setRotating(!widget.camera.rotating),
            icon: Icon(
              widget.camera.rotating
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
          ),
        ],
      ),
    ),
  );
}

// Claim a pinch before the name buttons can treat it as a tap.
class _TreePinchRecognizer extends OneSequenceGestureRecognizer {
  _TreePinchRecognizer() : super(supportedDevices: {PointerDeviceKind.touch});
  void claim() => resolve(GestureDisposition.accepted);
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
  String get debugDescription => 'reader tree pinch';
}

/// The rings of the cone, its axis and floor, and the edges, all projected.
class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.graph,
    required this.projected,
    required this.camera,
    required this.dark,
    required this.inFocus,
  });
  final QurraGraph graph;
  final Map<String, GraphScreenPoint> projected;
  final QurraGraphCamera camera;
  final bool dark;
  final bool Function(QurraGraphNode) inFocus;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(GraphPoint3 p) => projectQurraPoint(p, size, camera).point;
    final guide = dark ? Colors.white : const Color(0xFF204C43);
    // The floor under the cone, and its rings.
    Path ring(double radius, double y) {
      final path = Path();
      for (var i = 0; i <= 72; i++) {
        final a = i / 72 * math.pi * 2;
        final p = at(
          GraphPoint3(radius * math.sin(a), y, -radius * math.cos(a)),
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path;
    }

    final floor = ring(5.6, 3.9);
    canvas.drawPath(
      floor,
      Paint()
        ..shader = ui.Gradient.radial(
          at(const GraphPoint3(0, 3.9, 0)),
          math.max(
            1,
            (at(const GraphPoint3(5.6, 3.9, 0)) -
                    at(const GraphPoint3(0, 3.9, 0)))
                .distance,
          ),
          [guide.withAlpha(dark ? 26 : 20), guide.withAlpha(0)],
        ),
    );
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(floor, thin..color = guide.withAlpha(dark ? 40 : 35));
    canvas.drawPath(ring(2.3, -1.7), thin..color = guide.withAlpha(28));
    canvas.drawPath(ring(4.3, -.2), thin..color = guide.withAlpha(22));
    _dashed(
      canvas,
      at(const GraphPoint3(0, -3, 0)),
      at(const GraphPoint3(0, 3.9, 0)),
      thin..color = guide.withAlpha(30),
    );

    final byId = {for (final n in graph.nodes) n.id: n};
    // Far edges first.
    final edges = [...graph.edges]
      ..sort(
        (a, b) => (projected[b.from]!.depth + projected[b.to]!.depth).compareTo(
          projected[a.from]!.depth + projected[a.to]!.depth,
        ),
      );
    for (final e in edges) {
      final from = byId[e.from]!, to = byId[e.to]!;
      // A narrator's city is drawn only when it is not his reader's.
      if (e.kind == QurraEdgeKind.classification &&
          to.kind == QurraNodeKind.narrator &&
          to.city == to.reader!.city) {
        continue;
      }
      final a = projected[e.from]!, b = projected[e.to]!;
      final fade = (((a.depth + b.depth) / 2 + 6) / 12).clamp(0.0, 1.0);
      final focus = inFocus(from) && inFocus(to);
      final alpha = ((focus ? 230 : 30) * (1 - fade * .55)).round();
      final color = switch (e.kind) {
        QurraEdgeKind.samePerson => const Color(0xFFC89A42),
        _ when from.kind == QurraNodeKind.root => qurraCityColor(to.city),
        _ => qurraCityColor(from.city),
      };
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withAlpha(alpha)
        ..strokeWidth =
            (e.kind == QurraEdgeKind.transmission ? 2.4 : 1.6) *
            (a.perspective + b.perspective) /
            2;
      if (e.kind == QurraEdgeKind.classification &&
              to.kind == QurraNodeKind.narrator ||
          e.kind == QurraEdgeKind.samePerson) {
        _dashed(canvas, a.point, b.point, paint..strokeWidth *= .7);
      } else if (e.kind == QurraEdgeKind.transmission &&
          to.reader!.narrators.indexOf(to.narrator!) == 1) {
        // The second narrator hangs below the first: his branch bends
        // around it.
        final mid = (a.point + b.point) / 2;
        canvas.drawPath(
          Path()
            ..moveTo(a.point.dx, a.point.dy)
            ..quadraticBezierTo(
              mid.dx + 34 * b.perspective,
              mid.dy,
              b.point.dx,
              b.point.dy,
            ),
          paint,
        );
      } else {
        canvas.drawLine(a.point, b.point, paint);
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final length = (b - a).distance;
    if (length < 1) return;
    final step = (b - a) / length;
    for (var d = 0.0; d < length; d += 9) {
      canvas.drawLine(a + step * d, a + step * math.min(d + 5, length), paint);
    }
  }

  @override
  // Built anew on every camera move or focus change.
  bool shouldRepaint(covariant _ScenePainter old) => true;
}
