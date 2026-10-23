import 'package:flutter/material.dart';

import 'hafs_font_marks.dart';

/// Quran words in margins and reference sheets use the same font anchors
/// as the main text, without adding the main page's ink outline.
class QuranWordText extends StatelessWidget {
  const QuranWordText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
  });
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (style.fontFamily != 'Hafs' || !HafsFontMarks.needsAdjustment(text)) {
      return Text(
        text,
        style: style,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
      );
    }
    return HafsFontMarks(
      parts: [(text, style.color)],
      style: style,
      builder: (parts) => Text.rich(
        TextSpan(
          children: [
            for (final (s, c) in parts)
              TextSpan(
                text: s,
                style: TextStyle(color: c),
              ),
          ],
        ),
        style: style,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
      ),
    );
  }
}
