import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'mushaf_decor.dart';
import '../services/qcf_fonts.dart';
import 'mushaf_lines.dart';
import 'theme.dart';

typedef WordTap = void Function(Ayah ayah, int word);

/// One mushaf page: Hafs text with the selected riwayat's differences
/// applied according to [ReaderSettings.mode], and mutashabihat underlined.
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.page,
    required this.quran,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
    required this.onWordTap,
    this.showHamesh = true,
    this.onZoomChanged,
    this.onPageNumberTap,
    this.focus,
    this.qcf = false,
  });

  final int page;
  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;
  final WordTap onWordTap;

  /// False in full-screen reading: the page alone, words still coloured.
  final bool showHamesh;

  /// Told when the page is zoomed in (so turning pages pauses) or back.
  final ValueChanged<bool>? onZoomChanged;

  /// Tapping the page number (opens the page picker).
  final VoidCallback? onPageNumberTap;

  /// The mutashabih word chosen for the double blink (VariantRepository.key).
  final int? focus;

  /// Draw with the QCF V2 font of this page (it is loaded).
  final bool qcf;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

/// One hamesh entry: a Hafs word (or words), coloured as on the page, and
/// how the selected riwayat read it.
class HameshEntry {
  HameshEntry(this.ayah, this.word, this.hafs, this.color, this.readings);

  final Ayah ayah;
  final int word;
  final String hafs;
  final Color color;
  final List<Variant> readings;
}

class _MushafPageState extends State<MushafPage> {
  final _recognizers = <TapGestureRecognizer>[];

  /// How many hamesh notes fit beside the page (the rest go below it),
  /// measured after layout for [_splitFor].
  int? _split;
  String? _splitFor;

