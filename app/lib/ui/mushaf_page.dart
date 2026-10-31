import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/arabic.dart';
import '../data/audio_numbering.dart';
import '../data/lin_hamz.dart';
import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../data/usul_text.dart';
import '../data/reading_comparison.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'mushaf_decor.dart';
import '../services/qcf_fonts.dart';
import 'kharouf_section.dart' show readersAr;
import 'mushaf_lines.dart';
import 'mushaf_zoom.dart';
import 'hamza_replacement_mark.dart';
import 'letter_above_mark.dart';
import 'hafs_font_marks.dart';
import 'quran_word_text.dart';
import 'partition_marker.dart';
import 'reference_sheet.dart';
import 'reading_colors.dart';
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
    this.onAyahWordTap,
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
  final WordTap? onAyahWordTap;

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

class _MushafPageState extends State<MushafPage>
    with SingleTickerProviderStateMixin {
  final _recognizers = <TapGestureRecognizer>[];

  /// How many hamesh notes fit beside the page (the rest go below it),
  /// measured after layout for [_splitFor].
  int? _split;
  String? _splitFor;

  /// Pinch zoom of the page.
  final _zoom = TransformationController();
  bool _zoomed = false;
  bool _pinching = false;
  bool _pageQcf = false;

  bool get _showFarshMargins =>
      widget.showHamesh &&
      (widget.settings.mode == DisplayMode.hamesh ||
          widget.settings.selected.any(
            (id) => id != widget.settings.displayed,
          ) ||
          widget.settings.displayed != null && widget.settings.compareHafs);

  /// The page with its hamesh and usul below it.
  final _scroll = ScrollController();
  final _landscapeScroll = ScrollController();

  /// Moves the words that differ from Hafs («تنبيه الاختلافات»).
  late final _alert = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  void _syncAlert() {
    if (widget.settings.diffAlert == null) {
      if (_alert.isAnimating) _alert.stop();
      _alert.value = 0;
    } else if (!_alert.isAnimating) {
      _alert.repeat(reverse: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_syncZoom);
  }

  void _syncZoom() {
    final zoomed = _pinching || _zoom.value.getMaxScaleOnAxis() > 1.001;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _zoom.dispose();
    _scroll.dispose();
    _landscapeScroll.dispose();
    _alert.dispose();
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
    _syncAlert();
    // The riwayat or their data may have changed since the last build.
    _readingsMemo.clear();
    final ayahs = widget.quran.page(widget.page);
    // Page glyphs and the editable Hafs font have different visual scales.
    // If one word needs editable letters, use that font for the whole page.
    _pageQcf =
        widget.qcf &&
        !_nativeNumbering &&
        ayahs.every(
          (ayah) => ayah.words.indexed.every((entry) {
            final shown = _displayWord(ayah, entry.$1, qcf: true);
            return shown == null || shown.font.startsWith('QCF_');
          }),
        );
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
            ? MediaQuery.orientationOf(context) == Orientation.landscape
                  ? _landscapePage(ayahs, lines, viewport.biggest)
                  : widget.settings.marginLayout == MarginLayout.sequential &&
                        widget.showHamesh
                  ? _sequentialPage(ayahs, lines, viewport.biggest)
                  : _printedPage(ayahs, lines, viewport.biggest, narrow)
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
            MushafZoom(
              controller: _zoom,
              onPinchChanged: (active) {
                _pinching = active;
                _syncZoom();
              },
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

  /// One box per origin; lexical notes keep their own printed-line anchor.
  List<_SequentialNote> _sequentialNotes(
    List<(Ayah, int)> words,
    List<HameshEntry> entries,
  ) {
    final notes = <_SequentialNote>[
      for (final e in entries)
        _SequentialNote(
          e.ayah,
          e.word,
          true,
          KeyedSubtree(
            key: ValueKey(
              'sequential-farsh:${VariantRepository.key(e.ayah.surah, e.ayah.number, e.word)}',
            ),
            child: _EntryView(
              entry: e,
              onTap: _openReference,
              compact: true,
              scale: 1.1,
            ),
          ),
        ),
    ];
    // As in the organised layout: the words of one rule with the same ways in
    // one group, the ways written once under them.
    final merged = <String, _UsulGroup>{};
    for (final source in _usulNotes(
      words,
      widget.variants,
      widget.settings,
      widget.quran,
    )) {
      final group = merged.putIfAbsent(
        '${source.label}:${source.ways.join("|")}',
        () => _UsulGroup(source.label, source.color)..ways.addAll(source.ways),
      );
      for (final item in source.items.values) {
        final key = '${item.stopOnly}:${item.text}:${item.replacement}';
        final existing = group.items.putIfAbsent(key, () => item);
        if (existing != item) {
          existing.riwayat.addAll(item.riwayat);
          existing.readings.addAll(item.readings);
        }
      }
    }
    for (final (index, group) in merged.values.indexed) {
      if (group.items.isEmpty) continue;
      final first = group.items.values.first;
      notes.add(
        _SequentialNote(
          first.ayah,
          first.word,
          false,
          KeyedSubtree(
            key: ValueKey(
              'sequential-usul:${VariantRepository.key(first.ayah.surah, first.ayah.number, first.word)}:$index',
            ),
            child: _UsulBox(
              groups: [group],
              onTap: _openUsulReference,
              scale: 1.1,
              compact: true,
            ),
          ),
        ),
      );
    }
    notes.sort((a, b) => a.position.compareTo(b.position));
    return notes;
  }

  List<double> _sequentialTops(
    List<_SequentialNote> notes,
    List<MushafLine> lines,
    double lineHeight,
    double top,
  ) {
    final lineOf = <int, int>{};
    var span = 0;
    for (final line in lines) {
      if (line is TextLine) {
        for (final (a, w) in line.words) {
          lineOf[VariantRepository.key(a.surah, a.number, w)] = span;
        }
      }
      span += line.span;
    }
    return [
      for (final note in notes)
        math.max(
          0.0,
          top + (lineOf[note.position] ?? 0) * lineHeight - lineHeight * 0.3,
        ),
    ];
  }

  Widget _sequentialPage(List<Ayah> ayahs, List<MushafLine> lines, Size size) {
    final notes = _sequentialNotes([
      for (final line in lines)
        if (line is TextLine) ...line.words,
    ], _showFarshMargins ? _hameshEntries(ayahs) : []);
    final rail = notes.isEmpty ? 0.0 : (size.width * 0.20).clamp(60.0, 220.0);
    final textHeight = math.max(
      1.0,
      size.height - 30 - 2 * OrnamentFrame.inset - _PageFrame.numberHeight,
    );
    return _SequentialMarginPage(
      key: ValueKey(_sequentialSignature(size)),
      notes: notes,
      tops: _sequentialTops(
        notes,
        lines,
        textHeight / lines.fold(0, (n, l) => n + l.span),
        26 + OrnamentFrame.inset,
      ),
      right: widget.quran.isRightPage(widget.page),
      rail: rail,
      height: size.height,
      zoomed: _zoomed,
      page: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            SizedBox(
              height: 22,
              child: _PageHeader(
                surah: widget.quran.surah(ayahs.first.surah).nameAr,
                juz: ayahs.first.juz,
              ),
            ),
            Expanded(
              child: _PageFrame(
                page: widget.page,
                sides: true,
                onNumberTap: widget.onPageNumberTap,
                child: MushafLines(
                  lines: lines,
                  centered: widget.quran.isCentered(widget.page),
                  quran: widget.quran,
                  wordBuilder: _word,
                  display: _display,
                  marker: _marker,
                  wordMarker: _nativeNumbering ? _wordMarker : null,
                  height: textHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sequentialSignature(Size size) => [
    widget.page,
    widget.quran.edition,
    size,
    widget.settings.displayed,
    widget.settings.selected.join(','),
    widget.settings.kinds.join(','),
    widget.settings.compareHafs,
    widget.showHamesh,
  ].join('|');

  /// A large, continuously scrolling print. Fixed side margins follow
  /// only the lines currently in view; their own scroll keeps dense
  /// readings accessible without reducing the font or dropping notes.
  Widget _landscapePage(List<Ayah> ayahs, List<MushafLine> lines, Size size) {
    final scroll = _landscapeScroll;
    final sides = widget.showHamesh;
    final entries = _showFarshMargins
        ? _hameshEntries(ayahs)
        : const <HameshEntry>[];
    final words = [
      for (final l in lines)
        if (l is TextLine) ...l.words,
    ];
    final sequential = widget.settings.marginLayout == MarginLayout.sequential;
    final anyNotes =
        entries.isNotEmpty ||
        (sides &&
            _usulNotes(
              words,
              widget.variants,
              widget.settings,
              widget.quran,
            ).isNotEmpty);
    final hasUsul = sequential
        ? anyNotes
        : sides &&
              _usulNotes(
                words,
                widget.variants,
                widget.settings,
                widget.quran,
              ).isNotEmpty;
    final hasFarsh = sequential ? anyNotes : entries.isNotEmpty;
    final both = hasUsul && hasFarsh;
    final rail = (size.width * (both ? 0.19 : 0.30)).clamp(96.0, 280.0);
    final pageWidth =
        size.width -
        (sequential
            ? (anyNotes ? rail : 0)
            : (hasUsul ? rail : 0) + (hasFarsh ? rail : 0));
    const outer = 4.0, header = 22.0;
    const contentTop = outer + header + OrnamentFrame.inset;
    final textWidth =
        pageWidth - 2 * outer - 2 * OrnamentFrame.sideInset(sides);
    final spans = lines.fold(0, (n, l) => n + l.span);
    final natural = MushafLines(
      lines: lines,
      centered: widget.quran.isCentered(widget.page),
      quran: widget.quran,
      wordBuilder: _word,
      display: _display,
      marker: _marker,
      wordMarker: _nativeNumbering ? _wordMarker : null,
    ).metrics(textWidth);
    // Size by width, with a little less vertical expansion. The glyphs
    // keep their shapes, the print's word order and its inter-word spaces.
    final textHeight = math.max(
      natural.fontSize * 1.8 * spans,
      size.height * 1.65 -
          contentTop -
          OrnamentFrame.inset -
          _PageFrame.numberHeight -
          outer,
    );
    final lineHeight = textHeight / spans;
    final pageHeight =
        textHeight +
        contentTop +
        OrnamentFrame.inset +
        _PageFrame.numberHeight +
        outer;
    final first = ayahs.first;
    final print = SizedBox(
      key: const ValueKey('mushaf-print'),
      width: pageWidth,
      height: pageHeight,
      child: Padding(
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
                sides: sides,
                onNumberTap: widget.onPageNumberTap,
                child: MushafLines(
                  lines: lines,
                  centered: widget.quran.isCentered(widget.page),
                  quran: widget.quran,
                  wordBuilder: _word,
                  display: _display,
                  marker: _marker,
                  wordMarker: _nativeNumbering ? _wordMarker : null,
                  height: textHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (sequential) {
      return ListenableBuilder(
        listenable: scroll,
        builder: (context, _) {
          final offset = scroll.hasClients ? scroll.offset : 0.0;
          final visible = <(Ayah, int)>[];
          var span = 0;
          for (final line in lines) {
            final top = contentTop + span * lineHeight;
            final bottom = top + line.span * lineHeight;
            if (line is TextLine &&
                bottom > offset &&
                top < offset + size.height) {
              visible.addAll(line.words);
            }
            span += line.span;
          }
          final keys = {
            for (final (a, w) in visible)
              VariantRepository.key(a.surah, a.number, w),
          };
          final notes = _sequentialNotes(
            visible,
            entries
                .where(
                  (e) => keys.contains(
                    VariantRepository.key(e.ayah.surah, e.ayah.number, e.word),
                  ),
                )
                .toList(),
          );
          return _SequentialMarginPage(
            key: ValueKey(_sequentialSignature(size)),
            section: keys.join(','),
            notes: notes,
            tops: _sequentialTops(
              notes,
              lines,
              lineHeight,
              contentTop - offset,
            ),
            right: widget.quran.isRightPage(widget.page),
            rail: anyNotes ? rail : 0,
            height: size.height,
            zoomed: _zoomed,
            page: SingleChildScrollView(
              key: const ValueKey('landscape-page-scroll'),
              controller: scroll,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              child: print,
            ),
          );
        },
      );
    }

    Widget margin(bool farsh) => SizedBox(
      width: rail,
      child: ListenableBuilder(
        listenable: scroll,
        builder: (context, _) {
          final offset = scroll.hasClients ? scroll.offset : 0.0;
          final visible = <(Ayah, int)>[];
          var span = 0;
          for (final l in lines) {
            final top = contentTop + span * lineHeight;
            final bottom = top + l.span * lineHeight;
            if (l is TextLine &&
                bottom > offset &&
                top < offset + size.height) {
              visible.addAll(l.words);
            }
            span += l.span;
          }
          final keys = {
            for (final (a, w) in visible)
              VariantRepository.key(a.surah, a.number, w),
          };
          final section = visible.isEmpty
              ? 'empty'
              : '${keys.first}:${keys.last}';
          final notes = entries
              .where(
                (e) => keys.contains(
                  VariantRepository.key(e.ayah.surah, e.ayah.number, e.word),
                ),
              )
              .toList();
          final groups = farsh
              ? const <_UsulGroup>[]
              : _usulNotes(
                  visible,
                  widget.variants,
                  widget.settings,
                  widget.quran,
                );
          return _LandscapeMargin(
            key: ValueKey('landscape-${farsh ? 'farsh' : 'usul'}-$section'),
            farsh: farsh,
            child: farsh
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'الفرش',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MushafColors.green,
                        ),
                      ),
                      for (final e in notes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: KeyedSubtree(
                            key: ValueKey(
                              'landscape-note:${e.ayah.surah}:${e.ayah.number}:${e.word}',
                            ),
                            child: _EntryView(
                              entry: e,
                              onTap: _openReference,
                              compact: false,
                              scale: 1.1,
                            ),
                          ),
                        ),
                    ],
                  )
                : groups.isEmpty
                ? const SizedBox()
                : _UsulBox(
                    groups: groups,
                    onTap: _openUsulReference,
                    scale: 1.5,
                  ),
          );
        },
      ),
    );

    return Row(
      key: const ValueKey('landscape-reader'),
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFarsh) margin(true),
        Expanded(
          child: Scrollbar(
            controller: scroll,
            child: SingleChildScrollView(
              key: const ValueKey('landscape-page-scroll'),
              controller: scroll,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              child: print,
            ),
          ),
        ),
        if (hasUsul) margin(false),
      ],
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
    final entries = _showFarshMargins
        ? _hameshEntries(ayahs)
        : const <HameshEntry>[];
    // The hamesh takes room beside the page only when it has notes; the
    // page otherwise has the whole width, and its text the largest size.
    final withHamesh = entries.isNotEmpty;
    final sides = widget.showHamesh;
    final usul = sides
        ? _usulNotes(
            [
              for (final l in lines)
                if (l is TextLine) ...l.words,
            ],
            widget.variants,
            widget.settings,
            widget.quran,
          )
        : const <_UsulGroup>[];
    final signature = [
      widget.page,
      widget.quran.edition,
      size.width,
      size.height,
      widget.settings.fontSize,
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
    final spanCount = lines.fold(0, (n, l) => n + l.span);
    final normalLine =
        (size.height -
            2 * outer -
            header -
            2 * OrnamentFrame.inset -
            _PageFrame.numberHeight) /
        spanCount;
    // Less than two printed lines, without a second
    // height reduction when a margin overflows.
    final reserve = sides && (withHamesh || usul.isNotEmpty)
        ? math.min(size.height * 0.095, math.max(0.0, normalLine * 1.6))
        : 0.0;
    final pageHeight = size.height - reserve;
    // One outer margin, following the side of the printed page. The rest
    // of the width belongs to the mushaf, including on narrow phones.
    final marginWidth = withHamesh
        ? (size.width * 0.16).clamp(52.0, 104.0)
        : 0.0;
    final rightPage = widget.quran.isRightPage(widget.page);
    final rightWidth = rightPage ? marginWidth : 0.0;
    final leftWidth = rightPage ? 0.0 : marginWidth;
    final pageWidth = size.width - rightWidth - leftWidth;
    // Full screen: no bands at the sides, the text has the whole width.
    final textWidth =
        pageWidth - 2 * outer - 2 * OrnamentFrame.sideInset(sides);
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
      wordMarker: _nativeNumbering ? _wordMarker : null,
      height: textHeight,
    );
    final first = ayahs.first;
    final page = Padding(
      padding: EdgeInsets.symmetric(
        vertical: outer,
        horizontal: sides ? outer : 0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: header,
            child: _PageHeader(
              surah: widget.quran.surah(first.surah).nameAr,
              juz: first.juz,
              // The usul are told below the page; the header points there.
              onUsul: usul.isEmpty ? null : _showUsul,
            ),
          ),
          Expanded(
            child: _PageFrame(
              page: widget.page,
              sides: sides,
              onNumberTap: widget.onPageNumberTap,
              child: mushafLines,
            ),
          ),
        ],
      ),
    );
    final usulBox = usul.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(4, 1, 4, 6),
            child: _UsulBox(groups: usul, onTap: _openUsulReference),
          );
    if (!withHamesh) {
      if (usulBox == null) return page;
      return SingleChildScrollView(
        controller: _scroll,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const ValueKey('mushaf-print'),
              height: pageHeight,
              child: page,
            ),
            usulBox,
          ],
        ),
      );
    }

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
        math.max(
          0.0,
          top -
              lineHeight * 0.45 +
              (lineOf[VariantRepository.key(
                        e.ayah.surah,
                        e.ayah.number,
                        e.word,
                      )] ??
                      0) *
                  lineHeight,
        ),
    ];

    return SingleChildScrollView(
      controller: _scroll,
      physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: pageHeight,
            child: _MarginPage(
              page: SizedBox(
                key: const ValueKey('mushaf-print'),
                width: pageWidth,
                height: pageHeight,
                child: page,
              ),
              rightWidth: rightWidth,
              leftWidth: leftWidth,
              entries: shown,
              tops: tops,
              onTap: _openReference,
              onFit: (fit) => _setSplit(signature, fit),
            ),
          ),
          if (overflow)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 1, 4, 4),
              child: KeyedSubtree(
                key: const ValueKey('bottom-notes'),
                child: _HameshBox(
                  title: 'تتمة الهامش',
                  entries: entries.sublist(split),
                  onTap: _openReference,
                  columns: narrow ? 3 : 4,
                ),
              ),
            ),
          ?usulBox,
        ],
      ),
    );
  }

  /// Scrolls down to the usul of the page.
  void _showUsul() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  /// Called by the side hamesh after layout with how many notes fit.
  void _setSplit(String signature, int fit) {
    // Measured once; afterwards only fewer (a font loaded late makes the
    // notes taller), or the notes between the margin and the box below
    // would be shown in neither.
    if (signature != _splitFor || _split != null && fit >= _split!) return;
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
    void addEnd(int word) {
      final end = _wordMarker(ayah, word);
      if (end != null) out.add(TextSpan(text: '${end.text} '));
    }

    for (var w = 0; w < ayah.words.length; w++) {
      if (w == 0 && (ayah.rubStart != null || ayah.juzStart)) {
        out.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: PartitionMarker(
              key: ValueKey('partition:${ayah.surah}:${ayah.number}'),
              ayah: ayah,
              fontSize: s.fontSize,
            ),
          ),
        );
      }
      final m = _mark(ayah, w);
      final tap = _recognizer(ayah, w);
      final underline = m.mutashabih ? _mutashabihStyle : null;
      final source = s.displayed == null
          ? null
          : _displayWord(ayah, w, qcf: false)?.text ?? '';
      if (source == '') {
        if (_nativeNumbering) addEnd(w);
        continue;
      }
      final baseWord = source ?? ayah.words[w];

      // A reading given only as a description cannot replace the word.
      final replaceable = m.all.where((v) => v.canReplaceText);
      if (source == null && replace && replaceable.isNotEmpty) {
        final v = replaceable.first;
        if (v.word == w && v.text.isNotEmpty) {
          final shownHere = s.kinds.contains(v.kind);
          out.add(
            TextSpan(
              text: '${v.text} ',
              recognizer: tap,
              style: TextStyle(
                fontFamily: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
                color: shownHere ? ReadingColors.of(v) : null,
                backgroundColor: shownHere
                    ? ReadingColors.of(v).withAlpha(24)
                    : null,
              ),
            ),
          );
        }
        if (_nativeNumbering) addEnd(w);
        continue;
      }

      if (m.shown.every((v) => v.isMarginNote)) {
        out
          ..add(
            TextSpan(
              text: baseWord,
              recognizer: tap,
              style: (underline ?? const TextStyle()).copyWith(color: m.color),
            ),
          )
          ..add(const TextSpan(text: ' '));
        if (_nativeNumbering) addEnd(w);
        continue;
      }

      final color = m.color ?? MushafColors.ink;
      out.add(
        TextSpan(
          text: baseWord,
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
          final text = v.marginText.isNotEmpty ? v.marginText : v.text;
          if (!seen.add(text)) continue;
          out.add(
            TextSpan(
              text: ' ${text.isEmpty ? '—' : text}',
              recognizer: tap,
              style: TextStyle(
                fontFamily: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
                fontSize: s.fontSize * 0.62,
                color: ReadingColors.of(v),
              ),
            ),
          );
        }
      }
      out.add(const TextSpan(text: ' '));
      if (_nativeNumbering) addEnd(w);
    }
    if (!_nativeNumbering) {
      out.add(TextSpan(text: '${arabicDigits(ayah.number)} '));
    }
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
    final shown = _displayWord(ayah, w, qcf: _pageQcf);
    if (shown == null || shown.font.startsWith('QCF_')) return shown;
    final text =
        const {
          null,
          'hisham',
          'ibn_dhakwan',
        }.contains(widget.settings.displayed)
        ? spacedAwa(shown.text)
        : shown.text;
    if (!(_letterReadings(ayah, w)?.any(_spacedImala) ?? false)) {
      return (text: text, font: shown.font);
    }
    return (text: spacedImalaSigns(text), font: shown.font);
  }

  ({String text, String font})? _displayWord(
    Ayah ayah,
    int w, {
    required bool qcf,
  }) {
    final isYaqub = const {
      'ruways',
      'rawh',
    }.contains(widget.settings.displayed);
    final ownKabir = isYaqub
        ? _baseAt(
            widget.variants,
            widget.settings,
            ayah,
            w,
          ).where((v) => v.word == w && v.rule == 'idgham_kabir').firstOrNull
        : null;
    final previousAyah = w > 0
        ? ayah
        : ayah.number > 1
        ? widget.quran.ayah(ayah.surah, ayah.number - 1)
        : null;
    final previousWord = w > 0 ? w - 1 : (previousAyah?.words.length ?? 0) - 1;
    final previousKabir = isYaqub && previousAyah != null
        ? _baseAt(widget.variants, widget.settings, previousAyah, previousWord)
              .where((v) => v.word == previousWord && v.rule == 'idgham_kabir')
              .firstOrNull
        : null;
    final nextWord = w + 1 < ayah.words.length
        ? ayah.words[w + 1]
        : ayah.number < widget.quran.surahs[ayah.surah - 1].ayahCount
        ? widget.quran.ayah(ayah.surah, ayah.number + 1).words.first
        : '';
    final shortMadd =
        isYaqub &&
        ((RegExp(r'^[ءأإؤئآ]').hasMatch(nextWord) &&
                withoutSeparatedMaddSign(ayah.words[w]) != ayah.words[w]) ||
            withoutJoinedSeparatedMaddSign(ayah.words[w]) != ayah.words[w] ||
            _baseAt(
              widget.variants,
              widget.settings,
              ayah,
              w,
            ).any(isYaqubSeparatedMadd));
    final stoppingMadd = _baseAt(
      widget.variants,
      widget.settings,
      ayah,
      w,
    ).where((v) => ruwaysHasratiMaddText(v, ayah.words[w]) != null).firstOrNull;
    // Hafs's kasra for two sakins before a hamzat wasl (بَلِ ٱدَّٰرَكَ) is a
    // sukun again when the riwaya shown reads a hamzat qat' (بَلۡ أَدۡرَكَ).
    final clashKasra =
        widget.settings.displayed != null &&
        w + 1 < ayah.words.length &&
        nextWord.startsWith('ٱ') &&
        RegExp(r'ِ[ۖ-ۭ]*$').hasMatch(ayah.words[w]) &&
        RegExp('^[أإآ]')
            .hasMatch(_writtenDisplayWord(ayah, w + 1, qcf: false)?.text ?? '');
    // Read without Hafs's sakt (مَّرۡقَدِنَاۜ): its small sin is not written.
    final noSakt =
        widget.settings.displayed != null &&
        _baseAt(
          widget.variants,
          widget.settings,
          ayah,
          w,
        ).any((v) => v.word == w && v.rule == 'no_sakt');
    // Without the sakt, its idgham (مَن رَّاقٖ، بَل رَّانَ): the first word's
    // last letter bare, the next word's first letter doubled.
    bool saktIdgham(Ayah a, int i) =>
        i >= 0 &&
        widget.settings.displayed != null &&
        _baseAt(widget.variants, widget.settings, a, i).any(
          (v) =>
              v.word == i &&
              v.rule == 'no_sakt' &&
              v.description.contains('إدغام'),
        );
    final ownSaktIdgham = saktIdgham(ayah, w);
    final previousSaktIdgham = w > 0 && saktIdgham(ayah, w - 1);
    final shown = _writtenDisplayWord(
      ayah,
      w,
      qcf:
          qcf &&
          !clashKasra &&
          !noSakt &&
          !previousSaktIdgham &&
          !shortMadd &&
          stoppingMadd == null &&
          ownKabir == null &&
          previousKabir == null,
    );
    if (shown == null) return null;
    var text = shown.text;
    if (ownKabir != null) {
      final nextAyah = w + 1 < ayah.words.length
          ? ayah
          : ayah.number < widget.quran.surahs[ayah.surah - 1].ayahCount
          ? widget.quran.ayah(ayah.surah, ayah.number + 1)
          : null;
      if (nextAyah != null) {
        final nextW = nextAyah == ayah ? w + 1 : 0;
        final following =
            _writtenDisplayWord(nextAyah, nextW, qcf: false)?.text ??
            nextAyah.words[nextW];
        text = ruwaysKabirText(ownKabir, text, following)?.first ?? text;
      }
    }
    if (previousKabir != null && previousAyah != null) {
      final previous =
          _writtenDisplayWord(previousAyah, previousWord, qcf: false)?.text ??
          previousAyah.words[previousWord];
      text = ruwaysKabirText(previousKabir, previous, text)?.second ?? text;
    }
    if (noSakt) text = text.replaceAll('ۜ', '');
    if (ownSaktIdgham) text = text.replaceFirst(RegExp(r'[ْۡ](?=[ۖ-ۜ]*$)'), '');
    if (previousSaktIdgham && !RegExp('^.ّ').hasMatch(text)) {
      text = '${text[0]}ّ${text.substring(1)}';
    }
    if (clashKasra) text = text.replaceFirst(RegExp(r'ِ(?=[ۖ-ۭ]*$)'), 'ۡ');
    if (stoppingMadd != null) {
      return (
        text: ruwaysHasratiMaddText(stoppingMadd, text)!,
        font: shown.font,
      );
    }
    return (
      text: shortMadd
          ? withoutJoinedSeparatedMaddSign(withoutSeparatedMaddSign(text))
          : text,
      font: shown.font,
    );
  }

  ({String text, String font})? _writtenDisplayWord(
    Ayah ayah,
    int w, {
    required bool qcf,
  }) {
    final s = widget.settings;
    final source = widget.variants.sourceTextAt(
      s.displayed,
      ayah.surah,
      ayah.number,
      w,
    );
    final base = _baseAt(widget.variants, s, ayah, w);
    if (source != null &&
        s.displayed == 'warsh' &&
        _ruwaysTasheelAt(ayah, w) != null) {
      return (text: ayah.words[w], font: 'Hafs');
    }
    if (source != null) {
      final marked = base
          .map((v) => hamzaPairMaddText(v, source))
          .whereType<String>()
          .firstOrNull;
      return source.isEmpty ? null : (text: marked ?? source, font: 'Hafs');
    }
    // The riwaya shown in place of Hafs: its reading takes the place of the
    // Hafs word(s).
    final v = base.where((v) => v.canReplaceText).firstOrNull;
    if (v != null) {
      if (v.word != w || v.text.isEmpty) return null;
      if (const {'ruways', 'rawh'}.contains(s.displayed) &&
          _replacementAt(ayah, w) != null) {
        return (text: ayah.words[w], font: 'Hafs');
      }
      if (_dadAsZa(ayah, w) != null) {
        return (text: ayah.words[w], font: 'Hafs');
      }
      return (text: withNaqlVowel(v.text, ayah.words[w]), font: 'Hafs');
    }
    final glyph = qcf && !(w == 0 && (ayah.rubStart != null || ayah.juzStart))
        ? (ayah.glyphs?[w])
        : null;
    // Drawn with the word before.
    if (glyph != null && glyph.isEmpty) return null;
    final imala = [
      ...base,
      ..._readingsAt(widget.variants, s, ayah, w).shown,
    ].where((v) => v.word == w && v.isImala && !v.isStoppingTaqlil).firstOrNull;
    // The page font has no imala sign to add: such a word is drawn in the
    // Hafs font, with the sign under the letters the reading marks.
    if (imala != null) {
      return (text: withImalaSign(ayah.words[w], imala.text), font: 'Hafs');
    }
    if (_replacementAt(ayah, w) != null || _ruwaysTasheelAt(ayah, w) != null) {
      return (text: ayah.words[w], font: 'Hafs');
    }
    // Nor letters coloured apart.
    if (_letterReadings(ayah, w) != null) {
      return (text: ayah.words[w], font: 'Hafs');
    }
    if (glyph != null) return (text: glyph, font: QcfFonts.family(widget.page));
    return (text: ayah.words[w], font: 'Hafs');
  }

  /// General rules with a specific letter to colour. Compound hamza and
  /// silah readings keep both colours instead of a comparison rawi's colour.
  List<Variant>? _letterReadings(Ayah ayah, int w) {
    final s = widget.settings;
    final base = _baseAt(widget.variants, s, ayah, w);
    final readings =
        [
              ...base.where((v) => v.isUsul),
              ..._readingsAt(widget.variants, s, ayah, w).shown,
            ]
            .where(
              (v) =>
                  v.word == w &&
                  !v.isMarginNote &&
                  !isRoutineMadd(v) &&
                  showYaqubMimExample(v, ayah.words[v.word]) &&
                  _showYaIdafa(v, ayah, widget.variants, s) &&
                  s.kinds.contains(v.kind),
            )
            .toList();
    bool targeted(Variant v) =>
        v.isUsul &&
        (v.isBadal ||
            v.rule == 'ishmam' ||
            v.rule == 'ishmam_sad' ||
            v.isLinHamz ||
            v.isImala ||
            v.isTarqiqOrTaghliz ||
            _naqlKind(v) != null ||
            RegExp('همز|صلة|إدغام|ادغام').hasMatch(v.description));
    final lexical = readings.any((v) => !v.isUsul);
    if (readings.isEmpty ||
        readings.any((v) => v.isUsul && !targeted(v)) ||
        lexical && !readings.any((v) => v.isTarqiqOrTaghliz)) {
      return null;
    }
    // Tarqiq and taghliz colour their ra or lam alone, the rest of the word
    // in ink (the whole word glows when differences are alerted).
    if ((readings.any((v) => v.isImala && !v.isStoppingTaqlil) &&
        readings.every(
          (v) =>
              (v.isImala || v.isBadal) &&
              !RegExp('همز|نقل|صلة|إدغام|ادغام').hasMatch(v.description),
        ))) {
      return null;
    }
    return readings;
  }

  Variant? _replacementAt(Ayah ayah, int w) =>
      !const {'warsh', 'ruways', 'rawh'}.contains(widget.settings.displayed)
      ? null
      : [
              ..._baseAt(widget.variants, widget.settings, ayah, w),
              ..._readingsAt(widget.variants, widget.settings, ayah, w).shown,
            ]
            .where(
              (v) =>
                  v.word == w &&
                  v.riwayaId == widget.settings.displayed &&
                  v.hamzaReplacement != null &&
                  widget.settings.kinds.contains(v.kind),
            )
            .firstOrNull;

  /// The displayed riwaya reads the word's dad as a za' (بِظَنِينٖ for
  /// بِضَنِينٖ): the index of that letter, written as the rasm's dad with a
  /// small za' over it.
  int? _dadAsZa(Ayah ayah, int w) {
    if (widget.settings.displayed == null) return null;
    final v = _baseAt(
      widget.variants,
      widget.settings,
      ayah,
      w,
    ).where((v) => v.word == w && v.count == 1 && v.canReplaceText).firstOrNull;
    if (v == null) return null;
    final hafs = lettersOf(ayah.words[w]), own = lettersOf(v.text);
    if (hafs.length != own.length) return null;
    int? at;
    for (var i = 0; i < hafs.length; i++) {
      if (hafs[i][0] == own[i][0]) continue;
      if (at != null || hafs[i][0] != 'ض' || own[i][0] != 'ظ') return null;
      at = i;
    }
    return at;
  }

  /// Ruways's eased hamza, and Warsh's second hamza of two words (شُهَدَآءَ
  /// إِذۡ), drawn on Hafs's hamza with the circle; Warsh's own text writes it
  /// as a bare alif.
  Variant? _ruwaysTasheelAt(Ayah ayah, int w) =>
      !const {'ruways', 'warsh'}.contains(widget.settings.displayed)
      ? null
      : _baseAt(widget.variants, widget.settings, ayah, w)
            .where(
              (v) =>
                  v.word == w &&
                  (widget.settings.displayed == 'warsh'
                      // Not where his text writes the ibdal face (ٱلسَّمَآءَ آن).
                      ? v.rule == 'tasheel_pair' &&
                            !v.usulWays.any((w) => w.contains('إبدال'))
                      : const {
                          'tasheel_word',
                          'tasheel_pair',
                        }.contains(v.rule)) &&
                  v.description.contains('تسهيل') &&
                  widget.settings.kinds.contains(v.kind),
            )
            .firstOrNull;

  /// [text] in parts, each affected letter in the colour of its rule.
  List<(String, Color?)>? _letterParts(Ayah ayah, int w, String text) {
    final readings = _letterReadings(ayah, w);
    if (readings == null) return null;
    final letters = lettersOf(text);
    final colors = <int, Color>{};
    final priorities = <int, int>{};
    final farshColor = ReadingColors.ofReadings(
      readings.where((v) => !v.isUsul).toList(),
    );
    if (farshColor != null) {
      for (var i = 0; i < letters.length; i++) {
        colors[i] = farshColor;
      }
    }
    var priority = 0;
    void mark(int? i, Color color, {bool badal = false}) {
      if (i == null || i < 0 || i >= letters.length) return;
      final rank = priority * 2 + (badal ? 1 : 0);
      if (rank < (priorities[i] ?? -1)) return;
      colors[i] = color;
      priorities[i] = rank;
    }

    for (final v in readings) {
      if (!v.isUsul) continue;
      priority = v.riwayaId == widget.settings.displayed ? 1 : 0;
      if (v.rule == 'ishmam' || v.rule == 'ishmam_sad') {
        // The letter whose kasra is given a touch of damma: the qaf of
        // وَقِيلَ, not the waw before it.
        final kasra = letters.indexWhere((l) => l.contains('ِ'));
        final at = v.rule == 'ishmam_sad'
            ? letters.indexWhere((l) => l.startsWith('ص'))
            : kasra < 0
            ? 0
            : kasra;
        mark(at, ReadingColors.of(v));
        continue;
      }
      if (v.isStoppingTaqlil) {
        var at = letters.lastIndexWhere((l) => l.startsWith('ى'));
        if (at < 0) at = letters.lastIndexWhere((l) => l.startsWith('ا'));
        mark(at < 0 ? null : at, MushafColors.green);
        continue;
      }
      if (v.isLinHamz) {
        for (final i in linHamzLetters(text)) {
          mark(i, MushafColors.green);
        }
        continue;
      }
      if (v.isTarqiqOrTaghliz) {
        final i = v.rule == 'tarqiq' ? raLetter(letters) : lamLetter(letters);
        mark(i, MushafColors.rule);
        continue;
      }
      final kind = v.isBadal ? null : _naqlKind(v);
      final i = v.isBadal
          ? badalLetter(letters)
          : kind == _Naql.alef
          ? 0
          : kind == _Naql.dropped
          ? null
          : naqlLetter(letters, last: kind == _Naql.last);
      if (v.isBadal || kind != null) {
        mark(
          i,
          v.isBadal ? MushafColors.green : ReadingColors.naql,
          badal: v.isBadal,
        );
      }
      final d = v.description;
      if (v.rule == 'hamza_wasl' && d.contains('نقل')) {
        final lam = letters.indexWhere((l) => l.startsWith('ل'));
        mark(lam < 0 ? null : lam, ReadingColors.naql);
      }
      if (v.isImala) {
        // Every letter with the sign (رَ۪ءَ۪ا: the ra and the hamza).
        for (final (i, l) in letters.indexed) {
          if (l.contains(imalaSign)) mark(i, MushafColors.green);
        }
      }
      if (RegExp('إبدال|ابدال|تسهيل|تخفيف الهمزة').hasMatch(d)) {
        final hafs = lettersOf(ayah.words[w]);
        final hamzas = [
          for (final (i, l) in hafs.indexed)
            if (_hamzaCluster(l)) i,
        ];
        final variant = lettersOf(v.text);
        final target =
            v.rule == 'ibdal_waw' ||
                v.rule == 'ibdal_ya' ||
                v.rule == 'tasheel_pair'
            ? 0
            : v.rule == 'tasheel_word' || v.rule == 'hamza_wasl'
            ? 1
            : hamzas
                      .where(
                        (i) => i < variant.length && !_hamzaCluster(variant[i]),
                      )
                      .firstOrNull ??
                  hamzas.lastOrNull;
        mark(target, ReadingColors.hamza);
      }
      if (d.contains('صلة')) {
        final base = d.contains('ميم') || d.contains('الميم') ? 'م' : 'ه';
        final at = letters.lastIndexWhere((l) => l.startsWith(base));
        mark(at < 0 ? null : at, ReadingColors.silah);
      }
      if (RegExp('إدغام|ادغام').hasMatch(d)) {
        final merged = const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId)
            ? _mergedLetters(d, letters)
            : null;
        if (merged != null) {
          for (final i in merged) {
            mark(i, ReadingColors.idgham);
          }
        } else if (letters.first.contains('ّ')) {
          mark(0, ReadingColors.idgham);
        }
      }
    }
    if (colors.isEmpty) return null;
    // The displayed narrator owns overlapping letters. Within that narrator,
    // badal retains its agreed priority over naql independently of row order.
    return [for (final (i, l) in letters.indexed) (l, colors[i])];
  }

  /// [parts] (or [text] whole) drawn out by [kashida] tatweels.
  List<(String, Color?)>? _stretched(
    String text,
    List<(String, Color?)>? parts,
    int kashida,
  ) {
    if (kashida == 0) return parts;
    final letters = parts == null
        ? lettersOf(text)
        : [for (final (l, _) in parts) l];
    final drawn = withKashida(letters, kashida);
    return [
      for (final (i, l) in drawn.indexed)
        (l, parts == null ? null : parts[i].$2),
    ];
  }

  /// The ayah-end ornament: the printed one from the page font when loaded.
  ({String text, String font})? _marker(Ayah ayah) =>
      _pageQcf && ayah.endGlyph != null
      ? (text: ' ${ayah.endGlyph}', font: QcfFonts.family(widget.page))
      : null;

  String get _countingSystem =>
      AudioNumbering.displaySystemFor(widget.settings.displayed ?? 'hafs');
  bool get _nativeNumbering =>
      widget.quran.numbering != null && _countingSystem != 'kufi';

  ({String text, String font})? _wordMarker(Ayah ayah, int word) {
    final n = widget.quran.numbering?.markerAt(
      _countingSystem,
      ayah.surah,
      ayah.number,
      word,
    );
    return n == null ? null : (text: ' ${arabicDigits(n)}', font: 'Hafs');
  }

  /// One word of a printed line.
  Widget _word(Ayah ayah, int w, double fontSize, [int kashida = 0]) {
    final m = _mark(ayah, w);
    final shown = _display(ayah, w)!;
    // Not the page glyphs of the Madinah print: letters to colour and draw out.
    final hafsFont = !shown.font.startsWith('QCF_');
    final coloured = hafsFont ? _letterParts(ayah, w, shown.text) : null;
    final parts = hafsFont ? _stretched(shown.text, coloured, kashida) : null;
    // Kashida groups may contain several base characters. Repainting a
    // stripped hamza seat must preserve their expanded colour alignment.
    final expanded = parts == null
        ? null
        : [
            for (final (text, color) in parts)
              for (final cluster in lettersOf(text)) (cluster, color),
          ];
    final replacement = _replacementAt(ayah, w);
    final ruwaysTasheel = _ruwaysTasheelAt(ayah, w);
    final roundedTasheel =
        widget.settings.displayed == 'warsh' &&
        RegExp(r'^[اأ]َ[وي][ْۡ]۟').hasMatch(shown.text) &&
        _baseAt(
          widget.variants,
          widget.settings,
          ayah,
          w,
        ).any((v) => v.rule == 'tasheel_word');
    final stopping =
        _letterReadings(ayah, w)?.any((v) => v.isStoppingTaqlil) ?? false;
    final alert = widget.settings.diffAlert;
    Widget ink(String drawn, [int? hiddenHamza]) {
      final style = TextStyle(
        fontFamily: shown.font,
        fontSize: fontSize,
        height: 1,
        color: coloured != null
            ? MushafColors.ink
            : m.color ?? MushafColors.ink,
      );
      Widget draw(double glow) => InkText(
        shown.text,
        key: ValueKey('word:${ayah.surah}:${ayah.number}:$w'),
        parts: hiddenHamza != null
            ? HamzaReplacementMark.hideHamza([
                for (final (i, l) in lettersOf(drawn).indexed)
                  (l, expanded?.elementAtOrNull(i)?.$2),
              ], hiddenHamza)
            : drawn == (parts?.map((p) => p.$1).join() ?? shown.text)
            ? parts
            : [
                for (final (i, l) in lettersOf(drawn).indexed)
                  (l, expanded?.elementAtOrNull(i)?.$2),
              ],
        style: style,
        glowFinalAlif: stopping,
        glowStrength: glow,
      );
      final child = stopping && alert != null
          ? AnimatedBuilder(
              animation: _alert,
              builder: (_, _) => draw(Curves.easeInOut.transform(_alert.value)),
            )
          : draw(0);
      // Read so only when stopping: the letter's colour tells it, with no
      // sign under it.
      return child;
    }

    final drawn = parts?.map((p) => p.$1).join() ?? shown.text;
    Widget word = ink(drawn);
    if (replacement != null) {
      final h = _hamzaLetter(ayah.words[w]);
      word = HamzaReplacementMark(
        text: drawn,
        offset: lettersOf(drawn).take(h).join().length,
        originalHamza: lettersOf(ayah.words[w])[h],
        letter: replacement.hamzaReplacement!,
        color: ReadingColors.of(replacement),
        style: TextStyle(fontFamily: 'Hafs', fontSize: fontSize, height: 1),
        builder: ink,
      );
    } else if (roundedTasheel || ruwaysTasheel != null) {
      final second = ruwaysTasheel?.rule != 'tasheel_pair';
      // The hamza eased, as Hafs writes it; or as the riwaya does, where
      // Hafs has none there (أَئِنَّكُمۡ for إِنَّكُمۡ).
      final hafsHamza = lettersOf(ayah.words[w])
          .elementAtOrNull(second ? 1 : 0);
      word = HamzaReplacementMark(
        text: drawn,
        offset: second ? lettersOf(drawn).first.length : 0,
        originalHamza:
            hafsHamza != null && RegExp('[ءأإآؤئ]').hasMatch(hafsHamza)
            ? hafsHamza
            : lettersOf(drawn).elementAtOrNull(second ? 1 : 0),
        letter: '',
        color: ReadingColors.hamza,
        style: TextStyle(fontFamily: 'Hafs', fontSize: fontSize, height: 1),
        builder: ink,
      );
    }
    final za = _dadAsZa(ayah, w);
    if (za != null) {
      word = LetterAboveMark(
        text: drawn,
        offset: lettersOf(drawn).take(za).join().length,
        letter: 'ظ',
        style: TextStyle(fontFamily: 'Hafs', fontSize: fontSize, height: 1),
        color: m.color ?? MushafColors.ink,
        child: word,
      );
    }
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
    if (alert != null && !stopping && (m.color != null || coloured != null)) {
      word = _Alerting(animation: _alert, style: alert, child: word);
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
      onLongPress: widget.onAyahWordTap != null
          ? () => widget.onAyahWordTap!(ayah, w)
          : widget.onAyahTap == null
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

  void _openUsulReference(_UsulItem item) {
    ReferenceSheet.show(
      context,
      readings: item.readings,
      word: item.text,
      surah: item.ayah.surah,
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

const _letterNames = {
  'باء': 'ب',
  'تاء': 'ت',
  'ثاء': 'ث',
  'جيم': 'ج',
  'دال': 'د',
  'ذال': 'ذ',
  'راء': 'ر',
  'زاي': 'ز',
  'سين': 'س',
  'شين': 'ش',
  'صاد': 'ص',
  'ضاد': 'ض',
  'طاء': 'ط',
  'ظاء': 'ظ',
  'فاء': 'ف',
  'قاف': 'ق',
  'كاف': 'ك',
  'لام': 'ل',
  'ميم': 'م',
  'نون': 'ن',
  'واو': 'و',
  'ياء': 'ي',
};

/// The letters of an idgham told «بإدغام التاء في الصاد»: the merged letter
/// (the last of its word, or the one before the other with shadda) and the
/// word it is merged in, as the next word is coloured whole: «لَّهُدِّمَت
/// صَّوَٰمِعُ» colours the ta and «صَّوَٰمِعُ», not the lam of Hafs's own
/// idgham. Null when not told so.
List<int>? _mergedLetters(String description, List<String> letters) {
  final m = RegExp(r'إدغام (?:ال)?(\S+) (?:في|ب) ?(?:ال)?(\S+)')
      .firstMatch(description);
  final x = _letterNames[m?[1]], y = _letterNames[m?[2]];
  if (x == null || y == null) return null;
  // The letters without the space between two words read as one.
  final at = [
    for (final (i, l) in letters.indexed)
      if (l.trim().isNotEmpty) i,
  ];
  bool merges(int j) =>
      letters[at[j]].startsWith(y) && letters[at[j]].contains('ّ');
  final out = <int>[];
  for (var j = 0; j < at.length; j++) {
    if (!letters[at[j]].startsWith(x)) continue;
    if (at[j] == letters.length - 1) out.add(at[j]);
    if (j + 1 < at.length && merges(j + 1)) {
      out.add(at[j]);
      // The next word, when both are drawn as one.
      if (at[j + 1] > at[j] + 1) {
        for (
          var i = at[j + 1];
          i < letters.length && letters[i].trim().isNotEmpty;
          i++
        ) {
          out.add(i);
        }
      }
    }
  }
  return out;
}

/// Ibn Dhakwan's imala of the ra and the hamza (رَ۪ءَ۪اكَ), drawn apart so
/// that both signs are seen ([spacedImalaSigns]).
bool _spacedImala(Variant v) => v.riwayaId == 'ibn_dhakwan' && v.isImala;

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
  return variants
      .at([base], ayah.surah, ayah.number, w)
      .where((v) => !v.readsAsHafs && !isRoutineMadd(v))
      .toList();
}

/// Fixed colours for general rules; narrator colours for farsh readings.
Color? _colorOf(List<Variant> readings) {
  return ReadingColors.ofReadings(readings);
}

bool _showYaIdafa(
  Variant v,
  Ayah ayah,
  VariantRepository variants,
  ReaderSettings s,
) {
  if (v.rule != 'ya_idafa' || !const {'ruways', 'rawh'}.contains(v.riwayaId)) {
    return true;
  }
  final reference = s.displayed == null || s.displayed == v.riwayaId
      ? ayah.words[v.word]
      : readingText(variants, s.displayed, ayah, v.word, v.word + v.count);
  return showYaqubYaIdafaExample(v, reference);
}

/// How the other selected riwayat read a word, compared with the riwaya the
/// mushaf shows (Hafs, or [ReaderSettings.displayed]). Agreement with Hafs
/// is reconstructed when it differs from the displayed reading. Equal
/// readings are omitted; the base keeps its own usul colours.
_Readings _readingsAt(
  VariantRepository variants,
  ReaderSettings s,
  Ayah ayah,
  int w,
) => _readingsMemo.putIfAbsent((
  variants,
  s,
  ayah,
  w,
), () => _readingsOf(variants, s, ayah, w));

typedef _Readings = ({
  List<Variant> all,
  List<Variant> shown,
  List<Color> colors,
  Color? color,
});

/// The readings of each word, worked out once per build of the pages: a
/// word asks for them for its colour, its letters, the key and the hamesh.
final _readingsMemo = <(Object, Object, Ayah, int), _Readings>{};

_Readings _readingsOf(
  VariantRepository variants,
  ReaderSettings s,
  Ayah ayah,
  int w,
) {
  final base = _baseAt(variants, s, ayah, w);
  final all = compareReadings(
    repository: variants,
    ayah: ayah,
    word: w,
    displayed: s.displayed,
    selected: {...s.selected, if (s.compareHafs) hafsId},
  ).where((v) => !v.readsAsHafs).toList();
  // Source reminders remain visible when their own riwaya is the base.
  all.addAll(base.where((v) => v.isMarginNote));
  final shown = all
      .where(
        (v) =>
            s.kinds.contains(v.kind) &&
            !isRoutineMadd(v) &&
            showYaqubMimExample(v, ayah.words[v.word]) &&
            _showYaIdafa(v, ayah, variants, s),
      )
      .toList();
  final colors = [
    for (final id in shown.map((v) => v.riwayaId).toSet())
      ?ReadingColors.ofReadings(shown.where((v) => v.riwayaId == id).toList()),
  ];
  return (
    all: all,
    shown: shown,
    colors: colors,
    color:
        _colorOf(
          base
              .where(
                (v) =>
                    v.isUsul &&
                    !isRoutineMadd(v) &&
                    showYaqubMimExample(v, ayah.words[v.word]) &&
                    _showYaIdafa(v, ayah, variants, s) &&
                    s.kinds.contains(v.kind),
              )
              .toList(),
        ) ??
        _colorOf(shown),
  );
}

/// The usul of the page, by kind: each with its colour, and every word of
/// [words] it is read in, with who reads it so (الإمالة: «هُدَ۪ى» حمزة،
/// الكسائي). The page colours them; they are told once, below it.
List<_UsulGroup> _usulNotes(
  Iterable<(Ayah, int)> words,
  VariantRepository variants,
  ReaderSettings s,
  QuranRepository quran,
) {
  final groups = <String, _UsulGroup>{};
  final hasYaqub = {
    ...s.selected,
    ?s.displayed,
  }.any((id) => const {'ruways', 'rawh'}.contains(id));
  for (final (ayah, w) in words) {
    // Equal rule descriptions can still have different written examples
    // (e.g. Warsh's extended mim silah versus Ibn Kathir's). Do not use
    // the main text's comparison filter to choose the margin examples.
    for (final v in variants.at(
      {...s.selected, ?s.displayed},
      ayah.surah,
      ayah.number,
      w,
    )) {
      if (!s.kinds.contains(v.kind) ||
          v.word != w ||
          v.inHamesh ||
          v.riwayaId == hafsId ||
          isRoutineMadd(v) ||
          !showYaqubMimExample(v, ayah.words[w]) ||
          !_showYaIdafa(v, ayah, variants, s) ||
          v.rule == 'naql_source' ||
          v.rule == 'hamza_source') {
        continue;
      }
      final own = ReadingColors.of(v);
      final kinds = v.isBadal
          ? [('مد البدل', MushafColors.green)]
          : v.rule == 'tarqiq'
          ? [('ترقيق الراء', MushafColors.rule)]
          : v.rule == 'taghliz'
          ? [('تغليظ اللام', MushafColors.rule)]
          : v.isSakt
          ? [('السكت قبل الهمز', own)]
          : v.readsAsHafs
          ? [('الإدغام بلا غنة', own)]
          : v.isQasr
          ? [('قصر المنفصل', own)]
          : [
              if (v.isImala)
                RegExp('تقليل|بين').hasMatch(v.description)
                    ? ('التقليل', MushafColors.green)
                    : ('الإمالة', MushafColors.green),
              for (final l in _usulOf(v))
                if (!v.isImala || l != 'المدود') (l, own),
              if (!v.isImala && _usulOf(v).isEmpty) ('أصول أخرى', own),
            ];
      final word = usulReadingText(
        v,
        ayah,
        variants,
        nextAyah: ayah.number < quran.surah(ayah.surah).ayahCount
            ? quran.ayah(ayah.surah, ayah.number + 1)
            : null,
        previousAyah: v.word == 0 && ayah.number > 1
            ? quran.ayah(ayah.surah, ayah.number - 1)
            : null,
      );
      for (final (label, _) in kinds) {
        final ways =
            ReadingColors.labelForRule(v.rule) != null ||
                v.isLinHamz ||
                v.rule == 'ya_zaida' ||
                label.contains('همز') &&
                    (v.usulWays.length > 1 ||
                        v.rule == 'tasheel_pair' ||
                        v.rule == 'tasheel_word')
            ? v.usulWays
            : const <String>[];
        // Equal labels need separate groups when their permitted faces
        // differ (qasr / ishba', arid movement, or changed badal).
        final groupKey = '$label:${ways.join('|')}';
        final g = groups.putIfAbsent(
          groupKey,
          () => _UsulGroup(label, ReadingColors.forLabel(label)),
        );
        g.ways.addAll(ways);
        final item = g.items.putIfAbsent(
          hasYaqub
              ? 'yaqub:${v.stopOnly}:$word:${v.hamzaReplacement}'
              : '${ayah.surah}:${ayah.number}:$w:${v.stopOnly}:$word:${v.hamzaReplacement}',
          () => _UsulItem(
            ayah,
            w,
            word,
            v.stopOnly,
            v.hamzaReplacement ??
                ((v.riwayaId == 'ruways' &&
                            const {
                              'tasheel_word',
                              'tasheel_pair',
                            }.contains(v.rule) &&
                            v.description.contains('تسهيل')) ||
                        v.riwayaId == 'warsh' &&
                            v.rule == 'tasheel_word' &&
                            RegExp(r'^[اأ]َ[وي][ْۡ]۟').hasMatch(word)
                    ? ''
                    : null),
          ),
        );
        item.riwayat.add(v.riwayaId);
        item.readings.add(v);
      }
    }
  }
  return groups.values.toList();
}

class _UsulGroup {
  _UsulGroup(this.label, this.color);

  final String label;
  final Color color;
  final items = <String, _UsulItem>{};
  final ways = <String>{};
}

class _UsulItem {
  _UsulItem(this.ayah, this.word, this.text, this.stopOnly, this.replacement);

  final Ayah ayah;
  final int word;
  final String text;
  final bool stopOnly;
  final String? replacement;
  final riwayat = <String>{};
  final readings = <Variant>[];
  final ways = <String>{};
}

/// The usul a reading applies, by its description: the key's wording.
List<String> _usulOf(Variant v) {
  final typed = ReadingColors.labelForRule(v.rule);
  if (typed != null) return [typed];
  final d = v.description;
  if (v.rule == 'ya_zaida') return ['ياءات الزوائد'];
  if (v.isLinHamz) {
    return [LinHamz.values.singleWhere((kind) => kind.rule == v.rule).label];
  }
  if (v.rule == 'tasheel_word') {
    if (v.description.contains('تحقيق') && !v.description.contains('تسهيل')) {
      return ['الهمزتان في كلمة'];
    }
    // Named by the vowel of the second hamza of the word (ءَأَنذَرۡتَهُمۡ،
    // أَئِنَّكُمۡ، أَءُنزِلَ).
    // (Ibn 'Amir's readings; the others keep their own names.)
    final match = RegExp('[ءأإئؤ][ً-ٰٟ]*[^ءأإئؤ]{0,2}?[ءأإئؤ]([ً-ٰٟ]*)')
        .firstMatch(v.usulText);
    final second = const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId)
        ? match?.group(1)
        : null;
    return [
      second == null
          ? v.usulWays.length > 1
                ? 'الهمزتان المفتوحتان في كلمة'
                : 'تسهيل الهمزتين في كلمة'
          : second.contains('ِ')
          ? 'الهمزتان المفتوحة والمكسورة في كلمة'
          : second.contains('ُ')
          ? 'الهمزتان المفتوحة والمضمومة في كلمة'
          : 'الهمزتان المفتوحتان في كلمة',
      if (d.contains('صلة ميم الجمع')) 'صلة ميم الجمع',
    ];
  }
  if (v.rule == 'tasheel_pair' ||
      (v.rule == 'ibdal_waw' && v.usulWays.length > 1)) {
    return [
      'الهمزتان من كلمتين',
      if (d.contains('صلة ميم الجمع')) 'صلة ميم الجمع',
    ];
  }
  if (v.rule == 'ha_antum') return ['همزة هأنتم'];
  // Ya'qub's naql (عَادٗا ٱلُّاولَىٰ) is told in its own chapter only, though its
  // note names the merged tanween.
  if (v.rule == 'naql' && const {'ruways', 'rawh'}.contains(v.riwayaId)) {
    return ['النقل'];
  }
  if (v.rule == 'hamza_wasl') {
    return ['همزة الاستفهام مع همزة الوصل', if (d.contains('نقل')) 'النقل'];
  }
  return [
    if (RegExp('صلة (ال)?ميم|وصلة الميم|صلة الميم').hasMatch(d))
      'صلة ميم الجمع',
    if (RegExp('صلة (ال)?هاء|بصلة الهاء|ترك صلة').hasMatch(d)) 'صلة هاء الضمير',
    if (RegExp('إدغام|ادغام|الإدغام').hasMatch(d)) 'الإدغام',
    if (RegExp(r'نقل').hasMatch(d)) 'النقل',
    if (RegExp('إبدال|ابدال').hasMatch(d)) 'إبدال الهمز',
    if (RegExp('تسهيل').hasMatch(d)) 'تسهيل الهمز',
    if (RegExp('تخفيف الهمز|حذف الهمزة').hasMatch(d) && !d.contains('تسهيل'))
      'الهمزات',
    if (RegExp('تحقيق الهمز').hasMatch(d)) 'تحقيق الهمز',
    if (d.contains('البدل')) 'مد البدل',
    // Ya'qub's madd is known of the riwaya, not told at each word.
    if (!const {'ruways', 'rawh'}.contains(v.riwayaId) &&
        RegExp(r'(^|\s)(ب|و)?(ال)?مد|ومدها|القصر').hasMatch(d) &&
        !v.isQasr &&
        !d.contains('البدل') &&
        !RegExp('المتصل|المنفصل').hasMatch(d))
      'المدود',
    if (RegExp('إشمام|الإشمام').hasMatch(d)) 'الإشمام',
    if (RegExp('سكت').hasMatch(d) && !d.contains('دون سكت')) 'السكت',
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
      // Usul are told once by their colour, in the page's key; beside the
      // farsh, only what the certified source states.
      final starting = m.shown.where((v) => v.word == w && v.inHamesh).toList();
      if (starting.isEmpty) continue;
      final end = starting
          .map((v) => v.word + v.count)
          .reduce((a, b) => a > b ? a : b);
      // The word as shown on the page: Hafs, or the riwaya shown.
      final hafs = readingText(variants, settings.displayed, ayah, w, end);
      // With its vowels: «زَكَرِيَّآءَ» then «زَكَرِيَّآءُ» are two notes.
      final key = [
        hafs,
        for (final v in starting) '${v.riwayaId}=${v.text}=${v.description}',
      ].join('|');
      if (!seen.add(key)) continue;
      out.add(
        HameshEntry(
          ayah,
          w,
          spacedAwa(hafs),
          ReadingColors.ofReadings(starting) ?? m.color ?? MushafColors.ink,
          starting,
        ),
      );
    }
  }
  return out;
}

enum _Naql { lam, last, dropped, alef }

bool _hamzaCluster(String letter) =>
    letter.isNotEmpty && ('ءأإؤئآ'.contains(letter[0]) || letter.contains('ٔ'));

/// How a reading is naql: the hamza's vowel given to the lam of al, or to
/// the last letter of the word, or the hamza dropped after it; null when
/// it is something else.
_Naql? _naqlKind(Variant v) => switch (v.description) {
  'بنقل حركة الهمزة إليها' => _Naql.last,
  'بحذف الهمزة' => _Naql.dropped,
  'بنقل حركة الهمزة إلى الساكن قبلها وصلاً' => _Naql.alef,
  final d
      when v.rule == 'naql' &&
          d.startsWith('بنقل حركة الهمزة إلى الساكن قبلها') =>
    _Naql.alef,
  // The alef left of a hamza whose vowel went to the word before (اُخَرَ).
  'بتخفيف الهمزة' when RegExp(r'^ا[َ-ِ]?[ء-ي]').hasMatch(v.text) => _Naql.alef,
  final d
      when RegExp(r'^(بفتح اللام و)?ب?نقل حركة الهمزة إلى اللام( والقصر)?$')
          .hasMatch(d) =>
    _Naql.lam,
  _ => null,
};

/// The hamesh's few words on a reading: the riwaya file's explanation
/// (بفتح النون وتشديد الجيم), else the certified source's wording.
String _brief(Variant v) => v.shownDescription;

String arabicDigits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();

/// Ornamented mushaf border around the Hafs text, with the page number.
class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.page,
    required this.child,
    this.onNumberTap,
    this.sides = true,
  });

  final int page;
  final bool sides;
  final Widget child;
  final VoidCallback? onNumberTap;

  /// Space outside the border, including a visible gap above the number.
  static const numberHeight = 30.0;
  static const numberGap = 6.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: OrnamentFrame(
            key: ValueKey('mushaf-ornament-$page'),
            sides: sides,
            child: child,
          ),
        ),
        SizedBox(
          height: numberHeight,
          child: Padding(
            padding: const EdgeInsets.only(top: numberGap),
            child: Center(
              child: GestureDetector(
                onTap: onNumberTap,
                child: Text(
                  arabicDigits(page),
                  key: ValueKey('page-number-$page'),
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    // Hafs otherwise combines digits into ayah ornaments.
                    fontFeatures: const [
                      FontFeature.disable('liga'),
                      FontFeature.disable('rlig'),
                      FontFeature.disable('calt'),
                    ],
                    fontSize: 18,
                    height: 1.2,
                    color: MushafColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The line above the frame, as printed: surah name on the right, juz on
/// the left.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.surah, required this.juz, this.onUsul});

  final String surah;
  final int juz;

  /// Shows the usul of the page, told below it; null when it has none.
  final VoidCallback? onUsul;

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
            child: onUsul == null
                ? const SizedBox()
                : Center(
                    child: InkWell(
                      onTap: onUsul,
                      child: Text(
                        'الأصول ↓',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: MushafColors.green,
                        ),
                      ),
                    ),
                  ),
          ),
          Text('الجزء ${_juzNames[juz - 1]}', style: style),
        ],
      ),
    );
  }
}

