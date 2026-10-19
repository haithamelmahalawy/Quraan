import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/arabic.dart';
import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'mushaf_decor.dart';
import '../services/qcf_fonts.dart';
import 'mushaf_lines.dart';
import 'reference_sheet.dart';
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
    this.qcf = false,
    this.onAyahTap,
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

  /// Draw with the QCF V2 font of this page (it is loaded).
  final bool qcf;

  /// A word held: opens its ayah (tafsir, recitation).
  final ValueChanged<Ayah>? onAyahTap;

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

    return LayoutBuilder(
      builder: (context, viewport) {
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
      },
    );
  }

  /// The printed page filling the screen: the header line (surah, juz), the
  /// framed 15 lines spread over the height, and the hamesh beside it with
  /// each note level with its line. Notes that do not fit continue below,
  /// and the page then leaves a little room for them at the bottom.
  Widget _printedPage(
    List<Ayah> ayahs,
    List<MushafLine> lines,
    Size size,
    bool narrow,
  ) {
    final entries =
        widget.settings.mode == DisplayMode.hamesh && widget.showHamesh
        ? _hameshEntries(ayahs)
        : const <HameshEntry>[];
    // The hamesh takes room beside the page only when it has notes; the
    // page otherwise has the whole width, and its text the largest size.
    final withHamesh = entries.isNotEmpty;
    final signature = [
      widget.page,
      size.width,
      size.height,
      for (final e in entries)
        '${e.ayah.number}:${e.word}:${e.readings.length}',
    ].join('|');
    if (signature != _splitFor) {
      _split = null;
      _splitFor = signature;
    }
    final split = _split ?? entries.length;
    final overflow = split < entries.length;

    const outer = 4.0, header = 22.0;
    final pageHeight = size.height * (overflow ? 0.9 : 1.0);
    final pageWidth = withHamesh
        ? size.width * (narrow ? 0.81 : 0.84)
        : size.width;
    final textWidth = pageWidth - 2 * outer - 2 * OrnamentFrame.inset;
    final textHeight =
        pageHeight -
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
              usul: _usulKey(
                [
                  for (final l in lines)
                    if (l is TextLine) ...l.words,
                ],
                widget.variants,
                widget.settings,
              ),
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
    // The printed line each word is on (a Shamarly header takes two).
    final lineOf = <int, int>{};
    var at = 0;
    for (final line in lines) {
      if (line is TextLine) {
        for (final (a, w) in line.words) {
          lineOf[VariantRepository.key(a.surah, a.number, w)] = at;
        }
      }
      at += line.span;
    }
    final top = outer + header + OrnamentFrame.inset;
    final shown = entries.sublist(0, split);
    final tops = [
      for (final e in shown)
        top +
            (lineOf[VariantRepository.key(
                      e.ayah.surah,
                      e.ayah.number,
                      e.word,
                    )] ??
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
                    onTap: _openReference,
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
                onTap: _openReference,
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

  /// A clear, solid line under the words a mutashabih shares.
  /// The soft highlight behind the words a mutashabih shares.
  static Color get _mutashabihGlow =>
      MushafColors.gold.withAlpha(MushafColors.isDark ? 70 : 60);

  static TextStyle get _mutashabihStyle =>
      TextStyle(backgroundColor: _mutashabihGlow);

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
    final r = _readingsAt(widget.variants, s, ayah, w);
    return (
      all: r.all,
      shown: r.shown,
      colors: r.colors,
      color: r.color,
      mutashabih:
          s.showMutashabihat &&
          widget.mutashabihat.isShared(ayah.surah, ayah.number, w),
    );
  }

  /// What a word shows on a printed line. When one riwaya is shown in full
  /// (replace), its reading takes the place of the Hafs word(s); readings
  /// given only as a description keep the Hafs word, with the imala sign
  /// under its letter when read with imala.
  ({String text, String font})? _display(Ayah ayah, int w) {
    final s = widget.settings;
    final base = _baseAt(widget.variants, s, ayah, w);
    // The riwaya shown in place of Hafs: its reading takes the place of the
    // Hafs word(s).
    final v = base
        .where((v) => v.text.isNotEmpty || v.description.isEmpty)
        .firstOrNull;
    if (v != null) {
      if (v.word != w || v.text.isEmpty) return null;
      return (text: v.text, font: 'Hafs');
    }
    final glyph = widget.qcf ? (ayah.glyphs?[w]) : null;
    // Drawn with the word before.
    if (glyph != null && glyph.isEmpty) return null;
    final imala = [
      ...base,
      ..._readingsAt(widget.variants, s, ayah, w).shown,
    ].any((v) => v.word == w && v.isImala);
    // The page font has no imala sign to add: such a word is drawn in the
    // Hafs font.
    if (imala) return (text: withImalaSign(ayah.words[w]), font: 'Hafs');
    // Nor letters coloured apart.
    if (_letterReadings(ayah, w) != null) {
      return (text: ayah.words[w], font: 'Hafs');
    }
    if (glyph != null) return (text: glyph, font: QcfFonts.family(widget.page));
    return (text: ayah.words[w], font: 'Hafs');
  }

  /// The readings of a word when they are only naql and madd al-badal, which
  /// colour single letters rather than the word: the letter that takes the
  /// hamza's vowel, and the madd.
  List<Variant>? _letterReadings(Ayah ayah, int w) {
    final s = widget.settings;
    final readings = [
      ..._baseAt(widget.variants, s, ayah, w),
      ..._readingsAt(widget.variants, s, ayah, w).shown,
    ].where((v) => v.word == w && s.kinds.contains(v.kind)).toList();
    if (readings.isEmpty ||
        !readings.every((v) => v.isBadal || _naqlKind(v) != null)) {
      return null;
    }
    return readings;
  }

  /// [text] of a word in parts, its naql and madd letters coloured.
  List<(String, Color?)>? _letterParts(Ayah ayah, int w, String text) {
    final readings = _letterReadings(ayah, w);
    if (readings == null) return null;
    final letters = lettersOf(text);
    final colors = <int, Color>{};
    for (final v in readings) {
      final kind = v.isBadal ? null : _naqlKind(v);
      final i = v.isBadal
          ? badalLetter(letters)
          : kind == _Naql.dropped
          ? null
          : naqlLetter(letters, last: kind == _Naql.last);
      if (i != null) {
        colors[i] = v.isBadal ? MushafColors.green : qiraaOf(v.riwayaId).color;
      }
    }
    return [for (final (i, l) in letters.indexed) (l, colors[i])];
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
    final parts = shown.font == 'Hafs'
        ? _letterParts(ayah, w, shown.text)
        : null;
    Widget word = InkText(
      shown.text,
      parts: parts,
      style: TextStyle(
        fontFamily: shown.font,
        fontSize: fontSize,
        height: 1.0,
        color: parts != null ? MushafColors.ink : m.color ?? MushafColors.ink,
        backgroundColor: parts != null ? null : m.color?.withAlpha(28),
      ),
    );
    if (m.mutashabih) {
      // A soft highlight over the word and its marks, without taking room.
      word = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -1,
            right: -1,
            top: -fontSize * 0.28,
            bottom: -fontSize * 0.3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _mutashabihGlow,
                borderRadius: BorderRadius.circular(fontSize * 0.25),
              ),
            ),
          ),
          word,
        ],
      );
    }
    if (m.colors.length > 1 && widget.settings.mode == DisplayMode.highlight) {
      word = Stack(
        clipBehavior: Clip.none,
        children: [
          word,
          Positioned(top: -6, left: 0, child: _Dots(colors: m.colors)),
        ],
      );
    }
    // Every word opens its readings (or its ayah); held, its ayah.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onWordTap(ayah, w),
      onLongPress: widget.onAyahTap == null
          ? null
          : () => widget.onAyahTap!(ayah),
      child: word,
    );
  }

  /// A note of the hamesh tapped: where its readings are stated in the
  /// Shatibiyya and the Durrah.
  void _openReference(Ayah ayah, int w) {
    final readings = _readingsAt(
      widget.variants,
      widget.settings,
      ayah,
      w,
    ).shown.where((v) => v.word == w).toList();
    if (readings.isEmpty) return;
    final shown = _display(ayah, w)?.font == 'Hafs'
        ? _display(ayah, w)!.text
        : ayah.words[w];
    ReferenceSheet.show(
      context,
      readings: readings,
      word: shown,
      surah: ayah.surah,
      surahNames: [for (final s in widget.quran.surahs) s.nameAr],
    );
  }

  /// The notes of the words on this page (an ayah running over a page, as
  /// in the Shamarly print, has its other words on the next).
  List<HameshEntry> _hameshEntries(List<Ayah> ayahs) {
    final lines = widget.quran.lines(widget.page);
    final entries = _entriesOf(ayahs, widget.variants, widget.settings);
    if (lines == null) return entries;
    final here = {
      for (final l in lines)
        if (l is TextLine)
          for (final (a, w) in l.words)
            VariantRepository.key(a.surah, a.number, w),
    };
    return [
      for (final e in entries)
        if (here.contains(
          VariantRepository.key(e.ayah.surah, e.ayah.number, e.word),
        ))
          e,
    ];
  }

  TapGestureRecognizer _recognizer(Ayah ayah, int word) {
    final r = TapGestureRecognizer()
      ..onTap = () => widget.onWordTap(ayah, word);
    _recognizers.add(r);
    return r;
  }
}

