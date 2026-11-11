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
    if (style.fontFamily == 'Hafs' && hafsDrawable(text) != text) {
      return QuranWordText(
        hafsDrawable(text),
        style: style,
        textAlign: textAlign,
      );
    }
    final small = style.fontFamily == 'Hafs'
        ? smallHamzaAlifParts([(text, style.color)])
        : null;
    if (small != null) {
      final size = style.fontSize ?? 14;
      return Text.rich(
        TextSpan(
          children: [
            for (final (s, _, isSmall) in small)
              TextSpan(
                text: s,
                style: isSmall
                    ? TextStyle(
                        fontSize: size * smallHamzaAlifScale,
                        height: (style.height ?? 1) / smallHamzaAlifScale,
                      )
                    : null,
              ),
          ],
        ),
        style: style,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
      );
    }
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
