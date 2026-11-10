import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small circled waw/ya in the original hamza's position. Painting the
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
    this.originalHamza,
  });

  final String text, letter;
  final TextStyle style;
  final Color color;

  /// Builds the text with the hamza's seat, while the circle takes the
  /// hamza's place. The original [text] remains available for semantics.
  final Widget Function(String text, int? hiddenHamza) builder;
  final int offset;

  /// Hafs-aligned source cluster before Warsh's replacement spelling.
  final String? originalHamza;

  /// The hamza before an alif (هَٰٓؤُلَآءِ ءَالِهَةٗ): in its own place before
  /// the alif, not over it.
  static bool beforeAlif(
    String letter,
    String hamza,
    String text,
    int offset,
  ) =>
      letter.isNotEmpty &&
      hamza.startsWith('ء') &&
      text.startsWith('ا', offset);

  static bool isBelow(String cluster) =>
      cluster.startsWith('إ') || RegExp('[ٕ۪]').hasMatch(cluster);

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
        .replaceAll(RegExp('[َُِْٕ۪ٔ۬۟ۡ]'), '');
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
          '$text، ${letter.isEmpty
              ? 'تسهيل الهمزة الثانية بلا إدخال'
              : letter == 'و'
              ? 'إبدال الهمزة واوًا وصلاً'
              : 'إبدال الهمزة ياءً وصلاً'}',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _ReplacementPainter(
          text,
          letter,
          DefaultTextStyle.of(context).style.merge(style),
          color,
          offset,
          MediaQuery.textScalerOf(context),
          originalHamza,
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
    this.originalHamza,
  );

  final String text, letter;
  final TextStyle style;
  final Color color;
  final int offset;
  final TextScaler textScaler;
  final String? originalHamza;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = HamzaReplacementMark.seatText(text, offset);
    final painter = TextPainter(
      text: TextSpan(text: shown, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    // A word set narrower than its own width (وَرَآءِ۬ in its line) wraps its
    // hidden hamza onto a second line, under the first letter: placed on one
    // line instead, within the word's width.
    var squeeze = 1.0;
    if (painter.computeLineMetrics().length > 1 && size.width > 0) {
      painter.layout();
      squeeze = size.width / painter.width;
    }
    _paintMark(canvas, painter, shown, squeeze);
    painter.dispose();
  }

  void _paintMark(
    Canvas canvas,
    TextPainter painter,
    String shown,
    double squeeze,
  ) {
    if (offset < 0 || offset >= text.length) {
      return;
    }
    var end = offset + 1;
    while (end < text.length && RegExp('[ً-ٰٟۖ-ۭ]').hasMatch(text[end])) {
      end++;
    }
    var shownEnd = offset + 1;
    while (shownEnd < shown.length &&
        RegExp('[ً-ٰٟۖ-ۭ]').hasMatch(shown[shownEnd])) {
      shownEnd++;
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: shownEnd),
    );
    if (boxes.isEmpty) {
      return;
    }
    final box = boxes.first;
    final fontSize = textScaler.scale(style.fontSize ?? 14);
    final diameter = fontSize * (letter.isEmpty ? .18 : .30);
    final lines = painter.computeLineMetrics();
    final line = lines.firstWhere(
      (l) => box.top <= l.baseline && box.bottom >= l.baseline,
      orElse: () => lines.last,
    );
    // A selection box covers the line's font metrics, not the hamza's ink.
    // Anchor to the alif's baseline instead of the top/bottom of that box.
    final hamza = originalHamza ?? text.substring(offset, end);
    // On the alif of «لَا۬»: its box is the whole ligature, whose middle is under
    // the lam's fatha.
    final inLigature =
        letter.isEmpty &&
        text.startsWith('ا', offset) &&
        RegExp('ل[ً-ْ]*\$').hasMatch(text.substring(0, offset));
    final center = Offset(
      squeeze *
          (HamzaReplacementMark.beforeAlif(letter, hamza, text, offset)
              ? box.right + diameter * .55
              : (box.left + box.right) / 2 - (inLigature ? fontSize * .30 : 0)),
      line.baseline +
          fontSize *
              (hamza.startsWith('ء')
                  ? -0.12
                  : HamzaReplacementMark.isBelow(hamza) ||
                        // The eased hamza with its kasra (أَئِنَّكُمۡ): under
                        // the seat, as the kasra is.
                        letter.isEmpty &&
                            hamza.startsWith('ئ') &&
                            hamza.contains('ِ')
                  ? 0.15
                  : letter.isEmpty && RegExp('^[ؤئ]').hasMatch(hamza)
                  ? -.48
                  // A bare seat after the small alif of the idkhal, Hafs's ya after it,
                  // above it, clear of that alif (أَٰاَ۬يْن).
                  : letter.isEmpty &&
                        text.startsWith('ا', offset) &&
                        text.substring(0, offset).endsWith('ٰ') &&
                        RegExp('^ا[^ي]*ي').hasMatch(text.substring(offset))
                  ? -1.0
                  : -0.83),
    );
    // The tasheel dot filled, as Warsh's (أَءِذَا، أَىِ۪مَّةَ); the circle of
    // the ibdal ringed round its letter.
    canvas.drawCircle(
      center,
      diameter / 2,
      letter.isEmpty
          ? (Paint()..color = color)
          : (Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.5, diameter * 0.065)),
    );
    if (letter.isNotEmpty) {
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
    }
    final vowel =
        RegExp('[َُِ]').firstMatch(text.substring(offset, end))?.group(0) ??
        RegExp('[َُِ]').firstMatch(hamza)?.group(0);
    if (vowel != null) {
      final below = vowel == 'ِ';
      final markSize = fontSize * 0.64;
      // Shape on an invisible alif: an isolated combining mark otherwise
      // acquires a dotted circle in fallback fonts.
      final mark = TextPainter(
        text: TextSpan(
          style: TextStyle(fontFamily: 'Hafs', fontSize: markSize, height: 1),
          children: [
            const TextSpan(
              text: 'ا',
              style: TextStyle(color: Colors.transparent),
            ),
            TextSpan(
              text: vowel,
              style: TextStyle(color: color),
            ),
          ],
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final baseline = mark.computeLineMetrics().single.baseline;
      // A fatha or damma stands clear of the circle: of the small tasheel
      // one (a damma touching it reads as a waw: أَءُلۡقِيَ), and of the one
      // with the ya or waw of ibdal (ٱلنِّسَآءِ أَوِ).
      final gap = below
          ? .10
          : letter.isEmpty
          ? .17
          : .30;
      final inkY =
          center.dy + (below ? 1 : -1) * (diameter / 2 + fontSize * gap);
      mark.paint(
        canvas,
        Offset(
          center.dx - mark.width / 2,
          inkY + (below ? -.16 : .93) * markSize - baseline,
        ),
      );
      mark.dispose();
    }
  }

  @override
  bool shouldRepaint(_ReplacementPainter old) =>
      text != old.text ||
      letter != old.letter ||
      style != old.style ||
      color != old.color ||
      offset != old.offset ||
      originalHamza != old.originalHamza ||
      textScaler != old.textScaler;
}

