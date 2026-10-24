import 'package:flutter/material.dart';

/// Repairs the Hafs font's anchors without changing the source Quran text.
/// The Maghribi fathatan glyph and stacked dagger-alif/madd need different
/// anchors in this font. Iqlab mim is anchored independently so it cannot
/// fall inside a letter when the vowel below it changes the font anchor.
/// QCF page glyphs are never processed here.
class HafsFontMarks extends StatelessWidget {
  const HafsFontMarks({
    super.key,
    required this.parts,
    required this.style,
    required this.builder,
  });

  final List<(String, Color?)> parts;
  final TextStyle style;
  final Widget Function(List<(String, Color?)>) builder;

  static final _tanween = RegExp(
    r'([ًٗ])ا([ۖ-ۭ]*)(?=\s|$)|ا[ًٗ]([ۖ-ۭ]*)(?=\s|$)',
  );
  static final _cluster = RegExp('[^ً-ٰٟۖ-ۭ][ً-ٰٟۖ-ۭ]*');

  // A separate paint span for each code point breaks the font's hamza/vowel
  // shaping. Keep adjacent characters of the same colour in one shaping run.
  static List<(String, Color?)> _joined(List<(String, Color?)> parts) {
    final result = <(String, Color?)>[];
    for (final (text, color) in parts) {
      if (result.isNotEmpty && result.last.$2 == color) {
        result[result.length - 1] = (result.last.$1 + text, color);
      } else {
        result.add((text, color));
      }
    }
    return result;
  }

  static bool _lowerImala(String cluster) =>
      'بيئج'.contains(cluster[0]) && RegExp('[۪ٜ]').hasMatch(cluster);

  static bool needsAdjustment(String text) =>
      RegExp('[ۭۢ]').hasMatch(text) ||
      _tanween.hasMatch(text) ||
      _cluster
          .allMatches(text)
          .any(
            (m) =>
                m[0]!.contains('ٰ') && m[0]!.contains('ٓ') ||
                _lowerImala(m[0]!),
          );

  static List<(String, Color?)> positionedParts(List<(String, Color?)> parts) {
    final chars = <(String, Color?)>[
      for (final (text, color) in parts)
        for (final c in text.split('')) (c, color),
    ];
    final source = chars.map((p) => p.$1).join();
    for (final m in _tanween.allMatches(source)) {
      final color = chars[m.start].$2;
      chars[m.start] = ('ا', chars[m.start + (m[1] == null ? 0 : 1)].$2);
      chars[m.start + 1] = ('ً', color);
    }
    return _joined(chars);
  }

  @override
  Widget build(BuildContext context) {
    Widget preserveText(Widget child) => Semantics(
      label: parts.map((p) => p.$1).join(),
      excludeSemantics: true,
      child: child,
    );
    final placed = [
      for (final (text, color) in positionedParts(parts))
        for (final c in text.split('')) (c, color),
    ];
    final full = placed.map((p) => p.$1).join();
    final marks = <int, Color?>{};
    for (final m in _cluster.allMatches(full)) {
      if (m[0]!.contains('ٰ') && m[0]!.contains('ٓ')) {
        final at = full.indexOf('ٓ', m.start);
        marks[at] = placed[at].$2;
      }
      if (_lowerImala(m[0]!)) {
        final markAt = full.indexOf(RegExp('[۪ٜ]'), m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (RegExp('[ۭۢ]').hasMatch(m[0]!)) {
        final markAt = full.indexOf(RegExp('[ۭۢ]'), m.start);
        marks[markAt] = placed[markAt].$2;
      }
    }
    if (marks.isEmpty) return preserveText(builder(_joined(placed)));
    final rendered = _joined(<(String, Color?)>[
      for (final (i, p) in placed.indexed)
        if (!marks.containsKey(i)) p,
    ]);
    return preserveText(
      CustomPaint(
        foregroundPainter: _QuranMarkPainter(
          rendered,
          [
            for (final entry in marks.entries)
              for (final m in _cluster.allMatches(full))
                if (m.start <= entry.key && entry.key < m.end)
                  (
                    m.start - marks.keys.where((at) => at < m.start).length,
                    entry.value,
                    full[entry.key],
                  ),
          ],
          DefaultTextStyle.of(context).style.merge(style),
          MediaQuery.textScalerOf(context),
        ),
        child: builder(rendered),
      ),
    );
  }
}

class _QuranMarkPainter extends CustomPainter {
  _QuranMarkPainter(this.parts, this.targets, this.style, this.scaler);
  final List<(String, Color?)> parts;
  final List<(int, Color?, String)> targets;
  final TextStyle style;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        style: style,
        children: [
          for (final (s, c) in parts)
            TextSpan(
              text: s,
              style: TextStyle(color: c),
            ),
        ],
      ),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final font = scaler.scale(style.fontSize ?? 14);
    final source = parts.map((p) => p.$1).join();
    for (final (at, color, sign) in targets) {
      final imala = sign == '۪' || sign == 'ٜ';
      final below = imala || sign == 'ۭ';
      final iqlab = sign == 'ۢ';
      final end = HafsFontMarks._cluster.matchAsPrefix(source, at)!.end;
      final boxes = text.getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: end),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      final line = text.computeLineMetrics().firstWhere(
        (l) => l.baseline >= box.top && l.baseline <= box.bottom,
      );
      final mark = TextPainter(
        text: TextSpan(
          text: imala ? 'ا۪' : 'ا$sign',
          style: TextStyle(
            fontFamily: 'Hafs',
            fontSize: font,
            height: 1,
            color: color ?? style.color,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final origin = Offset(
        (box.left + box.right) / 2 - mark.width / 2,
        line.baseline -
            mark.computeLineMetrics().single.baseline +
            font *
                (imala
                    ? .40
                    : below
                    ? .18
                    : iqlab
                    ? -.12
                    : .05),
      );
      // Some font engines hide a mark when its carrier is transparent.
      // Paint the mark normally and clip away the carrier's ink instead.
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          -font,
          below
              ? origin.dy +
                    mark.computeLineMetrics().single.baseline +
                    font * .02
              : -font * 2,
          size.width + font,
          below
              ? size.height + font
              : origin.dy +
                    mark.computeLineMetrics().single.baseline -
                    font * .68,
        ),
      );
      mark.paint(canvas, origin);
      canvas.restore();
      mark.dispose();
    }
    text.dispose();
  }

  @override
  bool shouldRepaint(_QuranMarkPainter old) =>
      parts != old.parts ||
      targets != old.targets ||
      style != old.style ||
      scaler != old.scaler;
}
