import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/arabic.dart';
import '../data/audio_numbering.dart';
import '../data/lin_hamz.dart';
import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../data/usul_guide.dart';
import '../data/waqf_hamza.dart';
import '../data/usul_text.dart';
import '../data/mim_silah.dart';
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
import 'usul_guide_sheet.dart';
import 'usul_labels.dart';

typedef WordTap = void Function(Ayah ayah, int word);

const _ashabSilah = {'qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz'};

/// Ashab al-Silah's eased hamza in the place Hafs writes it, marked ۬ for
/// the tasheel dot to take: after a ra, its seat the dagger alif in their
/// source (أَرَٰ۬يْتَ → أَرَءَ۬يْتَ); a waw with the sifr (أَٰوْ۟نَبِّئُكُمُۥ →
/// أَٰؤُ۬نَبِّئُكُمُۥ); the last hamza, the sifr on its alif (هَٰؤُلَآ۟ →
/// هَٰؤُلَآءِ۬); the first, before an alif, its sifr dropped with the alif
/// taken for a naql (جَآءَ ا۟لَ → ءَ۬الَ).
String _easedAsHafs(String text, String hafs, bool hamza) {
  // Before a pause mark too (ٱلسَّمَآءِۚ).
  final last = RegExp(r'ء[َُِ](?=[ۖ-ۜ]*$)').firstMatch(hafs)?[0];
  if (hamza && hafs.startsWith('ءَا') && RegExp('^ا[^ً-ٰ]').hasMatch(text)) {
    text = 'ءَ۬$text';
  }
  return text
      .replaceAll('رَٰ۬', 'رَءَ۬')
      .replaceAll('وْ۟', 'ؤُ۬')
      .replaceFirstMapped(
        RegExp(r'([اآ]ٓ?)۟([ۖ-ۜ]*)$'),
        (m) => last == null ? m[0]! : '${m[1]}$last۬${m[2]}',
      );
}

/// A row easing the hamza that begins its word (شُهَدَآءَ إِذۡ).
bool _easesFirstHamza(Variant v) =>
    v.kind == VariantKind.hamza &&
    v.rule != 'tasheel_pair_first' &&
    // Its ibdal first, in the circle (يَشَآءُ إِلَىٰ for Abu Ja'far).
    v.hamzaReplacement == null &&
    RegExp('تسهيل|تخفيف الهمزة').hasMatch(v.description);

