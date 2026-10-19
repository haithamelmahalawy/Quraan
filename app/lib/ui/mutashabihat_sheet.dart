import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import 'theme.dart';

/// The places of a mutashabih on frosted glass: a bubble diagram of all
/// places around the shared phrase, and a card per place to swipe through.
class MutashabihatSheet extends StatefulWidget {
  const MutashabihatSheet({
    super.key,
    required this.places,
    required this.quran,
    required this.onGo,
    this.steps,
  });

  final List<MutashabihPlace> places;
  final QuranRepository quran;

  /// Opens the mushaf at a page.
  final ValueChanged<int> onGo;

  /// Moves between places: +1 next, -1 previous (eye gestures).
  final Stream<int>? steps;

  static Future<void> show(
    BuildContext context, {
    required List<MutashabihPlace> places,
    required QuranRepository quran,
    required ValueChanged<int> onGo,
    Stream<int>? steps,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withAlpha(60),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.88,
          child: MutashabihatSheet(
            places: places,
            quran: quran,
            onGo: onGo,
            steps: steps,
          ),
        ),
      );

  @override
  State<MutashabihatSheet> createState() => _MutashabihatSheetState();
}

class _MutashabihatSheetState extends State<MutashabihatSheet>
    with SingleTickerProviderStateMixin {
  final _pages = PageController(viewportFraction: 0.86);

  /// Drives the floating of the bubbles.
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();
  int _index = 0;

  StreamSubscription<int>? _steps;

  @override
  void initState() {
    super.initState();
    _steps = widget.steps?.listen(_step);
  }

  @override
  void dispose() {
    _steps?.cancel();
    _pages.dispose();
    _float.dispose();
    super.dispose();
  }

  void _step(int by) {
    final n = widget.places.length;
    _goTo(((_index + by) % n + n) % n);
  }

  void _goTo(int i) {
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  int _pageOf(MutashabihPlace p) => widget.quran.pageOf(p.surah, p.ayah);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.places.length;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MushafColors.paper.withAlpha(170),
                MushafColors.paper.withAlpha(215),
              ],
            ),
            border: Border(
              top: BorderSide(color: MushafColors.gold.withAlpha(150)),
            ),
          ),
          child: Stack(
            children: [
              // Decorative bubbles drifting up behind everything.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (context, _) => CustomPaint(
                      painter: _DriftingBubbles(_float.value),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MushafColors.ink.withAlpha(90),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Text('المتشابهات اللفظية',
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: MushafColors.green,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('$count مواضع',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: MushafColors.frame)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 210,
                    child: AnimatedBuilder(
                      animation: _float,
                      builder: (context, _) => _BubbleDiagram(
                        places: widget.places,
                        quran: widget.quran,
                        selected: _index,
                        phase: _float.value,
                        onTap: _goTo,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      physics: const BouncingScrollPhysics(),
                      itemCount: count,
                      onPageChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
                      itemBuilder: (context, i) => AnimatedBuilder(
                        animation: _pages,
                        builder: (context, child) {
                          final page = _pages.hasClients &&
                                  _pages.position.haveDimensions
                              ? _pages.page!
                              : _index.toDouble();
                          final d = (page - i).abs().clamp(0.0, 1.0);
                          return Opacity(
                            opacity: 1 - d * 0.45,
                            child: Transform.scale(
                              scale: 1 - d * 0.08,
                              child: child,
                            ),
                          );
                        },
                        child: _PlaceCard(
                          place: widget.places[i],
                          quran: widget.quran,
                          isHere: i == 0,
                          onGo: () {
                            final page = _pageOf(widget.places[i]);
                            Navigator.of(context).pop();
                            widget.onGo(page);
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'السابق',
                          onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: a, child: child),
                            ),
                            child: Text(
                              _index == count - 1 && count > 1
                                  ? '🎉 الموضع ${_index + 1} من $count'
                                  : 'الموضع ${_index + 1} من $count',
                              key: ValueKey(_index),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'التالي',
                          onPressed:
                              _index < count - 1 ? () => _goTo(_index + 1) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared phrase as a central bubble, and every place as a bubble
/// orbiting it, joined by threads. Bubbles float gently; the selected one
/// swells and glows. Tapping a bubble goes to its card.
class _BubbleDiagram extends StatelessWidget {
  const _BubbleDiagram({
    required this.places,
    required this.quran,
    required this.selected,
    required this.phase,
    required this.onTap,
  });

  final List<MutashabihPlace> places;
  final QuranRepository quran;
  final int selected;
  final double phase;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
      final n = places.length;
      final bubble = n <= 6 ? 62.0 : (n <= 10 ? 52.0 : 44.0);
      final rx = c.maxWidth / 2 - bubble / 2 - 12;
      final ry = c.maxHeight / 2 - bubble / 2 - 6;
      Offset at(int i) {
        // Round the centre, starting near the top.
        final angle = -math.pi / 2 + 2 * math.pi * i / n + math.pi / n;
        final bob = math.sin(2 * math.pi * phase + i * 1.3) * 5;
        return center + Offset(rx * math.cos(angle), ry * math.sin(angle) + bob);
      }

      final points = [for (var i = 0; i < n; i++) at(i)];
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _Threads(center, points, selected)),
          ),
          // Centre: the phrase they share.
          Positioned(
            left: center.dx - 34,
            top: center.dy - 34 + math.sin(2 * math.pi * phase) * 3,
            child: _Bubble(
              size: 68,
              color: MushafColors.green,
              glow: true,
              child: const Text('🔁', style: TextStyle(fontSize: 26)),
            ),
          ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: points[i].dx - bubble / 2,
              top: points[i].dy - bubble / 2,
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedScale(
                  scale: i == selected ? 1.22 : 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  child: _Bubble(
                    size: bubble,
                    color: i == 0 ? MushafColors.green : MushafColors.gold,
                    glow: i == selected,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          quran.surah(places[i].surah).nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'Hafs',
                            fontSize: bubble * 0.2,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${places[i].ayah}',
                          style: TextStyle(
                            fontSize: bubble * 0.2,
                            height: 1.1,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.size,
    required this.color,
    required this.child,
    this.glow = false,
  });

  final double size;
  final Color color;
  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A glossy sphere lit from the top-left.
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            Color.lerp(color, Colors.white, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: Colors.white.withAlpha(120), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(glow ? 150 : 60),
            blurRadius: glow ? 22 : 8,
            spreadRadius: glow ? 2 : 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Threads extends CustomPainter {
  _Threads(this.center, this.points, this.selected);

  final Offset center;
  final List<Offset> points;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, p) in points.indexed) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i == selected ? 2.4 : 1.2
        ..color = (i == selected ? MushafColors.green : MushafColors.gold)
            .withAlpha(i == selected ? 220 : 130);
      final mid = Offset.lerp(center, p, 0.5)!;
      final bend = Offset(-(p.dy - center.dy), p.dx - center.dx) * 0.12;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, p.dx, p.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Threads old) => true;
}

/// Small translucent bubbles rising slowly behind the sheet.
class _DriftingBubbles extends CustomPainter {
  _DriftingBubbles(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final seed = (i * 0.618034) % 1;
      final x = size.width * ((seed * 7.3) % 1);
      final speed = 0.6 + seed;
      final y = size.height * (1.1 - ((t * speed + seed) % 1.2));
      final r = 4 + 10 * ((seed * 3.7) % 1);
      canvas.drawCircle(
        Offset(x + math.sin(2 * math.pi * (t + seed)) * 12, y),
        r,
        Paint()
          ..color =
              (i.isEven ? MushafColors.gold : MushafColors.green).withAlpha(28),
      );
      canvas.drawCircle(
        Offset(x - r * 0.3, y - r * 0.3),
        r * 0.25,
        Paint()..color = Colors.white.withAlpha(30),
      );
    }
  }

  @override
  bool shouldRepaint(_DriftingBubbles old) => old.t != t;
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.quran,
    required this.isHere,
    required this.onGo,
  });

  final MutashabihPlace place;
  final QuranRepository quran;
  final bool isHere;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final first = quran.ayah(place.surah, place.ayah);
    final last = place.parts.last;
    final ayahLabel = place.parts.length == 1
        ? 'الآية ${place.ayah}'
        : 'الآيات ${place.ayah}–${last.ayah}';
    final accent = isHere ? MushafColors.green : MushafColors.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MushafColors.page.withAlpha(215),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withAlpha(200), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withAlpha(170)]),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Text(isHere ? '📍' : '✨',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سورة ${quran.surah(place.surah).nameAr}',
                      style: const TextStyle(
                        fontFamily: 'Hafs',
                        fontSize: 21,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _Chip(ayahLabel),
                  const SizedBox(width: 6),
                  _Chip('ص ${quran.pageOf(first.surah, first.number)}'),
                ],
              ),
            ),
            if (isHere)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'أنت هنا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: MushafColors.green, fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Text.rich(
                  TextSpan(children: [
                    for (final part in place.parts) ...[
                      for (final (w, word)
                          in quran.ayah(part.surah, part.ayah).words.indexed)
                        TextSpan(
                          text: '$word ',
                          style: part.words.contains(w)
                              ? TextStyle(
                                  color: MushafColors.green,
                                  backgroundColor:
                                      MushafColors.gold.withAlpha(80),
                                )
                              : null,
                        ),
                      TextSpan(text: '${_digits(part.ayah)} '),
                    ],
                  ]),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: 23,
                    height: 1.9,
                    color: MushafColors.ink,
                  ),
                ),
              ),
            ),
            if (!isHere)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MushafColors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onGo,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('انتقل إلى الموضع'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
}

String _digits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
