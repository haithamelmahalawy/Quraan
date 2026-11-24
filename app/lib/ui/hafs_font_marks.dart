import 'package:flutter/material.dart';

/// The ishmam's sign put after its letter in a word's parts: a dot painted
/// over the letter, clear of its marks, in the ishmam's colour (the user,
/// 2026-11-22). A mark no Quran text uses, never drawn by the font.
const ishmamSign = 'ٚ';

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
  static final _boundarySakt = RegExp(
    // The kashida drawn out after it too (شَيۡۜـًٔۜــا, the user, 2026-11-18).
    r'ۜ(ـ*[اى]?[ً-ٰٟۖ-ۭ]*)(?:(?=\s|$)|(?<=(?:^|\s)اۜ))',
  );

  /// Reserve a narrow inter-word anchor for boundary sakt. Source spelling
  /// and semantics retain the original sign; internal al/شيء are untouched.
  static String boundarySpacing(String text) =>
      text.replaceAllMapped(_boundarySakt, (m) => '${m[1]}\u2009');

  static bool _raisedMadd(String cluster, String? previous) =>
      cluster.contains('ٓ') &&
      (cluster.contains('ٰ') ||
          cluster.contains('َ') ||
          cluster.startsWith('ا') && (previous?.contains('َ') ?? false) ||
          // Over the hamza of a lam-alif after the lam's sukun (ٱلۡأٓخِرَةِ):
          // the font squeezes it into a dash, a fatha to the eye.
          cluster.startsWith('أ') && (previous?.startsWith('ل') ?? false));

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

  /// The imala sign drawn apart under its letter, on every letter: written
  /// into the word it breaks the font's stacking of the letter's other marks
  /// (مُّسَمّٗى: its tanween dropped onto the ya), and on the ra's tail
  /// (عِمۡرٰ۪نَ) the font puts it astray.
  static bool _lowerImala(String cluster) => RegExp('[۪ٜ]').hasMatch(cluster);

  /// The kasra (or kasratan) of a ya or waw with the hamza below it
  /// (وَرَآيِٕ، ٱللُّؤۡلُوِٕ، ٱمۡرِيٕٖ): the font draws it across the hamza; it
  /// is drawn apart, under the hamza.
  static final _kasras = RegExp('[ٍِٖ]');
  // Also on a kashida (Warsh's اَ۬لنَّبِيٓـِٕۧنَ): its hamza hangs below it.
  static bool _kasraUnderHamza(String cluster) =>
      (cluster.startsWith('ي') ||
              cluster.startsWith('و') ||
              cluster.startsWith('ـ') ||
              cluster.startsWith('ى')) &&
          cluster.contains('ٕ') &&
          _kasras.hasMatch(cluster) ||
      // The eased hamza's tooth with the tasheel dot under it (أَىِ۪مَّةَ).
      cluster.startsWith('ى') &&
          cluster.contains('۪') &&
          _kasras.hasMatch(cluster);

  /// The kasra under the ha of the Name after its doubled lam (لِلَّهِ،
  /// بِٱللَّهِ): the font sets it against the ha's foot, cut short; it is
  /// drawn apart, whole, under it (the user, 2026-11-19).
  static bool _kasraUnderNameHa(String cluster, String? previous) =>
      cluster.startsWith('ه') &&
      cluster.contains('ِ') &&
      (previous?.startsWith('ل') ?? false) &&
      previous!.contains('ّ');

  /// The iqlab mim drawn apart: the low one always, the high one only over
  /// a letter with a kasra (ءَايَٰتِۢ), whose anchor the font then moves into
  /// the letter. Over a letter without a vowel (مِنۢ، أَنۢبِئۡهُم) the font
  /// places it whole itself; drawn apart, its lower half was clipped.
  /// The stop sign over an alif with the tanween (قَلِيلاًۖ، عَلِيمًاۗ): the
  /// font sets it on the tanween; it is raised clear of it.
  static final _waqf = RegExp('[ۖ-ۛ]');
  static bool _waqfOverTanween(String cluster) =>
      cluster.startsWith('ا') &&
      cluster.contains('ً') &&
      _waqf.hasMatch(cluster);

  /// The stop sign over the madd of a dagger alif on a final ى (بَلَىٰٓۚ): the
  /// madd is raised, across the sign; the sign is raised clear of it.
  static bool _waqfOverMadd(String cluster) =>
      cluster.startsWith('ى') &&
      cluster.contains('ٰ') &&
      cluster.contains('ٓ') &&
      _waqf.hasMatch(cluster);

  /// The dagger alif after an eased hamza's alif (ءَا۬ـٰمَنتُم): drawn on its
  /// own between the alif and the next letter, without the kashida that
  /// carries it in the text.
  static bool _daggerApart(String cluster, String? previous) =>
      cluster.startsWith('ـ') &&
      cluster.contains('ٰ') &&
      (previous?.startsWith('ا') ?? false) &&
      previous!.contains('۬');

  /// The dagger alif of a fa with a shadda and the imala sign (ٱلۡغَفّٰ۪رِ, غافر
  /// 42): the font sets it across the shadda; it stands between the fa and
  /// the next letter.
  static bool _daggerOffShadda(String cluster) =>
      cluster.startsWith('ف') &&
      cluster.contains('ّ') &&
      cluster.contains('ٰ') &&
      cluster.contains('۪');

  /// The fatha moved onto a bare alif by the naql (إِنَ اَنَا۠): the font sets
  /// it on the alif's head, against the fatha of the word before; it is
  /// raised over it.
  static bool _naqlFatha(String cluster) =>
      cluster.startsWith('ا') &&
      cluster.contains('َ') &&
      !cluster.contains('ٰ') &&
      !cluster.contains('ٓ');

  /// The second hamza eased after the first (أَ۟ذَا، أَ۟نَّكَ): Warsh's text
  /// writes it as a ringed dot; the tasheel dot alone takes its place.
  /// After a naql the first hamza's seat is a bare alif with the fatha, the
  /// dot after it (حَاجِزًا اَ۟لَٰهٞ); on a wasl alif (اَ۟ذْكُرُواْ) the ring stays.
  static bool _easedDot(String cluster, String? next) =>
      RegExp('^[أإ]').hasMatch(cluster) && cluster.contains('۟') ||
      cluster == '\u0627\u064e\u06df' &&
          next != null &&
          (next.contains('\u064e') && !next.contains('\u0651') ||
              // \u0627\u064e\u06df\u0646\u0632\u0650\u0644\u064e\u060c \u0627\u064e\u06df\u0644\u0652\u0642\u0650\u064a\u064e\u060c \u0627\u064e\u06df\u0634\u0652\u0647\u0650\u062f\u064f\u0648\u0627\u0652; the rest are shown as a hamzat wasl.
              const {'\u0646', '\u0644\u06e1', '\u0634\u06e1'}.contains(next));

  /// The small waw of a madd on a kashida (لِيَسُـۥٓـُٔواْ): the font joins
  /// nothing across it and sets it on the line. The kashida and the waw are
  /// left out, the sin joined to the hamza's seat, and the waw with its madd
  /// drawn high over where they join.
  static bool _smallWawApart(String cluster) => cluster == 'ـۥٓ';

  /// The hamza over a lam-alif, the madd alif after it unwritten (ٱلۡأَخِرَةِ،
  /// لَأَيَةٗ): the lam-alif is written bare and the hamza with its fatha drawn
  /// apart, a little to the right of where the font sets it.
  /// Not a short hamza before a long a (ٱلۡأَمَانِيُّ، ٱلۡأَمَٰنَٰتِ): its hamza
  /// stands on the alif, as in ٱلۡأَرۡضِ.
  static bool _lamHamzaApart(String cluster, String? previous, String after) {
    final next = _cluster.matchAsPrefix(after)?[0];
    return cluster == 'أَ' &&
        (previous?.startsWith('ل') ?? false) &&
        next != null &&
        RegExp('[ً-ِ]').hasMatch(next) &&
        !RegExp('^مَ[اٰ]').hasMatch(after);
  }

  /// The dagger alif of a ta with its madd (طَٰٓئِفٞ، الأعراف ٢٠١): the font
  /// sets it over the ta; it stands beside it, at its left, the madd on it.
  static bool _daggerBesideTa(String cluster) =>
      cluster.startsWith('ط') && cluster.contains('ٰ') && cluster.contains('ٓ');

  /// The shadda over the small ya on one tooth (وَلِـِّۧيَ، الأعراف ١٩٦): the font
  /// sets it across the small ya; it is drawn apart, above it.
  static bool _shaddaOverSmallYa(String cluster) =>
      cluster.startsWith('ـ') && cluster.contains('ۧ') && cluster.contains('ّ');

  /// The small low seen under the sad (ٱلۡمُصَۣيۡطِرُونَ): the font has no
  /// glyph for it; a small sin is painted under the letter.
  static bool _lowSeen(String cluster) => cluster.contains('ۣ');

  static bool _iqlabApart(String cluster) =>
      cluster.contains('ۭ') ||
      cluster.contains('ۢ') &&
          (cluster.contains('ِ') ||
              // Over the za's stem (مَّحۡفُوظُۢ): moved off it, to its left.
              cluster.startsWith('ظ'));

  static bool needsAdjustment(String text) =>
      _cluster.allMatches(text).any((m) => _iqlabApart(m[0]!)) ||
      _boundarySakt.hasMatch(text) ||
      // The sakt within a word (ٱلۡۜأَرۡضِ), painted clear of the letter's marks.
      text.contains('ۜ') ||
      _tanween.hasMatch(text) ||
      text.contains(ishmamSign) ||
      _needsClusterAdjustment(text);

  static bool _needsClusterAdjustment(String text) {
    String? previous;
    for (final m in _cluster.allMatches(text)) {
      final cluster = m[0]!;
      if (_lamHamzaApart(cluster, previous, text.substring(m.end)) ||
          _raisedMadd(cluster, previous) ||
          _lowerImala(cluster) ||
          _lowSeen(cluster) ||
          _kasraUnderHamza(cluster) ||
          _kasraUnderNameHa(cluster, previous) ||
          _waqfOverTanween(cluster) ||
          _waqfOverMadd(cluster) ||
          _naqlFatha(cluster) ||
          _easedDot(cluster, _cluster.matchAsPrefix(text, m.end)?[0]) ||
          _smallWawApart(cluster) ||
          _daggerApart(cluster, previous) ||
          _daggerOffShadda(cluster) ||
          _shaddaOverSmallYa(cluster) ||
          _daggerBesideTa(cluster)) {
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
      // Each keeps its own colour: the tanween may be told alone (مَحْظُوراً).
      final color = chars[m.start + (m[1] == null ? 1 : 0)].$2;
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
    final thin = <int>{};
    final dots = <int>{};
    // The kashida carrying a small waw drawn apart, with the waw's colour.
    final waws = <int, Color?>{};
    final dropped = <int>{};
    // The hamzas drawn apart, their seats written as a bare alif.
    final seats = <int>{};
    String? previous;
    for (final m in _cluster.allMatches(full)) {
      if (_lamHamzaApart(m[0]!, previous, full.substring(m.end))) {
        seats.add(m.start);
        dropped.add(m.start + 1);
      }
      if (_raisedMadd(m[0]!, previous)) {
        final at = full.indexOf('ٓ', m.start);
        marks[at] = placed[at].$2;
      }
      if (_lowerImala(m[0]!)) {
        final markAt = full.indexOf(RegExp('[۪ٜ]'), m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_lowSeen(m[0]!)) {
        final markAt = full.indexOf('ۣ', m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (m[0]!.contains(ishmamSign)) {
        final markAt = full.indexOf(ishmamSign, m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_kasraUnderHamza(m[0]!) || _kasraUnderNameHa(m[0]!, previous)) {
        final markAt = full.indexOf(_kasras, m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_waqfOverTanween(m[0]!) || _waqfOverMadd(m[0]!)) {
        final markAt = full.indexOf(_waqf, m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_naqlFatha(m[0]!)) {
        final markAt = full.indexOf('َ', m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_easedDot(m[0]!, _cluster.matchAsPrefix(full, m.end)?[0])) {
        dots.add(full.indexOf('۟', m.start));
      }
      if (_smallWawApart(m[0]!)) {
        // Kept by the seat after it, drawn at its join with the sin.
        waws[m.end] = placed[m.start + 1].$2;
        dropped.addAll([m.start, m.start + 1, m.start + 2]);
      }
      if (_iqlabApart(m[0]!)) {
        final markAt = full.indexOf(RegExp('[ۭۢ]'), m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_daggerApart(m[0]!, previous)) {
        final markAt = full.indexOf('ٰ', m.start);
        marks[markAt] = placed[markAt].$2;
        thin.add(m.start);
      }
      if (_daggerOffShadda(m[0]!)) {
        final markAt = full.indexOf('ٰ', m.start);
        marks[markAt] = placed[markAt].$2;
      }
      if (_daggerBesideTa(m[0]!)) {
        for (final sign in ['ٰ', 'ٓ']) {
          final markAt = full.indexOf(sign, m.start);
          marks[markAt] = placed[markAt].$2;
        }
      }
      if (_shaddaOverSmallYa(m[0]!)) {
        final markAt = full.indexOf('ّ', m.start);
        marks[markAt] = placed[markAt].$2;
      }
      previous = m[0]!;
    }
    final sakt = {for (final m in _boundarySakt.allMatches(full)) m.start: m};
    // Abu Ja'far's sakt drawn out between two letters (الٓـۜـمٓۜ): painted over
    // its kashida, at the height of the one after the last letter.
    for (final m in RegExp('(?<=ـ)ۜ').allMatches(full)) {
      if (!sakt.containsKey(m.start)) marks[m.start] = placed[m.start].$2;
    }
    // The sakt within a word (ٱلۡۜأَرۡضِ، شَيۡۜءٍ): painted before its hamza, clear
    // of the letter's sukun and of the hamza after it, not left to the font
    // (the user, 2026-11-17). Not the sin over the sad (وَيَبۡصُۜطُ، بَصۜۡطَةٗ),
    // the word's own letter, no sakt: the font's, larger, right over it (the
    // user, 2026-11-18).
    for (final m in RegExp('(?<!ص[ً-ْۡ]*)ۜ').allMatches(full)) {
      if (!sakt.containsKey(m.start)) marks[m.start] = placed[m.start].$2;
    }
    if (marks.isEmpty &&
        sakt.isEmpty &&
        dots.isEmpty &&
        waws.isEmpty &&
        seats.isEmpty) {
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
      if (dots.contains(i)) {
        // The ringed dot's room, for the dot painted alone.
        targets.add((chars.length, placed[i].$2, '•'));
        chars.add((' ', placed[i].$2));
      } else if (i < placed.length &&
          !dropped.contains(i) &&
          !marks.containsKey(i) &&
          !sakt.containsKey(i)) {
        // The kashida under a dagger alif drawn apart: a thin space.
        chars.add(
          thin.contains(i)
              ? (' ', placed[i].$2)
              : seats.contains(i)
              ? ('ا', placed[i].$2)
              : placed[i],
        );
      }
    }
    for (final entry in marks.entries) {
      for (final m in _cluster.allMatches(full)) {
        if (m.start <= entry.key && entry.key < m.end) {
          targets.add((offsets[m.start]!, entry.value, full[entry.key]));
        }
      }
    }
    for (final at in seats) {
      targets.add((offsets[at]!, placed[at].$2, 'ٔ'));
    }
    for (final MapEntry(:key, :value) in waws.entries) {
      targets.add((offsets[key]!, value, 'ۥ'));
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

/// The hamza drawn apart over a lam-alif, in font sizes: how far right of its
/// alif, how high over the line, and where the ink of its own alif is clipped.
const lamHamzaShift = -.02;
const lamHamzaRise = -.10;
const lamHamzaClip = .70;

/// The small sin of the sakt: its size, and how high its baseline stands
/// after a word, over a tall letter and over a short one, in font sizes.
const saktSize = .24;
const saktRise = .72;
const saktOverTall = 1.10;
const saktOverShort = .84;

/// Over the lam and its sukun before a kashida (ءَآلۡۜـَٰٔنَ).
const saktOverLam = 1.0;

/// And how far left of the lam, in the sin's widths: off the madda over it.
const saktLeftOfLam = .6;

/// Over the hamza on its alif and its vowel (ٱلۡۜأَرۡضِ).
const saktOverHamza = 1.20;

/// And moved toward that hamza, off the lam before it.
const saktTowardHamza = .11;

/// Higher over a madd on that hamza.
const saktOverMadd = .12;

/// How far the sin after a word stands clear of its last letter.
const saktGap = .05;

/// How far the kasra under the ha of the Name stands, in font sizes.
const nameHaKasraDrop = .08;

/// And how far right of the ha's middle, in font sizes.
const nameHaKasraShift = .07;

/// The ishmam's dot over its letter: its radius, and how high its centre
/// stands over the line, in font sizes: over a short letter, one with dots
/// above, a tall one, and higher over a vowel, shadda or sukun above it.
const ishmamRadius = .065;
const ishmamOverShort = .76;
const ishmamOverDots = .80;
const ishmamOverTall = 1.08;
const ishmamOverMark = .30;

/// How far under the line the imala sign stands, in font sizes; under a jim.
const imalaDrop = .20;

/// How far right of its box the imala sign stands under a dal before a final
/// ya, in font sizes (ٱلۡهُدَ۪ىٰ).
const imalaDalBeforeYa = .08;

/// How far under the line the imala sign stands under that dal.
const imalaDalBeforeYaDrop = .08;

/// The small sin under the sad (ٱلۡمُصَۣيۡطِرُونَ): its size, how far under the
/// line its baseline stands, and how far right of the sad's middle, in font
/// sizes.
const lowSeenSize = .42;
const lowSeenDrop = .22;
const lowSeenShift = .0;

/// Under the jim's dot, raised a little off the line below (جَ۪آءَ, the user,
/// 2026-11-14).
const imalaUnderJim = .26;

/// How low the dagger alif beside a ta stands, and its madd, in font sizes.
const taDaggerDrop = .30;
const taDaggerMaddDrop = -.02;

/// How high the shadda over a small ya stands, in font sizes (negative: up).
const shaddaOverSmallYaLift = -.10;

/// How high the small waw of a madd stands over the line, in font sizes.
const smallWawRise = .55;

/// How far its madd stands over the waw's baseline, in font sizes.
const smallWawMaddLift = -.45;

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
    final taDaggers = {
      for (final (at, _, sign) in targets)
        if (sign == 'ٰ' && source.startsWith('ط', at)) at,
    };
    for (final (at, color, sign) in targets) {
      final sakt = sign == 'ۜ';
      final imala = sign == '۪' || sign == 'ٜ';
      final kasra = HafsFontMarks._kasras.hasMatch(sign);
      final below = imala || kasra;
      // The sakt after a word or on a kashida: its own room; over a letter,
      // the letter with its marks.
      final end = sakt && (source[at] == ' ' || source[at] == 'ـ')
          ? at + 1
          : HafsFontMarks._cluster.matchAsPrefix(source, at)!.end;
      // The mim beside the hamza and the kasra under it (ٱمۡرِيِٕۭ), not across.
      final besideHamza =
          (sign == 'ۭ' || sign == 'ۢ') &&
          source.substring(at, end).contains('ٕ');
      final low = sign == 'ۭ' || besideHamza;
      // This font draws the low mim (ۭ) like the high one, on the tatweel:
      // both are drawn as the high mim, the low one moved below the letter.
      final iqlab = sign == 'ۢ' || low;
      final boxes = text.getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: end),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      final line = text.computeLineMetrics().firstWhere(
        (l) => l.baseline >= box.top && l.baseline <= box.bottom,
      );
      if (sign == ishmamSign) {
        final cluster = source.substring(at, end);
        final tall = RegExp('^[اأإآلكطظ]').hasMatch(cluster);
        final dotted = RegExp('^[قغضفنتثشخذزظ]').hasMatch(cluster);
        // Over the vowel, shadda or sukun above the letter too.
        final marked = RegExp('[َُّْٰۡٓ]').hasMatch(cluster);
        final rise =
            (tall
                ? ishmamOverTall
                : dotted
                ? ishmamOverDots
                : ishmamOverShort) +
            (marked ? ishmamOverMark : 0);
        canvas.drawCircle(
          Offset((box.left + box.right) / 2, line.baseline - font * rise),
          font * ishmamRadius,
          Paint()..color = color ?? style.color ?? Colors.black,
        );
        continue;
      }
      if (sign == '•') {
        canvas.drawCircle(
          Offset((box.left + box.right) / 2, line.baseline - font * .10),
          font * .10,
          Paint()..color = color ?? style.color ?? Colors.black,
        );
        continue;
      }
      if (sign == 'ٔ') {
        final hamza = TextPainter(
          text: TextSpan(
            text: 'أَ',
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: font,
              height: 1,
              color: color ?? style.color,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        final baseline = line.baseline - font * lamHamzaRise;
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(
            -font,
            -font * 2,
            size.width + font,
            baseline - font * lamHamzaClip,
          ),
        );
        hamza.paint(
          canvas,
          Offset(
            (box.left + box.right - hamza.width) / 2 + font * lamHamzaShift,
            baseline - hamza.computeLineMetrics().single.baseline,
          ),
        );
        canvas.restore();
        hamza.dispose();
        continue;
      }
      if (sign == 'ۥ') {
        // The waw, then its madd over it from an alif whose ink is clipped
        // away, as the other marks are drawn.
        TextPainter painter(String text) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: font,
              height: 1,
              color: color ?? style.color,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        final waw = painter('ۥ'), madd = painter('آ');
        final baseline = line.baseline - font * smallWawRise;
        waw.paint(
          canvas,
          Offset(
            (box.left + box.right - waw.width) / 2,
            baseline - waw.computeLineMetrics().single.baseline,
          ),
        );
        final maddBaseline = baseline - font * smallWawMaddLift;
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(
            -font,
            -font * 2,
            size.width + font,
            maddBaseline - font * .70,
          ),
        );
        madd.paint(
          canvas,
          Offset(
            (box.left + box.right - madd.width) / 2,
            maddBaseline - madd.computeLineMetrics().single.baseline,
          ),
        );
        canvas.restore();
        waw.dispose();
        madd.dispose();
        continue;
      }
      if (sign == 'ۣ') {
        final mark = TextPainter(
          text: TextSpan(
            text: 'س',
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: font * lowSeenSize,
              height: 1,
              color: color ?? style.color,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        mark.paint(
          canvas,
          Offset(
            (box.left + box.right - mark.width) / 2 + font * lowSeenShift,
            line.baseline +
                font * lowSeenDrop -
                mark.computeLineMetrics().single.baseline,
          ),
        );
        mark.dispose();
        continue;
      }
      if (sakt) {
        final mark = TextPainter(
          text: TextSpan(
            text: 'س',
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: font * saktSize,
              height: 1,
              color: color ?? style.color,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        // Right before the hamza (the user, 2026-11-18): after the word, in its
        // own room, clear of the word's last letter (خَلَوۡاْۜ، عَذَابٌۜ); within
        // it, between its quiet letter and the hamza (ٱلۡۜأَرۡضِ، شَيۡۜءٍ), above
        // the taller of the two.
        final over = source[at];
        final after = end < source.length ? source[end] : '';
        // The article's lam before a kashida carrying the hamza and its marks
        // (ءَآلۡۜـَٰٔنَ): right over the lam and its sukun, clear of them (the
        // user, 2026-11-23).
        final overLam = over == 'ل' && after == 'ـ';
        final rise = overLam
            ? saktOverLam
            : over == ' ' || over == 'ـ'
            ? saktRise
            : 'أآ'.contains(after)
            // And the madd over it (ٱلۡۜأٓخِرَةِ), clear of it too.
            ? saktOverHamza +
                  (targets.any((t) => t.$1 == end && t.$3 == 'ٓ')
                      ? saktOverMadd
                      : 0)
            : 'اأإآلكطظ'.contains(over) || 'اأإآلكطظ'.contains(after)
            ? saktOverTall
            : saktOverShort;
        final x = over == ' '
            ? box.right - mark.width - font * saktGap
            : overLam
            ? box.left - mark.width * saktLeftOfLam
            : over == 'ـ'
            ? (box.left + box.right - mark.width) / 2
            : box.left -
                  mark.width / 2 -
                  // Near the hamza, off the lam (the user, 2026-11-18).
                  ('أإآ'.contains(after) ? font * saktTowardHamza : 0);
        mark.paint(
          canvas,
          Offset(
            x,
            line.baseline -
                font * rise -
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
      final lamHamza =
          sign == 'ٓ' &&
          source.startsWith('أ', at) &&
          RegExp(r'ل[ً-ْۡ]*$').hasMatch(source.substring(0, at));
      final lamAlif =
          sign == 'ٓ' &&
          source.startsWith('ا', at) &&
          RegExp(r'ل[ً-ْ]*$').hasMatch(source.substring(0, at));
      // The madd of a lam's dagger alif (أُوْلَٰٓئِكَ، مَلَٰٓئِكَةُ) over the
      // dagger alif, which stands low beside the lam's stem, not over it.
      final dagger = sign == 'ٓ' && source.substring(at, end).contains('ٰ');
      final lamDagger = dagger && source.startsWith('ل', at);
      // So on a ra (أَرَٰٓيْتَكُمْ، إِسۡرَٰٓءِيلَ): over its dagger alif, past
      // the ra's fatha.
      final raDagger = dagger && source.startsWith('ر', at);
      // So on a kaf (وَمِيكَٰٓئِلَ): over its dagger alif, not the kaf's stem.
      final kafDagger = dagger && source.startsWith('ك', at);
      // So on a ha (تَحَٰٓضُّونَ، أَتُحَٰٓجُّوٓنِّي): further left, over its dagger alif.
      final haDagger = dagger && source.startsWith('ح', at);
      // On the others with a fatha (أَتُحَٰٓجُّوٓنِّي، هَٰٓأَنتُمۡ) the dagger
      // alif stands after it, to its left: so its madd.
      final fathaDagger =
          dagger &&
          !source.startsWith('ى', at) &&
          source.substring(at, end).contains('َ');
      final daggerOffShadda = sign == 'ٰ' && source.startsWith('ف', at);
      // The dagger alif beside the ta, and its madd over it (طَٰٓئِفٞ).
      final taDagger = (sign == 'ٰ' || sign == 'ٓ') && taDaggers.contains(at);
      // The shadda over the small ya on its tooth (وَلِـِّۧيَ).
      final shaddaOverYa =
          sign == 'ّ' && source.substring(at, end).contains('ۧ');
      final waqfOverMadd =
          HafsFontMarks._waqf.hasMatch(sign) &&
          source.startsWith('ى', at) &&
          source.substring(at, end).contains('ٓ');
      final origin = Offset(
        (daggerOffShadda || taDagger ? box.left : (box.left + box.right) / 2) -
            mark.width / 2 -
            (besideHamza
                ? font * .20
                // Under the dal before a final ya (ٱلۡهُدَ۪ىٰ, هُد۪ٗى): its
                // box shares the ya's sweep, the sign under the dal itself
                // (the user, 2026-11-21).
                : imala &&
                      'دذ'.contains(source[at]) &&
                      source.startsWith('ى', end)
                ? -font * imalaDalBeforeYa
                // The low mim under a ra with its kasra (جُدُرِۭ): to its left,
                // clear of the kasra.
                : low && RegExp('[رز]').hasMatch(source[at])
                ? font * .16
                // The high mim over the za, off its stem.
                : iqlab && !low && source.startsWith('ظ', at)
                ? font * .08
                : lamAlif
                ? font * .22
                : lamDagger
                ? font * .16
                : raDagger
                ? font * .12
                : kafDagger
                ? font * .27
                : haDagger
                ? font * .16
                : fathaDagger
                ? font * .08
                // The dagger alif of a final ى (عَلَىٰٓ) stands at its left,
                // past the fatha of the letter before.
                : dagger && source.startsWith('ى', at)
                ? font * .12
                : kasra && source.startsWith('ه', at)
                ? -font * nameHaKasraShift
                : 0),
        line.baseline -
            mark.computeLineMetrics().single.baseline +
            font *
                (imala
                    // Just under the ra's tail; close under the dotless ya
                    // of the dagger alif (دِيٰ۪رِهِمْ), below a dotted one's
                    // dots.
                    ? (source.startsWith('ر', at)
                          ? .28
                          // Under the kaf's body (كٰ۪فِرِينَ), not its dagger alif.
                          : source.startsWith('ك', at)
                          ? .10
                          : source.startsWith('ي', at) &&
                                (source.substring(at, end).contains('ٰ') ||
                                    source.startsWith('ـٰ', end))
                          ? .22
                          // Close under the ba's dot (صَبّ۪ارٖ).
                          : source.startsWith('ب', at)
                          ? .24
                          // Clear of the kasra of the letter before (فَنِع۪مَّا).
                          : source.startsWith('ع', at) &&
                                RegExp('ِ[ً-ْ]*\$')
                                    .hasMatch(source.substring(0, at))
                          ? .56
                          // Under the jim's dot (جَ۪آءَتۡهُمُ), a dotted ya's
                          // dots (دِيَ۪ارِكُمۡ).
                          // Up under the dal, off the final ya's sweep below it
                          // (ٱلۡهُدَ۪ىٰ, the user, 2026-11-21).
                          : 'دذ'.contains(source[at]) &&
                                source.startsWith('ى', end)
                          ? imalaDalBeforeYaDrop
                          : source.startsWith('ج', at)
                          ? imalaUnderJim
                          : source.startsWith('ي', at)
                          ? .34
                          // Close under a letter with no dots below, a little
                          // under one with them (the user, 2026-11-13).
                          : imalaDrop)
                    : kasra
                    // The hamza hangs lower under the waw's tail.
                    ? (source.startsWith('و', at)
                          ? .50
                          // Under the ha of the Name, clear of its foot.
                          : source.startsWith('ه', at)
                          ? nameHaKasraDrop
                          // Under the tasheel dot on its tooth (أَىِ۪مَّةَ).
                          : source.startsWith('ى', at)
                          ? .30
                          // Raised a little under the ya's hamza (ٱلَّــٰٓيِٕ),
                          // clear of the line below.
                          : sign == 'ِ' && source.startsWith('ي', at)
                          ? .28
                          : sign == 'ِ'
                          ? .36
                          : .44)
                    : below
                    ? .18
                    : besideHamza
                    ? .52
                    : low
                    ? .72
                    : iqlab
                    ? -.45
                    // The dagger alif standing apart (ءَاٰ۬مَنتُم): low, beside
                    // the letters.
                    : waqfOverMadd
                    ? -.52
                    : taDagger
                    ? (sign == 'ٰ' ? taDaggerDrop : taDaggerMaddDrop)
                    : daggerOffShadda
                    ? .32
                    : sign == 'ٰ'
                    ? .42
                    // The dagger alif on a final ى (عَلَىٰٓ) stands low.
                    : source.startsWith('ى', at) &&
                          source.substring(at, end).contains('ٰ')
                    ? .06
                    // Over the dagger alif: higher on the ra and waw, whose
                    // dagger alif stands higher (إِسۡرَٰٓءِيلَ، ٱلرِّبَوٰٓاْ), close
                    // on the others (يَٰٓأَيُّهَا، هَٰٓؤُلَآءِ).
                    : source.substring(at, end).contains('ٰ')
                    ? (lamDagger
                          ? -.10
                          : raDagger
                          ? -.10
                          // Over a dagger alif on a full alif (آٰللَّهُ), which
                          // stands at the alif's top.
                          : source.startsWith('ا', at)
                          ? -.42
                          : RegExp('[رزو]').hasMatch(source[at])
                          ? -.22
                          : -.12)
                    // Above the small ya, clear of it.
                    : shaddaOverYa
                    ? shaddaOverSmallYaLift
                    // The naql's fatha, over the alif's head.
                    : sign == 'َ'
                    ? -.16
                    // Above the hamza of the lam-alif (ٱلۡأٓخِرَةِ).
                    : lamHamza
                    ? -.30
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
                    font *
                        (low
                            ? .12
                            : iqlab
                            ? .22
                            : .68),
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

/// The small alif under the hamza of «فَٱدَّٰرَأۡتُمۡ», as the Madinah print writes
/// it: the Hafs font has no such letter, and a dagger alif would stand on the
/// ra. Its share of the word's size; only here, not in «قَرَأۡتَ».
const smallHamzaAlifScale = .6;
final _smallHamzaAlif = RegExp('(?<=د[َّ]+ٰرَ)أ[ْۡ]?');

/// [parts] with the small alif told apart, each with whether it is small; null
/// when the word has none.
List<(String, Color?, bool)>? smallHamzaAlifParts(
  List<(String, Color?)> parts,
) {
  final match = _smallHamzaAlif.firstMatch(parts.map((p) => p.$1).join());
  if (match == null) return null;
  final out = <(String, Color?, bool)>[];
  var at = 0;
  for (final (text, color) in parts) {
    final end = at + text.length;
    final from = match.start.clamp(at, end) - at;
    final to = match.end.clamp(at, end) - at;
    if (from > 0) out.add((text.substring(0, from), color, false));
    if (to > from) out.add((text.substring(from, to), color, true));
    if (to < text.length) out.add((text.substring(to), color, false));
    at = end;
  }
  return out;
}

/// The text as the Hafs font can draw it: the small low seen under the sad
/// (ٱلۡمُصَۣيۡطِرُونَ) has no glyph in it, and would show as a dotted circle.
/// Only what is drawn; the Quran text itself keeps the mark.
String hafsDrawable(String text) =>
    hafsDrawableKeepingLowSeen(text).replaceAll('ۣ', '');

/// [hafsDrawable] for a word drawn through [HafsFontMarks], which paints the
/// small low seen itself, a small sin under the sad (حفص وخلاد، the user,
/// 2026-11-17).
String hafsDrawableKeepingLowSeen(String text) =>
    text
    // ٱلَّٰٓـِٔي: the dagger alif and its madd on the lam crowd its shadda and
    // fatha. Drawn out, they stand apart between the lam and the hamza.
    .replaceAll('لَّٰٓ', 'لَّــٰٓ');