/// The readings of the riwaya the mushaf shows ([ReaderSettings.displayed])
/// at a Hafs word; none when it shows Hafs.
List<Variant> _baseAt(
  VariantRepository variants,
  ReaderSettings s,
  Ayah ayah,
  int w,
) {
  final base = s.displayed;
  if (base == null || !variants.isLoaded(base)) return const [];
  return variants.at([base], ayah.surah, ayah.number, w).toList();
}

/// The colour of readings: green for imala and madd al-badal (in every
/// riwaya), orange for tarqiq of the ra and taghliz of the lam, otherwise
/// the qiraa's colour, or [MushafColors.multi] when several qiraat differ.
Color? _colorOf(List<Variant> readings) {
  if (readings.isEmpty) return null;
  if (readings.every((v) => v.isImala || v.isBadal)) return MushafColors.green;
  if (readings.every((v) => v.isTarqiqOrTaghliz)) return MushafColors.rule;
  final qiraat = {for (final v in readings) qiraaOf(v.riwayaId)};
  return qiraat.length == 1 ? qiraat.single.color : MushafColors.multi;
}

/// How the other selected riwayat read a word, compared with the riwaya the
/// mushaf shows (Hafs, or [ReaderSettings.displayed]): a riwaya that reads
/// it as the shown text is not listed, nor one that reads it as Hafs (it has
/// no reading). Readings of the kinds shown, their qiraat's colours, and the
/// word's colour: theirs, or else the shown riwaya's own where it differs
/// from Hafs.
({List<Variant> all, List<Variant> shown, List<Color> colors, Color? color})
_readingsAt(VariantRepository variants, ReaderSettings s, Ayah ayah, int w) {
  final base = _baseAt(variants, s, ayah, w);
  final same = {for (final v in base) _readingKey(v)};
  final all = variants
      .at(
        s.selected.where((id) => id != s.displayed && variants.isLoaded(id)),
        ayah.surah,
        ayah.number,
        w,
      )
      .where((v) => !same.contains(_readingKey(v)))
      .toList(growable: false);
  final shown = all.where((v) => s.kinds.contains(v.kind)).toList();
  final colors = [
    for (final q in {for (final v in shown) qiraaOf(v.riwayaId)}) q.color,
  ];
  return (
    all: all,
    shown: shown,
    colors: colors,
    color:
        _colorOf(shown) ??
        _colorOf(base.where((v) => s.kinds.contains(v.kind)).toList()),
  );
}

