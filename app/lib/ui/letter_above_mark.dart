import 'package:flutter/material.dart';

/// A small letter written over one letter of a word, as the Madinah print
/// writes a small za' over the dad of بِضَنِينٖ for those who read it with
/// the za'. The word keeps its own spelling, shaping and width.
class LetterAboveMark extends StatelessWidget {
  const LetterAboveMark({
    super.key,
    required this.text,
    required this.offset,
    required this.letter,
    required this.style,
    required this.color,
    required this.child,
  });

  /// The word as drawn by [child], and the code unit of the letter marked.
  final String text;
  final int offset;
  final String letter;
  final TextStyle style;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _LetterAbovePainter(
      text,
      offset,
      letter,
      DefaultTextStyle.of(context).style.merge(style),
      color,
      MediaQuery.textScalerOf(context),
    ),
    child: child,
  );
}

class _LetterAbovePainter extends CustomPainter {
  _LetterAbovePainter(
    this.text,
    this.offset,
    this.letter,
    this.style,
    this.color,
    this.textScaler,
  );

  final String text, letter;
  final int offset;
  final TextStyle style;
  final Color color;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (offset < 0 || offset >= text.length) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    // The letter with its marks: shaping keeps them in one cluster.
    var end = offset + 1;
    while (end < text.length && RegExp('[ً-ٰٟۖ-ۭ]').hasMatch(text[end])) {
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
    final baseline = painter.computeLineMetrics().first.baseline;
    final at = Offset(box.left + box.right, 0) / 2;
    // Filled, then outlined as the page's ink is (InkText), so it is not
    // lighter than the letters it sits over.
    for (final stroke in [false, true]) {
      final glyph = TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(
            fontFamily: 'Hafs',
            fontSize: fontSize * .5,
            height: 1,
            foreground: Paint()
              ..color = color
              ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
              ..strokeWidth = fontSize * .02,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      // Over the letter, just above its vowel.
      glyph.paint(
        canvas,
        Offset(
          at.dx - glyph.width / 2,
          baseline - fontSize * .9 - glyph.height / 2,
        ),
      );
      glyph.dispose();
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_LetterAbovePainter old) =>
      text != old.text ||
      offset != old.offset ||
      letter != old.letter ||
      style != old.style ||
      color != old.color ||
      textScaler != old.textScaler;
}
