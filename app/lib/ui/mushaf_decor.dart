import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Madinah-mushaf style page border: a band of motifs between rules, with
/// motif corners, as in the printed mushaf; its motif and colours of the
/// look picked ([MushafStyle]) (the user, 2026-11-14).
class OrnamentFrame extends StatelessWidget {
  const OrnamentFrame({
    super.key,
    required this.child,
    this.sides = true,
    this.style,
  });

  final Widget child;

  /// The bands at the right and left too; without them (full screen) the
  /// text has the whole width, between the bands above and below.
  final bool sides;

  /// The look drawn; the one in use when null (a preview gives its own).
  final MushafStyle? style;

  /// Distance from the right or left edge to the content.
  static double sideInset(bool sides) => sides ? inset : 6;

  /// Width of the patterned band.
  static const band = 14.0;

  /// Distance from the outside of the frame to its content, on every side.
  static const inset = band + 6;

  @override
  Widget build(BuildContext context) {
    final own = style;
    final look = own ?? MushafColors.style;
    // A preview of another look: its own page and frame, in the light.
    final apart = own != null && !MushafColors.isDark;
    return CustomPaint(
      painter: _FramePainter(
        sides,
        look,
        apart ? look.page : MushafColors.page,
        apart
            ? look.frameOn(MushafPalette.light)
            : look.frameOn(
                MushafColors.isDark ? MushafPalette.dark : MushafPalette.light,
              ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: inset,
          horizontal: sideInset(sides),
        ),
        child: child,
      ),
    );
  }
}

/// A small four-petal rosette, the motif of the border and banners.
void _rosette(Canvas canvas, Offset c, double r, Color petal, Color heart) {
  final p = Paint()..color = petal;
  for (var k = 0; k < 4; k++) {
    final a = k * math.pi / 2 + math.pi / 4;
    canvas.drawCircle(
      c + Offset(math.cos(a), math.sin(a)) * r * 0.55,
      r * 0.42,
      p,
    );
  }
  canvas.drawCircle(c, r * 0.3, Paint()..color = heart);
}