/// Where Ashab al-Silah's [drawn] word eases a hamza, and the hamza of
/// [hafs] there for its vowel: the dot their source writes on its seat
/// (ءَٰا۬نذَرْتَهُمُۥ، أَرَءَ۬يْتَ), which the font draws as a big round blot;
/// or, when [initial], the word's first hamza eased after the one before
/// (شُهَدَآءَ إِذۡ), which the Madinah script took for a wasl alif (ٱذۡ) or a
/// bare one (ا۟مَّةٗ), or which is written as Hafs. The tasheel dot of Warsh
/// takes its place (أَءِذَا).
(int, String)? _easedHamzaDot(
  String drawn,
  String hafs, {
  required bool initial,
}) {
  final letters = lettersOf(drawn);
  final own = lettersOf(hafs);
  final hamza = RegExp('^[ءأإآؤئ]');
  for (var i = 0; i < letters.length; i++) {
    // The dot on a first alif is a wasl's.
    if (!letters[i].contains('۬') ||
        !RegExp(i == 0 ? '^[ءؤئ]' : '^[اءؤئ]').hasMatch(letters[i])) {
      continue;
    }
    final h = own.elementAtOrNull(i);
    // Its own vowel where it differs from Hafs's (أَٰاَ۬يْن for أَئِن).
    final vowel = RegExp('[َُِ]').firstMatch(letters[i])?[0];
    return (
      i,
      RegExp('^[ءؤئ]').hasMatch(letters[i])
          ? letters[i]
          : h != null &&
                hamza.hasMatch(h) &&
                (vowel == null || h.contains(vowel))
          ? h
          : 'أ${vowel ?? 'َ'}',
    );
  }
  final first = letters.firstOrNull ?? '';
  return initial &&
          RegExp('^[أإ]').hasMatch(own.firstOrNull ?? '') &&
          (first.startsWith('ٱ') ||
              first == 'ا' ||
              first.startsWith(own.first[0]))
      ? (0, own.first)
      : null;
}

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
    this.onEdgeTurn,
    this.onDoubleTap,
    this.onShowRiwaya,
    this.onPageNumberTap,
    this.qcf = false,
    this.onAyahTap,
    this.onAyahWordTap,
    this.onHeaderMiddle,
    this.onJuzName,
    this.ayahShade,
  });

  /// Where the juz's name in the header is, on the screen: the lamp of
  /// «تنبيه الاختلافات» stands beside it, clear of the frame's band.
  final ValueChanged<Rect>? onJuzName;

  /// A shade behind an ayah's words (the Jam''s ayah read, and those done).
  final Color? Function(Ayah ayah)? ayahShade;

  /// Where the middle of the page's header is, across the page: the arrow of
  /// the riwayat stands there, between the surah and the juz.
  final ValueChanged<double>? onHeaderMiddle;

  /// The pages built, in order: turning one page should build only the
  /// page newly come near, whatever the riwayat chosen.
  @visibleForTesting
  static final built = <int>[];

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

  /// Zoomed in, dragged on past the page's side: turn the page that way.
  final ValueChanged<int>? onEdgeTurn;

  /// Two quick taps on the page (full screen on or off).
  final VoidCallback? onDoubleTap;

  /// A riwaya's square on the frame touched: the page shown in it (null:
  /// Hafs). Without it, no squares.
  final ValueChanged<String?>? onShowRiwaya;

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

  /// The notes measured to fit beside each page, by its signature.
  static final _splits = <String, int>{};

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
    assert(() {
      MushafPage.built.add(widget.page);
      return true;
    }());
    _disposeRecognizers();
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
                  squares: _riwayaStrip(),
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
              onEdgeTurn: widget.onEdgeTurn,
              onDoubleTap: widget.onDoubleTap,
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
        final key =
            '${item.stopOnly}:'
            '${item.text.replaceAll(RegExp('[ۖ-ۜ]'), '')}:'
            '${item.replacement}';
        final existing = group.items.putIfAbsent(key, () => item);
        if (existing != item) {
          existing.riwayat.addAll(item.riwayat);
          existing.readings.addAll(item.readings);
        }
      }
    }
    // The verified readers: a chapter once, at its first word.
    final notesOf = <String, List<_UsulGroup>>{};
    for (final (index, group) in merged.values.indexed) {
      if (group.items.isEmpty) continue;
      (notesOf[_isUnifiedGroup(group)
                  ? usulGuideLabel(group.label)
                  : '$index'] ??=
              [])
          .add(group);
    }
    for (final (index, of) in notesOf.values.indexed) {
      final first = of.first.items.values.first;
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
              groups: of,
              onTap: _openUsulReference,
              onGuide: _openUsulGuide,
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
        math.max(0.0, top + ((lineOf[note.position] ?? 0) + .5) * lineHeight),
    ];
  }

  Widget _sequentialPage(List<Ayah> ayahs, List<MushafLine> lines, Size size) {
    final notes = _sequentialNotes([
      for (final line in lines)
        if (line is TextLine) ...line.words,
    ], _showFarshMargins ? _hameshEntries(ayahs) : []);
    final rail = notes.isEmpty ? 0.0 : (size.width * 0.20).clamp(60.0, 220.0);
    _reportHeaderMiddle(
      (size.width - rail) / 2 +
          (widget.quran.isRightPage(widget.page) ? 0 : rail),
    );
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
                juzKey: _juzName,
                surah: widget.quran.surah(ayahs.first.surah).nameAr,
                juz: ayahs.first.juz,
              ),
            ),
            Expanded(
              child: _PageFrame(
                squares: _riwayaStrip(),
                page: widget.page,
                sides: true,
                onNumberTap: widget.onPageNumberTap,
                child: MushafLines(
                  lines: lines,
                  centered: widget.quran.isCentered(widget.page),
                  quran: widget.quran,
                  wordBuilder: _word,
                  onTapNearest: widget.onWordTap,
                  display: _display,
                  marker: _marker,
                  wordMarker: _nativeNumbering ? _wordMarker : null,
                  wordGap: _wordGap,
                  height: textHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Room before a word whose ibdal mark stands ahead of its alif (ءَالِهَةٗ),
  /// in ems, so the mark keeps clear of the word before it.
  double _wordGap(Ayah ayah, int w) {
    final replacement = _replacementAt(ayah, w)?.hamzaReplacement;
    final text = _display(ayah, w)?.text;
    if (replacement == null || text == null) return 0;
    final h = _hamzaLetter(ayah.words[w]);
    return HamzaReplacementMark.beforeAlif(
          replacement,
          lettersOf(ayah.words[w])[h],
          text,
          lettersOf(text).take(h).join().length,
        )
        ? .16
        : 0;
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
  void _reportHeaderMiddle(double x) {
    final report = widget.onHeaderMiddle;
    final name = widget.onJuzName;
    if (report == null && name == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      report?.call(x);
      final box = _juzName.currentContext?.findRenderObject();
      if (name != null && box is RenderBox && box.hasSize) {
        name(box.localToGlobal(Offset.zero) & box.size);
      }
    });
  }

  /// The juz's name in the header shown.
  final _juzName = GlobalKey();

  /// On the frame's bands, a small square for each riwaya chosen, in the
  /// qari's colour and the order of the readers, Hafs among them when he is
  /// chosen: one touched shows the page in it, without opening the riwayat.
  /// Each is built along the band it is set on, with its length along it.
  List<(_FrameSquare, double)> _riwayaStrip() {
    final show = widget.onShowRiwaya;
    final s = widget.settings;
    if (show == null || s.selected.isEmpty) return const [];
    // In the order of the readers, Hafs among them (after Shu'bah) when he
    // is chosen; not without it.
    final ids = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (r.id == hafsId ? s.compareHafs : s.selected.contains(r.id))
            r.id == hafsId ? null : r.id,
    ];
    const label = TextStyle(
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w600,
    );
    // Its width: the name, its padding and the gap beside it.
    double widthOf(String name) {
      final painter = TextPainter(
        // In the font it is drawn with.
        text: TextSpan(
          text: name,
          style: DefaultTextStyle.of(context).style.merge(label),
        ),
        textDirection: TextDirection.rtl,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width + 24 + 3 + 3;
      painter.dispose();
      return width;
    }

    _FrameSquare square(String? id) => (axis, depth, grow) {
      final now = s.displayed == id;
      final color = id == null ? MushafColors.green : qiraaOf(id).color;
      final across = axis == Axis.horizontal;
      // Raised out of the frame towards [grow], the riwaya shown pressed
      // back into it, as a button pushed in.
      final lift = now ? 0.0 : _PageFrame.squareLift;
      final anchor = switch (grow) {
        AxisDirection.down => Alignment.topCenter,
        AxisDirection.up => Alignment.bottomCenter,
        AxisDirection.left => Alignment.centerRight,
        AxisDirection.right => Alignment.centerLeft,
      };
      final away = Alignment(-anchor.x, -anchor.y);
      final name = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // As long as its name, whichever band it is on.
        child: Center(
          widthFactor: 1,
          child: Text(
            id == null ? 'حفص' : riwayaById(id).nameAr,
            style: label.copyWith(color: now ? Colors.white : color),
          ),
        ),
      );
      final radius = BorderRadius.circular(4);
      // Its face, on the band; on a side band its name read downwards.
      final face = Container(
        width: across ? null : depth,
        height: across ? depth : null,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: color, width: 1.2),
          gradient: LinearGradient(
            begin: anchor,
            end: away,
            colors: now
                // Pushed in: the light at its far side.
                ? [Color.lerp(color, Colors.black, 0.3)!, color]
                : [
                    Color.lerp(MushafColors.page, Colors.white, 0.7)!,
                    MushafColors.page,
                    Color.lerp(MushafColors.page, color, 0.22)!,
                  ],
          ),
        ),
        child: across ? name : RotatedBox(quarterTurns: 3, child: name),
      );
      // Its side, beyond the face, darker, with the shadow it casts.
      final button = AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: across ? null : depth + lift,
        height: across ? depth + lift : null,
        alignment: anchor,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Color.lerp(color, Colors.black, 0.25),
          boxShadow: [
            if (!now)
              BoxShadow(
                color: Colors.black.withAlpha(70),
                offset: Offset(away.x * -1.5, away.y * -1.5),
                blurRadius: 2.5,
              ),
          ],
        ),
        child: face,
      );
      return Padding(
        padding: across
            ? const EdgeInsets.symmetric(horizontal: 1.5)
            : const EdgeInsets.symmetric(vertical: 1.5),
        // Each in a slot as deep as a raised one, set against the band.
        child: SizedBox(
          width: across ? null : depth + _PageFrame.squareLift,
          height: across ? depth + _PageFrame.squareLift : null,
          child: Align(
            alignment: anchor,
            widthFactor: across ? 1 : null,
            heightFactor: across ? null : 1,
            child: Semantics(
              button: true,
              selected: now,
              child: GestureDetector(
                key: ValueKey('frame-riwaya-${id ?? 'hafs'}'),
                behavior: HitTestBehavior.opaque,
                onTap: now ? null : () => show(id),
                child: button,
              ),
            ),
          ),
        ),
      );
    };

    return [
      for (final id in ids)
        (square(id), widthOf(id == null ? 'حفص' : riwayaById(id).nameAr)),
    ];
  }

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
    final used = sequential
        ? (anyNotes ? rail : 0.0)
        : (hasUsul ? rail : 0.0) + (hasFarsh ? rail : 0.0);
    // No hamesh or usul beside it: the page no wider than beside one, in the
    // middle, so its lines stay as large and as many show (the user,
    // 2026-11-14).
    final oneRail = (size.width * 0.30).clamp(96.0, 280.0);
    final pageWidth = size.width - math.max(used, oneRail);
    final aside = (size.width - used - pageWidth) / 2;
    _reportHeaderMiddle(
      aside +
          pageWidth / 2 +
          (sequential
              ? (anyNotes && !widget.quran.isRightPage(widget.page) ? rail : 0)
              : (hasUsul ? rail : 0)),
    );
    // Turned: little room above and below the frame, the text the larger
    // (the user, 2026-11-13).
    const outer = 4.0, header = 20.0, top = 1.0;
    const contentTop = top + header + OrnamentFrame.inset;
    final textWidth =
        pageWidth - 2 * outer - 2 * OrnamentFrame.sideInset(sides);
    final spans = lines.fold(0, (n, l) => n + l.span);
    final natural = MushafLines(
      lines: lines,
      centered: widget.quran.isCentered(widget.page),
      quran: widget.quran,
      wordBuilder: _word,
      onTapNearest: widget.onWordTap,
      display: _display,
      marker: _marker,
      wordMarker: _nativeNumbering ? _wordMarker : null,
      wordGap: _wordGap,
    ).metrics(textWidth);
    // Size by width, with a little less vertical expansion. The glyphs
    // keep their shapes, the print's word order and its inter-word spaces.
    final textHeight = math.max(
      natural.fontSize * 1.8 * spans,
      size.height * 1.65 -
          contentTop -
          OrnamentFrame.inset -
          _PageFrame.compactNumberHeight -
          top,
    );
    final lineHeight = textHeight / spans;
    // The frame fixed, its upper and lower bands always in sight with their
    // riwayat, the lines scrolled between them, never under them (the user,
    // 2026-11-13).
    final window = math.max(
      1.0,
      size.height -
          contentTop -
          OrnamentFrame.inset -
          _PageFrame.compactNumberHeight -
          top,
    );
    final first = ayahs.first;
    final print = SizedBox(
      key: const ValueKey('mushaf-print'),
      width: pageWidth,
      height: size.height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(outer, top, outer, top),
        child: Column(
          children: [
            SizedBox(
              height: header,
              child: _PageHeader(
                juzKey: _juzName,
                surah: widget.quran.surah(first.surah).nameAr,
                juz: first.juz,
              ),
            ),
            Expanded(
              child: _PageFrame(
                squares: _riwayaStrip(),
                page: widget.page,
                sides: sides,
                compact: true,
                onNumberTap: widget.onPageNumberTap,
                child: Scrollbar(
                  controller: scroll,
                  child: SingleChildScrollView(
                    key: const ValueKey('landscape-page-scroll'),
                    controller: scroll,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: MushafLines(
                      lines: lines,
                      centered: widget.quran.isCentered(widget.page),
                      quran: widget.quran,
                      wordBuilder: _word,
                      onTapNearest: widget.onWordTap,
                      display: _display,
                      marker: _marker,
                      wordMarker: _nativeNumbering ? _wordMarker : null,
                      wordGap: _wordGap,
                      height: textHeight,
                    ),
                  ),
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
          // Only the lines wholly in sight: one cut by the frame has no note
          // beside it (the user, 2026-11-13).
          final visible = <(Ayah, int)>[];
          var span = 0;
          for (final line in lines) {
            final top = span * lineHeight;
            final bottom = top + line.span * lineHeight;
            if (line is TextLine &&
                top >= offset - .5 &&
                bottom <= offset + window + .5) {
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
            page: Center(child: print),
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
          // Only the lines wholly in sight (the user, 2026-11-13).
          final visible = <(Ayah, int)>[];
          var span = 0;
          for (final l in lines) {
            final top = span * lineHeight;
            final bottom = top + l.span * lineHeight;
            if (l is TextLine &&
                top >= offset - .5 &&
                bottom <= offset + window + .5) {
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
                    onGuide: _openUsulGuide,
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
        Expanded(child: Center(child: print)),
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
      // As measured before for this page and these readings: no second
      // build to measure it again.
      _split = _splits[signature];
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
        // Less than a printed line: the page the taller, its lines the further
        // apart (يُرِدۡ over بَوَّأۡنَا), the usul still in sight below it.
        ? math.min(size.height * 0.05, math.max(0.0, normalLine * 0.8))
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
    _reportHeaderMiddle(leftWidth + pageWidth / 2);
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
      onTapNearest: widget.onWordTap,
      display: _display,
      marker: _marker,
      wordMarker: _nativeNumbering ? _wordMarker : null,
      wordGap: _wordGap,
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
              juzKey: _juzName,
              surah: widget.quran.surah(first.surah).nameAr,
              juz: first.juz,
              // The usul are told below the page; the header points there.
              onUsul: usul.isEmpty ? null : _showUsul,
            ),
          ),
          Expanded(
            child: _PageFrame(
              squares: _riwayaStrip(),
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
            child: _UsulBox(
              groups: usul,
              onTap: _openUsulReference,
              onGuide: _openUsulGuide,
            ),
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

    // Vertical position of each note: the middle of its word's line.
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
          top +
              lineHeight * 0.5 +
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
        if (_splits.length > 300) _splits.remove(_splits.keys.first);
        _splits[signature] = fit;
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
    // The mim after a mim al-jam' joined with its waw: not merged into it.
    final apart = withMimSilah(
      widget.variants,
      widget.settings.displayed,
      ayah,
      w,
      shown.text,
    );
    final text =
        const {
          null,
          'hisham',
          'ibn_dhakwan',
        }.contains(widget.settings.displayed)
        ? spacedAwa(apart)
        : apart;
    if (!(_letterReadings(ayah, w)?.any(_spacedImala) ?? false)) {
      return (text: text, font: shown.font);
    }
    return (text: spacedImalaSigns(text), font: shown.font);
  }

  /// The shown riwaya's own imala of word [w], whose sign is drawn.
  static Variant? _ownImala(Iterable<Variant> base, int w) => base
      .where(
        (v) =>
            v.word == w &&
            v.isImala &&
            !v.isStoppingTaqlil &&
            // Nor a stop's own imala (مُوسَى ٱلۡكِتَٰبَ، the feminine ha):
            // its letter coloured, no sign (the user, 2026-11-12).
            !v.stopOnly &&
            v.rule != 'imala_ha' &&
            !v.fathPreferred,
      )
      .firstOrNull;

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
    // «ٱلَّٰٓـِٔي» of Warsh as of Abu Ja'far, its row's rasm, not his text's.
    final last = base
        .where((v) => v.word == w && v.rule == 'hamza_mutatarrif')
        .firstOrNull;
    if (source != null && last != null && last.text.isNotEmpty) {
      return (text: last.text, font: 'Hafs');
    }
    if (source != null) {
      final marked = base
          .map((v) => hamzaPairMaddText(v, source))
          .whereType<String>()
          .firstOrNull;
      if (source.isEmpty) return null;
      // Warsh's complete text writes يَٰعِبَادِے with the ya in the word's body.
      final written = base.any((v) => v.word == w && v.rule == 'ya_zaida')
          ? withSmallYa(marked ?? source)
          : marked ?? source;
      return (text: written, font: 'Hafs');
    }
    // The riwaya shown in place of Hafs: its reading takes the place of the
    // Hafs word(s).
    final v =
        base.where((v) => v.canReplaceText).firstOrNull ??
        // Their separated madd short, written without Hafs's sign (يُؤَدِّهِۦ
        // إِلَيۡكَ، مَا أُوتِيتُمۡ): no colour nor note, the word as it is read.
        (_ashabSilah.contains(s.displayed)
            ? widget.variants
                  .at([s.displayed!], ayah.surah, ayah.number, w)
                  .where((v) => v.word == w && v.isQasr && v.text.isNotEmpty)
                  .firstOrNull
            : null);
    if (v != null) {
      if (v.word != w || v.text.isEmpty) return null;
      if (const {'ruways', 'rawh'}.contains(s.displayed) &&
          _replacementAt(ayah, w) != null) {
        return (text: ayah.words[w], font: 'Hafs');
      }
      // «يَٰصَٰلِحُ ٱئۡتِنَا»: Hafs's word, its hamza under the mark of the waw,
      // its seat a ya with its dots, as Warsh's «ٱيتِنَا».
      if (v.rule == 'ibdal_single' &&
          RegExp('^ٱ[وي]').hasMatch(v.text) &&
          _replacementAt(ayah, w) != null) {
        return (text: ayah.words[w].replaceFirst('ئ', 'ي'), font: 'Hafs');
      }
      if (_dadAsZa(ayah, w) != null) {
        return (text: ayah.words[w], font: 'Hafs');
      }
      var text = withNaqlVowel(v.text, ayah.words[w]);
      // Its own word read with imala: the sign under it too, as under
      // Hafs's words (al-Kisa'i's «فَنَادَ۪ىٰهُ»).
      if (_ownImala(base, w) case final imala?) {
        text = withImalaSign(text, imala.text.isEmpty ? null : imala.text);
      }
      return (
        text: _ashabSilah.contains(s.displayed)
            ? _easedAsHafs(text, ayah.words[w], v.kind == VariantKind.hamza)
            : text,
        font: 'Hafs',
      );
    }
    final glyph = qcf && !(w == 0 && (ayah.rubStart != null || ayah.juzStart))
        ? (ayah.glyphs?[w])
        : null;
    // Drawn with the word before.
    if (glyph != null && glyph.isEmpty) return null;
    // The sign is the shown riwaya's own: a riwaya of the hamesh shades the
    // word, never marks Hafs's letters (the user, 2026-11-12).
    final imala = _ownImala(base, w);
    // The page font has no imala sign to add: such a word is drawn in the
    // Hafs font, with the sign under the letters the reading marks.
    if (imala != null) {
      return (text: withImalaSign(ayah.words[w], imala.text), font: 'Hafs');
    }
    if (_replacementAt(ayah, w) != null || _ruwaysTasheelAt(ayah, w) != null) {
      return (text: ayah.words[w], font: 'Hafs');
    }
    // Nor letters coloured apart.
    if (_letterReadings(ayah, w) != null ||
        _waslDammColor(ayah, w) != null ||
        w > 0 && _waslDammColor(ayah, w - 1) != null) {
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
              // And the shown riwaya's own farsh read with imala (يَٰبُشۡرٰ۪يَ).
              ...base.where(
                (v) =>
                    !_readByAll(widget.variants, s, ayah, w, v) &&
                    (v.isUsul ||
                        v.isImala && _farshImala(v) ||
                        _shadedFarsh(v)),
              ),
              ..._readingsAt(widget.variants, s, ayah, w).shown,
            ]
            .where(
              (v) =>
                  (v.word == w ||
                      _shadedFarsh(v) ||
                      // The next word's first letter of Khalaf's idgham.
                      v.rule == 'idgham_bila_ghunna') &&
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
            v.rule == 'ya_zaida' ||
            v.isLinHamz ||
            v.isImala && !v.fathPreferred ||
            v.isTarqiqOrTaghliz ||
            _naqlKind(v) != null ||
            isWarshRabbahuMadd(v) ||
            isWarshAnaMadd(v) ||
            v.rule == 'ikhfa' ||
            v.rule == 'first_sakin' ||
            RegExp('همز|تسهيل|صلة|إدغام|ادغام').hasMatch(v.description));
    final lexical = readings.any((v) => !v.isUsul);
    if (readings.isEmpty ||
        readings.any((v) => v.isUsul && !targeted(v)) ||
        // A farsh word alone is coloured whole; with a rule of its own
        // (نُوتِيهِمُ: its ibdal; وَٱلنَّبِيٓـِٕۧنَ: its badal) the rule's letter
        // takes the rule's colour, the rest the farsh colour.
        lexical &&
            !readings.any(
              (v) => v.isUsul || v.isImala && _farshImala(v) || _shadedFarsh(v),
            )) {
      return null;
    }
    // Tarqiq, taghliz and imala colour their letter alone, the rest of the
    // word in ink, or in the colour of its farsh (the whole word glows when
    // differences are alerted).
    return readings;
  }

  Variant? _replacementAt(Ayah ayah, int w) =>
      !const {'warsh', 'ruways', 'rawh'}.contains(widget.settings.displayed) &&
          // Ashab al-Silah's ibdal too, in Warsh's circle (ٱلسُّفَهَآءُ أَلَآ).
          !_ashabSilah.contains(widget.settings.displayed)
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

  (int, String)? _easedHamzaAt(Ayah ayah, int w, String drawn) =>
      _ashabSilah.contains(widget.settings.displayed)
      ? _easedHamzaDot(
          drawn,
          ayah.words[w],
          initial: _baseAt(
            widget.variants,
            widget.settings,
            ayah,
            w,
          ).any((v) => v.word == w && _easesFirstHamza(v)),
        )
      : null;

  /// [text] in parts, each affected letter in the colour of its rule.
  List<(String, Color?)>? _letterParts(Ayah ayah, int w, String text) {
    final readings = _letterReadings(ayah, w);
    if (readings == null) return null;
    final letters = lettersOf(text);
    final colors = <int, Color>{};
    final priorities = <int, int>{};
    // The shown riwaya's own farsh is its text: in ink, unless compared.
    final farshColor = ReadingColors.ofReadings(
      readings
          .where(
            (v) =>
                !v.isUsul &&
                (v.riwayaId != widget.settings.displayed || _shadedFarsh(v)),
          )
          .toList(),
    );
    // وَعَذَابٍ before the next ayah's ٱرۡكُضۡ: its last letter with the tanween
    // alone, and the alif the tanween may stand on (مَحۡظُورًا، مَحْظُوراً).
    final tanweenColor = readings.any(_tanweenDamm) ? farshColor : null;
    if (farshColor != null && tanweenColor == null) {
      for (var i = 0; i < letters.length; i++) {
        colors[i] = farshColor;
      }
    } else if (tanweenColor != null) {
      final at = letters.lastIndexWhere(_tanweenMark.hasMatch);
      final from = at > 0 && letters[at].startsWith('ا') ? at - 1 : at;
      for (var i = from; from >= 0 && i < letters.length; i++) {
        colors[i] = tanweenColor;
      }
    }
    var priority = 0;
    (int, Color)? zaida;
    // The eased hamza's dot after a naql's alif (اَ۟لَٰهٞ): apart from the alif.
    Color? easedDot;
    // رَبَّهُۥٓ: the small waw and the madd sign, apart from the ha.
    Color? smallWaw;
    void mark(int? i, Color color, {bool badal = false}) {
      if (i == null || i < 0 || i >= letters.length) return;
      final rank = priority * 2 + (badal ? 1 : 0);
      if (rank < (priorities[i] ?? -1)) return;
      colors[i] = color;
      priorities[i] = rank;
    }

    // The letters a reading's imala falls on: those with the sign, or, in a
    // text without it (Hafs's word, a riwaya of the hamesh read with imala:
    // طُغۡيَٰنِهِمۡ), where the sign would go: that letter alone coloured, as
    // the qaf of a reading's ishmam (the user, 2026-11-12).
    Iterable<int> imalaLetters(Variant v) {
      final signed = text.contains(imalaSign)
          ? letters
          : lettersOf(withImalaSign(text, v.text));
      if (signed.length != letters.length) return const [];
      return [
        for (final (i, l) in signed.indexed)
          if (l.contains(imalaSign)) i,
      ];
    }

    for (final v in readings) {
      priority = v.riwayaId == widget.settings.displayed ? 1 : 0;
      if (!v.isUsul) {
        // A farsh word read with imala: its letter green, in the farsh's
        // colour.
        if (v.isImala && _farshImala(v)) {
          for (final i in imalaLetters(v)) {
            if (!letters[i].startsWith('ا')) mark(i, MushafColors.green);
          }
        }
        continue;
      }
      // «التقاء الساكنين»: the first quiescent's letter (قُلُ), or the
      // tanween's and the alif it may stand on (مَحۡظُورًا).
      if (v.rule == 'first_sakin') {
        final at = letters.lastIndexWhere(
          (l) => _tanweenMark.hasMatch(l) || RegExp('[ُِ]').hasMatch(l),
        );
        final from = at > 0 && letters[at].startsWith('ا') ? at - 1 : at;
        for (var i = from; from >= 0 && i < letters.length; i++) {
          mark(i, ReadingColors.of(v));
        }
        continue;
      }
      if (isWarshRabbahuMadd(v)) {
        smallWaw = ReadingColors.of(v);
        continue;
      }
      if (isWarshAnaMadd(v)) {
        mark(letters.length - 1, ReadingColors.of(v));
        continue;
      }
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
      if (v.rule == 'ya_zaida') {
        // The added ya alone (دُعَآءِۦ); in Hafs's word, without it, the
        // letter it follows.
        final at = letters.lastIndexWhere((l) => l.contains('ۦ'));
        if (at >= 0 && priority >= (priorities[at] ?? 0)) {
          zaida = (at, ReadingColors.of(v));
        } else {
          mark(letters.length - 1, ReadingColors.of(v));
        }
        continue;
      }
      if (v.isStoppingTaqlil) {
        // تَرَٰٓءَا: its ra and hamza, written without the sign.
        if (v.description.contains('الراء والهمزة')) {
          mark(
            letters.indexWhere((l) => l.startsWith('ر')),
            MushafColors.green,
          );
          mark(
            letters.indexWhere((l) => l.startsWith('ء')),
            MushafColors.green,
          );
          continue;
        }
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
        // In Hafs's word the lam may read otherwise (يُصۡلِحَا for يَصَّٰلَحَا).
        final i = v.rule == 'tarqiq'
            ? raLetter(letters)
            : lamLetter(letters) ?? lamLetter(letters, anyVowel: true);
        mark(i, MushafColors.rule);
        continue;
      }
      // إِۦلَٰفِهِمۡ: the madd is the small ya on the hamza or the naql's alif,
      // that sign alone.
      if (v.isBadal &&
          RegExp('^[إا]').hasMatch(letters.first) &&
          letters.first.contains('ۦ')) {
        zaida = (0, MushafColors.green);
        continue;
      }
      final kind = v.isBadal ? null : _naqlKind(v);
      var i = v.isBadal
          // Not in Hafs's word without the hamza (ٱلنَّبِيِّـۧنَ); the
          // riwaya's own may have lost it to naql (اِ۬لَاخِرِ).
          ? (widget.settings.displayed != null ||
                    RegExp('[ءأإؤئٕٔ]').hasMatch(text)
                ? badalLetter(letters)
                : null)
          : kind == _Naql.alef
          ? 0
          : kind == _Naql.dropped
          ? null
          : naqlLetter(letters, last: kind == _Naql.last);
      // The eased hamza's alif (ءَا۬ـٰمَنتُم): the badal is the dagger alif
      // after it.
      if (v.isBadal &&
          i != null &&
          i + 1 < letters.length &&
          letters[i].contains('۬') &&
          letters[i + 1].contains('ٰ')) {
        i++;
      }
      if (v.isBadal || kind != null) {
        mark(
          i,
          v.isBadal ? MushafColors.green : ReadingColors.naql,
          badal: v.isBadal,
        );
      }
      // The waw of the madd with its alif (لِيَسُـۥٓـُٔواْ).
      if (v.isBadal &&
          i != null &&
          text.contains('ۥٓـ') &&
          letters[i].startsWith('و') &&
          i + 1 < letters.length &&
          letters[i + 1] == 'اْ') {
        mark(i + 1, MushafColors.green, badal: true);
      }
      final d = v.description;
      if (v.rule == 'hamza_wasl' && d.contains('نقل')) {
        final lam = letters.indexWhere((l) => l.startsWith('ل'));
        mark(lam < 0 ? null : lam, ReadingColors.naql);
      }
      if (v.isImala) {
        // Every letter with the sign (رَ۪ءَ۪ا: the ra and the hamza).
        for (final i in imalaLetters(v)) {
          mark(i, MushafColors.green);
        }
        // The feminine ha itself, with the letter before it (غِشَٰوَةٞ).
        if (v.rule == 'imala_ha') {
          final ha = letters.lastIndexWhere((l) => l.startsWith('ة'));
          if (ha >= 0) mark(ha, MushafColors.green);
        }
      }
      if (v.rule == 'ikhfa') {
        // The nun, or the tanween's letter and the alif it stands on
        // (نُزُلًا).
        final at = letters.lastIndexWhere(_tanweenMark.hasMatch);
        final from = at < 0
            ? letters.length - 1
            : at > 0 && letters[at].startsWith('ا')
            ? at - 1
            : at;
        for (var i = from; i < letters.length; i++) {
          mark(i, ReadingColors.of(v));
        }
      }
      // A hamza dropped or added has no letter of its own (مُسۡتَهۡزُونَ،
      // ٱلنَّبِيٓـِٕـۧنَ): the word in its colour, what else is coloured kept.
      if (v.kind == VariantKind.hamza &&
          kind == null &&
          !d.contains('نقل') &&
          (const {'hamza_zaida', 'hamza_hadhf'}.contains(v.rule) ||
              v.rule.isEmpty &&
                  !RegExp('إبدال|ابدال|تسهيل|تخفيف الهمزة|إسقاط')
                      .hasMatch(d))) {
        for (var i = 0; i < letters.length; i++) {
          if (!colors.containsKey(i)) mark(i, ReadingColors.hamza);
        }
      }
      if (RegExp('إبدال|ابدال|تسهيل|تخفيف الهمزة|إسقاط').hasMatch(d)) {
        final hafs = lettersOf(ayah.words[w]);
        final hamzas = [
          for (final (i, l) in hafs.indexed)
            if (_hamzaCluster(l)) i,
        ];
        final variant = lettersOf(v.text);
        // أَرَءَيۡتَ: its second hamza, or the letter Warsh writes it on (رَٰٓ).
        final araayta =
            v.rule == 'tasheel_word' &&
            d.contains('ألفًا خالصة مع المد المشبع للساكنين');
        int at(bool Function(String) test) =>
            letters.indexed.skip(1).where((l) => test(l.$2)).firstOrNull?.$1 ??
            -1;
        final second = at(_hamzaCluster);
        // Hafs's word without the second hamza (أَشَهِدُواْ): no letter to mark.
        final noSecond =
            // Both kept (أَرَءَيۡتُمۡ of Ibn Kathir): as Hafs, no letter to colour.
            v.description == 'بتحقيق الهمزتين' ||
            v.rule == 'tasheel_word' &&
                !letters.first.contains('۟') &&
                // ءَا۬عۡجَمِيّٞ: its second hamza is the alif, eased or changed.
                !(v.riwayaId == 'warsh' && v.surah == 41 && v.ayah == 44) &&
                lettersOf(v.usulText).where(_hamzaCluster).length < 2;
        final target = noSecond
            ? null
            : araayta
            ? (second >= 0 ? second : at((l) => l.contains('ٰ')))
            // لِأَهَبَ: its hamza is within the word, the lam left alone.
            : v.riwayaId == 'warsh' &&
                  v.description == 'بإبدال الهمزة ياءً مفتوحة'
            ? _hamzaLetter(ayah.words[w])
            : v.rule == 'ibdal_waw' ||
                  v.rule == 'ibdal_ya' ||
                  v.rule == 'tasheel_pair'
            ? 0
            // The second hamza, after the first (ءَآللَّهُ); the riwaya's own
            // text may write the two as one alif (آٰللَّهُ).
            : v.rule == 'tasheel_word' || v.rule == 'hamza_wasl'
            ? (letters.first.startsWith('ا') &&
                          letters.first.contains('ٰ') &&
                          letters.first.contains('ٓ') ||
                      // Or the second written as a dot after the first (أَ۟ذَا).
                      letters.first.contains('۟')
                  ? 0
                  : 1)
            : hamzas
                      .where(
                        (i) => i < variant.length && !_hamzaCluster(variant[i]),
                      )
                      .firstOrNull ??
                  hamzas.lastOrNull;
        if (v.rule == 'tasheel_word' &&
            target == 0 &&
            letters[0] == '\u0627\u064e\u06df') {
          easedDot = ReadingColors.hamza;
        } else {
          // The sakin hamza written as a dagger alif on the letter before
          // (يَسْتَٰخِرُونَ): one letter fewer than Hafs's word, that letter.
          final onDagger =
              v.rule == 'ibdal_single' &&
              target != null &&
              target > 0 &&
              letters.length == hafs.length - 1 &&
              letters[target - 1].contains('ٰ');
          mark(
            onDagger ? target - 1 : target,
            isWarshHamzaNaql(v) ? ReadingColors.naql : ReadingColors.hamza,
          );
        }
      }
      if (d.contains('صلة')) {
        final base = d.contains('ميم') || d.contains('الميم') ? 'م' : 'ه';
        final at = letters.lastIndexWhere((l) => l.startsWith(base));
        mark(at < 0 ? null : at, ReadingColors.silah);
      }
      if (v.rule == 'idgham_bila_ghunna') {
        // Khalaf's idgham without ghunna (مَن يَّقُولُ، غِشَٰوَةٞ وَّلَهُمۡ): the
        // nun or the letter with the tanween, and the next word's first.
        // The two words drawn as one: the letters on each side of the space.
        final space = letters.indexWhere((l) => l.trim().isEmpty);
        if (space > 0) {
          var last = space - 1;
          while (last > 0 && RegExp(r'^[اى][ۖ-ۭ]*$').hasMatch(letters[last])) {
            last--;
          }
          mark(last, ReadingColors.idgham);
          mark(space + 1, ReadingColors.idgham);
        } else if (w == v.word) {
          // Each word drawn apart: the first's last letter, the second's
          // first.
          var last = letters.length - 1;
          while (last > 0 && RegExp(r'^[اى][ۖ-ۭ]*$').hasMatch(letters[last])) {
            last--;
          }
          mark(last, ReadingColors.idgham);
        } else {
          mark(0, ReadingColors.idgham);
        }
      } else if (RegExp('إدغام|ادغام').hasMatch(d)) {
        final merged = const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId)
            ? _mergedLetters(d, letters)
            : null;
        final into = _idghamLetters(d);
        // The two words drawn as one (لَّقَد سَّمِعَ): the merged letter
        // before the space and the one it merges in after it, not the
        // first word's own doubled letter.
        final space = letters.indexWhere((l) => l.trim().isEmpty);
        if (merged == null &&
            into != null &&
            space > 0 &&
            space + 1 < letters.length &&
            letters[space - 1].startsWith(into.$1) &&
            letters[space + 1].startsWith(into.$2)) {
          mark(space - 1, ReadingColors.idgham);
          mark(space + 1, ReadingColors.idgham);
        } else if (merged != null) {
          for (final i in merged) {
            mark(i, ReadingColors.idgham);
          }
        } else if (into != null && letters.last.startsWith(into.$1)) {
          // Into the next word (حُرِّمَت ظُّهُورُهَا): this word's last
          // letter; the next word colours its first.
          mark(letters.length - 1, ReadingColors.idgham);
        } else if (letters.first.contains('ّ')) {
          mark(0, ReadingColors.idgham);
        }
      }
    }
    if (colors.isEmpty && zaida == null && smallWaw == null) return null;
    // The displayed narrator owns overlapping letters. Within that narrator,
    // badal retains its agreed priority over naql independently of row order.
    return [
      for (final (i, l) in letters.indexed)
        if (i == zaida?.$1) ...[
          (l.substring(0, l.indexOf('ۦ')), colors[i]),
          (l.substring(l.indexOf('ۦ')), zaida!.$2),
        ] else if (smallWaw != null && l.contains('\u06e5')) ...[
          (l.substring(0, l.indexOf('\u06e5')), colors[i]),
          (l.substring(l.indexOf('\u06e5')), smallWaw),
        ] else if (easedDot != null && l == '\u0627\u064e\u06df') ...[
          ('\u0627\u064e', colors[i]),
          ('\u06df', easedDot),
          // The sajda sign keeps the ink of the text (\u0648\u064e\u0671\u0642\u06e1\u062a\u064e\u0631\u0650\u0628\u06e9).
        ] else if (l.endsWith('\u06e9')) ...[
          (l.substring(0, l.length - 1), colors[i]),
          ('\u06e9', null),
        ] else
          (l, colors[i]),
    ];
  }

  /// The word the word before is merged into (حُرِّمَت ظُّهُورُهَا، قَد
  /// ضَّلُّواْ), or Abu Ja'far's nun hidden before (قَوۡلًا غَيۡرَ): its first
  /// letter in the rule's colour, the rest in ink.
  List<(String, Color?)>? _idghamInto(Ayah ayah, int w, String text) {
    final s = widget.settings;
    // The word before, the last of the ayah before at an ayah's head: the
    // nun hidden across it (نُزُلًا ۝ خَٰلِدِينَ).
    final prevAyah = w > 0
        ? ayah
        : ayah.number > 1
        ? widget.quran.ayah(ayah.surah, ayah.number - 1)
        : null;
    if (prevAyah == null) return null;
    final prev = w > 0 ? w - 1 : prevAyah.words.length - 1;
    final before = [
      ..._baseAt(widget.variants, s, prevAyah, prev).where((v) => v.isUsul),
      ..._readingsAt(widget.variants, s, prevAyah, prev).shown,
    ];
    final letters = lettersOf(text);
    final hidden = before
        .where(
          (v) =>
              v.word == prev &&
              v.rule == 'ikhfa' &&
              s.kinds.contains(v.kind) &&
              RegExp('^[خغ]').hasMatch(letters.firstOrNull ?? ''),
        )
        .firstOrNull;
    if (hidden != null) {
      return [
        for (final (i, l) in letters.indexed)
          (l, i == 0 ? ReadingColors.of(hidden) : null),
      ];
    }
    if (w == 0) return null;
    final into = before
        .where(
          (v) =>
              v.word == w - 1 &&
              v.count == 1 &&
              v.isUsul &&
              s.kinds.contains(v.kind) &&
              RegExp('إدغام|ادغام').hasMatch(v.description),
        )
        .map((v) => _idghamLetters(v.description))
        .where((xy) => xy != null && letters.first.startsWith(xy.$2))
        .firstOrNull;
    if (into == null) return null;
    return [
      for (final (i, l) in letters.indexed)
        (l, i == 0 ? ReadingColors.idgham : null),
    ];
  }

  /// A sakin or tanween read with a damma before a hamzat wasl (بِرَحۡمَةٍ
  /// ٱدۡخُلُواْ، أَنِ ٱقۡتُلُوٓاْ): the word's last letter and the wasl alif of
  /// the next word in the farsh's colour, the rest in ink.
  List<(String, Color?)>? _waslDamm(Ayah ayah, int w, String text) {
    final letters = lettersOf(text);
    final own = _waslDammColor(ayah, w);
    // The word before in the ayah before, too (مُّبِينٍ ۝ ٱقۡتُلُواْ).
    final before = w > 0
        ? ayah
        : ayah.number > 1
        ? widget.quran.ayah(ayah.surah, ayah.number - 1)
        : null;
    final into = before != null && RegExp('^[ٱا]').hasMatch(text)
        ? _waslDammColor(
            before,
            w > 0 ? w - 1 : before.words.length - 1,
            anyTanween: true,
          )
        : null;
    if (own == null && into == null) return null;
    return [
      for (final (i, l) in letters.indexed)
        (
          l,
          i == letters.length - 1 && own != null
              ? own
              : i == 0
              ? into
              : null,
        ),
    ];
  }

  /// [anyTanween]: the word after's alif coloured after a tanween of any
  /// vowel; the word's own last letter only after a kasra, its others told
  /// by its rule (مَحۡظُورًا).
  Color? _waslDammColor(Ayah ayah, int w, {bool anyTanween = false}) {
    // The word after, the next ayah's first at the ayah's end.
    final next = w + 1 < ayah.words.length
        ? ayah.words[w + 1]
        : ayah.number < widget.quran.surah(ayah.surah).ayahCount
        ? widget.quran.ayah(ayah.surah, ayah.number + 1).words.first
        : '';
    // A kasra; for the word after, a tanween of any vowel too, its alif
    // after it (فَتِيلًا ۝ ٱنظُرۡ، مَحۡظُورًا ۝ ٱنظُرۡ) (the user, 2026-11-14).
    final end = anyTanween
        ? RegExp(r'(ِ|[ًٌٍٖٗٞ][اى]?)[ۖ-ۭ]*$')
        : RegExp(r'[ٍِ][ۖ-ۭ]*$');
    if (!next.startsWith('ٱ') || !end.hasMatch(ayah.words[w])) {
      return null;
    }
    final s = widget.settings;
    final all = _readingsAt(
      widget.variants,
      s,
      ayah,
      w,
    ).shown.where((v) => v.word == w && s.kinds.contains(v.kind));
    // «التقاء الساكنين», in its colour; unless all the selected read it so.
    final usul = [
      ..._baseAt(widget.variants, s, ayah, w).where(
        (v) =>
            s.kinds.contains(v.kind) &&
            !_readByAll(widget.variants, s, ayah, w, v),
      ),
      ...all,
    ].where((v) => v.word == w && v.rule == 'first_sakin').firstOrNull;
    if (usul != null) return ReadingColors.of(usul);
    final shown = all.where((v) => !v.isUsul);
    final damm = [..._baseAt(widget.variants, s, ayah, w), ...shown].any(
      (v) =>
          v.word == w &&
          !v.isUsul &&
          v.description.contains('ضم') &&
          // The damma on the word's last letter, against the sakin after it
          // (قُلُ ٱدۡعُواْ), not one inside it (بِٱلۡقُسۡطَاسِ ٱلۡمُسۡتَقِيمِ).
          RegExp(r'[ٌُ][ۖ-ۭ]*$').hasMatch(v.text) &&
          // On a letter sakin but for the meeting (قُلِ، أَوِ، فَمَنِ، وَلَقَدِ،
          // وَقَالَتِ), not a case ending read otherwise (عَٰلِمُ ٱلۡغَيۡبِ).
          (v.description.contains('التقاء') ||
              RegExp(r'[نودلت][ً-ٰۖ-ۭ]*$').hasMatch(ayah.words[w])),
    );
    if (!damm) return null;
    return ReadingColors.ofReadings(
      shown.where((v) => v.riwayaId != s.displayed).toList(),
    );
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
  /// Whether a word read so glows under the lamp: its farsh always, its usul
  /// unless every asl it is told under was put out.
  bool _glows(List<Variant> readings) {
    final unlit = widget.settings.unlitUsul;
    return unlit.isEmpty ||
        readings.isEmpty ||
        readings.any(
          (v) =>
              v.inHamesh ||
              usulKindsOf(v).any((k) => !unlit.contains(usulGuideLabel(k.$1))),
        );
  }

  /// The other word of two hamzas from two words (يَشَآءُ إِنَّهُۥ): it glows
  /// with the word its rule is told on, the two read as one.
  bool _pairGlows(Ayah ayah, int w) {
    bool pair(Variant v) =>
        usulOf(v).any((l) => l.startsWith('الهمزتان من كلمتين'));
    List<Variant> at(int i) => i < 0 || i >= ayah.words.length
        ? const []
        : [
            ..._readingsAt(widget.variants, widget.settings, ayah, i).shown,
            ...?_letterReadings(ayah, i),
          ].where((v) => v.word == i).toList();
    // The pair's first word told on itself (أَوۡلِيَآءُ أُوْلَٰٓئِكَ): the word
    // before it is not of the pair.
    final next = at(w + 1)
        .where((v) => pair(v) && v.rule != 'tasheel_pair_first')
        .toList();
    final before = at(w - 1)
        .where((v) => v.rule == 'tasheel_pair_first')
        .toList();
    // «التقاء الساكنين»: the word after the meeting with it, the next ayah's
    // first at the ayah's end (فَتِيلًا ۝ ٱنظُرۡ) (the user, 2026-11-14).
    final prev = w > 0
        ? ayah
        : ayah.number > 1
        ? widget.quran.ayah(ayah.surah, ayah.number - 1)
        : null;
    if (prev != null && ayah.words[w].startsWith('ٱ')) {
      final p = w > 0 ? w - 1 : prev.words.length - 1;
      final sakin = _readingsAt(
        widget.variants,
        widget.settings,
        prev,
        p,
      ).shown.where((v) => v.word == p && v.rule == 'first_sakin').toList();
      if (sakin.isNotEmpty && _glows(sakin)) return true;
    }
    return next.isNotEmpty && _glows(next) ||
        before.isNotEmpty && _glows(before);
  }

  Widget _word(Ayah ayah, int w, double fontSize, [int kashida = 0]) {
    final m = _mark(ayah, w);
    final shown = _display(ayah, w)!;
    // Not the page glyphs of the Madinah print: letters to colour and draw out.
    final hafsFont = !shown.font.startsWith('QCF_');
    final own = hafsFont
        ? _waslDamm(ayah, w, shown.text) ?? _letterParts(ayah, w, shown.text)
        : null;
    // Coloured for a rule of its own and hidden into as well (مِنۡ
    // خَطَٰيَٰهُمُۥ: its silah, and the kha Abu Ja'far's nun is hidden before).
    final into =
        hafsFont && (own == null || (own.isNotEmpty && own.first.$2 == null))
        ? _idghamInto(ayah, w, shown.text)
        : null;
    final coloured = own == null
        ? into
        : into == null || into.isEmpty
        ? own
        : [(own.first.$1, into.first.$2), ...own.skip(1)];
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
    final drawnText = parts?.map((p) => p.$1).join() ?? shown.text;
    final eased = hafsFont ? _easedHamzaAt(ayah, w, drawnText) : null;
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
      final child = draw(stopping && alert != null ? 1 : 0);
      // Read so only when stopping: the letter's colour tells it, with no
      // sign under it.
      return child;
    }

    final drawn = drawnText;
    Widget word = ink(drawn);
    final yaBelow =
        hafsFont &&
        YaBelowMark.applies(drawn) &&
        _baseAt(
          widget.variants,
          widget.settings,
          ayah,
          w,
        ).any((v) => v.word == w && v.rule == 'hamza_mutatarrif');
    if (yaBelow) {
      word = YaBelowMark(
        text: drawn,
        style: TextStyle(fontFamily: 'Hafs', fontSize: fontSize, height: 1),
        color: expanded?.lastOrNull?.$2 ?? m.color ?? MushafColors.ink,
        builder: ink,
      );
    } else if (eased != null) {
      final (i, hamza) = eased;
      word = HamzaReplacementMark(
        text: drawn,
        offset: lettersOf(drawn).take(i).join().length,
        originalHamza: hamza,
        letter: '',
        // In the colour of its letter: in ink when nothing is compared.
        color: expanded?.elementAtOrNull(i)?.$2 ?? m.color ?? MushafColors.ink,
        style: TextStyle(fontFamily: 'Hafs', fontSize: fontSize, height: 1),
        builder: ink,
      );
    } else if (replacement != null) {
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
    if (widget.ayahShade?.call(ayah) case final shade?) {
      // Over the gaps between the words too, so the ayah reads as one.
      word = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -fontSize * 0.2,
            right: -fontSize * 0.2,
            top: -fontSize * 0.3,
            bottom: -fontSize * 0.35,
            child: ColoredBox(
              key: ValueKey('ayah-shade:${ayah.surah}:${ayah.number}:$w'),
              color: shade,
            ),
          ),
          word,
        ],
      );
    }
    if (alert != null &&
        !stopping &&
        ((m.color != null || coloured != null) &&
                _glows([...m.shown, ...?_letterReadings(ayah, w)]) ||
            _pairGlows(ayah, w))) {
      word = _Alerting(child: word);
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
    final here = _readingsAt(widget.variants, widget.settings, ayah, w).shown;
    // A note over two words (عَادٗا ٱلُّولَىٰ of Abu Ja'far) holds the readings
    // of its second word too (Qalun's ٱلُّؤۡلَىٰ).
    final end = here
        .where((v) => v.word == w)
        .fold(w + 1, (e, v) => v.word + v.count > e ? v.word + v.count : e);
    final readings = <Variant>[
      for (var i = w; i < end; i++)
        ...(i == w
                ? here
                : _readingsAt(widget.variants, widget.settings, ayah, i).shown)
            .where((v) => v.word == i),
    ];
    readings.addAll(
      _otherBodies(widget.variants, widget.settings, ayah, w, readings),
    );
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

  /// A label of the key: the rule explained, for every selected riwaya that
  /// has it, the page's own first.
  void _openUsulGuide(_UsulGroup group) {
    final chapter = usulGuideLabel(group.label);
    UsulGuideSheet.show(
      context,
      label: group.label,
      riwayat: {
        for (final i in group.items.values) ...i.riwayat,
        for (final r in widget.settings.selected)
          if (usulOfRiwaya(
            widget.variants,
            widget.quran,
            r,
          ).containsKey(chapter))
            r,
      }.toList(),
      variants: widget.variants,
      quran: widget.quran,
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

/// The two letters an idgham names («بإدغام الدال في الضاد»: د and ض).
(String, String)? _idghamLetters(String description) {
  final m = RegExp(r'إدغام (?:ال)?(\S+) (?:في|ب) ?(?:ال)?(\S+)')
      .firstMatch(description);
  final x = _letterNames[m?[1]], y = _letterNames[m?[2]];
  return x == null || y == null ? null : (x, y);
}

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

/// A usul imala, or a farsh word read with it (يَٰبُشۡرٰ۪يَ بالتقليل); not the
/// sign under a wasl alif begun with kasra (اَ۪تَّخَذتُّمُ), nor يُوح۪ىٰٓ for
/// نُوحِيٓ, whose taqlil is part of its farsh: the whole word in its colour.
bool _farshImala(Variant v) =>
    v.isUsul ||
    RegExp('إمالة|الإمالة|تقليل|التقليل').hasMatch(v.description) &&
        !v.description.startsWith('بالياء وتقليل');

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
  // Every riwaya's ya as Hafs reads it is no difference (إِنِّيٓ أَعۡلَمُ).
  if (v.rule != 'ya_idafa') return true;
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
  if (s.displayed == null) {
    all.removeWhere((v) => _readByAll(variants, s, ayah, w, v));
  }
  // Source reminders remain visible when their own riwaya is the base, but
  // for it shown alone: its usul below the page, no hamesh.
  final alone =
      s.displayed != null &&
      !s.compareHafs &&
      {...s.selected, s.displayed}.length == 1;
  if (!alone) all.addAll(base.where((v) => v.isMarginNote));
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
                    !_readByAll(variants, s, ayah, w, v) &&
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

/// Without Hafs to compare with, the mushaf's riwaya is compared with the
/// other selected ones only: a usul all of them read alike (their mim silah)
/// differs from none, so it is not coloured; the usul below the page tell it.
/// Shown alone, nothing of it is coloured.
bool _readByAll(
  VariantRepository variants,
  ReaderSettings s,
  Ayah ayah,
  int w,
  Variant v,
) {
  if (v.isMarginNote || s.compareHafs) return false;
  final readers = {...s.selected, ?s.displayed};
  // The mushaf in one riwaya alone: nothing to compare it with, its farsh
  // its text. Hafs's text with one riwaya selected is compared with it.
  if (readers.length < 2) return s.displayed != null;
  if (!v.isUsul) return false;
  final key = readingVariantKey(v);
  return readers.every(
    (id) => variants
        .at([id], ayah.surah, ayah.number, w)
        .any((o) => o.isUsul && o.word == w && readingVariantKey(o) == key),
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
      final kinds = usulKindsOf(v);
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
        final faces =
            ReadingColors.labelForRule(v.rule) != null ||
                v.isLinHamz ||
                v.rule == 'ya_zaida' ||
                label.startsWith('الهمزتان من كلمتين') ||
                label.contains('همز') &&
                    (v.usulWays.length > 1 ||
                        v.rule == 'tasheel_pair' ||
                        v.rule == 'tasheel_word')
            ? v.usulWays
            : const <String>[];
        // A verified reader's two hamzas told only in the row's wording.
        final ways =
            faces.isEmpty &&
                usulUnifiedRiwayat.contains(v.riwayaId) &&
                label.startsWith('الهمزتان من كلم') &&
                v.description.isNotEmpty
            ? [v.description.replaceFirst(RegExp('^ب'), '')]
            : faces;
        // Equal labels need separate groups when their permitted faces
        // differ (qasr / ishba', arid movement, or changed badal).
        final groupKey = '$label:${ways.join('|')}';
        final g = groups.putIfAbsent(
          groupKey,
          () => _UsulGroup(label, ReadingColors.forLabel(label)),
        );
        g.ways.addAll(ways);
        // One word however a reader's text marks its pause («رَّبِّهِمُۥۖ»),
        // or its font writes the sukun and the ya («مَعِے»، «مَعِي»).
        final same = word
            .replaceAll(RegExp('[ۖ-ۜ]'), '')
            .replaceAll('ۡ', 'ْ')
            .replaceAll(RegExp('[ىے]'), 'ي')
            // Nor its madd, Qalun's short and Warsh's long (ٱلنَّبِيٓءُ إِنَّآ).
            .replaceAll(
              RegExp(label.startsWith('الهمزتان من كلمتين') ? 'ٓ' : r'(?!)'),
              '',
            )
            // Nor its dhal merged into the ta, told in its own chapter: one
            // silah of «أَتَّخَذۡتُمُۥ» for al-Bazzi and Abu Ja'far.
            .replaceAllMapped(
              RegExp('ذْ?ت([َُِ]?)ّ?([َُِ]?)'),
              (m) => 'ذت${m[1]}${m[2]}',
            );
        final item = g.items.putIfAbsent(
          hasYaqub
              ? 'yaqub:${v.stopOnly}:$same:${v.hamzaReplacement}'
              : '${ayah.surah}:${ayah.number}:$w:${v.stopOnly}:$same:${v.hamzaReplacement}',
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

/// The readers verified so far share one set of chapters: their rules are
/// told by chapter, kind, then a table of the word, reader and face.
bool _isUnifiedGroup(_UsulGroup g) => g.items.values.every(
  (i) =>
      i.riwayat.every(usulUnifiedRiwayat.contains) ||
      // Abu 'Amr's «ٱلَّٰٓـِٔي», told with theirs.
      i.readings.every((v) => v.rule == 'hamza_mutatarrif'),
);

/// Below this a phone's margin has no room for three columns: a table's row
/// is then told in one column.
const _tableMinWidth = 200.0;

/// A rule's table: the word and the reader as wide as they need, up to their
/// share of a narrow margin, and the face all the rest.
const _tightColumns = <int, TableColumnWidth>{
  0: MinColumnWidth(IntrinsicColumnWidth(), FractionColumnWidth(0.34)),
  1: MinColumnWidth(IntrinsicColumnWidth(), FractionColumnWidth(0.2)),
  2: FlexColumnWidth(),
};

/// A rule's table: its fields set apart by a visible line and a small gap.
const _cellPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 2);
TableBorder get _tableBorder =>
    TableBorder.all(color: MushafColors.gold.withAlpha(220), width: 0.8);

/// The place of a riwaya in the app's list of the readers.
int _riwayaRank(String id) {
  var rank = 0;
  for (final q in qiraat) {
    for (final r in q.riwayat) {
      if (r.id == id) return rank;
      rank++;
    }
  }
  return rank;
}

class _UsulGroup {
  _UsulGroup(this.label, this.color);

  final String label;
  final Color color;
  final items = <String, _UsulItem>{};
  final ways = <String>{};
}

/// The tasheel dot of Ashab al-Silah in [item]'s text, as on the page: the
/// text with its eased hamza in Hafs's place, the offset of the dot and
/// Hafs's hamza there.
(String, int, String)? _usulEasedDot(_UsulItem item) =>
    _easedDotIn(item.text, item.ayah, item.word, item.readings);

/// [text], read at [word] of [ayah] by [readings], with its tasheel dot. Its
/// words are Hafs's own from [from], or else beginning where their first
/// letters agree (هَٰؤُلَآ۟ إِن from the first of the pair, شُهَدَآءَ إِذۡ to the
/// second).
(String, int, String)? _easedDotIn(
  String text,
  Ayah ayah,
  int word,
  List<Variant> readings, {
  int? from,
}) {
  final words = text.split(' ');
  final hafs = ayah.words;
  String head(String w) => w.isEmpty
      ? ''
      : RegExp('[اأإآٱء]').hasMatch(w[0])
      ? 'ا'
      : w[0];
  var start = from ?? word;
  for (var s = word - words.length + 1; from == null && s <= word; s++) {
    if (s < 0) continue;
    if ([
      for (final (k, w) in words.indexed)
        head(w) == head(hafs.elementAtOrNull(s + k) ?? ''),
    ].every((same) => same)) {
      start = s;
      break;
    }
  }
  final hamza = readings.any((v) => v.kind == VariantKind.hamza);
  final initial = readings.any(_easesFirstHamza);
  var offset = 0;
  for (final (k, w) in words.indexed) {
    final own = hafs.elementAtOrNull(start + k) ?? '';
    words[k] = _easedAsHafs(w, own, hamza);
    final dot = _easedHamzaDot(
      words[k],
      own,
      initial: initial && start + k == word,
    );
    if (dot != null) {
      final (i, h) = dot;
      return (
        words.join(' '),
        offset + lettersOf(words[k]).take(i).join().length,
        h,
      );
    }
    offset += words[k].length + 1;
  }
  return null;
}

/// [shown] in [style], the hamza at [hidden] kept for its room but unseen
/// under the dot that takes its place.
Widget _withHiddenHamza(String shown, int? hidden, TextStyle style) =>
    hidden == null
    ? QuranWordText(shown, style: style)
    : Text.rich(
        TextSpan(
          children: [
            for (final (part, color) in HamzaReplacementMark.hideHamza([
              (shown, null),
            ], hidden))
              TextSpan(
                text: part,
                style: TextStyle(color: color),
              ),
          ],
        ),
        textDirection: TextDirection.rtl,
        style: style,
      );

/// The surahs opening with separate letters; al-Shura's second ayah too.
const _openingSurahs = {
  2, 3, 7, 10, 11, 12, 13, 14, 15, 19, 20, 26, 27, 28, 29, 30, 31, 32, //
  36, 38, 40, 41, 42, 43, 44, 45, 46, 50, 68,
};

bool _openingLetters(Ayah ayah, int word) =>
    word == 0 &&
    _openingSurahs.contains(ayah.surah) &&
    (ayah.number == 1 || ayah.surah == 42 && ayah.number == 2);

/// The descriptions of [readings], each once; with its readers when the
/// readings are not told alike.
List<(String, String?)> _descriptionsOf(List<Variant> readings) {
  final by = <String, List<String>>{};
  for (final v in readings) {
    if (v.shownDescription.isEmpty) continue;
    (by[v.shownDescription] ??= []).add(v.riwayaId);
  }
  return [
    for (final MapEntry(key: d, value: ids) in by.entries)
      (d, by.length > 1 ? readersAr(ids, const []) : null),
  ];
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

/// Hamesh entries of [ayahs] in page order: one per word where a reading
/// of the selected riwayat starts. The same word read the same way again on
/// the page is listed once.
/// The word of each selected reader who does not read a rule of the shown
/// reader's that changes its body (النَّبِيٓـِٕينَ, for those who read it without
/// the hamza).
List<Variant> _otherBodies(
  VariantRepository variants,
  ReaderSettings s,
  Ayah ayah,
  int w,
  List<Variant> told,
) => otherBodyNotes(
  variants,
  ayah,
  w,
  s.displayed,
  {
    ...s.selected.where((id) => variants.isLoaded(id)),
    if (s.compareHafs) hafsId,
  }.where((id) => id != s.displayed),
  told,
);

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
      final own = m.shown.where((v) => v.word == w && v.inHamesh).toList();
      final starting = [
        ...own,
        ..._otherBodies(variants, settings, ayah, w, m.shown),
      ];
      if (starting.isEmpty) continue;
      final end = starting
          .map((v) => v.word + v.count)
          .reduce((a, b) => a > b ? a : b);
      // The word as shown on the page: Hafs, or the riwaya shown.
      // Or both words of a farsh across two ayahs (يسٓ وَٱلۡقُرۡءَانِ), once.
      final hafs =
          starting.where(_farshAcrossAyahs).firstOrNull?.usulText ??
          readingText(variants, settings.displayed, ayah, w, end);
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
          (own.isEmpty ? m.color : ReadingColors.ofReadings(starting)) ??
              m.color ??
              MushafColors.ink,
          starting,
        ),
      );
    }
  }
  return out;
}

/// Warsh's لَأَتَوْهَا (الأحزاب 14), its rasm as Hafs's: shaded in its own text
/// too, the difference being only in the reading.
/// And its يسٓ وَٱلۡقُرۡءَانِ, read as one with the idgham.
bool _shadedFarsh(Variant v) =>
    v.description == 'بحذف المد الطبيعي بعد الهمزة' ||
    // «لَأَتَوۡهَا» of Ashab al-Silah: written as Hafs's, read short.
    v.description == 'بقصر الهمزة' ||
    // ٱلۡغَنِيُّ ٱلۡحَمِيدُ (الحديد 24), without هُوَ.
    v.description == 'بحذف هو' ||
    _farshAcrossAyahs(v) ||
    _tanweenDamm(v);

bool _farshAcrossAyahs(Variant v) => !v.isUsul && v.usulText.contains(' ');

/// Warsh's tanween read with a damma in wasl, before the next ayah: the book's
/// wording (مُّنِيبٍ «ضم التنوين وصلاً») or the reviewed one.
bool _tanweenDamm(Variant v) =>
    v.riwayaId == 'warsh' &&
    (v.description == 'بالضم في الوصل' || v.description.contains('ضم التنوين'));

final _tanweenMark = RegExp('[ً-ٍٖٗٞ]');

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
  // With another rule told after it (ٱلۡأَعۡلَىٰ: «، بالتقليل»).
  final d
      when v.rule == 'naql' && d.startsWith('بنقل حركة الهمزة إلى اللام،') =>
    _Naql.lam,
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
    this.squares = const [],
    this.compact = false,
  });

  final int page;
  final bool sides;

  /// Turned: the number's line no taller than it must be, the text the
  /// larger (the user, 2026-11-13).
  final bool compact;
  final Widget child;
  final VoidCallback? onNumberTap;

  /// The riwayat chosen, each with its length, on the frame's upper band and
  /// its lower one, in every view (the user, 2026-11-13): see [_splitRiwayat].
  final List<(_FrameSquare, double)> squares;

  /// A square across a band reaches the line inside it.
  static const squareDepth = OrnamentFrame.band + 3;

  /// How far a raised square stands out of its band, down into the page.
  static const squareLift = 7.0;

  /// Space outside the border, including a visible gap above the number.
  static const numberHeight = 30.0;
  static const numberGap = 6.0;

  /// The number's line when [compact]: just clear of a raised square.
  static const compactNumberHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, box) {
              const corner = OrnamentFrame.band + 2;
              final across = box.maxWidth - 2 * corner;
              final (upper, lower) = _splitRiwayat(squares, across, across);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  OrnamentFrame(
                    key: ValueKey('mushaf-ornament-$page'),
                    sides: sides,
                    child: child,
                  ),
                  if (upper.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: corner,
                      right: corner,
                      child: _RiwayatBar(
                        key: const ValueKey('frame-riwayat'),
                        squares: upper,
                      ),
                    ),
                  if (lower.isNotEmpty)
                    Positioned(
                      bottom: -squareLift,
                      left: corner,
                      right: corner,
                      child: _RiwayatBar(
                        key: const ValueKey('frame-riwayat-lower'),
                        squares: lower,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: compact ? compactNumberHeight : numberHeight,
          child: _number(),
        ),
      ],
    );
  }

  Widget _number() => Padding(
    padding: EdgeInsets.only(top: compact ? squareLift : numberGap),
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
            fontSize: compact ? 13 : 18,
            height: compact ? 1.1 : 1.2,
            color: MushafColors.ink,
          ),
        ),
      ),
    ),
  );
}

