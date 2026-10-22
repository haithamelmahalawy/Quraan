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
    required this.builder,
    this.offset = 0,
  });

  final String text, letter;
  final TextStyle style;
  final Color color;

  /// Builds the text with the hamza's seat, while the circle takes the
  /// hamza's place. The original [text] remains available for semantics.
  final Widget Function(String text, int? hiddenHamza) builder;
  final int offset;

  static String seatText(String text, int offset) {
    if (offset < 0 || offset >= text.length) return text;
    var end = offset + 1;
    while (end < text.length && RegExp('[ً-ٰٟۖ-ۭ]').hasMatch(text[end])) {
      end++;
    }
    final cluster = text.substring(offset, end);
    final seat = cluster
        .replaceAll(RegExp('[أإٱ]'), 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ى')
        .replaceAll(RegExp('[ٕ۪ٔ۬]'), '');
    return text.replaceRange(offset, end, seat);
  }

  /// A standalone hamza has no seat to leave behind. Keep its advance and
  /// joining behaviour, but hide its ink under the replacement circle.
  static List<(String, Color?)> hideHamza(
    List<(String, Color?)> parts,
    int? offset,
  ) {
    if (offset == null) return parts;
    var start = 0;
    final result = <(String, Color?)>[];
    for (final (text, color) in parts) {
      if (offset >= start && offset < start + text.length) {
        final at = offset - start;
        if (at > 0) result.add((text.substring(0, at), color));
        result.add((text[at], Colors.transparent));
        if (at + 1 < text.length) result.add((text.substring(at + 1), color));
      } else {
        result.add((text, color));
      }
      start += text.length;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final shown = seatText(text, offset);
    return Semantics(
      label:
          '$text، ${letter == 'و' ? 'إبدال الهمزة واوًا وصلاً' : 'إبدال الهمزة ياءً وصلاً'}',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _ReplacementPainter(
          shown,
          letter,
          DefaultTextStyle.of(context).style.merge(style),
          color,
          offset,
          MediaQuery.textScalerOf(context),
        ),
        child: builder(
          shown,
          shown.length > offset && offset >= 0 && shown[offset] == 'ء'
              ? offset
              : null,
        ),
      ),
    );
  }
}

class _ReplacementPainter extends CustomPainter {
  _ReplacementPainter(
    this.text,
    this.letter,
    this.style,
    this.color,
    this.offset,
    this.textScaler,
  );

  final String text, letter;
  final TextStyle style;
  final Color color;
  final int offset;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    if (offset < 0 || offset >= text.length) {
      painter.dispose();
      return;
    }
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
    final fontSize = textScaler.scale(style.fontSize ?? 14);
    final diameter = fontSize * 0.30;
    final lines = painter.computeLineMetrics();
    final line = lines.firstWhere(
      (l) => box.top <= l.baseline && box.bottom >= l.baseline,
      orElse: () => lines.last,
    );
    // A selection box covers the line's font metrics, not the hamza's ink.
    // Anchor to the alif's baseline instead of the top/bottom of that box.
    final center = Offset(
      (box.left + box.right) / 2,
      line.baseline +
          fontSize *
              (text[offset] == 'ء'
                  ? -0.12
                  : letter == 'و'
                  ? -0.83
                  : 0.15),
    );
    canvas.drawCircle(
      center,
      diameter / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, diameter * 0.065),
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
      offset != old.offset ||
      textScaler != old.textScaler;
}
