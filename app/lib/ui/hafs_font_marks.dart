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
  static final _boundarySakt = RegExp(r'ۜ([اى]?[ً-ٰٟۖ-ۭ]*)(?=\s|$)');

  /// Reserve a narrow inter-word anchor for boundary sakt. Source spelling
  /// and semantics retain the original sign; internal al/شيء are untouched.
  static String boundarySpacing(String text) =>
      text.replaceAllMapped(_boundarySakt, (m) => '${m[1]}\u2009');

  static bool _raisedMadd(String cluster, String? previous) =>
      cluster.contains('ٓ') &&
      (cluster.contains('ٰ') ||
          cluster.contains('َ') ||
          cluster.startsWith('ا') && (previous?.contains('َ') ?? false));

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
      'بيئج'.contains(cluster[0]) && RegExp('[۪ٜ]').hasMatch(cluster) ||
      // عِمۡرٰ۪نَ: the font puts the sign on the ra's tail.
      cluster.startsWith('ر') && cluster.contains('ٰ') && cluster.contains('۪');

  /// The kasra (or kasratan) of a ya or waw with the hamza below it
  /// (وَرَآيِٕ، ٱللُّؤۡلُوِٕ، ٱمۡرِيٕٖ): the font draws it across the hamza; it
  /// is drawn apart, under the hamza.
  static final _kasras = RegExp('[ٍِٖ]');
  // Also on a kashida (Warsh's اَ۬لنَّبِيٓـِٕۧنَ): its hamza hangs below it.
  static bool _kasraUnderHamza(String cluster) =>
      (cluster.startsWith('ي') ||
          cluster.startsWith('و') ||
          cluster.startsWith('ـ')) &&
      cluster.contains('ٕ') &&
      _kasras.hasMatch(cluster);

  /// The iqlab mim drawn apart: the low one always, the high one only over
  /// a letter with a kasra (ءَايَٰتِۢ), whose anchor the font then moves into
  /// the letter. Over a letter without a vowel (مِنۢ، أَنۢبِئۡهُم) the font
  /// places it whole itself; drawn apart, its lower half was clipped.
  static bool _iqlabApart(String cluster) =>
      cluster.contains('ۭ') || cluster.contains('ۢ') && cluster.contains('ِ');

  static bool needsAdjustment(String text) =>
      _cluster.allMatches(text).any((m) => _iqlabApart(m[0]!)) ||
      _boundarySakt.hasMatch(text) ||
      _tanween.hasMatch(text) ||
      _needsClusterAdjustment(text);

  static bool _needsClusterAdjustment(String text) {
    String? previous;
    for (final m in _cluster.allMatches(text)) {
      final cluster = m[0]!;
      if (_raisedMadd(cluster, previous) ||
          _lowerImala(cluster) ||
          _kasraUnderHamza(cluster)) {
        return true;
      }
      previous = cluster;
    }
    return false;
  }

  static List<(String, Color?)> positionedParts(List<(String, Color?)> parts) {
    final chars = <(String, Color?)>[
      for (final (text, color) in parts)
        for (final c in text.split('')) (c, color),
    ];
    final source = chars.map((p) => p.$1).join();
    for (final m in _tanween.allMatches(source)) {
      // The offset fathatan (ikhfa', idgham: شَرّٗا يَرَهُۥ) stays on the
      // letter before the alef, as the mushaf writes it: the font has no
      // place for it on the alef.
      if ((m[1] ?? source[m.start + 1]) == 'ٗ') {
        if (m[1] == null) {
          final alef = chars[m.start];
          chars[m.start] = chars[m.start + 1];
          chars[m.start + 1] = alef;
        }
        continue;
      }
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
    String? previous;
    for (final m in _cluster.allMatches(full)) {
      if (_raisedMadd(m[0]!, previous)) {
        final at = full.indexOf('ٓ', m.start);
        marks[at] = placed[at].$2;
      }
      if (_lowerImala(m[0]!)) {
        final markAt = full.indexOf(RegExp('[۪ٜ]'), m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_kasraUnderHamza(m[0]!)) {
        final markAt = full.indexOf(_kasras, m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_iqlabApart(m[0]!)) {
        final markAt = full.indexOf(RegExp('[ۭۢ]'), m.start);
        marks[markAt] = placed[markAt].$2;
      }
      previous = m[0]!;
    }
    final sakt = {for (final m in _boundarySakt.allMatches(full)) m.start: m};
    if (marks.isEmpty && sakt.isEmpty) {
      return preserveText(builder(_joined(placed)));
    }
    final insertions = {for (final m in sakt.values) m.end: placed[m.start].$2};
    final chars = <(String, Color?)>[];
    final offsets = <int, int>{};
    final targets = <(int, Color?, String)>[];
    for (var i = 0; i <= placed.length; i++) {
      if (insertions.containsKey(i)) {
        targets.add((chars.length, insertions[i], 'ۜ'));
        chars.add(('\u2009', insertions[i]));
      }
      offsets[i] = chars.length;
      if (i < placed.length && !marks.containsKey(i) && !sakt.containsKey(i)) {
        chars.add(placed[i]);
      }
    }
    for (final entry in marks.entries) {
      for (final m in _cluster.allMatches(full)) {
        if (m.start <= entry.key && entry.key < m.end) {
          targets.add((offsets[m.start]!, entry.value, full[entry.key]));
        }
      }
    }
    final rendered = _joined(chars);
    return preserveText(
      CustomPaint(
        foregroundPainter: _QuranMarkPainter(
          rendered,
          targets,
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
      final sakt = sign == 'ۜ';
      final imala = sign == '۪' || sign == 'ٜ';
      final low = sign == 'ۭ';
      final kasra = HafsFontMarks._kasras.hasMatch(sign);
      final below = imala || kasra;
      // This font draws the low mim (ۭ) like the high one, on the tatweel:
      // both are drawn as the high mim, the low one moved below the letter.
      final iqlab = sign == 'ۢ' || low;
      final end = sakt
          ? at + 1
          : HafsFontMarks._cluster.matchAsPrefix(source, at)!.end;
      final boxes = text.getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: end),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      final line = text.computeLineMetrics().firstWhere(
        (l) => l.baseline >= box.top && l.baseline <= box.bottom,
      );
      if (sakt) {
        final mark = TextPainter(
          text: TextSpan(
            text: 'س',
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: font * .38,
              height: 1,
              color: color ?? style.color,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        mark.paint(
          canvas,
          Offset(
            (box.left + box.right - mark.width) / 2,
            line.baseline -
                font * .72 -
                mark.computeLineMetrics().single.baseline,
          ),
        );
        mark.dispose();
        continue;
      }
      final mark = TextPainter(
        text: TextSpan(
          text: imala
              ? 'ا۪'
              : iqlab
              ? 'ـۢ'
              : 'ا$sign',
          style: TextStyle(
            fontFamily: 'Hafs',
            fontSize: font,
            height: 1,
            color: color ?? style.color,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      // The madd of a lam-alif (إِلَّآ) over its alif, clear of the lam's
      // shadda and vowel.
      final lamAlif =
          sign == 'ٓ' &&
          source.startsWith('ا', at) &&
          RegExp(r'ل[ً-ْ]*$').hasMatch(source.substring(0, at));
      final origin = Offset(
        (box.left + box.right) / 2 -
            mark.width / 2 -
            (lamAlif ? font * .22 : 0),
        line.baseline -
            mark.computeLineMetrics().single.baseline +
            font *
                (imala
                    // Just under the ra's tail; close under the dotless ya
                    // of the dagger alif (دِيٰ۪رِهِمْ), below a dotted one's
                    // dots.
                    ? (source.startsWith('ر', at)
                          ? .28
                          : source.startsWith('ي', at) &&
                                (source.substring(at, end).contains('ٰ') ||
                                    source.startsWith('ـٰ', end))
                          ? .22
                          : .40)
                    : kasra
                    // The hamza hangs lower under the waw's tail.
                    ? (source.startsWith('و', at)
                          ? .50
                          : sign == 'ِ'
                          ? .36
                          : .44)
                    : below
                    ? .18
                    : low
                    ? .72
                    : iqlab
                    ? -.45
                    // The dagger alif on a final ى (عَلَىٰٓ) stands low.
                    : source.startsWith('ى', at) &&
                          source.substring(at, end).contains('ٰ')
                    ? .06
                    // Over the dagger alif: higher on the ra and waw, whose
                    // dagger alif stands higher (إِسۡرَٰٓءِيلَ، ٱلرِّبَوٰٓاْ), close
                    // on the others (يَٰٓأَيُّهَا، هَٰٓؤُلَآءِ).
                    : source.substring(at, end).contains('ٰ')
                    ? (RegExp('[رزو]').hasMatch(source[at]) ? -.22 : -.12)
                    : -.12),
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
                    font * .10
              : -font * 2,
          size.width + font,
          below
              ? size.height + font
              : origin.dy +
                    mark.computeLineMetrics().single.baseline -
                    font * (iqlab ? .22 : .68),
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