/// One motif of [shape] at [c], [r] its half size, in [main] around a
/// [heart].
void frameMotif(
  Canvas canvas,
  FrameMotif shape,
  Offset c,
  double r,
  Color main,
  Color heart,
) {
  final fill = Paint()..color = main;
  void turned(double angle, void Function() draw) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    draw();
    canvas.restore();
  }

  switch (shape) {
    case FrameMotif.rosette:
      _rosette(canvas, c, r, main, heart);
    case FrameMotif.star:
      // The eight-pointed star: two squares, one turned.
      for (final angle in [0.0, math.pi / 4]) {
        turned(
          angle,
          () => canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: r * 1.3,
              height: r * 1.3,
            ),
            fill,
          ),
        );
      }
      canvas.drawCircle(c, r * 0.28, Paint()..color = heart);
    case FrameMotif.diamond:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.75, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * 0.75, c.dy)
          ..close(),
        fill,
      );
      canvas.drawCircle(c, r * 0.22, Paint()..color = heart);
    case FrameMotif.ring:
      canvas.drawCircle(
        c,
        r * 0.72,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.34
          ..color = main,
      );
      canvas.drawCircle(c, r * 0.22, Paint()..color = heart);
    case FrameMotif.flower:
      // Six petals around a heart.
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3;
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * r * 0.52,
          r * 0.34,
          fill,
        );
      }
      canvas.drawCircle(c, r * 0.3, Paint()..color = heart);
    case FrameMotif.dots:
      canvas.drawCircle(c, r * 0.38, fill);
      for (final dx in [-r * 0.85, r * 0.85]) {
        canvas.drawCircle(c + Offset(dx, 0), r * 0.16, fill);
      }
    case FrameMotif.leaf:
      // Two leaves, back to back, and a bud between them.
      for (final angle in [math.pi / 4, -math.pi * 3 / 4]) {
        turned(
          angle,
          () => canvas.drawOval(
            Rect.fromLTWH(r * 0.05, -r * 0.28, r * 0.95, r * 0.56),
            fill,
          ),
        );
      }
      canvas.drawCircle(c, r * 0.24, Paint()..color = heart);
    case FrameMotif.square:
      turned(
        math.pi / 4,
        () => canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.2, height: r * 1.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.26
            ..color = main,
        ),
      );
      canvas.drawRect(
        Rect.fromCenter(center: c, width: r * 0.5, height: r * 0.5),
        Paint()..color = heart,
      );
    case FrameMotif.chevron:
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.3
        ..strokeCap = StrokeCap.round
        ..color = main;
      for (final dy in [-r * 0.32, r * 0.32]) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.75, c.dy + dy - r * 0.3)
            ..lineTo(c.dx, c.dy + dy + r * 0.3)
            ..lineTo(c.dx + r * 0.75, c.dy + dy - r * 0.3),
          stroke,
        );
      }
    case FrameMotif.knot:
      // Two rings interlaced.
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..color = main;
      for (final dx in [-r * 0.32, r * 0.32]) {
        canvas.drawCircle(c + Offset(dx, 0), r * 0.55, stroke);
      }
      canvas.drawCircle(c, r * 0.18, Paint()..color = heart);
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.sides, this.style, this.page, this.colors);

  final bool sides;
  final MushafStyle style;
  final Color page;
  final ({Color band, Color motif, Color accent}) colors;

  void _at(Canvas canvas, Offset c, double r) => frameMotif(
    canvas,
    style.motifShape,
    c,
    r,
    colors.motif.withAlpha(style.motifShape == FrameMotif.rosette ? 200 : 235),
    colors.accent,
  );

  @override
  void paint(Canvas canvas, Size size) {
    const band = OrnamentFrame.band;
    final outer = Offset.zero & size;
    final inner = sides
        ? outer.deflate(band)
        : Rect.fromLTRB(0, band, size.width, size.height - band);
    final motif = colors.motif, gold = colors.accent;

    canvas.drawRect(outer, Paint()..color = colors.band);
    canvas.drawRect(inner, Paint()..color = page);
    if (!sides) return _bandsOnly(canvas, size, inner);

    // Motifs along each side, small dots between them.
    void along(Offset from, Offset to) {
      final length = (to - from).distance;
      final count = math.max(1, (length / (band * 1.25)).floor());
      final step = (to - from) / count.toDouble();
      for (var i = 0; i < count; i++) {
        _at(canvas, from + step * (i + 0.5), band * 0.42);
        if (i > 0) {
          canvas.drawCircle(
            from + step * i.toDouble(),
            1.3,
            Paint()..color = gold,
          );
        }
      }
    }

    const h = band / 2;
    along(const Offset(band, h), Offset(size.width - band, h));
    along(
      Offset(band, size.height - h),
      Offset(size.width - band, size.height - h),
    );
    along(const Offset(h, band), Offset(h, size.height - band));
    along(
      Offset(size.width - h, band),
      Offset(size.width - h, size.height - band),
    );

    // Corner squares.
    for (final c in [
      const Offset(h, h),
      Offset(size.width - h, h),
      Offset(h, size.height - h),
      Offset(size.width - h, size.height - h),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: band, height: band),
        Paint()..color = motif,
      );
      frameMotif(canvas, style.motifShape, c, band * 0.4, colors.band, gold);
    }

    // Rules: the motif's colour outside; gold then the motif's inside.
    final line = Paint()..style = PaintingStyle.stroke;
    canvas.drawRect(
      outer.deflate(0.6),
      line
        ..color = motif
        ..strokeWidth = 1.2,
    );
    canvas.drawRect(
      inner,
      line
        ..color = gold
        ..strokeWidth = 1.4,
    );
    canvas.drawRect(
      inner.deflate(2.5),
      line
        ..color = motif
        ..strokeWidth = 0.8,
    );
  }

  /// Full screen: the bands above and below the text only.
  void _bandsOnly(Canvas canvas, Size size, Rect inner) {
    const band = OrnamentFrame.band, h = band / 2;
    final count = math.max(1, (size.width / (band * 1.25)).floor());
    final step = size.width / count;
    for (final y in [h, size.height - h]) {
      for (var i = 0; i < count; i++) {
        _at(canvas, Offset(step * (i + 0.5), y), band * 0.42);
        if (i > 0) {
          canvas.drawCircle(
            Offset(step * i, y),
            1.3,
            Paint()..color = colors.accent,
          );
        }
      }
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = colors.accent;
    for (final y in [inner.top, inner.bottom]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.sides != sides ||
      old.style != style ||
      old.page != page ||
      old.colors != colors;
}

/// Surah title banner as printed: a rose lattice panel with rosettes and a
/// central cartouche holding the name.
class SurahBanner extends StatelessWidget {
  const SurahBanner({
    super.key,
    required this.title,
    this.fontSize = 21,
    this.height = 46,
  });

  final String title;
  final double fontSize;

  /// Banner height; null to fill the parent (a mushaf line).
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: height == null ? 2 : 6),
      height: height,
      child: CustomPaint(
        painter: _BannerPainter(MushafColors.frameColors),
        child: Center(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: fontSize,
              height: 1.1,
              color: MushafColors.frameColors.motif,
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  _BannerPainter(this.frame);

  /// The frame's colours, of the look in use.
  final ({Color band, Color motif, Color accent}) frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rose = frame.motif, gold = frame.accent;

    // Panel with a fine diagonal lattice.
    canvas.drawRect(rect, Paint()..color = frame.band);
    canvas.save();
    canvas.clipRect(rect);
    final lattice = Paint()
      ..color = rose.withAlpha(70)
      ..strokeWidth = 0.8;
    final step = size.height / 3;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        lattice,
      );
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        lattice,
      );
    }
    canvas.restore();

    // Rosettes on both sides of the cartouche.
    final r = size.height * 0.26;
    for (final x in [0.08, 0.17, 0.83, 0.92]) {
      _rosette(canvas, Offset(size.width * x, size.height / 2), r, rose, gold);
    }

    // The cartouche: a frame with pointed ends for the name.
    final w = size.width * 0.52, hh = size.height - 8;
    final c = rect.center;
    Path cartouche(double grow) {
      final left = c.dx - w / 2 - grow, right = c.dx + w / 2 + grow;
      final top = c.dy - hh / 2 - grow, bottom = c.dy + hh / 2 + grow;
      final tip = hh / 2 + grow;
      return Path()
        ..moveTo(left + tip, top)
        ..lineTo(right - tip, top)
        ..quadraticBezierTo(right - tip * 0.2, top, right, c.dy)
        ..quadraticBezierTo(right - tip * 0.2, bottom, right - tip, bottom)
        ..lineTo(left + tip, bottom)
        ..quadraticBezierTo(left + tip * 0.2, bottom, left, c.dy)
        ..quadraticBezierTo(left + tip * 0.2, top, left + tip, top)
        ..close();
    }

    canvas.drawPath(cartouche(3), Paint()..color = gold);
    canvas.drawPath(cartouche(0), Paint()..color = MushafColors.page);
    final stroke = Paint()..style = PaintingStyle.stroke;
    canvas.drawPath(
      cartouche(0),
      stroke
        ..color = rose
        ..strokeWidth = 1.2,
    );
    canvas.drawPath(
      cartouche(3),
      stroke
        ..color = rose
        ..strokeWidth = 0.8,
    );
    canvas.drawRect(
      rect.deflate(0.6),
      stroke
        ..color = rose
        ..strokeWidth = 1.2,
    );
    canvas.drawRect(
      rect.deflate(2.5),
      stroke
        ..color = gold
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_BannerPainter old) => old.frame != frame;
}
