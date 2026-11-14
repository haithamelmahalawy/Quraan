import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/reader_settings.dart';
import 'mushaf_decor.dart';
import 'theme.dart';

/// «شكل المصحف»: the looks of the mushaf on a ring over the page, turned in
/// 3D as the qurra's and as close; a look touched is put on the mushaf at
/// once, the page in sight below it, to see it and go on to another (the
/// user, 2026-11-14). In one row: the looks for all, then the men's, the
/// girls', the children's.
class MushafStyleRing extends StatefulWidget {
  const MushafStyleRing({super.key, required this.settings});

  final ReaderSettings settings;

  /// The ring's height over the page.
  static const height = 132.0;

  /// The looks in the ring's order: for all, then men, girls, children.
  static final looks = [
    for (final audience in const [
      MushafAudience.all,
      MushafAudience.men,
      MushafAudience.girls,
      MushafAudience.kids,
    ])
      for (final look in MushafStyle.values)
        if (look.audience == audience) look,
  ];

  @override
  State<MushafStyleRing> createState() => _MushafStyleRingState();
}

class _MushafStyleRingState extends State<MushafStyleRing>
    with SingleTickerProviderStateMixin {
  List<MushafStyle> get _looks => MushafStyleRing.looks;

  /// The ring's turn, in looks: the one at [_turn] in front.
  late final _turn = AnimationController.unbounded(
    vsync: this,
    value: math
        .max(0, _looks.indexOf(MushafStyle.named(widget.settings.mushafStyle)))
        .toDouble(),
  );

  /// A look's place apart from the next, as the qurra's.
  static const _cell = 58.0;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _settle(double to) => _turn.animateTo(
    to,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  /// Look [i] put on the mushaf at once, and brought to the front.
  void _take(int i) {
    widget.settings.mushafStyle = _looks[i].name;
    final n = _looks.length;
    var by = (i - _turn.value) % n;
    if (by > n / 2) by -= n;
    _settle((_turn.value + by).roundToDouble());
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('mushaf-style-ring'),
    color: const Color(0xFF0B1F18),
    elevation: 6,
    child: SizedBox(
      width: double.infinity,
      height: MushafStyleRing.height,
      child: LayoutBuilder(builder: (_, box) => _ring(box)),
    ),
  );

  Widget _ring(BoxConstraints box) {
    final looks = _looks;
    final n = looks.length;
    // Neighbours a cell apart at the front, as the qurra stand.
    final reach = _cell / math.sin(2 * math.pi / n);
    final current = MushafStyle.named(widget.settings.mushafStyle);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragDown: (_) => _turn.stop(),
      onHorizontalDragUpdate: (d) => _turn.value -= d.delta.dx / _cell,
      onHorizontalDragEnd: (d) => _settle(
        (_turn.value - (d.primaryVelocity ?? 0) / _cell * .18).roundToDouble(),
      ),
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          // Each look's angle from the front, its nearest way round; the
          // nearest painted last.
          final placed = [
            for (var i = 0; i < n; i++)
              (
                i: i,
                angle:
                    (((i - _turn.value + n / 2) % n) - n / 2) * 2 * math.pi / n,
              ),
          ]..sort((a, b) => math.cos(a.angle).compareTo(math.cos(b.angle)));
          return SizedBox.expand(
            child: ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _Stage())),
                  for (final (:i, :angle) in placed)
                    if (math.cos(angle) > 0 &&
                        (math.sin(angle) * reach).abs() < box.maxWidth / 2 + 40)
                      () {
                        final near = math.cos(angle);
                        return Transform.translate(
                          // The next look at the left, as the text runs.
                          offset: Offset(
                            -math.sin(angle) * reach,
                            8 - 10 * (1 - near),
                          ),
                          child: Opacity(
                            opacity: .45 + .55 * near,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .002)
                                ..rotateY(angle * .8)
                                ..scaleByDouble(
                                  .7 + .3 * near,
                                  .7 + .3 * near,
                                  1,
                                  1,
                                ),
                              child: GestureDetector(
                                key: ValueKey('mushaf-style-${looks[i].name}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _take(i),
                                child: _card(looks[i], looks[i] == current),
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

  /// A look: a small page in its frame and colours, and its name.
  Widget _card(MushafStyle look, bool chosen) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 52,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: chosen ? MushafColors.gold : Colors.white24,
            width: chosen ? 2.2 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          // The page drawn at its size, made small: the frame as it is.
          child: FittedBox(
            child: Container(
              width: 118,
              height: 158,
              color: look.paper,
              padding: const EdgeInsets.all(4),
              child: OrnamentFrame(
                style: look,
                child: Center(
                  child: Text(
                    'بِسۡمِ ٱللَّهِ\nٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Hafs',
                      fontSize: 11,
                      height: 1.6,
                      // The darker of the frame's colours: read on the page.
                      color:
                          look.motif.computeLuminance() <
                              look.band.computeLuminance()
                          ? look.motif
                          : look.band,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        look.nameAr,
        maxLines: 1,
        style: TextStyle(
          color: chosen ? MushafColors.goldLight : Colors.white,
          fontSize: 10,
          fontWeight: chosen ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ],
  );
}

/// The stage of the ring: a glow beneath, and the ellipse they stand on, as
/// the qurra's.
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
    final center = size.center(const Offset(0, 22));
    for (final (grow, alpha) in [(1.0, 90), (.82, 45), (.64, 25)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: (size.width - 30) * grow,
          height: 46 * grow,
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
