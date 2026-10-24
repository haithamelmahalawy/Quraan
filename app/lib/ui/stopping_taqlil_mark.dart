import 'package:flutter/material.dart';

/// A stopping-only taqlil annotation; the Quran spelling stays unchanged.
/// The small dot is circled to distinguish it from continuous taqlil.
class StoppingTaqlilMark extends StatelessWidget {
  const StoppingTaqlilMark({
    super.key,
    required this.text,
    required this.style,
    required this.color,
    required this.child,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _StoppingTaqlilPainter(
      text,
      style,
      color,
      MediaQuery.textScalerOf(context),
    ),
    child: child,
  );
}

class _StoppingTaqlilPainter extends CustomPainter {
  _StoppingTaqlilPainter(this.text, this.style, this.color, this.scaler);
  final String text;
  final TextStyle style;
  final Color color;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    var at = text.lastIndexOf('ى');
    if (at < 0) at = text.lastIndexOf('ا');
    if (at < 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: at, extentOffset: at + 1),
    );
    if (boxes.isNotEmpty) {
      final box = boxes.first;
      final line = painter.computeLineMetrics().firstWhere(
        (l) => l.baseline >= box.top && l.baseline <= box.bottom,
      );
      final font = scaler.scale(style.fontSize ?? 14);
      final center = Offset(
        (box.left + box.right) / 2,
        line.baseline + font * .31,
      );
      canvas.drawCircle(
        center,
        font * .09,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = font * .02,
      );
      canvas.drawCircle(center, font * .024, Paint()..color = color);
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_StoppingTaqlilPainter old) =>
      text != old.text ||
      style != old.style ||
      color != old.color ||
      scaler != old.scaler;
}
