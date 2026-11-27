import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// The place of a word on the page, carried by its widget for the lamp to
/// find under its light.
class WordTag {
  const WordTag(this.ayah, this.word);

  final Ayah ayah;
  final int word;

  @override
  bool operator ==(Object other) =>
      other is WordTag &&
      other.ayah.surah == ayah.surah &&
      other.ayah.number == ayah.number &&
      other.word == word;

  @override
  int get hashCode => Object.hash(ayah.surah, ayah.number, word);
}

/// The lamp of «تنبيه الاختلافات» laid on the mushaf, its light pointing up,
/// dragged over the page as «الكشاف» was, which it took the place of (the
/// user, 2026-11-27): its light on a word told otherwise shows at once,
/// above the word, the page's own usul and hamesh of it, its readers grouped
/// as there. A tap lights the words that differ, or puts them out; held, it
/// opens its settings: the usul it lights and the ways it tells a word.
class Lamp extends StatefulWidget {
  const Lamp({
    super.key,
    required this.settings,
    required this.panelFor,
    required this.onTap,
    required this.onLongPress,
  });

  final ReaderSettings settings;

  /// A tap: the glow of the words that differ, on or off.
  final VoidCallback onTap;

  /// Held: its settings.
  final VoidCallback onLongPress;

  /// The panel of word [word] of [ayah]; null where nothing is told of it.
  final Widget? Function(Ayah ayah, int word) panelFor;

  /// The lamp's body and its light above it.
  static const width = 34.0;
  static const bodyHeight = 34.0;
  static const beamHeight = 22.0;
  static const height = bodyHeight + beamHeight;

  @override
  State<Lamp> createState() => _LampState();
}

class _LampState extends State<Lamp> {
  /// Its place over the area, in fractions of its width and height.
  /// At first at the page's top (the user, 2026-11-27).
  late Offset _at = widget.settings.flashlightAt ?? const Offset(.04, 0);

  /// The word under the beam's tip, its panel and its box in the area.
  WordTag? _tag;
  Widget? _panel;

  /// Being dragged: the panel lets the beam through to the words beneath.
  bool _dragging = false;
  Rect? _wordRect;

  /// The beam's tip: the top of its light, over the middle of the body.
  Offset _tip(Size area) =>
      Offset(_at.dx * area.width + Lamp.width / 2, _at.dy * area.height);

  /// The beam's light over the area: its cone's box.
  Rect _beam(Size area) {
    final tip = _tip(area);
    return Rect.fromLTWH(
      tip.dx - Lamp.width / 2,
      tip.dy,
      Lamp.width,
      Lamp.beamHeight,
    );
  }

  /// The word any part of the beam touches, its top first (the user,
  /// 2026-11-26): the whole light down to the lens, across its width as it
  /// narrows, the middle first. The beam lets the touch through to the words
  /// (it took the probe for itself, the words under it unseen).
  (WordTag, Rect)? _touched(RenderBox box, Size area) {
    final tip = _tip(area);
    const across = [0.0, -.15, .15, -.3, .3, -.45, .45];
    for (var dy = 0.0; dy <= Lamp.beamHeight; dy += 3) {
      // The cone from the full width at its top to .4 of it at the lens.
      final half = .5 - .3 * dy / Lamp.beamHeight;
      for (final f in across) {
        if (f.abs() > half) continue;
        final dx = f;
        final result = HitTestResult();
        WidgetsBinding.instance.hitTestInView(
          result,
          box.localToGlobal(tip + Offset(dx * Lamp.width, dy)),
          View.of(context).viewId,
        );
        for (final entry in result.path) {
          final target = entry.target;
          if (target is RenderMetaData && target.metaData is WordTag) {
            return (
              target.metaData as WordTag,
              box.globalToLocal(target.localToGlobal(Offset.zero)) &
                  target.size,
            );
          }
        }
      }
    }
    return null;
  }

