import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
/// applied according to [ReaderSettings.mode].
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.page,
    required this.quran,
    required this.variants,
    required this.settings,
    required this.onWordTap,
  });

  final int page;
  final QuranRepository quran;
  final VariantRepository variants;
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
    // On phones the page shares the width with the hamesh beside it.
    final narrow = MediaQuery.sizeOf(context).width < 600;
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

    // Highlight and hamesh keep the printed lines; inline and replace change
    // word widths, so they flow the text instead.
    final lines = widget.quran.lines(widget.page);
    final printed = lines != null &&
        (s.mode == DisplayMode.hamesh || s.mode == DisplayMode.highlight);
    for (final ayah in printed ? const <Ayah>[] : ayahs) {
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

    final page = printed
        ? MushafLines(
            lines: lines,
            centered: widget.quran.isCentered(widget.page),
            quran: widget.quran,
            wordBuilder: _word,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: blocks,
          );
    final framed = _PageFrame(page: widget.page, child: page);
    if (s.mode != DisplayMode.hamesh) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
        child: framed,
      );
    }

    // The hamesh sits outside the page, on its left (the end side in RTL).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: narrow ? 76 : 78, child: framed),
          const SizedBox(width: 4),
          Expanded(
            flex: narrow ? 24 : 22,
            child: _Hamesh(
              entries: _hameshEntries(ayahs),
              onTap: widget.onWordTap,
              compact: narrow,
            ),
          ),
        ],
      ),
    );
  }

  void _addAyah(Ayah ayah, List<InlineSpan> out) {
    final s = widget.settings;
    final selected = s.selected.where(widget.variants.isLoaded).toList();
    final replace = s.mode == DisplayMode.replace && selected.length == 1;

    for (var w = 0; w < ayah.words.length; w++) {
      final all = widget.variants
          .at(selected, ayah.surah, ayah.number, w)
          .toList(growable: false);
      final shown = all.where((v) => s.kinds.contains(v.kind)).toList();
      final tap = all.isEmpty ? null : _recognizer(ayah, w);

      if (replace && all.isNotEmpty) {
        final v = all.first;
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

      if (shown.isEmpty) {
        out.add(TextSpan(text: '${ayah.words[w]} ', recognizer: tap));
        continue;
      }

      final groups = {for (final v in shown) qiraaOf(v.riwayaId)}.toList();
      final color = groups.length == 1 ? groups.single.color : MushafColors.multi;

      out.add(TextSpan(
        text: ayah.words[w],
        recognizer: tap,
        style: TextStyle(color: color, backgroundColor: color.withAlpha(28)),
      ));
      if (groups.length > 1 && s.mode != DisplayMode.inline) {
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: _Dots(colors: [for (final q in groups) q.color]),
        ));
      }
      if (s.mode == DisplayMode.inline) {
        // Each distinct reading once, at the first word it covers.
        final seen = <String>{};
        for (final v in shown.where((v) => v.word == w)) {
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

  /// The selected riwayat's readings of a Hafs word, and its colour: the
  /// qiraa's colour, or [MushafColors.multi] when several qiraat differ.
  ({List<Variant> all, List<Variant> shown, List<Color> colors}) _mark(
      Ayah ayah, int w) {
    final s = widget.settings;
    final all = widget.variants
        .at(s.selected.where(widget.variants.isLoaded), ayah.surah, ayah.number, w)
        .toList(growable: false);
    final shown = all.where((v) => s.kinds.contains(v.kind)).toList();
    return (
      all: all,
      shown: shown,
      colors: [for (final q in {for (final v in shown) qiraaOf(v.riwayaId)}) q.color],
    );
  }

  /// One word of a printed line.
  Widget _word(Ayah ayah, int w, double fontSize) {
    final m = _mark(ayah, w);
    final color = m.colors.isEmpty
        ? null
        : m.colors.length == 1
            ? m.colors.single
            : MushafColors.multi;
    Widget word = Text(
      ayah.words[w],
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: 'Hafs',
        fontSize: fontSize,
        height: 1.0,
        color: color ?? MushafColors.ink,
        backgroundColor: color?.withAlpha(28),
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
    if (m.all.isEmpty) return word;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onWordTap(ayah, w),
      child: word,
    );
  }

  /// Hamesh entries in page order: one per word where a selected reading
  /// starts.
  List<HameshEntry> _hameshEntries(List<Ayah> ayahs) {
    final out = <HameshEntry>[];
    for (final ayah in ayahs) {
      for (var w = 0; w < ayah.words.length; w++) {
        final m = _mark(ayah, w);
        final starting = m.shown.where((v) => v.word == w).toList();
        if (starting.isEmpty) continue;
        final end =
            starting.map((v) => v.word + v.count).reduce((a, b) => a > b ? a : b);
        out.add(HameshEntry(
          ayah,
          w,
          ayah.words.sublist(w, end).join(' '),
          m.colors.length == 1 ? m.colors.single : MushafColors.multi,
          starting,
        ));
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
          Text(
            arabicDigits(page),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: MushafColors.green),
          ),
        ],
      ),
    );
  }
}

/// The margin beside the page: for each marked word, who reads it how,
/// written in that riwaya's own font, with a short description
/// ("بالتاء", "بضم الهاء", ...).
class _Hamesh extends StatelessWidget {
  const _Hamesh({
    required this.entries,
    required this.onTap,
    required this.compact,
  });

  final List<HameshEntry> entries;
  final WordTap onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
      fontSize: compact ? 8.5 : 10,
      height: 1.4,
      color: MushafColors.ink,
    );
    final quran = compact ? 11.0 : 13.0;
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
            'الهامش',
            textAlign: TextAlign.center,
            style: label.copyWith(
              fontSize: label.fontSize! + 2,
              fontWeight: FontWeight.bold,
              color: MushafColors.green,
            ),
          ),
          const Divider(height: 10, color: MushafColors.gold),
          if (entries.isEmpty)
            Text(
              'لا خلاف في هذه الصفحة بين حفص والقراءات المختارة.',
              style: label.copyWith(color: MushafColors.frame),
            ),
          for (final e in entries)
            InkWell(
              onTap: () => onTap(e.ayah, e.word),
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
            ),
        ],
      ),
    );
  }

  /// Who reads what: a qiraa by its name ("نافع") when both its riwayat
  /// read alike, otherwise each riwaya ("ورش عن نافع"); qiraat with the same
  /// reading share one entry ("نافع وابن كثير: مَلِكِ").
  static List<_Reading> _readings(List<Variant> vs) {
    final out = <_Reading>[];
    void add(String name, Color color, String font, Variant v) {
      final same = out
          .where((g) => g.text == v.text && g.description == v.description)
          .firstOrNull;
      same != null
          ? same.names.add((name, color))
          : out.add(_Reading([(name, color)], font, v.text, v.description));
    }

    for (final q in qiraat) {
      final mine = [
        for (final r in q.riwayat)
          for (final v in vs)
            if (v.riwayaId == r.id) (r, v),
      ];
      if (mine.isEmpty) continue;
      final sameText = mine.length == q.riwayat.length &&
          mine.every((m) => m.$2.text == mine.first.$2.text);
      if (sameText) {
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
  _Reading(this.names, this.font, this.text, this.description);

  final List<(String, Color)> names;
  final String font;
  final String text;

  /// e.g. "بالتاء", "بضم الهاء"; empty when not generated.
  final String description;
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
