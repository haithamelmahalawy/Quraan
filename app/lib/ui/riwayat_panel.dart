import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// An arrow at the top of the mushaf, named «الرواة», that can be called at any
/// time. It lets down the qurra on a ring in depth, turned by dragging: the one
/// in front bold and marked, the others fainter the farther back they are. The
/// mushaf grows shorter beneath it and stays whole, as large again once the
/// arrow sends it back up. A check box on a qari ticks his two riwayat; beside
/// each riwaya a second one shows the mushaf in it, one riwaya at a time.
class RiwayatPanel extends StatefulWidget {
  const RiwayatPanel({
    super.key,
    required this.settings,
    required this.variants,
    required this.child,
  });

  final ReaderSettings settings;
  final VariantRepository variants;

  /// The mushaf.
  final Widget child;

  /// As low as a qari and his two riwayat allow, not to shrink the page much.
  static const height = 112.0;

  @override
  State<RiwayatPanel> createState() => _RiwayatPanelState();
}

class _RiwayatPanelState extends State<RiwayatPanel>
    with SingleTickerProviderStateMixin {
  static const _cellWidth = 150.0;

  /// Which qari is in front, between one and the next as the ring turns.
  late final _turn = AnimationController.unbounded(vsync: this);
  bool _open = false;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  ReaderSettings get s => widget.settings;

  bool _available(String id) => id == hafsId || widget.variants.isAvailable(id);

  bool _chosen(String id) =>
      id == hafsId ? s.compareHafs : s.selected.contains(id);

  /// The readings chosen, in the order of the catalogue.
  List<String> get _ordered => [
    for (final q in qiraat)
      for (final r in q.riwayat)
        if (r.id != hafsId && s.selected.contains(r.id)) r.id,
  ];

  /// Something is always shown: with Hafs not among those chosen, the first of
  /// them; with none left, Hafs's text.
  void _keepOneShown() {
    final shown = s.displayed;
    if (shown != null && !s.selected.contains(shown)) s.displayed = null;
    if (!s.compareHafs && s.displayed == null && s.selected.isNotEmpty) {
      s.displayed = _ordered.first;
    }
  }

  void _setChosen(Iterable<String> ids, bool on) {
    final next = {...s.selected};
    for (final id in ids) {
      if (id == hafsId) {
        s.compareHafs = on;
      } else {
        on ? next.add(id) : next.remove(id);
      }
    }
    s.setSelected(next);
    _keepOneShown();
  }

  /// The mushaf shown in [id], which is chosen with it. One at a time: another
  /// takes its place, and the one shown stays until then.
  void _show(String id) {
    if (id == hafsId) {
      s.compareHafs = true;
      s.displayed = null;
      return;
    }
    s.setSelected({...s.selected, id});
    s.displayed = id;
  }

  /// The ring opens with the qari of the riwaya shown in front.
  void _toggle() {
    if (!_open) {
      final shown = s.displayed ?? hafsId;
      final at = qiraat.indexWhere((q) => q.riwayat.any((r) => r.id == shown));
      _turn.value = math.max(at, 0).toDouble();
    }
    setState(() => _open = !_open);
  }

  void _settle(double target) => _turn.animateTo(
    target,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOut,
  );

  /// Brings the qari [i] to the front, the shorter way round.
  void _bringToFront(int i) {
    final n = qiraat.length;
    var by = (i - _turn.value) % n;
    if (by > n / 2) by -= n;
    _settle(_turn.value + by);
  }

  Widget _box({
    required Key key,
    required bool? value,
    required Color color,
    required ValueChanged<bool?>? onChanged,
    bool tristate = false,
  }) => SizedBox.square(
    dimension: 26,
    child: Checkbox(
      key: key,
      tristate: tristate,
      value: value,
      activeColor: color,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: onChanged,
    ),
  );

  /// A qari's cell: his check box and name, and under them his riwayat, each
  /// with its check box and, at the cell's other side, the one that shows it.
  Widget _qari(Qiraa q, {required bool front}) {
    final ids = [
      for (final r in q.riwayat)
        if (_available(r.id)) r.id,
    ];
    final chosen = ids.where(_chosen).length;
    return Container(
      key: front ? ValueKey('riwayat-front-${q.id}') : null,
      width: _cellWidth,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: MushafColors.page,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: front ? q.color : MushafColors.gold.withAlpha(150),
          width: front ? 2 : .8,
        ),
        boxShadow: front
            ? [BoxShadow(color: q.color.withAlpha(90), blurRadius: 8)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _box(
                key: ValueKey('qari-check-${q.id}'),
                tristate: true,
                // Both ticked, one, or none.
                value: chosen == ids.length && ids.isNotEmpty
                    ? true
                    : chosen == 0
                    ? false
                    : null,
                color: q.color,
                onChanged: ids.isEmpty
                    ? null
                    : (_) => _setChosen(ids, chosen < ids.length),
              ),
              Expanded(
                child: Text(
                  q.shortAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: front ? 13 : 12,
                    fontWeight: front ? FontWeight.w900 : FontWeight.normal,
                    color: q.color,
                  ),
                ),
              ),
            ],
          ),
          for (final r in q.riwayat)
            if (_available(r.id))
              Row(
                children: [
                  _box(
                    key: ValueKey('riwaya-check-${r.id}'),
                    value: _chosen(r.id),
                    color: q.color,
                    onChanged: (v) => _setChosen([r.id], v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      r.nameAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: front ? FontWeight.bold : FontWeight.normal,
                        color: MushafColors.ink,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'عرض المصحف برواية ${r.nameAr}',
                    child: _box(
                      key: ValueKey('riwaya-show-${r.id}'),
                      value: r.id == hafsId
                          ? s.displayed == null
                          : s.displayed == r.id,
                      color: MushafColors.green,
                      onChanged: (_) => _show(r.id),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  /// The ring: each qari by his place on it, the nearest painted last. Only the
  /// one in front answers; another, tapped, comes to the front.
  Widget _ring(double width) {
    final n = qiraat.length;
    final radius = math.max(0.0, (width - _cellWidth) / 2);
    return GestureDetector(
      key: const ValueKey('riwayat-ring'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        // Dragged to the right, the next at the left comes round to the front.
        _turn.value += d.delta.dx / math.max(radius, 60) * n / (2 * math.pi);
      },
      onHorizontalDragEnd: (d) {
        final flick = (d.primaryVelocity ?? 0) / 900;
        _settle((_turn.value + flick.clamp(-1.0, 1.0)).roundToDouble());
      },
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final front = _turn.value.round() % n;
          final places = [
            for (var i = 0; i < n; i++)
              (i: i, theta: (i - _turn.value) * 2 * math.pi / n),
          ]..sort((a, b) => math.cos(a.theta).compareTo(math.cos(b.theta)));
          return ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (:i, :theta) in places)
                  // The back of the ring is out of sight.
                  if (math.cos(theta) > -.45)
                    () {
                      final near = (math.cos(theta) + 1) / 2;
                      final isFront = i == front;
                      return Transform.translate(
                        // The next qari at the left, as the text runs.
                        offset: Offset(-radius * math.sin(theta), 0),
                        child: Transform.scale(
                          scale: .62 + .38 * near,
                          child: Opacity(
                            opacity: isFront
                                ? 1
                                : (math.pow(near, 2.2) * .75).clamp(.08, .7),
                            child: GestureDetector(
                              key: ValueKey('qari-cell-${qiraat[i].id}'),
                              // Hit though its check boxes do not answer.
                              behavior: HitTestBehavior.opaque,
                              onTap: isFront ? null : () => _bringToFront(i),
                              child: IgnorePointer(
                                ignoring: !isFront,
                                child: _qari(qiraat[i], front: isFront),
                              ),
                            ),
                          ),
                        ),
                      );
                    }(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panel() => Material(
    key: const ValueKey('riwayat-panel'),
    color: MushafColors.paper,
    elevation: 3,
    child: SizedBox(
      height: RiwayatPanel.height,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '  اسحب لتدوير القراء • المربع الأيسر لعرض المصحف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: MushafColors.frame),
                  ),
                ),
                if (s.selected.isNotEmpty || s.compareHafs)
                  InkWell(
                    key: const ValueKey('riwayat-clear'),
                    onTap: () {
                      s.setSelected({});
                      s.compareHafs = false;
                      s.displayed = null;
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'إلغاء الكل',
                        style: TextStyle(
                          fontSize: 10,
                          color: MushafColors.green,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => _ring(box.maxWidth),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// The arrow, drawn: pointing down to let the ring down, up to send it back.
  Widget _arrow() => Semantics(
    button: true,
    expanded: _open,
    label: _open ? 'إخفاء الرواة' : 'إظهار الرواة',
    child: Material(
      color: MushafColors.goldLight,
      elevation: 3,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      child: InkWell(
        key: const ValueKey('riwayat-panel-toggle'),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 1, 10, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الرواة',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: MushafColors.green,
                ),
              ),
              const SizedBox(width: 5),
              CustomPaint(
                size: const Size(14, 9),
                painter: _Chevron(MushafColors.green, pointsUp: _open),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_open) _panel(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              // Clear of the page's header: its surah, its «الأصول», its juz.
              Align(alignment: const Alignment(-.62, -1), child: _arrow()),
            ],
          ),
        ),
      ],
    ),
  );
}

/// An arrow head, drawn: no font to be missing.
class _Chevron extends CustomPainter {
  const _Chevron(this.color, {required this.pointsUp});

  final Color color;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final (near, far) = pointsUp
        ? (size.height * .85, size.height * .15)
        : (size.height * .15, size.height * .85);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .1, near)
        ..lineTo(size.width / 2, far)
        ..lineTo(size.width * .9, near),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Chevron old) =>
      color != old.color || pointsUp != old.pointsUp;
}