/// A fixed, readable margin for the visible section of a landscape page.
class _LandscapeMargin extends StatefulWidget {
  const _LandscapeMargin({super.key, required this.child, required this.farsh});

  final Widget child;
  final bool farsh;

  @override
  State<_LandscapeMargin> createState() => _LandscapeMarginState();
}

class _LandscapeMarginState extends State<_LandscapeMargin> {
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: ValueKey(
      widget.farsh ? 'landscape-farsh-margin' : 'landscape-usul-margin',
    ),
    color: MushafColors.goldLight.withAlpha(35),
    child: Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        key: ValueKey(
          widget.farsh ? 'landscape-farsh-scroll' : 'landscape-usul-scroll',
        ),
        controller: _scroll,
        primary: false,
        padding: const EdgeInsets.all(5),
        child: widget.child,
      ),
    ),
  );
}

/// One outer margin; the measured remainder continues below the print.
class _SequentialNote {
  const _SequentialNote(this.ayah, this.word, this.farsh, this.child);
  final Ayah ayah;
  final int word;
  final bool farsh;
  final Widget child;
  int get position => VariantRepository.key(ayah.surah, ayah.number, word);
}

class _SequentialMarginPage extends StatefulWidget {
  const _SequentialMarginPage({
    super.key,
    required this.notes,
    required this.tops,
    required this.page,
    required this.right,
    required this.rail,
    required this.height,
    required this.zoomed,
    this.section = '',
  });
  final String section;
  final List<_SequentialNote> notes;
  final List<double> tops;
  final Widget page;
  final bool right, zoomed;
  final double rail, height;
  @override
  State<_SequentialMarginPage> createState() => _SequentialMarginPageState();
}

