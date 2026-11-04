import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'mushaf_page.dart' show MarginRule, PageCover;
import 'theme.dart';

/// An arrow at the right of the screen, named «الرواة», that can be called at
/// any time. It opens a narrow list over the hamesh at the page's right, never
/// over the mushaf: wider than the hamesh, the mushaf grows smaller by the rest
/// and stays whole, as large again once it is closed. The arrow stays, at the
/// list's edge, pointing in to close it. A check box on a qari ticks his two
/// riwayat; beside each riwaya a second one shows the mushaf in it, one riwaya
/// at a time.
class RiwayatPanel extends StatefulWidget {
  const RiwayatPanel({
    super.key,
    required this.settings,
    required this.variants,
    required this.child,
    this.rightMargin,
  });

  final ReaderSettings settings;
  final VariantRepository variants;

  /// The mushaf.
  final Widget child;

  /// The hamesh at the page's right, that the list may cover.
  final ValueListenable<MarginRule?>? rightMargin;

  /// As narrow as the names, two check boxes and the arrow allow, not to shrink
  /// the page.
  static const width = 136.0;

  /// The mushaf's width with the list open on a screen [total] wide: the list
  /// covers the hamesh, and what it wants more comes off the mushaf. The hamesh
  /// grows narrower with the page, so the two are settled together.
  static double pageWidth(double total, MarginRule? rule) {
    var page = total - width;
    if (rule == null) return page;
    for (var i = 0; i < 12; i++) {
      final margin = (page * rule.share).clamp(rule.least, rule.most);
      page = math.min(total, total - width + margin);
    }
    return page;
  }

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

  Widget _list() => Container(
    key: const ValueKey('riwayat-panel'),
    width: RiwayatPanel.width,
    color: MushafColors.page,
    child: Row(
      // The arrow on the side of the mushaf, whatever the text's direction.
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _arrow(open: true)),
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
  Widget _arrow({required bool open}) => Semantics(
    button: true,
    expanded: open,
    label: open ? 'إخفاء الرواة' : 'إظهار الرواة',
    child: Material(
      color: MushafColors.goldLight,
      elevation: 3,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
      child: InkWell(
        key: ValueKey(open ? 'riwayat-panel-close' : 'riwayat-panel-open'),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
        onTap: () => setState(() => _open = !open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(12, 18),
                painter: _Chevron(MushafColors.green, pointsRight: open),
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
        final margin = widget.rightMargin;
        Widget laidOut(MarginRule? rule) {
          final page = _open
              ? RiwayatPanel.pageWidth(box.maxWidth, rule)
              : box.maxWidth;
          return Stack(
            children: [
              // The mushaf at the left: only what the list leaves it.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: page,
                child: PageCover(
                  right: _open
                      ? math.max(0.0, page - box.maxWidth + RiwayatPanel.width)
                      : 0,
                  child: widget.child,
                ),
              ),
              if (_open)
                Positioned(right: 0, top: 0, bottom: 0, child: _list())
              else
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _arrow(open: false)),
                ),
            ],
          );
        }

        return margin == null
            ? laidOut(null)
            : ValueListenableBuilder(
                valueListenable: margin,
                builder: (context, rule, _) => laidOut(rule),
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
