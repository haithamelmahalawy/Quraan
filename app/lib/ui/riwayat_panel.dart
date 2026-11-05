import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// An arrow across from the page's hamesh, or at the right of the screen on a
/// page with none, named «الرواة», that can be called at any time. It opens a
/// narrow list on that side, and the mushaf and its hamesh grow smaller beside
/// it, both still in sight, and as large again once it is closed. The arrow
/// stays, at the list's edge, pointing in to close it. A check box on a qari ticks his two
/// riwayat; beside each riwaya a second one shows the mushaf in it, one riwaya
/// at a time.
class RiwayatPanel extends StatefulWidget {
  const RiwayatPanel({
    super.key,
    required this.settings,
    required this.variants,
    required this.child,
    this.marginSide,
  });

  final ReaderSettings settings;
  final VariantRepository variants;

  /// The mushaf.
  final Widget child;

  /// The side of the page's hamesh: at its right or not; null with none.
  final ValueListenable<bool?>? marginSide;

  /// As narrow as the names, two check boxes and the arrow allow, not to shrink
  /// the page much.
  static const width = 136.0;

  @override
  State<RiwayatPanel> createState() => _RiwayatPanelState();
}

class _RiwayatPanelState extends State<RiwayatPanel> {
  bool _open = false;

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

  Widget _qari(Qiraa q) {
    final ids = [
      for (final r in q.riwayat)
        if (_available(r.id)) r.id,
    ];
    final chosen = ids.where(_chosen).length;
    return Column(
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
                    style: TextStyle(fontSize: 11, color: MushafColors.ink),
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
        Divider(height: 5, color: MushafColors.gold.withAlpha(140)),
      ],
    );
  }

  Widget _list({required bool atRight}) => Container(
    key: const ValueKey('riwayat-panel'),
    width: RiwayatPanel.width,
    color: MushafColors.page,
    child: Row(
      // The arrow on the side of the mushaf, whatever the text's direction.
      textDirection: atRight ? TextDirection.ltr : TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _arrow(open: true, atRight: atRight)),
        Expanded(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _names(),
          ),
        ),
      ],
    ),
  );

  Widget _names() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          'المربع الأيسر لعرض المصحف',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: MushafColors.frame),
        ),
      ),
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            for (final q in qiraat) _qari(q),
            if (s.selected.isNotEmpty || s.compareHafs)
              TextButton(
                key: const ValueKey('riwayat-clear'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  s.setSelected({});
                  s.compareHafs = false;
                  s.displayed = null;
                },
                child: const Text(
                  'إلغاء الكل (حفص فقط)',
                  style: TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  /// The arrow: at the screen's edge pointing in to open the list, then at the
  /// list's edge pointing back to close it.
  Widget _arrow({required bool open, required bool atRight}) => Semantics(
    button: true,
    expanded: open,
    label: open ? 'إخفاء الرواة' : 'إظهار الرواة',
    child: Material(
      color: MushafColors.goldLight,
      elevation: 3,
      borderRadius: BorderRadius.horizontal(
        left: atRight ? const Radius.circular(10) : Radius.zero,
        right: atRight ? Radius.zero : const Radius.circular(10),
      ),
      child: InkWell(
        key: ValueKey(open ? 'riwayat-panel-close' : 'riwayat-panel-open'),
        borderRadius: BorderRadius.horizontal(
          left: atRight ? const Radius.circular(10) : Radius.zero,
          right: atRight ? Radius.zero : const Radius.circular(10),
        ),
        onTap: () => setState(() => _open = !open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(12, 18),
                painter: _Chevron(
                  MushafColors.green,
                  pointsRight: open == atRight,
                ),
              ),
              const SizedBox(height: 4),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'الرواة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: MushafColors.green,
                  ),
                ),
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
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final side = widget.marginSide;
        Widget laidOut(bool? marginAtRight) {
          // Across from the hamesh; with none, at the right.
          final atRight = !(marginAtRight ?? false);
          final page = _open ? box.maxWidth - RiwayatPanel.width : box.maxWidth;
          return Stack(
            children: [
              // The mushaf on the other side: only what the list leaves it.
              Positioned(
                left: atRight ? 0 : null,
                right: atRight ? null : 0,
                top: 0,
                bottom: 0,
                width: page,
                child: widget.child,
              ),
              if (_open)
                Positioned(
                  left: atRight ? null : 0,
                  right: atRight ? 0 : null,
                  top: 0,
                  bottom: 0,
                  child: _list(atRight: atRight),
                )
              else
                Positioned(
                  left: atRight ? null : 0,
                  right: atRight ? 0 : null,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _arrow(open: false, atRight: atRight)),
                ),
            ],
          );
        }

        return side == null
            ? laidOut(null)
            : ValueListenableBuilder(
                valueListenable: side,
                builder: (context, atRight, _) => laidOut(atRight),
              );
      },
    ),
  );
}

/// An arrow head, drawn: no font to be missing.
class _Chevron extends CustomPainter {
  const _Chevron(this.color, {required this.pointsRight});

  final Color color;
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final (near, far) = pointsRight
        ? (size.width * .2, size.width * .8)
        : (size.width * .8, size.width * .2);
    canvas.drawPath(
      Path()
        ..moveTo(near, size.height * .1)
        ..lineTo(far, size.height / 2)
        ..lineTo(near, size.height * .9),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Chevron old) =>
      color != old.color || pointsRight != old.pointsRight;
}
