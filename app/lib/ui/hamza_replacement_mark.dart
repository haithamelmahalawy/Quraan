import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small circled waw above, or ya below, the second hamza. Painting the
/// annotation preserves Arabic shaping, word width and the printed lines.
class HamzaReplacementMark extends StatelessWidget {
  const HamzaReplacementMark({
    super.key,
    required this.text,
    required this.letter,
    required this.style,
    required this.color,
    required this.child,
    this.offset = 0,
  });

  final String text, letter;
  final TextStyle style;
  final Color color;
  final Widget child;
  final int offset;

  @override
  Widget build(BuildContext context) => Semantics(
    label: letter == 'و'
        ? 'إبدال الهمزة واوًا وصلاً'
        : 'إبدال الهمزة ياءً وصلاً',
    child: CustomPaint(
      foregroundPainter: _ReplacementPainter(
        text,
        letter,
        style,
        color,
        offset,
      ),
      child: child,
    ),
  );
}

class _ReplacementPainter extends CustomPainter {
  _ReplacementPainter(
    this.text,
    this.letter,
    this.style,
    this.color,
    this.offset,
  );

  final String text, letter;
  final TextStyle style;
  final Color color;
  final int offset;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
    )..layout();
    var end = offset + 1;
    while (end < text.length && RegExp('[ً-ٰٟۖ-ۭ]').hasMatch(text[end])) {
      end++;
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: end),
    );
    if (boxes.isEmpty) {
      painter.dispose();
      return;
    }
    final box = boxes.first;
    final diameter = math.max(7.0, (style.fontSize ?? 14) * 0.42);
    final center = Offset(
      (box.left + box.right) / 2,
      letter == 'و' ? box.top - diameter * 0.18 : box.bottom + diameter * 0.18,
    );
    canvas.drawCircle(
      center,
      diameter / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, diameter * 0.075),
    );
    final glyph = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: diameter * 0.83,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ReplacementPainter old) =>
      text != old.text ||
      letter != old.letter ||
      style != old.style ||
      color != old.color ||
      offset != old.offset;
}