  /// The panel of the word touched alone: put away as soon as the beam leaves
  /// it, shown again only on a word told of in the hamesh or the usul (the
  /// user, 2026-11-26).
  void _probe(Size area) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final touched = _touched(box, area);
    if (touched == null) {
      // Kept while the light is still on the word (between its letters).
      final lit = _wordRect;
      if (lit != null && _beam(area).overlaps(lit)) return;
      if (_tag != null) {
        setState(() {
          _tag = null;
          _panel = null;
          _wordRect = null;
        });
      }
      return;
    }
    final (tag, rect) = touched;
    if (tag == _tag) {
      if (rect != _wordRect) setState(() => _wordRect = rect);
      return;
    }
    final panel = widget.panelFor(tag.ayah, tag.word);
    setState(() {
      _tag = tag;
      _wordRect = rect;
      _panel = panel;
    });
  }

  /// A mode chosen in its settings: the word lit told again by it.
  FlashMode? _mode;

  void _settingsChanged() {
    final mode = widget.settings.flashMode;
    if (mode == _mode) return;
    _mode = mode;
    final tag = _tag;
    if (tag == null || !mounted) return;
    setState(() {
      _panel = widget.panelFor(tag.ayah, tag.word);
      if (_panel == null) {
        _tag = null;
        _wordRect = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.settings.flashMode;
    widget.settings.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final area = constraints.biggest;
      final maxX = (area.width - Lamp.width) / area.width;
      final maxY = (area.height - Lamp.height) / area.height;
      final at = Offset(_at.dx.clamp(0.0, maxX), _at.dy.clamp(0.0, maxY));
      final lit = _panel != null;
      final rect = _wordRect;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (lit && rect != null)
            _panelOver(area, rect, (at.dy * area.height) + Lamp.height),
          // The light drawn, the touch through it to the words beneath.
          Positioned(
            left: at.dx * area.width,
            top: at.dy * area.height,
            child: IgnorePointer(
              child: SizedBox(
                width: Lamp.width,
                height: Lamp.height,
                child: ListenableBuilder(
                  listenable: widget.settings,
                  builder: (context, _) => CustomPaint(
                    key: widget.settings.diffAlert != null
                        ? const ValueKey('glow-rays')
                        : null,
                    painter: _Beam(
                      lit: lit,
                      glowing: widget.settings.diffAlert != null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The body held and dragged.
          Positioned(
            left: at.dx * area.width,
            top: at.dy * area.height + Lamp.beamHeight,
            child: GestureDetector(
              key: const ValueKey('glow-lamp'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                setState(() {
                  _at = Offset(
                    ((_at.dx * area.width + d.delta.dx) / area.width).clamp(
                      0.0,
                      maxX,
                    ),
                    ((_at.dy * area.height + d.delta.dy) / area.height).clamp(
                      0.0,
                      maxY,
                    ),
                  );
                });
                _probe(area);
              },
              onPanStart: (_) => setState(() => _dragging = true),
              onPanEnd: (_) {
                setState(() => _dragging = false);
                widget.settings.flashlightAt = _at;
              },
              onPanCancel: () => setState(() => _dragging = false),
              // Held: its settings, the usul on the right, the ways on the
              // left (the user, 2026-11-27).
              onLongPress: widget.onLongPress,
              // A tap: the glow on or off, the panel put away.
              onTap: () {
                setState(() {
                  _tag = null;
                  _panel = null;
                  _wordRect = null;
                });
                widget.onTap();
              },
              child: Tooltip(
                triggerMode: TooltipTriggerMode.manual,
                message: 'المصباح: اسحبه حتى يقع ضوؤه على كلمة',
                child: const SizedBox(
                  width: Lamp.width,
                  height: Lamp.bodyHeight,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  /// The panel right above the word (under it, where the page's top leaves
  /// no room, and below the lamp then), across most of the page, the
  /// words beneath covered.
  Widget _panelOver(Size area, Rect word, double lampBottom) {
    final width = area.width * .94;
    final left = (word.center.dx - width / 2)
        .clamp(4.0, area.width - width - 4)
        .toDouble();
    final above = word.top > area.height * .4;
    return Positioned(
      key: const ValueKey('lamp-panel'),
      left: left,
      width: width,
      // Under the lamp, not over it.
      top: above
          ? null
          : (lampBottom > word.bottom ? lampBottom : word.bottom) + 4,
      bottom: above ? area.height - word.top + 4 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: area.height * .5),
        child: IgnorePointer(
          ignoring: _dragging,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MushafColors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MushafColors.gold, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: _panel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lamp: a bulb on its base below, its light widening up to the tip,
/// bright when it lights a word; its rays round the bulb while the words
/// that differ glow.
class _Beam extends CustomPainter {
  _Beam({required this.lit, required this.glowing});

  /// On a word told of.
  final bool lit;

  /// «تنبيه الاختلافات» on.
  final bool glowing;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, beam = Lamp.beamHeight;
    final light = MushafColors.gold;
    final bulb = Offset(w / 2, beam + 12);
    const r = 9.0;
    // The light: from the bulb up, widening to the tip's edge.
    final cone = Path()
      ..moveTo(w * .30, beam + 4)
      ..lineTo(w * .70, beam + 4)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            light.withAlpha(lit ? 150 : 110),
            light.withAlpha(lit ? 50 : 25),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, beam)),
    );
    // The tip, a thin line where the light touches the word.
    canvas.drawLine(
      Offset(w * .15, 1),
      Offset(w * .85, 1),
      Paint()
        ..color = light.withAlpha(255)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // The body at 70%, the verse read through its light (as the
    // flashlight's, the user, 2026-11-26).
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = const Color.fromRGBO(0, 0, 0, .7),
    );
    final ink = MushafColors.green;
    // Its rays while the words glow, still, not flickering.
    if (glowing) {
      final ray = Paint()
        ..color = light
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final deg in [-150, -110, -70, -30, 10, 170]) {
        final a = deg * 3.14159265 / 180;
        final d = Offset(_cos(a), _sin(a));
        canvas.drawLine(bulb + d * (r + 2), bulb + d * (r + 5), ray);
      }
    }
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    // The base: two bands under the bulb, and its tip.
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(w / 2 - 5, bulb.dy + r - 1, 10, 8),
      const Radius.circular(2),
    );
    canvas.drawCircle(bulb + const Offset(0, 1), r, shadow);
    canvas.drawRRect(base.shift(const Offset(0, 1)), shadow);
    final edge = Paint()
      ..color = glowing ? ink : light
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(bulb, r, Paint()..color = glowing ? light : ink);
    canvas.drawCircle(bulb, r, edge);
    canvas.drawRRect(base, Paint()..color = ink);
    canvas.drawRRect(
      base,
      Paint()
        ..color = light
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(w / 2 - 5, bulb.dy + r + 3),
      Offset(w / 2 + 5, bulb.dy + r + 3),
      Paint()
        ..color = light
        ..strokeWidth = 1,
    );
    // The filament.
    canvas.drawPath(
      Path()
        ..moveTo(bulb.dx - 3, bulb.dy + 3)
        ..lineTo(bulb.dx - 3, bulb.dy - 1)
        ..lineTo(bulb.dx, bulb.dy + 1)
        ..lineTo(bulb.dx + 3, bulb.dy - 1)
        ..lineTo(bulb.dx + 3, bulb.dy + 3),
      Paint()
        ..color = glowing ? ink : (lit ? light : MushafColors.paper)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  static double _cos(double a) => math.cos(a);
  static double _sin(double a) => math.sin(a);

  @override
  bool shouldRepaint(_Beam old) => old.lit != lit || old.glowing != glowing;
}