/// «ٱلَّــٰٓى۪» and «ٱلَّــٰٓيِٕ»: the tasheel dot, or the hamza with its kasra,
/// under the middle of the last ya, where the font sets it at the ya's start.
class YaBelowMark extends StatelessWidget {
  const YaBelowMark({
    super.key,
    required this.text,
    required this.style,
    required this.color,
    required this.builder,
  });

  final String text;
  final TextStyle style;
  final Color color;

  /// Builds the text with its ya bare, dotless as Hafs's final ya.
  final Widget Function(String text) builder;

  static final _end = RegExp(r'([يىی])([ِ۪ٕ]+)$');

  /// Whether [text] ends in a ya with the dot or the hamza under it.
  static bool applies(String text) =>
      _end.firstMatch(text)?[2]?.contains(RegExp('[۪ٕ]')) ?? false;

  static String seat(String text) => text.replaceFirstMapped(_end, (_) => 'ى');

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _YaBelowPainter(
      text,
      DefaultTextStyle.of(context).style.merge(style),
      color,
      MediaQuery.textScalerOf(context),
    ),
    child: builder(seat(text)),
  );
}

class _YaBelowPainter extends CustomPainter {
  _YaBelowPainter(this.text, this.style, this.color, this.textScaler);

  final String text;
  final TextStyle style;
  final Color color;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = YaBelowMark.seat(text);
    final painter = TextPainter(
      text: TextSpan(text: shown, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    var squeeze = 1.0;
    if (painter.computeLineMetrics().length > 1 && size.width > 0) {
      painter.layout();
      squeeze = size.width / painter.width;
    }
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: shown.length - 1, extentOffset: shown.length),
    );
    final lines = painter.computeLineMetrics();
    if (boxes.isEmpty || lines.isEmpty) {
      painter.dispose();
      return;
    }
    final box = boxes.first;
    final fontSize = textScaler.scale(style.fontSize ?? 14);
    final x = squeeze * (box.left + box.right) / 2;
    final baseline = lines.last.baseline;
    final marks = text.substring(shown.length);
    // Below the bowl of the ya, clear of its stroke.
    var top = baseline + fontSize * .38;
    if (marks.contains('۪')) {
      final r = fontSize * .08;
      canvas.drawCircle(Offset(x, top + r), r, Paint()..color = color);
      painter.dispose();
      return;
    }
    // The hamza, then its kasra under it; the hamza's ink lies low in its
    // line, so set higher than the dot.
    top -= fontSize * .08;
    final hamza = TextPainter(
      text: TextSpan(
        text: 'ء',
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: fontSize,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final ink = hamza.computeLineMetrics().single;
    // The hamza's ink sits on its baseline, about its ascent tall.
    final inkTop = ink.baseline - ink.ascent * .55;
    hamza.paint(canvas, Offset(x - hamza.width / 2, top - inkTop));
    top += ink.ascent * .55 + fontSize * .04;
    hamza.dispose();
    if (marks.contains('ِ')) {
      final kasra = TextPainter(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Hafs',
            fontSize: fontSize * .9,
            height: 1,
          ),
          children: [
            const TextSpan(
              text: 'ا',
              style: TextStyle(color: Colors.transparent),
            ),
            TextSpan(
              text: 'ِ',
              style: TextStyle(color: color),
            ),
          ],
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final line = kasra.computeLineMetrics().single;
      // A kasra hangs just under the alif's baseline.
      kasra.paint(
        canvas,
        Offset(x - kasra.width / 2, top - line.baseline - fontSize * .02),
      );
      kasra.dispose();
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_YaBelowPainter old) =>
      text != old.text ||
      style != old.style ||
      color != old.color ||
      textScaler != old.textScaler;
}
