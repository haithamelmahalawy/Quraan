import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'mushaf_decor.dart';
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
  });

  final int page;
  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;
  final WordTap onWordTap;

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
  final _frameKey = GlobalKey();
  final _sideKey = GlobalKey();

  /// How many hamesh entries fit beside the page (the rest go below it),
  /// measured after layout for [_splitFor].
  int? _split;
  String? _splitFor;

  @override
  void dispose() {
    _disposeRecognizers();
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

    // Highlight and hamesh keep the printed lines; inline and replace change
    // word widths, so they flow the text instead.
    final lines = widget.quran.lines(widget.page);
    final printed = lines != null &&
        (s.mode == DisplayMode.hamesh || s.mode == DisplayMode.highlight);
    final page = printed
        ? MushafLines(
            lines: lines,
            centered: widget.quran.isCentered(widget.page),
            quran: widget.quran,
            wordBuilder: _word,
          )
        : _flowingText(ayahs, narrow);
    final framed = KeyedSubtree(
      key: _frameKey,
      child: _PageFrame(page: widget.page, child: page),
    );
    if (s.mode != DisplayMode.hamesh) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
        child: framed,
      );
    }

    // The hamesh sits outside the page, on its left (the end side in RTL);
    // what does not fit beside the page continues below it.
    final entries = _hameshEntries(ayahs);
    final signature = [
      widget.page,
      MediaQuery.sizeOf(context).width,
      for (final e in entries) '${e.ayah.number}:${e.word}:${e.readings.length}',
    ].join('|');
    if (signature != _splitFor) {
      _split = null;
      _splitFor = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureSplit(signature));
    }
    final split = _split ?? entries.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: narrow ? 76 : 78, child: framed),
              const SizedBox(width: 4),
              Expanded(
                flex: narrow ? 24 : 22,
                child: _Hamesh(
                  key: _sideKey,
                  title: 'الهامش',
                  entries: entries.sublist(0, split),
                  onTap: widget.onWordTap,
                  compact: narrow,
                ),
              ),
            ],
          ),
          if (split < entries.length) ...[
            const SizedBox(height: 8),
            _Hamesh(
              title: 'تتمة الهامش',
              entries: entries.sublist(split),
              onTap: widget.onWordTap,
              compact: false,
              columns: narrow ? 2 : 3,
            ),
          ],
        ],
      ),
    );
  }

  /// After layout: keep beside the page only the entries that end above the
  /// bottom of the page frame.
  void _measureSplit(String signature) {
    if (!mounted || signature != _splitFor) return;
    final frame = _frameKey.currentContext?.findRenderObject() as RenderBox?;
    final side = _sideKey.currentState as _HameshState?;
    if (frame == null || side == null) return;
    final fit = side.entriesFitting(frame.size.height);
    if (fit != _split) setState(() => _split = fit);
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
      blocks.add(Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        style: textStyle,
      ));
      spans = [];
    }

    for (final ayah in ayahs) {
      if (ayah.number == 1) {
        flush();
        blocks.add(SurahBanner(
            title: 'سورة ${widget.quran.surah(ayah.surah).nameAr}'));
        if (ayah.surah != 1 && ayah.surah != 9) {
          blocks.add(Text(
            widget.quran.basmala,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: textStyle,
          ));
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

      if (replace && m.all.isNotEmpty) {
        final v = m.all.first;
        if (v.word == w && v.text.isNotEmpty) {
          final shownHere = s.kinds.contains(v.kind);
          out.add(TextSpan(
            text: '${v.text} ',
            recognizer: tap,
            style: TextStyle(
              fontFamily: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
              color: shownHere ? qiraaOf(v.riwayaId).color : null,
              backgroundColor:
                  shownHere ? qiraaOf(v.riwayaId).color.withAlpha(24) : null,
            ),
          ));
        }
        continue;
      }

      if (m.shown.isEmpty) {
        out
          ..add(TextSpan(text: ayah.words[w], recognizer: tap, style: underline))
          ..add(const TextSpan(text: ' '));
        continue;
      }

      final color = m.color!;
      out.add(TextSpan(
        text: ayah.words[w],
        recognizer: tap,
        style: (underline ?? const TextStyle())
            .copyWith(color: color, backgroundColor: color.withAlpha(28)),
      ));
      if (m.colors.length > 1 && s.mode != DisplayMode.inline) {
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: _Dots(colors: m.colors),
        ));
      }
      if (s.mode == DisplayMode.inline) {
        // Each distinct reading once, at the first word it covers.
        final seen = <String>{};
        for (final v in m.shown.where((v) => v.word == w)) {
          if (!seen.add(v.text)) continue;
          out.add(TextSpan(
            text: ' ${v.text.isEmpty ? '—' : v.text}',
            recognizer: tap,
            style: TextStyle(
              fontFamily: riwayaById(v.riwayaId).fontFamily ?? 'Hafs',
              fontSize: s.fontSize * 0.62,
              color: qiraaOf(v.riwayaId).color,
            ),
          ));
        }
      }
      out.add(const TextSpan(text: ' '));
    }
    out.add(TextSpan(text: '${arabicDigits(ayah.number)} '));
  }

  static const _mutashabihStyle = TextStyle(
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
  }) _mark(Ayah ayah, int w) {
    final s = widget.settings;
    final all = widget.variants
        .at(s.selected.where(widget.variants.isLoaded), ayah.surah, ayah.number, w)
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
      mutashabih: s.showMutashabihat &&
          widget.mutashabihat.isShared(ayah.surah, ayah.number, w),
    );
  }

  /// One word of a printed line.
  Widget _word(Ayah ayah, int w, double fontSize) {
    final m = _mark(ayah, w);
    Widget word = Text(
      ayah.words[w],
      textDirection: TextDirection.rtl,
      style: (m.mutashabih ? _mutashabihStyle : const TextStyle()).copyWith(
        fontFamily: 'Hafs',
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
        final end =
            starting.map((v) => v.word + v.count).reduce((a, b) => a > b ? a : b);
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
    final r = TapGestureRecognizer()..onTap = () => widget.onWordTap(ayah, word);
    _recognizers.add(r);
    return r;
  }
}

/// Identifies a reading independently of each riwaya's text encoding: the
/// generated description when there is one, otherwise the bare letters.
String _readingKey(Variant v) =>
    v.description.isNotEmpty ? v.description : _bare(v.text);

/// Letters only (no vowels, waqf signs or tatweel).
String _bare(String text) => String.fromCharCodes(text.runes.where((c) =>
    (c >= 0x0621 && c <= 0x064A) || c == 0x0671 || c == 0x0020));

String arabicDigits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();

/// Ornamented mushaf border around the Hafs text, with the page number.
class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.page, required this.child});

  final int page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OrnamentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: MushafColors.gold),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                arabicDigits(page),
                style: const TextStyle(fontSize: 12, color: MushafColors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The margin: for each marked word, who reads it how, written in that
/// riwaya's own font, with a short description ("بالتاء", "بضم الهاء", ...).
/// Readings that are the same for several riwayat / qiraat share one line.
class _Hamesh extends StatefulWidget {
  const _Hamesh({
    super.key,
    required this.title,
    required this.entries,
    required this.onTap,
    required this.compact,
    this.columns = 1,
  });

  final String title;
  final List<HameshEntry> entries;
  final WordTap onTap;
  final bool compact;
  final int columns;

  @override
  State<_Hamesh> createState() => _HameshState();
}

class _HameshState extends State<_Hamesh> {
  final _keys = <GlobalKey>[];

  /// Number of leading entries whose bottom is within [height] of the top.
  int entriesFitting(double height) {
    final me = context.findRenderObject() as RenderBox?;
    if (me == null) return widget.entries.length;
    var fit = 0;
    for (final key in _keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) break;
      final bottom = box.localToGlobal(Offset(0, box.size.height), ancestor: me).dy;
      // Leave room for the box's bottom padding.
      if (bottom + 8 > height) break;
      fit++;
    }
    return fit;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final label = TextStyle(
      fontSize: compact ? 8.5 : 10,
      height: 1.4,
      color: MushafColors.ink,
    );
    final quran = compact ? 11.0 : 13.0;
    while (_keys.length < widget.entries.length) {
      _keys.add(GlobalKey());
    }
    final items = [
      for (final (i, e) in widget.entries.indexed)
        KeyedSubtree(key: _keys[i], child: _entry(e, label, quran)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        color: MushafColors.goldLight.withAlpha(70),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MushafColors.gold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: label.copyWith(
              fontSize: label.fontSize! + 2,
              fontWeight: FontWeight.bold,
              color: MushafColors.green,
            ),
          ),
          const Divider(height: 10, color: MushafColors.gold),
          if (widget.entries.isEmpty)
            Text(
              'لا خلاف في هذه الصفحة بين حفص والقراءات المختارة.',
              style: label.copyWith(color: MushafColors.frame),
            ),
          if (widget.columns == 1)
            ...items
          else
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 8,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: (c.maxWidth - 8 * (widget.columns - 1)) /
                          widget.columns,
                      child: item,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _entry(HameshEntry e, TextStyle label, double quran) {
    return InkWell(
      onTap: () => widget.onTap(e.ayah, e.word),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.hafs,
              style: TextStyle(
                fontFamily: 'Hafs',
                fontSize: quran,
                color: e.color,
                backgroundColor: e.color.withAlpha(28),
              ),
            ),
            for (final g in _readings(e.readings))
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Text.rich(TextSpan(children: [
                  for (var i = 0; i < g.names.length; i++)
                    TextSpan(
                      text: i == 0 ? g.names[i].$1 : ' و${g.names[i].$1}',
                      style: label.copyWith(
                        color: g.names[i].$2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(text: ': ', style: label),
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
                      text: '  ${g.description}',
                      style: label.copyWith(color: MushafColors.frame),
                    ),
                ])),
              ),
          ],
        ),
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
          : out.add(_Reading([(name, color)], font, v.text, v.description, key));
    }

    for (final q in qiraat) {
      final mine = [
        for (final r in q.riwayat)
          for (final v in vs)
            if (v.riwayaId == r.id) (r, v),
      ];
      if (mine.isEmpty) continue;
      final sameReading = mine.length == q.riwayat.length &&
          mine.every((m) => _readingKey(m.$2) == _readingKey(mine.first.$2));
      if (sameReading) {
        final (r, v) = mine.first;
        add(q.shortAr, q.color, r.fontFamily ?? 'Hafs', v);
      } else {
        for (final (r, v) in mine) {
          add('${r.nameAr} عن ${_genitive(q.shortAr)}', q.color,
              r.fontFamily ?? 'Hafs', v);
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
