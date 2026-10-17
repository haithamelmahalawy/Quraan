import 'package:flutter/material.dart';

import 'theme.dart';

/// Madinah-mushaf style page border: a patterned band of green diamonds on
/// gold between two rules, with corner squares.
class OrnamentFrame extends StatelessWidget {
  const OrnamentFrame({super.key, required this.child, this.band = 14});

  final Widget child;
  final double band;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(band),
      child: Padding(
        padding: EdgeInsets.all(band + 6),
        child: child,
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.band);

  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = outer.deflate(band);
    final gold = Paint()..color = MushafColors.gold;
    final green = Paint()..color = MushafColors.green;
    final rule = Paint()
      ..color = MushafColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Band background and paper inside.
    canvas.drawRect(outer, gold);
    canvas.drawRect(inner, Paint()..color = MushafColors.paper);

    // Diamonds along each side.
    void diamonds(Offset from, Offset to) {
      final length = (to - from).distance;
      final count = (length / band).floor();
      final step = (to - from) / count.toDouble();
      final dir = step / step.distance;
      final normal = Offset(-dir.dy, dir.dx);
      final r = band / 2 - 2;
      for (var i = 0; i < count; i++) {
        final c = from + step * (i + 0.5);
        final path = Path()
          ..moveTo(c.dx + dir.dx * r, c.dy + dir.dy * r)
          ..lineTo(c.dx + normal.dx * r, c.dy + normal.dy * r)
          ..lineTo(c.dx - dir.dx * r, c.dy - dir.dy * r)
          ..lineTo(c.dx - normal.dx * r, c.dy - normal.dy * r)
          ..close();
        canvas.drawPath(path, green);
        canvas.drawCircle(c, 1.6, Paint()..color = MushafColors.paper);
      }
    }

    final h = band / 2;
    diamonds(Offset(band, h), Offset(size.width - band, h));
    diamonds(Offset(band, size.height - h), Offset(size.width - band, size.height - h));
    diamonds(Offset(h, band), Offset(h, size.height - band));
    diamonds(Offset(size.width - h, band), Offset(size.width - h, size.height - band));

    // Corner squares.
    for (final c in [
      Offset(h, h),
      Offset(size.width - h, h),
      Offset(h, size.height - h),
      Offset(size.width - h, size.height - h),
    ]) {
      canvas.drawRect(Rect.fromCenter(center: c, width: band, height: band), green);
      canvas.drawCircle(c, band / 4, gold);
    }

    // Double rules: outside, and inside the band with a thin gap.
    canvas.drawRect(outer.deflate(0.7), rule);
    canvas.drawRect(inner, rule);
    canvas.drawRect(inner.deflate(3), rule..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.band != band;
}

/// Surah title banner: patterned side panels and a central cartouche.
class SurahBanner extends StatelessWidget {
  const SurahBanner({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      height: 46,
      child: CustomPaint(
        painter: _BannerPainter(),
        child: Center(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Hafs',
              fontSize: 21,
              height: 1.1,
              color: MushafColors.ink,
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
    final gold = Paint()..color = MushafColors.gold;
    final green = Paint()..color = MushafColors.green;
    final stroke = Paint()
      ..color = MushafColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRect(rect, gold);

    // Side panels: alternating green lozenges.
    final panel = rect.deflate(4);
    canvas.drawRect(panel, Paint()..color = MushafColors.goldLight);
    final cy = size.height / 2;
    final r = panel.height / 2 - 2;
    for (var x = panel.left + r + 2; x < panel.right - r; x += r * 2 + 4) {
      final path = Path()
        ..moveTo(x - r, cy)
        ..lineTo(x, cy - r)
        ..lineTo(x + r, cy)
        ..lineTo(x, cy + r)
        ..close();
      canvas.drawPath(path, green);
      canvas.drawCircle(Offset(x, cy), r / 3, gold);
    }

    // Central cartouche for the name.
    final cartouche = Rect.fromCenter(
      center: rect.center,
      width: size.width * 0.5,
      height: size.height - 6,
    );
    final rr = RRect.fromRectAndRadius(cartouche, Radius.circular(cartouche.height / 2));
    canvas.drawRRect(rr.inflate(3), gold);
    canvas.drawRRect(rr, Paint()..color = MushafColors.paper);
    canvas.drawRRect(rr, stroke);
    canvas.drawRRect(rr.inflate(3), stroke..strokeWidth = 1);

    canvas.drawRect(rect.deflate(0.7), stroke..strokeWidth = 1.4);
    canvas.drawRect(panel, stroke..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(_BannerPainter old) => false;
}