/// The usul coloured on [words] of the page, as a key: each colour with
/// what it means, in the order green, orange, then sakt.
List<(Color, String)> _usulKey(
  Iterable<(Ayah, int)> words,
  VariantRepository variants,
  ReaderSettings s,
) {
  var imala = false, badal = false, tarqiq = false, taghliz = false;
  final sakt = <Color>{};
  for (final (ayah, w) in words) {
    final m = _readingsAt(variants, s, ayah, w);
    for (final v in [
      ...m.shown,
      ..._baseAt(variants, s, ayah, w).where((v) => s.kinds.contains(v.kind)),
    ]) {
      if (v.word != w || !v.isUsul) continue;
      if (v.isBadal) {
        badal = true;
      } else if (v.rule == 'tarqiq') {
        tarqiq = true;
      } else if (v.rule == 'taghliz') {
        taghliz = true;
      } else if (v.isSakt) {
        sakt.add(qiraaOf(v.riwayaId).color);
      } else {
        imala = true;
      }
    }
  }
  return [
    if (imala || badal)
      (
        MushafColors.green,
        [if (imala) 'الإمالة والتقليل', if (badal) 'مد البدل'].join(' و'),
      ),
    if (tarqiq || taghliz)
      (
        MushafColors.rule,
        [if (tarqiq) 'ترقيق الراء', if (taghliz) 'تغليظ اللام'].join(' و'),
      ),
    for (final c in sakt) (c, 'السكت قبل الهمز'),
  ];
}

