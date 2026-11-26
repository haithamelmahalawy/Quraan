import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// The place of a word on the page, carried by its widget for «الكشاف» to
/// find under its beam.
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

/// «الكشاف»: a flashlight laid on the mushaf, its beam pointing up, dragged
/// over the page; the beam's tip on a word told otherwise shows at once,
/// above the word, the page's own usul and hamesh of it, its readers grouped
/// as there (the user, 2026-11-26).
class Flashlight extends StatefulWidget {
  const Flashlight({super.key, required this.settings, required this.panelFor});

  final ReaderSettings settings;

  /// The panel of word [word] of [ayah]; null where nothing is told of it.
  final Widget? Function(Ayah ayah, int word) panelFor;

  /// The flashlight's body and its beam above it.
  static const width = 34.0;
  static const bodyHeight = 34.0;
  static const beamHeight = 22.0;
  static const height = bodyHeight + beamHeight;

  @override
  State<Flashlight> createState() => _FlashlightState();
}

class _FlashlightState extends State<Flashlight> {
  /// Its place over the area, in fractions of its width and height.
  late Offset _at = widget.settings.flashlightAt ?? const Offset(.04, .86);

  /// The word under the beam's tip, its panel and its box in the area.
  WordTag? _tag;
  Widget? _panel;

  /// Being dragged: the panel lets the beam through to the words beneath.
  bool _dragging = false;
  Rect? _wordRect;

  /// The beam's tip: the top of its light, over the middle of the body.
  Offset _tip(Size area) =>
      Offset(_at.dx * area.width + Flashlight.width / 2, _at.dy * area.height);

  /// The word any part of the beam's top touches (the user, 2026-11-26):
  /// its edge and a little below it, across its width, the middle first.
  (WordTag, Rect)? _touched(RenderBox box, Size area) {
    final tip = _tip(area);
    const across = [0.0, -.25, .25, -.45, .45];
    const down = [0.0, 4.0, 8.0];
    for (final dy in down) {
      for (final dx in across) {
        final result = HitTestResult();
        WidgetsBinding.instance.hitTestInView(
          result,
          box.localToGlobal(tip + Offset(dx * Flashlight.width, dy)),
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final area = constraints.biggest;
      final maxX = (area.width - Flashlight.width) / area.width;
      final maxY = (area.height - Flashlight.height) / area.height;
      final at = Offset(_at.dx.clamp(0.0, maxX), _at.dy.clamp(0.0, maxY));
      final lit = _panel != null;
      final rect = _wordRect;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (lit && rect != null)
            _panelOver(area, rect, (at.dy * area.height) + Flashlight.height),
          Positioned(
            left: at.dx * area.width,
            top: at.dy * area.height,
            child: GestureDetector(
              key: const ValueKey('flashlight'),
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
              // Held: what it tells, the chosen one marked (the user,
              // 2026-11-26).
              onLongPressStart: (d) => _chooseMode(d.globalPosition),
              // A tap puts the panel away.
              onTap: () => setState(() {
                _tag = null;
                _panel = null;
                _wordRect = null;
              }),
              child: Tooltip(
                triggerMode: TooltipTriggerMode.manual,
                message: 'الكشاف: اسحبه حتى يلمس شعاعه كلمة',
                child: SizedBox(
                  width: Flashlight.width,
                  height: Flashlight.height,
                  child: CustomPaint(painter: _Beam(lit: lit)),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _chooseMode(Offset at) async {
    final now = widget.settings.flashMode;
    final picked = await showMenu<FlashMode>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy - 160, at.dx, at.dy),
      color: MushafColors.paper,
      // A thin gold edge, as the panel's.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: MushafColors.gold, width: 1.2),
      ),
      items: [
        for (final mode in FlashMode.values)
          CheckedPopupMenuItem(
            key: ValueKey('flash-mode:${mode.name}'),
            value: mode,
            checked: mode == now,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mode.labelAr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: MushafColors.green,
                  ),
                ),
                Text(mode.hintAr, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
    if (picked == null || picked == now || !mounted) return;
    widget.settings.flashMode = picked;
    // The word lit told again by the new mode.
    final tag = _tag;
    setState(() {
      _panel = tag == null ? null : widget.panelFor(tag.ayah, tag.word);
      if (_panel == null) {
        _tag = null;
        _wordRect = null;
      }
    });
  }

  /// The panel right above the word (under it, where the page's top leaves
  /// no room, and below the flashlight then), across most of the page, the
  /// words beneath covered.
  Widget _panelOver(Size area, Rect word, double lampBottom) {
    final width = area.width * .94;
    final left = (word.center.dx - width / 2)
        .clamp(4.0, area.width - width - 4)
        .toDouble();
    final above = word.top > area.height * .4;
    return Positioned(
      key: const ValueKey('flashlight-panel'),
      left: left,
      width: width,
      // Under the flashlight, not over it.
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

/// The flashlight: a body below and its beam widening up to its tip, bright
/// when it lights a word.
class _Beam extends CustomPainter {
  _Beam({required this.lit});

  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, beam = Flashlight.beamHeight;
    final light = MushafColors.gold;
    // The beam: from the lens up, widening to the tip's edge.
    final cone = Path()
      ..moveTo(w * .30, beam)
      ..lineTo(w * .70, beam)
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
    // The body: the head holding the lens, then the handle.
    // Solid, to be seen on the page; its beam light, the verse read through
    // it (the user, 2026-11-26).
    final ink = MushafColors.green;
    final head = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * .18, beam, w * .64, 10),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .32, beam + 10, w * .36, Flashlight.bodyHeight - 12),
      const Radius.circular(3),
    );
    // The whole body at 70% (the user, 2026-11-26): its shadow, edge and
    // switch with it.
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = const Color.fromRGBO(0, 0, 0, .7),
    );
    // A soft shadow under it, then a thin gold edge, clear on the page.
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(head.shift(const Offset(0, 1)), shadow);
    canvas.drawRRect(handle.shift(const Offset(0, 1)), shadow);
    final edge = Paint()
      ..color = light
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final part in [head, handle]) {
      canvas.drawRRect(part, Paint()..color = ink);
      canvas.drawRRect(part, edge);
    }
    // Its switch.
    canvas.drawCircle(
      Offset(w / 2, beam + 18),
      2.5,
      Paint()..color = lit ? light : MushafColors.paper,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Beam old) => old.lit != lit;
}