class _SequentialMarginPageState extends State<_SequentialMarginPage> {
  Set<int>? _fit;
  @override
  void didUpdateWidget(_SequentialMarginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) _fit = null;
  }

  void _onFit(Set<int> fit) {
    // Measured once; afterwards only fewer (a font loaded late), or a note
    // would be shown neither beside the page nor below it.
    if (_fit != null && fit.length >= _fit!.length) return;
    final section = widget.section;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (_fit == null || fit.length < _fit!.length) &&
          widget.section == section) {
        setState(() => _fit = fit);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _fit ?? {for (var i = 0; i < widget.notes.length; i++) i};
    return SingleChildScrollView(
      key: const ValueKey('sequential-reader'),
      primary: false,
      physics: widget.zoomed ? const NeverScrollableScrollPhysics() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: ClipRect(
              key: ValueKey(
                widget.right
                    ? 'sequential-right-margin'
                    : 'sequential-left-margin',
              ),
              child: CustomMultiChildLayout(
                delegate: _SequentialNotesLayout(
                  widget.notes,
                  widget.tops,
                  shown,
                  _onFit,
                  widget.right,
                  widget.rail,
                ),
                children: [
                  LayoutId(id: 'page', child: widget.page),
                  for (final i in shown)
                    LayoutId(id: i, child: widget.notes[i].child),
                ],
              ),
            ),
          ),
          if (shown.length < widget.notes.length)
            Padding(
              key: const ValueKey('sequential-bottom-notes'),
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.notes.length; i++)
                    if (!shown.contains(i))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: widget.notes[i].child,
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Give farsh its printed-line position first; origins fill the remaining
/// gaps as whole groups. Neither a crowded group nor a late note pushes
/// an earlier farsh note away from its Quran line.
class _SequentialNotesLayout extends MultiChildLayoutDelegate {
  _SequentialNotesLayout(
    this.notes,
    this.tops,
    this.shown,
    this.onFit,
    this.right,
    this.rail,
  );
  final List<_SequentialNote> notes;
  final List<double> tops;
  final Set<int> shown;
  final ValueChanged<Set<int>> onFit;
  final bool right;
  final double rail;

  @override
  void performLayout(Size size) {
    layoutChild(
      'page',
      BoxConstraints.tightFor(
        width: math.max(1.0, size.width - rail),
        height: size.height,
      ),
    );
    positionChild('page', Offset(right ? 0 : rail, 0));
    final heights = {
      for (final i in shown)
        i: layoutChild(
          i,
          BoxConstraints(maxWidth: math.max(1.0, rail - 4)),
        ).height,
    };
    final placed = <int, double>{};
    // In the order of the words: a note of the same line as the one before
    // it (يُجَٰزَىٰٓ … ٱلۡكَفُورُ) goes just under it, not below the page.
    final lexical = shown.where((i) => notes[i].farsh).toList()..sort();
    final order = <int>[];
    var bottom = 0.0;
    for (final i in lexical) {
      var y = math.max(tops[i], bottom);
      // Too far below its line (نتقبل … أحسن … ونتجاوز on one line): the
      // notes stacked just above it rise into the free room above them,
      // each still within a line of its own.
      final need = y - tops[i] - 63;
      if (need > 0) {
        // How far each note above must move: what the gap under it
        // cannot absorb.
        final moves = <int, double>{};
        var rise = need;
        var edge = y;
        var fits = true;
        for (final j in order.reversed) {
          rise -= edge - (placed[j]! + heights[j]! + 3);
          if (rise <= 0) break;
          if (rise > placed[j]! - math.max(0.0, tops[j] - 63)) {
            fits = false;
            break;
          }
          moves[j] = rise;
          edge = placed[j]!;
        }
        if (fits) {
          moves.forEach((j, d) => placed[j] = placed[j]! - d);
          y -= need;
        }
      }
      // Still beside its line; farther away, below the page.
      if (y + heights[i]! > size.height || y - tops[i] >= 64) continue;
      placed[i] = y;
      order.add(i);
      bottom = y + heights[i]! + 3;
    }
    for (final i in shown.where((i) => !notes[i].farsh)) {
      var y = 2.0;
      for (final j
          in placed.keys.toList()
            ..sort((a, b) => placed[a]!.compareTo(placed[b]!))) {
        if (y + heights[i]! + 3 <= placed[j]!) break;
        y = math.max(y, placed[j]! + heights[j]! + 3);
      }
      if (y + heights[i]! <= size.height) placed[i] = y;
    }
    for (final i in shown) {
      positionChild(
        i,
        Offset(
          right ? size.width - rail + 2 : 2,
          placed[i] ?? size.height + heights[i]!,
        ),
      );
    }
    onFit(placed.keys.toSet());
  }

  @override
  bool shouldRelayout(_SequentialNotesLayout old) => true;
}

/// Portrait notes follow their printed lines and report how many fit.
class _MarginPage extends StatelessWidget {
  const _MarginPage({
    required this.page,
    required this.rightWidth,
    required this.leftWidth,
    required this.entries,
    required this.tops,
    required this.onTap,
    required this.onFit,
  });

  final List<HameshEntry> entries;
  final Widget page;
  final double rightWidth, leftWidth;
  final List<double> tops;
  final WordTap onTap;
  final ValueChanged<int> onFit;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomMultiChildLayout(
        delegate: _NotesLayout(tops, onFit, rightWidth, leftWidth),
        children: [
          LayoutId(id: 'page', child: page),
          for (final (i, e) in entries.indexed)
            LayoutId(
              id: i,
              child: KeyedSubtree(
                key: ValueKey('side-note-$i'),
                child: _EntryView(entry: e, onTap: onTap, compact: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesLayout extends MultiChildLayoutDelegate {
  _NotesLayout(this.tops, this.onFit, this.rightWidth, this.leftWidth);

  final List<double> tops;
  final ValueChanged<int> onFit;
  final double rightWidth, leftWidth;

  @override
  void performLayout(Size size) {
    layoutChild(
      'page',
      BoxConstraints.tightFor(
        width: size.width - rightWidth - leftWidth,
        height: size.height,
      ),
    );
    positionChild('page', Offset(leftWidth, 0));
    final heights = [
      for (var i = 0; i < tops.length; i++)
        layoutChild(
          i,
          BoxConstraints(maxWidth: math.max(rightWidth, leftWidth) - 4),
        ).height,
    ];
    final columns = [<int>[], <int>[]]; // right, then left
    final used = [0.0, 0.0];
    var fit = tops.length;
    for (var i = 0; i < tops.length; i++) {
      final rightFits = rightWidth > 0 && used[0] + heights[i] <= size.height;
      final leftFits = leftWidth > 0 && used[1] + heights[i] <= size.height;
      if (!rightFits && !leftFits) {
        fit = i;
        break;
      }
      final c = rightFits && (!leftFits || used[0] <= used[1]) ? 0 : 1;
      columns[c].add(i);
      used[c] += heights[i] + 3;
    }
    for (var c = 0; c < columns.length; c++) {
      final positions = <int, double>{};
      var bottom = 0.0;
      for (final i in columns[c]) {
        positions[i] = math.max(tops[i], bottom);
        bottom = positions[i]! + heights[i] + 3;
      }
      // Float late notes upwards when there is free space in the margin.
      var limit = size.height;
      for (final i in columns[c].reversed) {
        final y = math.min(positions[i]!, limit - heights[i]);
        positionChild(i, Offset(c == 0 ? size.width - rightWidth + 2 : 2, y));
        limit = y - 3;
      }
    }
    for (var i = fit; i < tops.length; i++) {
      positionChild(i, Offset(0, size.height + heights[i]));
    }
    onFit(fit);
  }

  @override
  bool shouldRelayout(_NotesLayout old) => true;
}

/// Notes in a box (the continuation below the page), in columns.
/// A word that differs from Hafs, moving as chosen in «تنبيه الاختلافات».
class _Alerting extends StatelessWidget {
  const _Alerting({
    required this.animation,
    required this.style,
    required this.child,
  });

  final Animation<double> animation;
  final DiffAlert style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return RepaintBoundary(
      child: switch (style) {
        DiffAlert.blink => FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.15).animate(t),
          child: child,
        ),
        DiffAlert.shake => AnimatedBuilder(
          animation: t,
          builder: (_, c) => Transform.translate(
            offset: Offset((t.value - 0.5) * 5, 0),
            child: c,
          ),
          child: child,
        ),
        DiffAlert.pulse => ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.18).animate(t),
          child: child,
        ),
        DiffAlert.glow => AnimatedBuilder(
          animation: t,
          builder: (_, c) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: MushafColors.gold.withAlpha((170 * t.value).round()),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: c,
          ),
          child: child,
        ),
      },
    );
  }
}

/// The usul of the page below it: each kind in its colour, then every word
/// read with it and who reads it so. Tapping a word opens its readings.
class _UsulBox extends StatelessWidget {
  const _UsulBox({
    required this.groups,
    required this.onTap,
    this.scale = 1,
    this.compact = false,
  });

  final List<_UsulGroup> groups;
  final ValueChanged<_UsulItem> onTap;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('usul-notes'),
      padding: compact
          ? const EdgeInsets.all(3)
          : const EdgeInsets.fromLTRB(8, 4, 8, 6),
      decoration: BoxDecoration(
        color: MushafColors.goldLight.withAlpha(60),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MushafColors.gold.withAlpha(160)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (n, g) in groups.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      if (n == 0 && !compact)
                        Text(
                          'الأصول',
                          style: TextStyle(
                            fontSize: 8 * scale,
                            fontWeight: FontWeight.bold,
                            color: MushafColors.green,
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: g.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${g.label}:',
                              style: TextStyle(
                                fontSize: 9 * scale,
                                fontWeight: FontWeight.bold,
                                color: g.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (final i in g.items.values)
                        InkWell(
                          key: ValueKey(
                            'usul-reference:${g.label}:${i.ayah.surah}:${i.ayah.number}:${i.word}:${i.riwayat.join(',')}',
                          ),
                          onTap: () => onTap(i),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _usulWord(i, g.color),
                              // How the ya is read (يَدِي: بإسكان الياء).
                              if (i.readings.any((v) => v.rule == 'ya_idafa'))
                                Text(
                                  i.readings.any(
                                        (v) =>
                                            v.rule == 'ya_idafa' &&
                                            v.description.contains('فتح'),
                                      )
                                      ? ' (بفتح الياء)'
                                      : ' (بإسكان الياء)',
                                  style: TextStyle(
                                    fontSize: 9 * scale,
                                    color: g.color,
                                  ),
                                ),
                              if (i.stopOnly)
                                Text(
                                  ' (وقفًا فقط)',
                                  style: TextStyle(
                                    fontSize: 9 * scale,
                                    color: g.color,
                                  ),
                                ),
                              Text(
                                ' (${readersAr(i.riwayat.toList(), const [])})',
                                style: TextStyle(
                                  fontSize: 8.5 * scale,
                                  color: MushafColors.ink,
                                ),
                              ),
                              if (i.ways.isNotEmpty)
                                Text(
                                  ' ${i.ways.join('؛ ')}',
                                  style: TextStyle(
                                    fontSize: 8.5 * scale,
                                    color: g.color,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (g.ways.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1, bottom: 1),
                      child: Text(
                        g.ways
                            .toList()
                            .asMap()
                            .entries
                            .map((e) => '${e.key + 1}- ${e.value}')
                            .join('؛ '),
                        key: ValueKey(
                          g.label.contains('في كلمة')
                              ? 'hamza-word-ways'
                              : 'hamza-ways:${g.label}:${g.ways.join('|')}',
                        ),
                        style: TextStyle(
                          fontSize: 9 * scale,
                          height: 1.3,
                          color: g.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _usulWord(_UsulItem item, Color color) {
    final style = TextStyle(
      fontFamily: 'Hafs',
      fontSize: 12 * scale,
      color: color,
    );
    Widget text(String shown, [int? hiddenHamza]) => hiddenHamza == null
        ? QuranWordText(shown, style: style)
        : Text.rich(
            TextSpan(
              children: [
                for (final (part, color) in HamzaReplacementMark.hideHamza([
                  (shown, null),
                ], hiddenHamza))
                  TextSpan(
                    text: part,
                    style: TextStyle(color: color),
                  ),
              ],
            ),
            textDirection: TextDirection.rtl,
            style: style,
          );
    if (item.replacement == null) {
      return text(
        item.readings.any(_spacedImala)
            ? spacedImalaSigns(item.text)
            : item.text,
      );
    }
    final start = item.text.lastIndexOf(' ') + 1;
    final tasheel = item.replacement!.isEmpty;
    final second =
        tasheel && !item.readings.any((v) => v.rule == 'tasheel_pair');
    var markedText = item.text;
    final hafs = lettersOf(item.ayah.words[item.word]);
    // The hamza replaced is not always the first letter (لِأَهَبَ).
    final h = tasheel
        ? (second ? 1 : 0)
        : _hamzaLetter(item.ayah.words[item.word]);
    final before = lettersOf(item.text.substring(start)).take(h).join().length;
    if (!tasheel &&
        item.readings.any(
          (v) => const {'ruways', 'rawh'}.contains(v.riwayaId),
        )) {
      // Keep the original alif/ya/waw seat; the circled letter replaces its
      // hamza rather than adding a second, full-size replacement letter.
      markedText = markedText.replaceRange(
        start + before,
        start + before + 1,
        hafs[h][0],
      );
    }
    return HamzaReplacementMark(
      text: markedText,
      originalHamza: hafs[h],
      offset: start + before,
      letter: item.replacement!,
      style: style,
      color: color,
      builder: text,
    );
  }
}

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
    this.scale = 1,
  });

  final HameshEntry entry;
  final WordTap onTap;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final label = TextStyle(
      fontSize: (compact ? 7.5 : 10) * scale,
      height: 1.3,
      color: MushafColors.ink,
    );
    // The Hafs word of the note, and the riwaya's reading larger, to read
    // at a glance.
    final quran = (compact ? 10.5 : 13.0) * scale;
    final reading = (compact ? 14.0 : 17.0) * scale;
    return InkWell(
      key: ValueKey(
        'margin-reference:${e.ayah.surah}:${e.ayah.number}:${e.word}',
      ),
      onTap: () => onTap(e.ayah, e.word),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: e.hafs,
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: quran,
                    height: 1.4,
                    color: e.color,
                    backgroundColor: e.readings.every((v) => v.isMarginNote)
                        ? null
                        : e.color.withAlpha(28),
                  ),
                ),
                // Confirmed by the certified source (التسهيل).
                if (e.readings.every((v) => v.certified))
                  TextSpan(
                    text: ' ✓',
                    style: TextStyle(
                      fontSize: quran * 0.8,
                      color: MushafColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          for (final g in _readings(
            e.readings,
            e.ayah.words
                .sublist(e.word, e.word + e.readings.first.count)
                .join(' '),
          ))
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
                    _wordSpan(g, e, reading),
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

  InlineSpan _wordSpan(_Reading g, HameshEntry e, double size) {
    final text = g.text.isNotEmpty
        ? g.text
        : g.imala
        ? withImalaSign(e.hafs)
        : '(بحذفها)';
    final style = TextStyle(
      fontFamily: g.font,
      fontSize: size,
      color: g.imala
          ? MushafColors.green
          : g.names.length == 1
          ? g.names.single.$2
          : MushafColors.multi,
    );
    if (g.font == 'Hafs' && HafsFontMarks.needsAdjustment(text)) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: QuranWordText(text, style: style),
      );
    }
    return TextSpan(text: text, style: style);
  }

  /// Who reads what: a qiraa by its name ("نافع") when both its riwayat
  /// read alike, otherwise each riwaya ("ورش عن نافع"); qiraat with the same
  /// reading share one line ("نافع وابن كثير: مَلِكِ").
  static List<_Reading> _readings(List<Variant> vs, String baseline) {
    final out = <_Reading>[];
    void add(String name, Color color, String font, Variant v) {
      final key = readingVariantKey(v, baseline: baseline);
      final same = out.where((g) => g.key == key).firstOrNull;
      same != null
          ? same.names.add((name, color))
          : out.add(
              _Reading(
                [(name, color)],
                font,
                v.marginText.isNotEmpty
                    ? v.marginText
                    : _spacedImala(v)
                    ? spacedImalaSigns(v.text)
                    : v.text,
                _brief(v),
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
          mine.every(
            (m) =>
                readingVariantKey(m.$2, baseline: baseline) ==
                readingVariantKey(mine.first.$2, baseline: baseline),
          );
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

/// The letter whose hamza a replacement circle stands for: the first hamza
/// of the Hafs word (its first letter when it has none).
int _hamzaLetter(String word) {
  final i = lettersOf(word).indexWhere((l) => RegExp('[ءأإآؤئ]').hasMatch(l));
  return i < 0 ? 0 : i;
}