/// The height of a band's row of riwayat, a raised square's lift with it.
const _riwayatBar = _PageFrame.squareDepth + _PageFrame.squareLift;

/// [squares] in the order of the Shatibiyya, dealt to the frame's upper band
/// ([upper] long) and its lower one ([lower] long), from the right
/// (the user, 2026-11-13): the upper filled first, then the lower; when both
/// are full the lower keeps as many as it holds, the last ones, and the rest
/// go up, the upper then scrolled. The lower never is.
(List<_FrameSquare>, List<_FrameSquare>) _splitRiwayat(
  List<(_FrameSquare, double)> squares,
  double upper,
  double lower,
) {
  var top = 0;
  for (var used = 0.0; top < squares.length; top++) {
    used += squares[top].$2;
    if (used > upper) break;
  }
  // The longest run of the last ones the lower bar holds.
  var from = squares.length;
  for (var used = 0.0; from > top; from--) {
    used += squares[from - 1].$2;
    if (used > lower) break;
  }
  return (
    [for (final s in squares.take(from)) s.$1],
    [for (final s in squares.skip(from)) s.$1],
  );
}

/// A riwaya's square, built along its bar ([Axis.horizontal]) and [depth]
/// across it, raised towards [grow].
typedef _FrameSquare = Widget Function(
  Axis axis,
  double depth,
  AxisDirection grow,
);