  /// Pinch zoom of the page.
  final _zoom = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed == _zoomed) return;
      setState(() => _zoomed = zoomed);
      widget.onZoomChanged?.call(zoomed);
    });
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _zoom.dispose();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final ayahs = widget.quran.page(widget.page);
    final s = widget.settings;
    final narrow = MediaQuery.sizeOf(context).width < 600;

    // Every mode but inline keeps the printed lines of the Madinah mushaf;
    // a riwaya shown in full (replace) uses the same pages and lines as Hafs.
    // Inline adds text to the lines, so it flows instead.
    final lines = widget.quran.lines(widget.page);
    final printed = lines != null && s.mode != DisplayMode.inline;

    return LayoutBuilder(builder: (context, viewport) {
      final content = printed
          ? _printedPage(ayahs, lines, viewport.biggest, narrow)
          : SingleChildScrollView(
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              child: _PageFrame(
                page: widget.page,
                onNumberTap: widget.onPageNumberTap,
                child: _flowingText(ayahs, narrow),
              ),
            );
      // Pinch zooms the whole page image: frame, text and hamesh together.
      return Stack(
        children: [
          InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 4,
            panEnabled: _zoomed,
            child: SizedBox.fromSize(size: viewport.biggest, child: content),
          ),
          if (_zoomed)
            PositionedDirectional(
              bottom: 12,
              end: 12,
              child: FilledButton.tonalIcon(
                onPressed: () => _zoom.value = Matrix4.identity(),
                icon: const Icon(Icons.zoom_out_map, size: 18),
                label: const Text('حجم الصفحة'),
              ),
            ),
        ],
      );
    });
  }

  /// The printed page filling the screen: the header line (surah, juz), the
  /// framed 15 lines spread over the height, and the hamesh beside it with
  /// each note level with its line. Notes that do not fit continue below,
  /// and the page then leaves a little room for them at the bottom.
  Widget _printedPage(
      List<Ayah> ayahs, List<MushafLine> lines, Size size, bool narrow) {
    final withHamesh =
        widget.settings.mode == DisplayMode.hamesh && widget.showHamesh;
    final entries = withHamesh ? _hameshEntries(ayahs) : const <HameshEntry>[];
    final signature = [
      widget.page,
      size.width,
      size.height,
      for (final e in entries) '${e.ayah.number}:${e.word}:${e.readings.length}',
    ].join('|');
    if (signature != _splitFor) {
      _split = null;
      _splitFor = signature;
    }
    final split = _split ?? entries.length;
    final overflow = split < entries.length;

    const outer = 4.0, header = 22.0;
    final pageHeight = size.height * (overflow ? 0.9 : 1.0);
    final pageWidth =
        withHamesh ? size.width * (narrow ? 0.81 : 0.84) : size.width;
    final textWidth = pageWidth - 2 * outer - 2 * OrnamentFrame.inset;
    final textHeight = pageHeight -
        2 * outer -
        header -
        2 * OrnamentFrame.inset -
        _PageFrame.numberHeight;
    final mushafLines = MushafLines(
      lines: lines,
      centered: widget.quran.isCentered(widget.page),
      quran: widget.quran,
      wordBuilder: _word,
      display: _display,
      marker: _marker,
      height: textHeight,
    );
    final first = ayahs.first;
    final page = Padding(
      padding: const EdgeInsets.all(outer),
      child: Column(
        children: [
          SizedBox(
            height: header,
            child: _PageHeader(
              surah: widget.quran.surah(first.surah).nameAr,
              juz: first.juz,
            ),
          ),
          Expanded(
            child: _PageFrame(
              page: widget.page,
              onNumberTap: widget.onPageNumberTap,
              child: mushafLines,
            ),
          ),
        ],
      ),
    );
    if (!withHamesh) return page;

    // Vertical position of each note: level with its word's line.
    final lineHeight = mushafLines.metrics(textWidth).lineHeight;
    final lineOf = <int, int>{};
    for (final (i, line) in lines.indexed) {
      if (line is TextLine) {
        for (final (a, w) in line.words) {
          lineOf[VariantRepository.key(a.surah, a.number, w)] = i;
        }
      }
    }
    final top = outer + header + OrnamentFrame.inset;
    final shown = entries.sublist(0, split);
    final tops = [
      for (final e in shown)
        top +
            (lineOf[VariantRepository.key(e.ayah.surah, e.ayah.number, e.word)] ??
                    0) *
                lineHeight,
    ];

    return SingleChildScrollView(
      physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: pageHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: pageWidth, child: page),
                Expanded(
                  child: _SideHamesh(
                    entries: shown,
                    tops: tops,
                    onTap: widget.onWordTap,
                    onFit: (fit) => _setSplit(signature, fit),
                  ),
                ),
              ],
            ),
          ),
          if (overflow)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 24),
              child: _HameshBox(
                title: 'تتمة الهامش',
                entries: entries.sublist(split),
                onTap: widget.onWordTap,
                columns: narrow ? 3 : 4,
              ),
            ),
        ],
      ),
    );
  }

  /// Called by the side hamesh after layout with how many notes fit.
  void _setSplit(String signature, int fit) {
    if (signature != _splitFor || _split != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && signature == _splitFor && _split != fit) {
        setState(() => _split = fit);
      }
    });
  }

  Widget _flowingText(List<Ayah> ayahs, bool narrow) {
    final s = widget.settings;
    final scale = s.mode == DisplayMode.hamesh && narrow ? 0.8 : 1.0;
    final textStyle = TextStyle(
      fontFamily: 'Hafs',
      fontSize: s.fontSize * scale,
      height: 2.0,
      color: MushafColors.ink,
    );
    final blocks = <Widget>[];
    var spans = <InlineSpan>[];
    void flush() {
      if (spans.isEmpty) return;
      blocks.add(
        Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: textStyle,
        ),
      );
      spans = [];
    }

    for (final ayah in ayahs) {
      if (ayah.number == 1) {
        flush();
        blocks.add(
          SurahBanner(title: 'سورة ${widget.quran.surah(ayah.surah).nameAr}'),
        );
        if (ayah.surah != 1 && ayah.surah != 9) {
          blocks.add(
            Text(
              widget.quran.basmala,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: textStyle,
            ),
          );
        }
      }
      _addAyah(ayah, spans);
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  void _addAyah(Ayah ayah, List<InlineSpan> out) {
    final s = widget.settings;
    final selected = s.selected.where(widget.variants.isLoaded).toList();
    final replace = s.mode == DisplayMode.replace && selected.length == 1;

    for (var w = 0; w < ayah.words.length; w++) {
      final m = _mark(ayah, w);
      final tap = m.all.isEmpty && !m.mutashabih ? null : _recognizer(ayah, w);
      final underline = m.mutashabih ? _mutashabihStyle : null;

      // A reading given only as a description cannot replace the word.
      final replaceable = m.all.where(
        (v) => v.text.isNotEmpty || v.description.isEmpty,
      );
      if (replace && replaceable.isNotEmpty) {
        final v = replaceable.first;
        if (v.word == w && v.text.isNotEmpty) {
          final shownHere = s.kinds.contains(v.kind);
          out.add(
            TextSpan(
              text: '${v.text} ',
              recognizer: tap,
              style: TextStyle(
                fontFamily: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
                color: shownHere ? qiraaOf(v.riwayaId).color : null,
                backgroundColor: shownHere
                    ? qiraaOf(v.riwayaId).color.withAlpha(24)
                    : null,
              ),
            ),
          );
        }
        continue;
      }

      if (m.shown.isEmpty) {
        out
          ..add(
            TextSpan(text: ayah.words[w], recognizer: tap, style: underline),
          )
          ..add(const TextSpan(text: ' '));
        continue;
      }

      final color = m.color!;
      out.add(
        TextSpan(
          text: ayah.words[w],
          recognizer: tap,
          style: (underline ?? const TextStyle()).copyWith(
            color: color,
            backgroundColor: color.withAlpha(28),
          ),
        ),
      );
      if (m.colors.length > 1 && s.mode != DisplayMode.inline) {
        out.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: _Dots(colors: m.colors),
          ),
        );
      }
      if (s.mode == DisplayMode.inline) {
        // Each distinct reading once, at the first word it covers.
        final seen = <String>{};
        for (final v in m.shown.where((v) => v.word == w)) {
          if (!seen.add(v.text)) continue;
          out.add(
            TextSpan(
              text: ' ${v.text.isEmpty ? '—' : v.text}',
              recognizer: tap,
              style: TextStyle(
                fontFamily: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
                fontSize: s.fontSize * 0.62,
                color: qiraaOf(v.riwayaId).color,
              ),
            ),
          );
        }
      }
      out.add(const TextSpan(text: ' '));
    }
    out.add(TextSpan(text: '${arabicDigits(ayah.number)} '));
  }

  static TextStyle get _mutashabihStyle => TextStyle(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    decorationColor: MushafColors.green,
    decorationThickness: 2,
  );

  /// The selected riwayat's readings of a Hafs word, its colour (the qiraa's
  /// colour, or [MushafColors.multi] when several qiraat differ) and whether
  /// it belongs to a mutashabih.
  ({
    List<Variant> all,
    List<Variant> shown,
    List<Color> colors,
    Color? color,
    bool mutashabih,
  })
  _mark(Ayah ayah, int w) {
    final s = widget.settings;
    final all = widget.variants
        .at(
          s.selected.where(widget.variants.isLoaded),
          ayah.surah,
          ayah.number,
          w,
        )
        .toList(growable: false);
    final shown = all.where((v) => s.kinds.contains(v.kind)).toList();
    final colors = [
      for (final q in {for (final v in shown) qiraaOf(v.riwayaId)}) q.color,
    ];
    return (
      all: all,
      shown: shown,
      colors: colors,
      color: colors.isEmpty
          ? null
          : colors.length == 1
          ? colors.single
          : MushafColors.multi,
      mutashabih:
          s.showMutashabihat &&
          widget.mutashabihat.isShared(ayah.surah, ayah.number, w),
    );
  }

  /// What a word shows on a printed line. When one riwaya is shown in full
  /// (replace), its reading takes the place of the Hafs word(s), in its own
  /// font; readings given only as a description keep the Hafs word.
  ({String text, String font})? _display(Ayah ayah, int w) {
    final s = widget.settings;
    final selected = s.selected.where(widget.variants.isLoaded).toList();
    if (s.mode == DisplayMode.replace && selected.length == 1) {
      final v = widget.variants
          .at(selected, ayah.surah, ayah.number, w)
          .where((v) => v.text.isNotEmpty || v.description.isEmpty)
          .firstOrNull;
      if (v != null) {
        if (v.word != w || v.text.isEmpty) return null;
        return (
          text: v.text,
          font: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
        );
      }
    }
    if (widget.qcf && ayah.glyphs != null) {
      final glyph = ayah.glyphs![w];
      return glyph.isEmpty
          ? null
          : (text: glyph, font: QcfFonts.family(widget.page));
    }
    return (text: ayah.words[w], font: 'Hafs');
  }

  /// The ayah-end ornament: the printed one from the page font when loaded.
  ({String text, String font})? _marker(Ayah ayah) =>
      widget.qcf && ayah.endGlyph != null
          ? (text: ' ${ayah.endGlyph}', font: QcfFonts.family(widget.page))
          : null;

  /// One word of a printed line.
  Widget _word(Ayah ayah, int w, double fontSize) {
    final m = _mark(ayah, w);
    final shown = _display(ayah, w)!;
    Widget word = Text(
      shown.text,
      textDirection: TextDirection.rtl,
      style: (m.mutashabih ? _mutashabihStyle : const TextStyle()).copyWith(
        fontFamily: shown.font,
        fontSize: fontSize,
        height: 1.0,
        color: m.color ?? MushafColors.ink,
        backgroundColor: m.color?.withAlpha(28),
      ),
    );
    if (m.colors.length > 1 && widget.settings.mode == DisplayMode.highlight) {
      word = Stack(
        clipBehavior: Clip.none,
        children: [
          word,
          Positioned(top: -6, left: 0, child: _Dots(colors: m.colors)),
        ],
      );
    }
    if (widget.focus == VariantRepository.key(ayah.surah, ayah.number, w)) {
      // Drawn over the word, so the line keeps its width.
      word = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: MushafColors.green, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: word,
      );
    }
    if (m.all.isEmpty && !m.mutashabih) return word;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onWordTap(ayah, w),
      child: word,
    );
  }

  /// Hamesh entries in page order: one per word where a selected reading
  /// starts. The same word read the same way again on the page is listed
  /// once.
  List<HameshEntry> _hameshEntries(List<Ayah> ayahs) {
    final out = <HameshEntry>[];
    final seen = <String>{};
    for (final ayah in ayahs) {
      for (var w = 0; w < ayah.words.length; w++) {
        final m = _mark(ayah, w);
        final starting = m.shown.where((v) => v.word == w).toList();
        if (starting.isEmpty) continue;
        final end = starting
            .map((v) => v.word + v.count)
            .reduce((a, b) => a > b ? a : b);
        final hafs = ayah.words.sublist(w, end).join(' ');
        final key = [
          _bare(hafs),
          for (final v in starting) '${v.riwayaId}=${_readingKey(v)}',
        ].join('|');
        if (!seen.add(key)) continue;
        out.add(HameshEntry(ayah, w, hafs, m.color!, starting));
      }
    }
    return out;
  }

  TapGestureRecognizer _recognizer(Ayah ayah, int word) {
    final r = TapGestureRecognizer()
      ..onTap = () => widget.onWordTap(ayah, word);
    _recognizers.add(r);
    return r;
  }
}

