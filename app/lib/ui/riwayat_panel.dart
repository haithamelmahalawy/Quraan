import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// An arrow at the top of the mushaf, named «الرواة», that can be called at any
/// time. It lets down all the qurra on a ring in depth: as many in the front row
/// as the width holds, bold and marked with their check boxes, and dragging turns
/// it a qari at a time, as far as it goes; the rest by name behind, smaller and fainter the farther
/// back they are. The
/// mushaf grows shorter beneath it and stays whole, as large again once the
/// arrow sends it back up. A check box on a qari ticks his two riwayat; beside
/// each riwaya a second one shows the mushaf in it, one riwaya at a time.
class RiwayatPanel extends StatefulWidget {
  const RiwayatPanel({
    super.key,
    required this.settings,
    required this.variants,
    required this.child,
    this.arrowAt,
    this.open,
    this.tab = false,
    this.beside,
    this.onJam,
    this.onJamSelected,
  });

  /// Opens «الجمع للقراءات العشر» at the page read; no button without it.
  final VoidCallback? onJam;

  /// Opens «جمع الروايات المختارة»: the jam' of the riwayat chosen, Hafs
  /// among them when the mushaf shows him or compares with him.
  final ValueChanged<Set<String>>? onJamSelected;

  /// Where the middle of the page's header is, for the arrow; the middle of the
  /// screen without it.
  final ValueListenable<double?>? arrowAt;

  /// Opened and closed from outside (the reader's top bar), with no arrow of
  /// its own over the page; null: by its arrow.
  final ValueNotifier<bool>? open;

  /// Opened from outside, its arrow over the page all the same: the bar it
  /// is opened from folded away, or in full screen.
  final bool tab;

  /// Beside the arrow, over the page's header.
  final Widget? beside;

  final ReaderSettings settings;
  final VariantRepository variants;

  /// The mushaf.
  final Widget child;

  /// How many qurra the front row holds on a screen so wide.
  @visibleForTesting
  static int frontRowFor(double width) => _RiwayatPanelState.frontRow(width);

  /// As low as a qari and his two riwayat allow, not to shrink the page much.
  static const height = 124.0;

  @override
  State<RiwayatPanel> createState() => _RiwayatPanelState();
}

