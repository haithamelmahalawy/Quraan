import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Madinah-mushaf style page border: a band of rose rosettes between rose
/// and gold rules, with rosette corners, as in the printed mushaf.
class OrnamentFrame extends StatelessWidget {
  const OrnamentFrame({super.key, required this.child, this.sides = true});

  final Widget child;

  /// The bands at the right and left too; without them (full screen) the
  /// text has the whole width, between the bands above and below.
  final bool sides;

  /// Distance from the right or left edge to the content.
  static double sideInset(bool sides) => sides ? inset : 6;

  /// Width of the patterned band.
  static const band = 14.0;

  /// Distance from the outside of the frame to its content, on every side.
  static const inset = band + 6;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(sides),
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

class _FramePainter extends CustomPainter {
  _FramePainter(this.sides);

  final bool sides;

  @override
  void paint(Canvas canvas, Size size) {
    const band = OrnamentFrame.band;
    final outer = Offset.zero & size;
    final inner = sides
        ? outer.deflate(band)
        : Rect.fromLTRB(0, band, size.width, size.height - band);
    final rose = MushafColors.rose, gold = MushafColors.gold;

    canvas.drawRect(outer, Paint()..color = MushafColors.roseLight);
    canvas.drawRect(inner, Paint()..color = MushafColors.page);
    if (!sides) return _bandsOnly(canvas, size, inner);

    // Rosettes along each side, small gold dots between them.
    void along(Offset from, Offset to) {
      final length = (to - from).distance;
      final count = math.max(1, (length / (band * 1.25)).floor());
      final step = (to - from) / count.toDouble();
      for (var i = 0; i < count; i++) {
        _rosette(
          canvas,
          from + step * (i + 0.5),
          band * 0.42,
          rose.withAlpha(200),
          gold,
        );
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
        Paint()..color = rose,
      );
      _rosette(canvas, c, band * 0.4, MushafColors.roseLight, gold);
    }

    // Rules: rose outside; gold then rose inside.
    final line = Paint()..style = PaintingStyle.stroke;
    canvas.drawRect(
      outer.deflate(0.6),
      line
        ..color = rose
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
        ..color = rose
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
        _rosette(
          canvas,
          Offset(step * (i + 0.5), y),
          band * 0.42,
          MushafColors.rose.withAlpha(200),
          MushafColors.gold,
        );
        if (i > 0) {
          canvas.drawCircle(
            Offset(step * i, y),
            1.3,
            Paint()..color = MushafColors.gold,
          );
        }
      }
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = MushafColors.gold;
    for (final y in [inner.top, inner.bottom]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.sides != sides;
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
        painter: _BannerPainter(),
        child: Center(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: fontSize,
              height: 1.1,
              color: MushafColors.rose,
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rose = MushafColors.rose, gold = MushafColors.gold;

    // Panel with a fine diagonal lattice.
    canvas.drawRect(rect, Paint()..color = MushafColors.roseLight);
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
  bool shouldRepaint(_BannerPainter old) => false;
}
