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

/// A city-grouped forest: each reader and his narrators share a small 3D
/// stage. Edges never leave that stage, so unrelated families cannot cross.
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
  final _scroll = ScrollController();
  final _pointers = <int, Offset>{};
  _TreePinchRecognizer? _pinchRecognizer;
  Duration? _lastTick;
  bool _reduceMotion = false, _rotateDrag = false, _pinching = false;

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
        math.min(.05, (elapsed - previous).inMicroseconds / 1000000) * .17,
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
    _scroll.dispose();
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
    } else if (_rotateDrag) {
      final delta = event.localPosition - before;
      widget.camera.orbit(delta.dx * .008, -delta.dy * .008);
    }
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _pinching) setState(() => _pinching = false);
  }

  void _reset() {
    widget.camera.reset();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _rotateDrag = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final readers = widget.graph.nodes
        .where((n) => n.kind == QurraNodeKind.reader)
        .toList();
    final cities = RecitationCity.values
        .where((c) => readers.any((r) => r.city == c))
        .toList();
    final byId = {for (final n in widget.graph.nodes) n.id: n};
    final narratorCityOwner = <RecitationCity, String>{};
    for (final n in widget.graph.nodes.where(
      (n) => n.kind == QurraNodeKind.narrator,
    )) {
      if (!cities.contains(n.city)) {
        narratorCityOwner.putIfAbsent(n.city!, () => n.id);
      }
    }
    final zoomScale = math.sqrt(widget.camera.zoom).clamp(.85, 1.7);
    Widget citySection(RecitationCity city) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
          child: Row(
            children: [
              Flexible(
                child: InkWell(
                  key: ValueKey('graph-node-city-${city.name}'),
                  onTap: () => _select(byId['city-${city.name}']!),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: qurraCityColor(city),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: dark
                                  ? Colors.white
                                  : const Color(0xFF204C43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  indent: 8,
                  endIndent: 8,
                  color: qurraCityColor(city).withAlpha(65),
                ),
              ),
              Text(
                '${readers.where((r) => r.city == city).length}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        for (final reader in readers.where((r) => r.city == city))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReaderBranch(
              key: ValueKey('graph-family-${reader.reader!.qiraaId}'),
              reader: reader,
              narrators: widget.graph.nodes
                  .where(
                    (n) =>
                        n.kind == QurraNodeKind.narrator &&
                        n.reader?.qiraaId == reader.reader!.qiraaId,
                  )
                  .toList(),
              camera: widget.camera,
              scale: scale * zoomScale,
              dark: dark,
              selected: widget.selected,
              cityOwner: narratorCityOwner,
              cityNodes: byId,
              onSelect: _select,
            ),
          ),
      ],
    );
    return ColoredBox(
      color: dark ? const Color(0xFF0F2028) : const Color(0xFFF3F6F2),
      child: Column(
        children: [
          Expanded(
            child: Listener(
              key: const ValueKey('qurra-3d-canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: RawGestureDetector(
                gestures: {
                  _TreePinchRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _TreePinchRecognizer
                      >(_TreePinchRecognizer.new, (r) => _pinchRecognizer = r),
                },
                child: GestureDetector(
                  onPanUpdate: _rotateDrag ? (_) {} : null,
                  child: Scrollbar(
                    controller: _scroll,
                    child: ListView(
                      key: const PageStorageKey('qurra-organized-forest'),
                      controller: _scroll,
                      physics: _rotateDrag || _pinching
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      children: [
                        if (byId['root'] case final root?)
                          InkWell(
                            key: const ValueKey('graph-node-root'),
                            onTap: () => _select(root),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_tree_rounded,
                                    size: 23,
                                    color: qurraCityColor(null),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'القارئ في الأعلى • راوياه في الأسفل',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final count = math.max(
                              1,
                              (c.maxWidth /
                                      (310 *
                                          zoomScale *
                                          math.max(1.0, scale * .85)))
                                  .floor(),
                            );
                            final columns = List.generate(
                              count,
                              (_) => <RecitationCity>[],
                            );
                            final weights = List.filled(count, 0);
                            for (final city in cities) {
                              var target = 0;
                              for (var i = 1; i < count; i++) {
                                if (weights[i] < weights[target]) target = i;
                              }
                              columns[target].add(city);
                              weights[target] += readers
                                  .where((r) => r.city == city)
                                  .length;
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < columns.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final city in columns[i])
                                          citySection(city),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'بلد كل راوٍ مكتوب تحت اسمه، وقد يختلف عن بلد القارئ.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
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

  Widget _toolbar(bool dark) => Material(
    color: dark ? const Color(0xFF182E36) : const Color(0xFFE5EDE5),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          IconButton(
            tooltip: _rotateDrag ? 'العودة للتصفح بالتمرير' : 'تدوير بالسحب',
            isSelected: _rotateDrag,
            onPressed: () => setState(() {
              _rotateDrag = !_rotateDrag;
              widget.camera.setRotating(false);
            }),
            icon: const Icon(Icons.threed_rotation),
            selectedIcon: const Icon(Icons.swipe_vertical_rounded),
          ),
          IconButton(
            tooltip: 'إعادة ضبط المنظور',
            onPressed: _reset,
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

// Claim a pinch before the name buttons or the scroll view can treat it as a tap.
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

class _ReaderBranch extends StatelessWidget {
  const _ReaderBranch({
    super.key,
    required this.reader,
    required this.narrators,
    required this.camera,
    required this.scale,
    required this.dark,
    required this.selected,
    required this.cityOwner,
    required this.cityNodes,
    required this.onSelect,
  });
  final QurraGraphNode reader;
  final List<QurraGraphNode> narrators;
  final QurraGraphCamera camera;
  final double scale;
  final bool dark;
  final String? selected;
  final Map<RecitationCity, String> cityOwner;
  final Map<String, QurraGraphNode> cityNodes;
  final ValueChanged<QurraGraphNode> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final width = c.maxWidth;
      final parentHeight = 90 * scale, childHeight = 90 * scale;
      final height = parentHeight + childHeight + 65;
      final parentWidth = math.min(width - 32, 176 * math.sqrt(scale));
      final childWidth = narrators.length == 1
          ? math.min(width - 32, 165.0)
          : (width - 38) / 2;
      final size = Size(width, height);
      final origin = reader.position.x;
      GraphScreenPoint project(QurraGraphNode n) => projectQurraPoint(
        GraphPoint3(n.position.x - origin, n.position.y, n.position.z),
        size,
        camera,
      );
      final parentProjection = project(reader);
      // Labels face the viewer, with independent lanes even at an edge-on angle.
      // The true 3D projection drives the motion and depth within those lanes.
      final parentLeft =
          (width / 2 -
                  parentWidth / 2 +
                  (parentProjection.point.dx - width / 2).clamp(-12, 12))
              .clamp(8.0, width - parentWidth - 8);
      final parent = Rect.fromLTWH(parentLeft, 12, parentWidth, parentHeight);
      final children = <Rect>[];
      for (var i = 0; i < narrators.length; i++) {
        final projection = project(narrators[i]);
        final right = narrators.length > 1 && i == 0;
        final center = narrators.length == 1
            ? width / 2
            : right
            ? width * .75
            : width * .25;
        final rawX =
            center -
            childWidth / 2 +
            (projection.point.dx - width / 2).clamp(-4, 4);
        final minX = narrators.length == 1
            ? 10.0
            : right
            ? width / 2 + 9
            : 10.0;
        final maxX = narrators.length == 1
            ? width - childWidth - 10
            : right
            ? width - childWidth - 10
            : width / 2 - childWidth - 9;
        children.add(
          Rect.fromLTWH(
            rawX.clamp(minX, math.max(minX, maxX)),
            parent.bottom +
                35 +
                (projection.point.dy - size.height / 2).clamp(-3, 3),
            childWidth,
            childHeight,
          ),
        );
      }
      final color = qurraCityColor(reader.city);
      return Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: dark ? const Color(0xFF182D35) : Colors.white,
          border: Border.all(color: color.withAlpha(dark ? 65 : 85)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(dark ? 22 : 10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BranchLines(parent, children, color, dark),
              ),
            ),
            Positioned.fromRect(
              rect: parent,
              child: _node(reader, color, parentProjection.depth, true),
            ),
            for (var i = 0; i < narrators.length; i++)
              Positioned.fromRect(
                rect: children[i],
                child: _node(
                  narrators[i],
                  color,
                  project(narrators[i]).depth,
                  false,
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _node(
    QurraGraphNode node,
    Color branchColor,
    double depth,
    bool parent,
  ) {
    final active = selected == node.id;
    final complementary = parent && node.reader!.group == RecitationGroup.three;
    final ownColor = qurraCityColor(node.city);
    final fill = dark ? const Color(0xFF243F46) : const Color(0xFFF8FBF6);
    final border = active || complementary
        ? const Color(0xFFC89A42)
        : branchColor.withAlpha(parent ? 160 : 75);
    final label = parent
        ? node.reader!.qiraa.shortAr
        : node.narrator!.riwaya.nameAr;
    final city = node.city!;
    return Semantics(
      button: true,
      label: node.description,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateX(math.sin(camera.pitch) * .08)
          ..rotateY(math.sin(camera.yaw) * .12),
        child: Material(
          key: ValueKey('graph-node-${node.id}'),
          color: fill,
          elevation: (7 - depth).clamp(2, 12),
          shadowColor: branchColor.withAlpha(80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(parent ? 15 : 12),
            side: BorderSide(color: border, width: parent ? 1.4 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelect(node),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (parent)
                    Text(
                      complementary ? 'من المتممين للعشرة' : 'من القراء السبعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.linear(scale),
                      style: TextStyle(
                        fontSize: 9,
                        color: dark
                            ? const Color(0xFFADC4BD)
                            : const Color(0xFF627D71),
                      ),
                    ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.linear(scale),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: parent ? 18 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: dark ? Colors.white : const Color(0xFF183F34),
                    ),
                  ),
                  if (!parent) ...[
                    const SizedBox(height: 3),
                    InkWell(
                      key: cityOwner[city] == node.id
                          ? ValueKey('graph-node-city-${city.name}')
                          : null,
                      onTap: () => onSelect(cityNodes['city-${city.name}']!),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: ownColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                city.nameAr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textScaler: TextScaler.linear(scale),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: dark
                                      ? const Color(0xFFBFD2CD)
                                      : const Color(0xFF546E62),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchLines extends CustomPainter {
  _BranchLines(this.parent, this.children, this.color, this.dark);
  final Rect parent;
  final List<Rect> children;
  final Color color;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final start = parent.bottomCenter;
    final splitY = start.dy + 17;
    final paint = Paint()
      ..color = color.withAlpha(dark ? 195 : 175)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final line = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(start.dx, splitY);
    for (final child in children) {
      line.moveTo(start.dx, splitY);
      line.lineTo(child.center.dx, splitY);
      line.lineTo(child.center.dx, child.top);
    }
    canvas.drawPath(line, paint);
    canvas.drawCircle(Offset(start.dx, splitY), 3.3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BranchLines old) =>
      old.parent != parent ||
      old.children != children ||
      old.color != color ||
      old.dark != dark;
}