class _RiwayatPanelState extends State<RiwayatPanel>
    with SingleTickerProviderStateMixin {
  /// The narrowest a qari in the front row may be: his names and two boxes.
  static const _leastCell = 112.0;

  /// How many qurra stand in front on a screen so wide, and how many a turn
  /// brings: as many as the room holds.
  static int frontRow(double width) =>
      ((width - 8) / _leastCell).floor().clamp(1, qiraat.length);

  /// The width of a qari in the front row, by the screen's.
  double _cell = 140;

  /// How many there are in the front row now.
  int _row = 3;

  /// Which qari is in front, between one and the next as the ring turns.
  late final _turn = AnimationController.unbounded(vsync: this);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.open?.addListener(_followOpen);
    _open = widget.open?.value ?? false;
  }

  @override
  void didUpdateWidget(RiwayatPanel old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    old.open?.removeListener(_followOpen);
    widget.open?.addListener(_followOpen);
    _open = widget.open?.value ?? _open;
  }

  /// Opened or closed from outside, as by its arrow.
  void _followOpen() {
    if (widget.open!.value != _open) _toggle();
  }

  @override
  void dispose() {
    widget.open?.removeListener(_followOpen);
    _turn.dispose();
    super.dispose();
  }

  ReaderSettings get s => widget.settings;

  bool _available(String id) => id == hafsId || widget.variants.isAvailable(id);

  bool _chosen(String id) =>
      id == hafsId ? s.compareHafs : s.selected.contains(id);

  /// The ring's order: those with a riwaya chosen together first, to be changed
  /// the more easily, the others after them; each in the catalogue's order.
  List<Qiraa> get _order => [
    for (final q in qiraat)
      if (q.riwayat.any((r) => _available(r.id) && _chosen(r.id))) q,
    for (final q in qiraat)
      if (!q.riwayat.any((r) => _available(r.id) && _chosen(r.id))) q,
  ];

  /// Does [change], which may move qari [q] among those chosen: he stays where
  /// he is under the finger, and the ring moves round him.
  void _keepingInPlace(Qiraa q, VoidCallback change) {
    final before = _order.indexOf(q);
    change();
    final by = _order.indexOf(q) - before;
    if (by != 0) {
      _turn.stop();
      _turn.value += by;
    }
  }

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
      final at = _order.indexWhere((q) => q.riwayat.any((r) => r.id == shown));
      // That qari in the middle of the front row.
      _row = frontRow(context.size?.width ?? 400);
      _turn.value = (math.max(at, 0) - (_row - 1) ~/ 2).toDouble();
    }
    setState(() => _open = !_open);
    widget.open?.value = _open;
  }

  /// The ring dragged: its boxes take no tap until it rests (a finger
  /// turning it, or stopping it, chose the riwaya it came down on).
  bool _dragging = false;

  void _settle(double target) => _turn.animateTo(
    target,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOut,
  );

  /// Brings the qari [i] to the middle of the front, the shorter way round.
  void _bringToFront(int i) {
    final n = qiraat.length;
    var by = (i - (_row - 1) ~/ 2 - _turn.value) % n;
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
      width: _cell,
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
                    : (_) => _keepingInPlace(
                        q,
                        () => _setChosen(ids, chosen < ids.length),
                      ),
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
                    onChanged: (v) => _keepingInPlace(
                      q,
                      () => _setChosen([r.id], v ?? false),
                    ),
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
                    // On or off: the mushaf shown in this riwaya.
                    child: SizedBox(
                      height: 20,
                      child: FittedBox(
                        child: Switch(
                          key: ValueKey('riwaya-show-${r.id}'),
                          value: r.id == hafsId
                              ? s.displayed == null
                              : s.displayed == r.id,
                          activeThumbColor: Colors.white,
                          activeTrackColor: MushafColors.green,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (_) =>
                              _keepingInPlace(q, () => _show(r.id)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  /// A qari elsewhere on the ring: a chip with his name, smaller and fainter the
  /// farther back, with a mark if a riwaya of his is chosen.
  Widget _name(Qiraa q, double near) {
    final chosen = q.riwayat.any((r) => _available(r.id) && _chosen(r.id));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(q.color, Colors.white, .22)!,
            Color.lerp(q.color, Colors.black, .28)!,
          ],
        ),
        border: Border.all(
          color: chosen ? Colors.white : Colors.white.withAlpha(70),
          width: chosen ? 1.2 : .6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 3 + 5 * near,
            offset: Offset(0, 1 + 3 * near),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chosen)
            Icon(Icons.check, size: 9 + 3 * near, color: Colors.white),
          Text(
            q.shortAr,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9 + 3 * near,
              fontWeight: chosen ? FontWeight.bold : FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// The ring: all the qurra at once, the nearest painted last. As many as the
  /// room holds stand in the front row with their check boxes, and a turn brings
  /// as many others; those behind stand on the row above by name. One of them,
  /// tapped, comes to the middle of the front.
  Widget _ring(double width) {
    final n = qiraat.length;
    _row = frontRow(width);
    _cell = math.min((width - 4 - 2 * (_row - 1)) / _row, 170);
    final reach = width / 2 - 28;
    // The middle of the front row, from the first of it.
    final middle = (_row - 1) / 2;
    return GestureDetector(
      key: const ValueKey('riwayat-ring'),
      behavior: HitTestBehavior.opaque,
      // Under the finger, a qari at a time: dragged to the right, those at the
      // left come round to the front, as many as it goes.
      // A finger down on the ring turning: it stops there, and comes to
      // rest on the nearest qari unless dragged on.
      onHorizontalDragDown: (_) {
        if (_turn.isAnimating) _turn.stop();
      },
      onHorizontalDragCancel: () {
        if (_turn.value != _turn.value.roundToDouble()) {
          _settle(_turn.value.roundToDouble());
        }
      },
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (d) => _turn.value += d.delta.dx / (_cell + 2),
      // Coming to rest on a qari, a flick carrying it on by as many as it is quick.
      onHorizontalDragEnd: (d) {
        setState(() => _dragging = false);
        _settle(
          (_turn.value + (d.primaryVelocity ?? 0) / (_cell + 2) * .18)
              .roundToDouble(),
        );
      },
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final order = _order;
          // Each qari's place from the middle of the front: its nearest way.
          final places = [
            for (var i = 0; i < n; i++)
              (i: i, d: ((i - _turn.value - middle + n / 2) % n) - n / 2),
          ]..sort((a, b) => b.d.abs().compareTo(a.d.abs()));
          // Turning, its boxes and switches take no tap: only one meant,
          // the ring at rest, chooses a riwaya.
          return AbsorbPointer(
            absorbing: _dragging || _turn.isAnimating,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The ring they stand on.
                  const Positioned.fill(child: CustomPaint(painter: _Stage())),
                  for (final (:i, :d) in places)
                    () {
                      final isFront = d.abs() <= _row / 2;
                      // 1 next to the front row, 0 at the very back.
                      final near = isFront || _row >= n
                          ? 1.0
                          : (1 - (d.abs() - _row / 2) / (n / 2 - _row / 2))
                                .clamp(0.0, 1.0);
                      // Along the front row, from its middle to its ends: they
                      // curve back, as a part of the ring, and still answer.
                      final along = _row < 2 ? 0.0 : d / (_row / 2);
                      return Transform.translate(
                        // The next qari at the left, as the text runs.
                        offset: isFront
                            ? Offset(-d * (_cell + 2), 12 - 14 * along * along)
                            : Offset(-d.sign * reach * near, -44 + 8 * near),
                        child: Opacity(
                          opacity: isFront ? 1 : .35 + .6 * near,
                          child: GestureDetector(
                            key: ValueKey('qari-cell-${order[i].id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: isFront ? null : () => _bringToFront(i),
                            child: isFront
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .0012)
                                      ..rotateY(-along * .5)
                                      ..scaleByDouble(
                                        1 - .14 * along * along,
                                        1 - .14 * along * along,
                                        1,
                                        1,
                                      ),
                                    child: _qari(order[i], front: true),
                                  )
                                : Transform(
                                    alignment: Alignment.center,
                                    // In perspective, turned as the ring turns.
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .004)
                                      ..rotateY(-d.sign * .6 * near)
                                      ..rotateX(-.25 * (1 - near)),
                                    child: _name(order[i], near),
                                  ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _panel() => Material(
    key: const ValueKey('riwayat-panel'),
    color: const Color(0xFF0B1F18),
    elevation: 6,
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
                    '  اسحب لتحريك القراء • المربع الأيسر لعرض المصحف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withAlpha(170),
                    ),
                  ),
                ),
                if (widget.onJam != null)
                  InkWell(
                    key: const ValueKey('riwayat-jam'),
                    onTap: widget.onJam,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: MushafColors.gold.withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MushafColors.gold),
                      ),
                      child: const Text(
                        'أجمع العشر',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (widget.onJamSelected != null)
                  Builder(
                    builder: (context) {
                      final chosen = {
                        ...s.selected,
                        if (s.displayed == null || s.compareHafs) hafsId,
                      };
                      final enabled = chosen.length >= 2;
                      return InkWell(
                        key: const ValueKey('riwayat-jam-selected'),
                        onTap: enabled
                            ? () => widget.onJamSelected!(chosen)
                            : null,
                        child: Opacity(
                          opacity: enabled ? 1 : .45,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: MushafColors.green.withAlpha(90),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MushafColors.gold),
                            ),
                            child: const Text(
                              'أجمع المختار من الروايات',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
                          color: Colors.white.withAlpha(220),
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
    // A button, no arrow: tapped, the ring down; again, up (the user,
    // 2026-11-13). Gold while it is down, light while up.
    child: Material(
      color: _open ? MushafColors.gold : MushafColors.goldLight,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: const ValueKey('riwayat-panel-toggle'),
        borderRadius: BorderRadius.circular(10),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 3),
          child: Text(
            'الرواة',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: MushafColors.green,
            ),
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
          child: LayoutBuilder(
            builder: (context, box) {
              if (widget.open != null && !widget.tab) return widget.child;
              Widget placed(double? at) => Stack(
                children: [
                  Positioned.fill(child: widget.child),
                  // Over the middle of the page's header, between its surah and
                  // its juz.
                  Positioned(
                    left: at ?? box.maxWidth / 2,
                    top: 0,
                    child: FractionalTranslation(
                      translation: const Offset(-.5, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _arrow(),
                          if (widget.beside case final beside?) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: beside,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
              final arrowAt = widget.arrowAt;
              return arrowAt == null
                  ? placed(null)
                  : ValueListenableBuilder(
                      valueListenable: arrowAt,
                      builder: (context, at, _) => placed(at),
                    );
            },
          ),
        ),
      ],
    ),
  );
}

/// The stage of the ring: a glow beneath, and the ellipse the qurra stand on.
class _Stage extends CustomPainter {
  const _Stage();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, .35),
          radius: 1.1,
          colors: [Color(0xFF2E7D5B), Color(0xFF123427), Color(0xFF0B1F18)],
          stops: [0, .55, 1],
        ).createShader(rect),
    );
    final center = size.center(const Offset(0, -6));
    for (final (grow, alpha) in [(1.0, 90), (.82, 45), (.64, 25)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: (size.width - 30) * grow,
          height: (size.height - 16) * grow,
        ),
        Paint()
          ..color = Colors.white.withAlpha(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_Stage old) => false;
}