/// A band's row of the riwayat, from the right. Those beyond its width are
/// scrolled to; an arrow at a side tells there are more that way, and a tap
/// on it brings them.
class _RiwayatBar extends StatefulWidget {
  const _RiwayatBar({super.key, required this.squares});

  final List<_FrameSquare> squares;

  @override
  State<_RiwayatBar> createState() => _RiwayatBarState();
}

class _RiwayatBarState extends State<_RiwayatBar> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_moved);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _moved() => setState(() {});

  /// A drag along the row slides it, the page under it not turned (the user,
  /// 2026-11-13): told sooner than the page's turn, on a riwaya only.
  void _drag(double dx) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    // From the right: a finger moving right brings those on the left.
    _scroll.jumpTo((p.pixels + dx).clamp(p.minScrollExtent, p.maxScrollExtent));
  }

  void _fling(DragEndDetails end) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final v = end.velocity.pixelsPerSecond.dx;
    if (v.abs() < 50) return;
    _scroll.animateTo(
      (p.pixels + v * .3).clamp(p.minScrollExtent, p.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Towards the right ([right]) or the left by most of the bar.
  void _page(bool right) {
    final p = _scroll.position;
    // From the right: the right is the start.
    final to = p.pixels + (right ? -1 : 1) * p.viewportDimension * .7;
    _scroll.animateTo(
      to.clamp(p.minScrollExtent, p.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _scroll.hasClients && _scroll.position.hasContentDimensions
        ? _scroll.position
        : null;
    // Measured once laid out: then the arrows.
    if (p == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) setState(() {});
      });
    }
    final moreRight = p != null && p.extentBefore > .5;
    final moreLeft = p != null && p.extentAfter > .5;
    Widget arrow(bool right) => Positioned(
      top: 0,
      bottom: 0,
      right: right ? 0 : null,
      left: right ? null : 0,
      child: GestureDetector(
        key: ValueKey('riwayat-more-${right ? 'right' : 'left'}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _page(right),
        child: Container(
          width: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: right ? Alignment.centerRight : Alignment.centerLeft,
              end: right ? Alignment.centerLeft : Alignment.centerRight,
              colors: [MushafColors.page, MushafColors.page.withAlpha(0)],
              stops: const [.55, 1],
            ),
          ),
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Icon(
            right ? Icons.chevron_right : Icons.chevron_left,
            size: 20,
            color: MushafColors.green,
          ),
        ),
      ),
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: _riwayatBar,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                // Slid by its own drag below.
                physics: const NeverScrollableScrollPhysics(),
                child: RawGestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  gestures: {
                    HorizontalDragGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          HorizontalDragGestureRecognizer
                        >(
                          HorizontalDragGestureRecognizer.new,
                          (r) => r
                            // Before the page's turn (10), after a tap's
                            // tremble.
                            ..gestureSettings = const DeviceGestureSettings(
                              touchSlop: 4,
                            )
                            ..onUpdate = ((d) => _drag(d.delta.dx))
                            ..onEnd = _fling,
                        ),
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final square in widget.squares)
                        square(
                          Axis.horizontal,
                          _PageFrame.squareDepth,
                          AxisDirection.down,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Fixed whichever way the text runs.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  if (moreRight) arrow(true),
                  if (moreLeft) arrow(false),
                ],
              ),
            ),
          ],
        ),
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
    this.onUsul,
    this.juzKey,
  });

  final String surah;

  /// On the juz's name, to find where it stands.
  final Key? juzKey;
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
                : Align(
                    // Clear of the arrow of the riwayat, in the middle.
                    alignment: const AlignmentDirectional(.78, 0),
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
          Text('الجزء ${_juzNames[juz - 1]}', key: juzKey, style: style),
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
    // Each note's middle on the middle of its word's line.
    final wanted = {
      for (final i in shown) i: math.max(0.0, tops[i] - heights[i]! / 2),
    };
    // In the order of the words: a note of the same line as the one before
    // it (يُجَٰزَىٰٓ … ٱلۡكَفُورُ) goes just under it, not below the page.
    final lexical = shown.where((i) => notes[i].farsh).toList()..sort();
    final order = <int>[];
    var bottom = 0.0;
    for (final i in lexical) {
      var y = math.max(wanted[i]!, bottom);
      // Too far below its line (نتقبل … أحسن … ونتجاوز on one line): the
      // notes stacked just above it rise into the free room above them,
      // each still within a line of its own.
      final need = y - wanted[i]! - 63;
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
          if (rise > placed[j]! - math.max(0.0, wanted[j]! - 63)) {
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
      if (y + heights[i]! > size.height || y - wanted[i]! >= 64) continue;
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
        // Its middle on the middle of its word's line.
        positions[i] = math.max(tops[i] - heights[i] / 2, bottom);
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
/// A word that differs from Hafs, glowing still while the lamp of
/// «تنبيه الاختلافات» is lit.
class _Alerting extends StatelessWidget {
  const _Alerting({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: MushafColors.gold.withAlpha(150),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    ),
    child: child,
  );
}

/// The usul of the page below it: each kind in its colour, then every word
/// read with it and who reads it so. Tapping a word opens its readings.
class _UsulBox extends StatelessWidget {
  const _UsulBox({
    required this.groups,
    required this.onTap,
    this.onGuide,
    this.scale = 1,
    this.compact = false,
  });

  final List<_UsulGroup> groups;
  final ValueChanged<_UsulItem> onTap;
  final ValueChanged<_UsulGroup>? onGuide;
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
        children: _rules(),
      ),
    );
  }

  /// The rules told: a rule with no kinds or faces on its line; the others
  /// under the name of their chapter, each kind with its table.
  List<Widget> _rules() {
    final rules = <Widget>[];
    final told = <String>{};
    for (final g in groups) {
      if (!_isUnifiedGroup(g)) {
        rules.add(_plain(g, first: rules.isEmpty));
        continue;
      }
      final chapter = usulGuideLabel(g.label);
      if (!told.add(chapter)) continue;
      final of = [
        for (final o in groups)
          if (_isUnifiedGroup(o) && usulGuideLabel(o.label) == chapter) o,
      ];
      if (of.every((o) => o.label == chapter && o.ways.isEmpty)) {
        for (final o in of) {
          rules.add(_plain(o, first: rules.isEmpty));
        }
      } else {
        rules.add(_chapter(chapter, of, first: rules.isEmpty));
      }
    }
    return rules;
  }

  Widget _chapter(String chapter, List<_UsulGroup> of, {required bool first}) {
    final labels = {for (final g in of) g.label}.toList();
    // The kinds of «الوقف على الهمز» in the guide's order.
    if (chapter == 'الوقف على الهمز') {
      int rank(String l) {
        final at = waqfHamzaKinds.indexWhere((k) => l.endsWith('($k)'));
        return at < 0 ? waqfHamzaKinds.length : at;
      }

      labels.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    final alone = labels.length == 1 && labels.single == chapter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (first && !compact)
            Text(
              'الأصول',
              style: TextStyle(
                fontSize: 8 * scale,
                fontWeight: FontWeight.bold,
                color: MushafColors.green,
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              key: ValueKey(
                alone ? 'usul-guide:$chapter' : 'usul-chapter:$chapter',
              ),
              onTap: onGuide == null ? null : () => onGuide!(of.first),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: of.first.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$chapter:',
                      style: TextStyle(
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.bold,
                        color: of.first.color,
                        decoration: onGuide == null
                            ? null
                            : TextDecoration.underline,
                        decorationColor: of.first.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final label in labels)
            Padding(
              padding: EdgeInsetsDirectional.only(start: 10 * scale, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (label != chapter)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InkWell(
                        key: ValueKey('usul-guide:$label'),
                        onTap: onGuide == null
                            ? null
                            : () => onGuide!(
                                of.firstWhere((g) => g.label == label),
                              ),
                        child: Text(
                          '${label.substring(chapter.length + 2, label.length - 1)}:',
                          style: TextStyle(
                            fontSize: 9 * scale,
                            fontWeight: FontWeight.bold,
                            color: of.first.color,
                          ),
                        ),
                      ),
                    ),
                  _table([
                    for (final g in of)
                      if (g.label == label) g,
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The word, its reader and the face, a row for each reader's own; in the
  /// order of the readers' list.
  Widget _table(List<_UsulGroup> of) {
    final rows = <(_UsulGroup, List<_UsulItem>, List<String>, String)>[];
    for (final g in of) {
      // One word of one face, however each reader's text writes it.
      final places = <String, (_UsulItem, Set<String>)>{};
      for (final i in g.items.values) {
        final place = places.putIfAbsent(
          // A madd written in one reader's word only is a word of its own.
          '${i.ayah.surah}:${i.ayah.number}:${i.word}:${i.stopOnly}:'
          '${i.text.endsWith('\u0653')}:'
          // Told by its wording: each wording a row of its own (\u0647\u064e\u0670\u0653\u0623\u064e\u0646\u062a\u064f\u0645\u06e1).
          '${g.ways.isEmpty ? i.readings.first.description : ''}',
          () => (i, {}),
        );
        place.$2.addAll(i.riwayat);
      }
      final byRow = <String, (List<_UsulItem>, List<String>, String)>{};
      for (final (i, readers) in places.values) {
        final ordered = readers.toList()
          ..sort((a, b) => _riwayaRank(a).compareTo(_riwayaRank(b)));
        // Told by its faces, or else by the wording of its row.
        // Numbered where there are several; one told as it is.
        final faces = g.ways.length == 1
            ? g.ways.single
            : g.ways.isNotEmpty
            ? g.ways
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}- ${e.value}')
                  .join('؛ ')
            : i.readings.first.description.replaceFirst(RegExp('^ب'), '');
        byRow
            .putIfAbsent(
              '${ordered.join(',')}:$faces',
              () => ([], ordered, faces),
            )
            .$1
            .add(i);
      }
      for (final (items, readers, faces) in byRow.values) {
        rows.add((g, items, readers, faces));
      }
    }
    // In the order of the page, a word's rows together (أَتُمِدُّونَنِ of each
    // reader, then ءَاتَىٰنِ); each word's in the order of the readers.
    int at((_UsulGroup, List<_UsulItem>, List<String>, String) r) {
      final i = r.$2.first;
      return (i.ayah.surah * 1000 + i.ayah.number) * 1000 + i.word;
    }

    // Hamza's stop on the article and on the separated sakin: Khalaf's and
    // Khallad's one row, their faces, and Khalaf's other face, the sakt,
    // beside them (the user, 2026-11-12).
    if (const {
      'الوقف على الهمز (الوقف على لام التعريف)',
      'الوقف على الهمز (الوقف على الساكن المفصول)',
    }.contains(of.first.label)) {
      String places(List<_UsulItem> items) =>
          (items
                  .map((i) => '${i.ayah.surah}:${i.ayah.number}:${i.word}')
                  .toList()
                ..sort())
              .join(',');
      for (final khalaf in [...rows]) {
        if (khalaf.$3.length != 1 || khalaf.$3.single != 'khalaf_hamzah') {
          continue;
        }
        final khallad = rows
            .where(
              (r) =>
                  r.$3.length == 1 &&
                  r.$3.single == 'khallad' &&
                  places(r.$2) == places(khalaf.$2),
            )
            .firstOrNull;
        // Khalaf's faces Khallad's and the sakt.
        if (khallad == null ||
            [...khallad.$1.ways, 'السكت'].join('|') !=
                khalaf.$1.ways.join('|')) {
          continue;
        }
        final at = rows.indexOf(khalaf);
        rows
          ..[at] = (
            khallad.$1,
            khalaf.$2,
            const ['khalaf_hamzah', 'khallad'],
            '${khallad.$4}${khallad.$4.contains('؛') ? '؛' : '،'} '
                'ولخلف وجه آخر بالسكت',
          )
          ..remove(khallad);
      }
    }
    rows.sort((a, b) {
      final place = at(a).compareTo(at(b));
      return place != 0
          ? place
          : _riwayaRank(a.$3.first).compareTo(_riwayaRank(b.$3.first));
    });
    Widget cell(Widget child) => Padding(padding: _cellPadding, child: child);
    Widget wordsOf(_UsulGroup g, List<_UsulItem> items) => Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (n, i) in items.indexed) ...[
          if (n > 0)
            Text(
              '، ',
              style: TextStyle(fontSize: 9 * scale, color: g.color),
            ),
          _item(g, i, named: false),
        ],
      ],
    );
    Widget face(_UsulGroup g, String faces) => Text(
      faces,
      key: ValueKey(
        g.label.startsWith('الهمزتان من كلمة (')
            ? 'hamza-word-ways'
            : 'hamza-ways:${g.label}:${g.ways.join('|')}',
      ),
      style: TextStyle(fontSize: 8.5 * scale, height: 1.3, color: g.color),
    );
    Widget reader(List<String> readers) => Text(
      readersAr(readers, const []),
      style: TextStyle(fontSize: 8.5 * scale, color: MushafColors.ink),
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < _tableMinWidth
          ? Table(
              border: _tableBorder,
              children: [
                for (final (g, items, readers, faces) in rows)
                  TableRow(
                    children: [
                      cell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            wordsOf(g, items),
                            reader(readers),
                            face(g, faces),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            )
          : Table(
              columnWidths: _tightColumns,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: _tableBorder,
              children: [
                for (final (g, items, readers, faces) in rows)
                  TableRow(
                    children: [
                      cell(wordsOf(g, items)),
                      cell(reader(readers)),
                      cell(face(g, faces)),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _plain(_UsulGroup g, {required bool first}) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            if (first && !compact)
              Text(
                'الأصول',
                style: TextStyle(
                  fontSize: 8 * scale,
                  fontWeight: FontWeight.bold,
                  color: MushafColors.green,
                ),
              ),
            InkWell(
              key: ValueKey('usul-guide:${g.label}'),
              onTap: onGuide == null ? null : () => onGuide!(g),
              child: Row(
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
                        decoration: onGuide == null
                            ? null
                            : TextDecoration.underline,
                        decorationColor: g.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The words the same readers share, their readers named once:
            // first what several share, then each reader's own.
            for (final (items, readers) in _byReaders(g.items.values))
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (n, i) in items.indexed) ...[
                    if (n > 0)
                      Text(
                        '، ',
                        style: TextStyle(fontSize: 9 * scale, color: g.color),
                      ),
                    _item(g, i, named: false),
                  ],
                  Text(
                    ' (${readersAr(readers, const [])})',
                    style: TextStyle(
                      fontSize: 8.5 * scale,
                      color: MushafColors.ink,
                    ),
                  ),
                ],
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
                g.label.contains('في كلمة') ||
                        g.label.startsWith('الهمزتان من كلمة (')
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
  );

  /// [items] by the readers who read them, in the page's order: the sets of
  /// several readers first, by their first reader, then each one's own.
  List<(List<_UsulItem>, List<String>)> _byReaders(Iterable<_UsulItem> items) {
    final sets = <String, (List<_UsulItem>, List<String>)>{};
    for (final i in items) {
      final readers = i.riwayat.toList()
        ..sort((a, b) => _riwayaRank(a).compareTo(_riwayaRank(b)));
      sets.putIfAbsent(readers.join(','), () => ([], readers)).$1.add(i);
    }
    return sets.values.toList()..sort((a, b) {
      final many = (b.$2.length > 1 ? 1 : 0) - (a.$2.length > 1 ? 1 : 0);
      if (many != 0) return many;
      return _riwayaRank(a.$2.first).compareTo(_riwayaRank(b.$2.first));
    });
  }

  Widget _item(_UsulGroup g, _UsulItem i, {bool named = true}) => InkWell(
    key: ValueKey(
      'usul-reference:${g.label}:${i.ayah.surah}:${i.ayah.number}:${i.word}:${i.riwayat.join(',')}',
    ),
    onTap: () => onTap(i),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _usulWord(i, g.color),
        // How the ya is read (يَدِي: بإسكان ياء الإضافة).
        // With more told of the word, its own wording (تَأۡمُرُوٓنِّيَ: بفتح الياء
        // وتشديد النون مع المد المشبع).
        if (i.readings.any((v) => v.rule == 'ya_idafa'))
          Text(
            ' (${i.readings.where((v) => v.rule == 'ya_idafa' && RegExp('^بفتح الياء و').hasMatch(v.description)).firstOrNull?.description ?? (i.readings.any((v) => v.rule == 'ya_idafa' && v.description.contains('فتح')) ? 'بفتح ياء الإضافة' : 'بإسكان ياء الإضافة')}'
            // A second face of one of them (رَبِّيَ: ولقالون وجه ثانٍ بإسكان الياء).
            '${{for (final v in i.readings)
              if (v.rule == 'ya_idafa' && v.description.contains('، ول')) v.description.substring(v.description.indexOf('، ول'))}.join()})',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // Abu Ja'far's ya of the zawaid, in wasl alone (ٱلدَّاعِۦ، دَعَانِۦ).
        // Not where its face is told already (يَهۡدِيَنِۦ: إثبات الياء وصلاً فقط).
        if (i.readings.any(
              (v) =>
                  v.rule == 'ya_zaida' &&
                  const {'ibn_wardan', 'ibn_jammaz'}.contains(v.riwayaId),
            ) &&
            !i.readings.any((v) => v.usulWays.any((w) => w.contains('وصل'))))
          Text(
            ' (وصلًا فقط)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // How the opening letters are read, whatever the chapter (الٓمٓ:
        // بالسكت على كل حرف، الٓرۚ: بإمالة الراء), by each reader if they differ.
        if (_openingLetters(i.ayah, i.word))
          for (final (d, readers) in _descriptionsOf(i.readings))
            Text(
              readers == null ? ' ($d)' : ' ($d: $readers)',
              style: TextStyle(fontSize: 9 * scale, color: g.color),
            ),
        // A naql told in words of its own (مِنِ ٱجۡلِ، مِلُ), not the bare rule.
        for (final d in {
          for (final v in i.readings)
            if (v.rule == 'naql' &&
                _ashabSilah.contains(v.riwayaId) &&
                v.description.isNotEmpty &&
                v.description != 'بالنقل')
              v.description,
        })
          Text(
            ' ($d)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // The first of two sakins: what it is read with, joined.
        for (final d in {
          for (final v in i.readings)
            if (v.rule == 'first_sakin' && _ashabSilah.contains(v.riwayaId))
              firstSakinNote(v.description),
        })
          Text(
            ' ($d)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // Qalun's ٱلتَّوۡرَىٰةَ: its two faces, the fath preferred.
        for (final v in i.readings.where((v) => v.fathPreferred))
          Text(
            ' (${v.description})',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // Warsh's taqlil of يُجَٰزِيٓ, read with another face.
        if (i.readings.any(
          (v) =>
              v.riwayaId == 'warsh' &&
              v.isImala &&
              v.description.contains('بخلف'),
        ))
          Text(
            ' (بخلف)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // بَنَىٰهَا and its neighbours, with the fath.
        if (i.readings.any(
          (v) =>
              v.riwayaId == 'warsh' &&
              v.isImala &&
              v.description.contains('والتقليل مقدم'),
        ))
          Text(
            ' (له الفتح والتقليل والتقليل مقدم)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        // Its two faces (ذِكۡرًا، سِتۡرًا، إِمۡرًا).
        if (i.readings.any((v) => v.rule == 'tarqiq' && v.usulWays.length > 1))
          Text(
            ' (بالتفخيم والترقيق)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        if (i.stopOnly)
          Text(
            ' (وقفًا فقط)',
            style: TextStyle(fontSize: 9 * scale, color: g.color),
          ),
        if (named)
          Text(
            ' (${readersAr(i.riwayat.toList(), const [])})',
            style: TextStyle(fontSize: 8.5 * scale, color: MushafColors.ink),
          ),
        if (i.ways.isNotEmpty)
          Text(
            ' ${i.ways.join('؛ ')}',
            style: TextStyle(fontSize: 8.5 * scale, color: g.color),
          ),
      ],
    ),
  );

  Widget _usulWord(_UsulItem item, Color color) {
    final style = TextStyle(
      fontFamily: 'Hafs',
      fontSize: 12 * scale,
      color: color,
    );
    Widget text(String shown, [int? hiddenHamza]) =>
        _withHiddenHamza(shown, hiddenHamza, style);
    if (item.readings.any((v) => v.rule == 'hamza_mutatarrif') &&
        YaBelowMark.applies(item.text)) {
      return YaBelowMark(
        text: item.text,
        style: style,
        color: color,
        builder: text,
      );
    }
    final eased =
        item.replacement == null &&
            item.readings.isNotEmpty &&
            item.readings.every((v) => _ashabSilah.contains(v.riwayaId))
        ? _usulEasedDot(item)
        : null;
    if (eased != null) {
      final (shown, offset, hamza) = eased;
      return HamzaReplacementMark(
        text: shown,
        offset: offset,
        originalHamza: hamza,
        letter: '',
        style: style,
        color: color,
        builder: text,
      );
    }
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
    // Confirmed by the certified source (التسهيل).
    final certified = e.readings.every((v) => v.certified);
    final tick = TextSpan(
      text: ' ✓',
      style: TextStyle(
        fontSize: quran * 0.8,
        color: MushafColors.green,
        fontWeight: FontWeight.bold,
      ),
    );
    return InkWell(
      key: ValueKey(
        'margin-reference:${e.ayah.surah}:${e.ayah.number}:${e.word}',
      ),
      onTap: () => onTap(e.ayah, e.word),
      child: _noteLine(
        LayoutBuilder(
          builder: (context, box) =>
              box.maxWidth >= _tableMinWidth &&
                  e.readings.every(
                    (v) => usulUnifiedRiwayat.contains(v.riwayaId),
                  )
              ? _table(e, certified ? tick : null, label, reading * 0.85)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, g) in _readings(
                      e.readings,
                      e.ayah.words
                          .sublist(e.word, e.word + e.readings.first.count)
                          .join(' '),
                    ).indexed) ...[
                      // A faint line between the readers of one word
                      // (ابن وردان … / ابن جماز …).
                      if (i > 0)
                        Divider(
                          height: 4,
                          thickness: .4,
                          color: MushafColors.gold.withAlpha(90),
                        ),
                      Text.rich(
                        textAlign: TextAlign.start,
                        TextSpan(
                          children: [
                            for (var i = 0; i < g.names.length; i++)
                              TextSpan(
                                text: i == 0
                                    ? g.names[i].$1
                                    : ' و${g.names[i].$1}',
                                style: label.copyWith(
                                  color: g.names[i].$2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            TextSpan(text: ': ', style: label),
                            if (g.text.isNotEmpty ||
                                g.description.isEmpty ||
                                g.imala)
                              _wordSpan(g, e, reading),
                            if (g.description.isNotEmpty)
                              _descriptionSpan(
                                g.description,
                                label.copyWith(color: MushafColors.frame),
                                quran,
                              ),
                            if (certified) tick,
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  /// The line under a note, parting it from the next place: plainer than the
  /// faint one between the readers of one word.
  static Widget _noteLine(Widget note) => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(bottom: 3),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: MushafColors.gold, width: 1.4)),
    ),
    child: note,
  );

  /// A verified reader's farsh: the word, the reader and the reading.
  Widget _table(
    HameshEntry e,
    InlineSpan? tick,
    TextStyle label,
    double reading,
  ) {
    Widget cell(Widget child) => Padding(padding: _cellPadding, child: child);
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _tableBorder,
      children: [
        for (final g in _readings(
          e.readings,
          e.ayah.words
              .sublist(e.word, e.word + e.readings.first.count)
              .join(' '),
        ))
          TableRow(
            children: [
              cell(
                Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < g.names.length; i++)
                        TextSpan(
                          // A reader to a line: the column as wide as one
                          // name, the word beside it whole (ٱلۡمَيۡتَةَ).
                          text: i == 0 ? g.names[i].$1 : '\n${g.names[i].$1}',
                          style: label.copyWith(
                            color: g.names[i].$2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              cell(
                Text.rich(
                  TextSpan(
                    children: [
                      if (g.text.isNotEmpty || g.description.isEmpty || g.imala)
                        _wordSpan(g, e, reading),
                      if (g.description.isNotEmpty)
                        _descriptionSpan(
                          g.description,
                          label.copyWith(color: MushafColors.frame),
                          reading * 13 / 17,
                        ),
                      ?tick,
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// A reading's description, the vowelled word it quotes («يَٰحَسۡرَتَٰٓيۡ»)
  /// in the mushaf's font, its marks in their places.
  static InlineSpan _descriptionSpan(
    String text,
    TextStyle style,
    double size,
  ) {
    // Its faces each on a line of their own (\n before them: «ٱلۡأُولَىٰ» بضم
    // الهمزة / و«ٱلُولَىٰ» بضم اللام), as wide as the note.
    final lines = text.split('\n');
    if (lines.length == 1) return _quotedSpan(text, style, size);
    return TextSpan(
      children: [
        _quotedSpan(lines.first, style, size),
        for (final line in lines.skip(1))
          WidgetSpan(
            child: SizedBox(
              width: double.infinity,
              child: Text.rich(
                _quotedSpan(line, style, size),
                textAlign: TextAlign.start,
              ),
            ),
          ),
      ],
    );
  }

  static InlineSpan _quotedSpan(String text, TextStyle style, double size) {
    final quoted = RegExp('«([^»]*[ً-ْٰۖ-ۭ][^»]*)»');
    final parts = <InlineSpan>[];
    var at = 0;
    for (final m in quoted.allMatches(text)) {
      var before = text.substring(at, m.start).replaceAll(RegExp(r' +$'), '');
      // «و» and «بـ» go with the word they lead (و«ٱلُولَىٰ»), never left at
      // a line's end beside the word before.
      final lead = RegExp(r'(?:^|(?<=[\s،:]))(و|بـ)$').firstMatch(before)?[1];
      if (lead != null) {
        before = before
            .substring(0, before.length - lead.length)
            .replaceAll(RegExp(r' +$'), '');
      }
      // A face of its own line (\n before it) starts without a space.
      final space = before.isEmpty || before.endsWith('\n') ? '' : ' ';
      parts.add(TextSpan(text: before));
      // The quotes with the word, never parted from it at a line's end.
      final word = m[1]!;
      final hafs = TextStyle(
        fontFamily: 'Hafs',
        fontSize: size,
        color: style.color,
      );
      parts.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$space${lead ?? ''}«', style: style),
              // The font's line is tall for its marks: the word in a box
              // no taller than its letters, its marks overflowing it.
              Align(
                widthFactor: 1,
                heightFactor: .85,
                alignment: Alignment.bottomCenter,
                child: QuranWordText(word, style: hafs),
              ),
              Text('»', style: style),
            ],
          ),
        ),
      );
      at = m.end;
    }
    if (parts.isEmpty) return TextSpan(text: ' $text', style: style);
    parts.add(TextSpan(text: text.substring(at)));
    return TextSpan(
      style: style,
      children: [
        const TextSpan(text: ' '),
        ...parts,
      ],
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
    // Ashab al-Silah's eased hamza with the tasheel dot, as on the page.
    final ashab = [
      for (final v in e.readings)
        if (_ashabSilah.contains(v.riwayaId) &&
            (v.marginText.isNotEmpty ? v.marginText : v.text) == g.text)
          v,
    ];
    final dot = g.font == 'Hafs' && ashab.isNotEmpty
        ? _easedDotIn(text, e.ayah, ashab.first.word, ashab, from: e.word)
        : null;
    if (dot != null) {
      final (shown, offset, hamza) = dot;
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: HamzaReplacementMark(
          text: shown,
          offset: offset,
          originalHamza: hamza,
          letter: '',
          style: style,
          color: style.color!,
          builder: (shown, hidden) => _withHiddenHamza(shown, hidden, style),
        ),
      );
    }
    if (g.font == 'Hafs' && HafsFontMarks.needsAdjustment(text)) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: QuranWordText(text, style: style),
      );
    }
    return TextSpan(
      text: g.font == 'Hafs' ? hafsDrawable(text) : text,
      style: style,
    );
  }

  /// Who reads what: a qiraa by its name ("نافع") when both its riwayat
  /// read alike, otherwise each riwaya ("ورش عن نافع"); qiraat with the same
  /// reading share one line ("نافع وابن كثير: مَلِكِ").
  static List<_Reading> _readings(List<Variant> all, String baseline) {
    // A reader's note of the word (the faces of beginning with ٱلۡأُولَىٰ)
    // told on his own line, not a line of its own.
    final notes = [
      for (final v in all)
        if (v.rule == 'note') v,
    ];
    final vs = notes.isEmpty
        ? all
        : [
            for (final v in all)
              if (v.rule != 'note') v,
          ];
    final byRiwaya = <String, _Reading>{};
    final out = <_Reading>[];
    void add(String name, Color color, String font, Variant v) {
      final key = readingVariantKey(v, baseline: baseline);
      final text = v.marginText.isNotEmpty ? v.marginText : v.text;
      // A farsh read alike but for the silah of the ha (نَنكُسۡهُ، ولابن كثير
      // بالصلة): one line, the silah told of its readers.
      final bare = withoutHaSilah(text);
      // Two faces by khulf (al-Bazzi's لَأُقۡسِمُ) are not the one of another.
      bool sameFaces(_Reading g) =>
          !(g.description.startsWith('بخلف') || _brief(v).startsWith('بخلف')) ||
          g.description == _brief(v);
      final same =
          out.where((g) => g.key == key && sameFaces(g)).firstOrNull ??
          out
              .where(
                (g) =>
                    !g.imala &&
                    !v.isImala &&
                    g.font == font &&
                    g.text != text &&
                    withoutHaSilah(g.text) == bare &&
                    (g.description.isEmpty ||
                        _brief(v).isEmpty ||
                        g.description == _brief(v)),
              )
              .firstOrNull;
      final group =
          same ??
          _Reading(
            [],
            font,
            v.marginText.isNotEmpty
                ? v.marginText
                : _spacedImala(v)
                ? spacedImalaSigns(v.text)
                : v.text,
            _brief(v),
            key,
            imala: v.isImala,
          );
      if (same == null) out.add(group);
      // The first told without one (al-Bazzi's ta, told in the usul): the
      // wording of another read alike (لَآ تَّنَاصَرُونَ «بتشديد التاء»).
      if (group.description.isEmpty) group.description = _brief(v);
      group.names.add((name, color));
      byRiwaya[v.riwayaId] = group;
      if (bare != text) {
        group.silah.add(name);
      } else {
        group.withoutSilah = true;
      }
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
                    readingVariantKey(mine.first.$2, baseline: baseline) &&
                // Al-Bazzi's two faces, Qunbul's one (لَأُقۡسِمُ): apart.
                (_brief(m.$2).startsWith('بخلف') ||
                        _brief(mine.first.$2).startsWith('بخلف')
                    ? _brief(m.$2) == _brief(mine.first.$2)
                    : true),
          );
      if (sameReading) {
        final (r, v) = mine.first;
        add(q.shortAr, q.color, r.fontFamily ?? 'Hafs', v);
        for (final (_, o) in mine) {
          byRiwaya[o.riwayaId] = byRiwaya[v.riwayaId]!;
        }
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
    // Read alike but for the silah of the ha (عَمِلَتۡهُ، ولابن كثير بالصلة):
    // the word as the others read it, the silah told of its readers.
    for (final g in out) {
      if (g.silah.isEmpty || !g.withoutSilah) continue;
      g.text = withoutHaSilah(g.text);
      g.description = [
        if (g.description.isNotEmpty) g.description,
        // «ولابن كثير»، «وللدوري» (the lam with the al of the name).
        'و${[for (final n in g.silah) n.startsWith('ال') ? 'ل${n.substring(1)}' : 'ل$n'].join(' و')} بالصلة',
      ].join('، ');
    }
    // The notes on their readers' lines, once for a line of two riwayat
    // (أبو عمرو); a reader without a line here keeps his note apart.
    final told = <_Reading>{};
    for (final v in notes) {
      final group = byRiwaya[v.riwayaId];
      if (group == null) {
        final q = qiraaOf(v.riwayaId);
        final apart = _Reading(
          [
            (
              '${riwayaById(v.riwayaId).nameAr} عن ${_genitive(q.shortAr)}',
              q.color,
            ),
          ],
          'Hafs',
          v.text,
          _brief(v),
          'note:${v.riwayaId}',
        );
        out.add(apart);
      } else if (told.add(group) && !group.description.contains(_brief(v))) {
        group.description = [
          if (group.description.isNotEmpty) group.description,
          _brief(v).replaceFirst(RegExp('^و'), ''),
        ].join('، و');
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
  String text;

  /// e.g. "بالتاء", "بضم الهاء"; empty when not generated.
  String description;
  final String key;

  /// Who of [names] reads the ha of the word with its silah (عَمِلَتۡهُۥ),
  /// and whether one reads it without.
  final silah = <String>[];
  var withoutSilah = false;

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