/// Identifies a reading independently of each riwaya's text encoding: the
/// generated description when there is one, otherwise the bare letters.
String _readingKey(Variant v) =>
    v.description.isNotEmpty ? v.description : _bare(v.text);

/// Letters only (no vowels, waqf signs or tatweel).
String _bare(String text) => String.fromCharCodes(
  text.runes.where(
    (c) => (c >= 0x0621 && c <= 0x064A) || c == 0x0671 || c == 0x0020,
  ),
);

String arabicDigits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();

/// Ornamented mushaf border around the Hafs text, with the page number.
class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.page, required this.child, this.onNumberTap});

  final int page;
  final Widget child;
  final VoidCallback? onNumberTap;

  /// Height taken by the page number under the lines.
  static const numberHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    return OrnamentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: child),
          SizedBox(
            height: numberHeight,
            child: Center(
              child: GestureDetector(
                onTap: onNumberTap,
                // Not the Hafs font: it draws digits as ayah-end ornaments.
                child: Text(
                  arabicDigits(page),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: MushafColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line above the frame, as printed: surah name on the right, juz on
/// the left.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.surah, required this.juz});

  final String surah;
  final int juz;

  static const _juzNames = [
    'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', //
    'الثامن', 'التاسع', 'العاشر', 'الحادي عشر', 'الثاني عشر', 'الثالث عشر',
    'الرابع عشر', 'الخامس عشر', 'السادس عشر', 'السابع عشر', 'الثامن عشر',
    'التاسع عشر', 'العشرون', 'الحادي والعشرون', 'الثاني والعشرون',
    'الثالث والعشرون', 'الرابع والعشرون', 'الخامس والعشرون',
    'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون',
    'التاسع والعشرون', 'الثلاثون',
  ];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Hafs',
      fontSize: 15,
      height: 1.1,
      color: MushafColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text('سورة $surah', style: style),
          const Spacer(),
          Text('الجزء ${_juzNames[juz - 1]}', style: style),
        ],
      ),
    );
  }
}