/// Hamesh entries of [ayahs] in page order: one per word where a reading
/// of the selected riwayat starts. The same word read the same way again on
/// the page is listed once.
List<HameshEntry> _entriesOf(
  List<Ayah> ayahs,
  VariantRepository variants,
  ReaderSettings settings,
) {
  final out = <HameshEntry>[];
  final seen = <String>{};
  for (final ayah in ayahs) {
    for (var w = 0; w < ayah.words.length; w++) {
      final m = _readingsAt(variants, settings, ayah, w);
      // Usul are told once by their colour, in the page's key.
      final starting = m.shown
          .where((v) => v.word == w && !v.isUsul)
          .toList();
      if (starting.isEmpty) continue;
      final end = starting
          .map((v) => v.word + v.count)
          .reduce((a, b) => a > b ? a : b);
      // The word as shown on the page: Hafs, or the riwaya shown.
      final shownText = _baseAt(variants, settings, ayah, w)
          .where((v) => v.word == w && v.text.isNotEmpty)
          .firstOrNull
          ?.text;
      final hafs = shownText ?? ayah.words.sublist(w, end).join(' ');
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

enum _Naql { lam, last, dropped }

/// How a reading is naql: the hamza's vowel given to the lam of al, or to
/// the last letter of the word, or the hamza dropped after it; null when
/// it is something else.
_Naql? _naqlKind(Variant v) => switch (v.description) {
  'بنقل حركة الهمزة إليها' => _Naql.last,
  'بحذف الهمزة' => _Naql.dropped,
  final d
      when RegExp(
        r'^(بفتح اللام و)?ب?نقل حركة الهمزة إلى اللام( والقصر)?$',
      ).hasMatch(d) =>
    _Naql.lam,
  _ => null,
};

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
  const _PageHeader({
    required this.surah,
    required this.juz,
    this.usul = const [],
  });

  final String surah;
  final int juz;

  /// The colours of the usul on the page and what they mean.
  final List<(Color, String)> usul;

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
          Expanded(
            child: usul.isEmpty
                ? const SizedBox()
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        for (final (color, meaning) in usul) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            meaning,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
          ),
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
      positionChild(i, Offset(2, i >= fit ? size.height + child.height : top));
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
                  if (g.text.isNotEmpty || g.description.isEmpty || g.imala)
                    TextSpan(
                      text: g.text.isNotEmpty
                          ? g.text
                          : g.imala
                          ? withImalaSign(e.hafs)
                          : '(بحذفها)',
                      style: TextStyle(
                        fontFamily: g.font,
                        fontSize: quran,
                        color: g.imala
                            ? MushafColors.green
                            : g.names.length == 1
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
              _Reading(
                [(name, color)],
                font,
                v.text,
                v.description,
                key,
                imala: v.isImala,
              ),
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
  _Reading(
    this.names,
    this.font,
    this.text,
    this.description,
    this.key, {
    this.imala = false,
  });

  final List<(String, Color)> names;
  final String font;
  final String text;

  /// e.g. "بالتاء", "بضم الهاء"; empty when not generated.
  final String description;
  final String key;

  /// Read with imala: shown as the word with the imala sign, in green.
  final bool imala;
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