/// The hamesh beside the page: each note at the height of its word's line,
/// pushed down only when the note above needs the room. Reports how many
/// notes fit beside the page.
class _SideHamesh extends StatelessWidget {
  const _SideHamesh({
    required this.entries,
    required this.tops,
    required this.onTap,
    required this.onFit,
  });

  final List<HameshEntry> entries;
  final List<double> tops;
  final WordTap onTap;
  final ValueChanged<int> onFit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: MushafColors.gold.withAlpha(120)),
        ),
      ),
      child: ClipRect(
        child: CustomMultiChildLayout(
          delegate: _NotesLayout(tops, onFit),
          children: [
            for (final (i, e) in entries.indexed)
              LayoutId(
                id: i,
                child: _EntryView(entry: e, onTap: onTap, compact: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotesLayout extends MultiChildLayoutDelegate {
  _NotesLayout(this.tops, this.onFit);

  final List<double> tops;
  final ValueChanged<int> onFit;

  @override
  void performLayout(Size size) {
    var bottom = 0.0;
    var fit = tops.length;
    for (var i = 0; i < tops.length; i++) {
      final child = layoutChild(i, BoxConstraints(maxWidth: size.width - 4));
      final top = math.max(tops[i], bottom);
      if (fit == tops.length && top + child.height > size.height) fit = i;
      positionChild(
          i, Offset(2, i >= fit ? size.height + child.height : top));
      bottom = top + child.height + 3;
    }
    onFit(fit);
  }

  @override
  bool shouldRelayout(_NotesLayout old) => true;
}

/// Notes in a box (the continuation below the page), in columns.
class _HameshBox extends StatelessWidget {
  const _HameshBox({
    required this.title,
    required this.entries,
    required this.onTap,
    this.columns = 1,
  });

  final String title;
  final List<HameshEntry> entries;
  final WordTap onTap;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        color: MushafColors.goldLight.withAlpha(60),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MushafColors.gold.withAlpha(160)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: MushafColors.green,
            ),
          ),
          Divider(height: 8, color: MushafColors.gold.withAlpha(160)),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in entries)
                  SizedBox(
                    width: (c.maxWidth - 8 * (columns - 1)) / columns,
                    child: _EntryView(entry: e, onTap: onTap, compact: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One note: the Hafs word in its colour, then who reads it how, in the
/// riwaya's own font, with a short description ("بالتاء", "بضم الهاء", ...).
/// Readings that are the same for several riwayat / qiraat share one line.
class _EntryView extends StatelessWidget {
  const _EntryView({
    required this.entry,
    required this.onTap,
    required this.compact,
  });

  final HameshEntry entry;
  final WordTap onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final label = TextStyle(
      fontSize: compact ? 7.5 : 10,
      height: 1.3,
      color: MushafColors.ink,
    );
    final quran = compact ? 10.5 : 13.0;
    return InkWell(
      onTap: () => onTap(e.ayah, e.word),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            e.hafs,
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: quran,
              height: 1.4,
              color: e.color,
              backgroundColor: e.color.withAlpha(28),
            ),
          ),
          for (final g in _readings(e.readings))
            Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < g.names.length; i++)
                    TextSpan(
                      text: i == 0 ? g.names[i].$1 : ' و${g.names[i].$1}',
                      style: label.copyWith(
                        color: g.names[i].$2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(text: ': ', style: label),
                  if (g.text.isNotEmpty || g.description.isEmpty)
                    TextSpan(
                      text: g.text.isEmpty ? '(بحذفها)' : g.text,
                      style: TextStyle(
                        fontFamily: g.font,
                        fontSize: quran,
                        color: g.names.length == 1
                            ? g.names.single.$2
                            : MushafColors.multi,
                      ),
                    ),
                  if (g.description.isNotEmpty)
                    TextSpan(
                      text: ' ${g.description}',
                      style: label.copyWith(color: MushafColors.frame),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Who reads what: a qiraa by its name ("نافع") when both its riwayat
  /// read alike, otherwise each riwaya ("ورش عن نافع"); qiraat with the same
  /// reading share one line ("نافع وابن كثير: مَلِكِ").
  static List<_Reading> _readings(List<Variant> vs) {
    final out = <_Reading>[];
    void add(String name, Color color, String font, Variant v) {
      final key = _readingKey(v);
      final same = out.where((g) => g.key == key).firstOrNull;
      same != null
          ? same.names.add((name, color))
          : out.add(
              _Reading([(name, color)], font, v.text, v.description, key),
            );
    }

    for (final q in qiraat) {
      final mine = [
        for (final r in q.riwayat)
          for (final v in vs)
            if (v.riwayaId == r.id) (r, v),
      ];
      if (mine.isEmpty) continue;
      final sameReading =
          mine.length == q.riwayat.length &&
          mine.every((m) => _readingKey(m.$2) == _readingKey(mine.first.$2));
      if (sameReading) {
        final (r, v) = mine.first;
        add(q.shortAr, q.color, r.fontFamily ?? 'Hafs', v);
      } else {
        for (final (r, v) in mine) {
          add(
            '${r.nameAr} عن ${_genitive(q.shortAr)}',
            q.color,
            r.fontFamily ?? 'Hafs',
            v,
          );
        }
      }
    }
    return out;
  }

  /// "عن أبو عمرو" → "عن أبي عمرو".
  static String _genitive(String name) =>
      name.startsWith('أبو ') ? 'أبي ${name.substring(4)}' : name;
}

class _Reading {
  _Reading(this.names, this.font, this.text, this.description, this.key);

  final List<(String, Color)> names;
  final String font;
  final String text;

  /// e.g. "بالتاء", "بضم الهاء"; empty when not generated.
  final String description;
  final String key;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in colors)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
