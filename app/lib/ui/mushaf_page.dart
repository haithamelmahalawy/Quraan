import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
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

/// One numbered hamesh entry: a Hafs word (or words) and how the selected
/// riwayat read it.
class HameshEntry {
  HameshEntry(this.number, this.ayah, this.word, this.hafs, this.readings);

  final int number;
  final Ayah ayah;
  final int word;
  final String hafs;
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
    final textStyle = TextStyle(
      fontFamily: 'Hafs',
      fontSize: s.fontSize,
      height: 2.0,
      color: MushafColors.ink,
    );
    final blocks = <Widget>[];
    final hamesh = <HameshEntry>[];
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
        blocks.add(_SurahHeader(surah: widget.quran.surah(ayah.surah)));
        if (ayah.surah != 1 && ayah.surah != 9) {
          blocks.add(Text(
            widget.quran.basmala,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: textStyle,
          ));
        }
      }
      _addAyah(ayah, spans, hamesh);
    }
    flush();

    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
    if (s.mode != DisplayMode.hamesh) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: page,
      );
    }

    final framed = _PageFrame(page: widget.page, child: page);
    final margin = _Hamesh(entries: hamesh, onTap: widget.onWordTap);
    return LayoutBuilder(builder: (context, constraints) {
      // Tablets / landscape: hamesh beside the page; phones: below it.
      if (constraints.maxWidth >= 840) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: framed,
              ),
            ),
            SizedBox(
              width: constraints.maxWidth * 0.36,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: margin,
              ),
            ),
          ],
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [framed, const SizedBox(height: 12), margin],
        ),
      );
    });
  }

  void _addAyah(Ayah ayah, List<InlineSpan> out, List<HameshEntry> hamesh) {
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

      if (s.mode == DisplayMode.hamesh) {
        // Clean Hafs word; a numbered marker after the first word of each
        // difference refers to the hamesh.
        out.add(TextSpan(text: ayah.words[w], recognizer: tap));
        final starting = shown.where((v) => v.word == w).toList();
        if (starting.isNotEmpty) {
          final end = starting
              .map((v) => v.word + v.count)
              .reduce((a, b) => a > b ? a : b);
          final entry = HameshEntry(
            hamesh.length + 1,
            ayah,
            w,
            ayah.words.sublist(w, end).join(' '),
            starting,
          );
          hamesh.add(entry);
          out.add(WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: GestureDetector(
              onTap: () => widget.onWordTap(ayah, w),
              child: _Marker(number: entry.number, color: color),
            ),
          ));
        }
        out.add(const TextSpan(text: ' '));
        continue;
      }

      out.add(TextSpan(
        text: ayah.words[w],
        recognizer: tap,
        style: TextStyle(color: color, backgroundColor: color.withAlpha(28)),
      ));
      if (groups.length > 1 && s.mode == DisplayMode.highlight) {
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

/// Mushaf-style border around the Hafs text, with the page number.
class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.page, required this.child});

  final int page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: MushafColors.frame, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(110),
          border: Border.all(color: MushafColors.frame.withAlpha(120)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            Text(
              arabicDigits(page),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: MushafColors.frame),
            ),
          ],
        ),
      ),
    );
  }
}

/// The margin: one line per marked word, each reading prefixed by the
/// qiraa (or riwaya) that reads it, written in that riwaya's own font.
class _Hamesh extends StatelessWidget {
  const _Hamesh({required this.entries, required this.onTap});

  final List<HameshEntry> entries;
  final WordTap onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: MushafColors.frame.withAlpha(14),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          top: BorderSide(color: MushafColors.frame.withAlpha(140), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الهامش - أوجه القراءات',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: MushafColors.frame),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'لا خلاف في هذه الصفحة بين حفص والقراءات المختارة.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final e in entries)
            InkWell(
              onTap: () => onTap(e.ayah, e.word),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(children: _line(e)),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _line(HameshEntry e) {
    const label = TextStyle(fontSize: 13, color: MushafColors.ink);
    final spans = <InlineSpan>[
      TextSpan(
        text: '(${arabicDigits(e.number)}) ',
        style: label.copyWith(fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: e.hafs,
        style: const TextStyle(
            fontFamily: 'Hafs', fontSize: 19, color: MushafColors.ink),
      ),
      TextSpan(text: ' :  ', style: label),
    ];
    var first = true;
    for (final (who, color, font, text) in _readings(e.readings)) {
      if (!first) spans.add(TextSpan(text: '  ،  ', style: label));
      first = false;
      spans
        ..add(TextSpan(
          text: '$who: ',
          style: label.copyWith(color: color, fontWeight: FontWeight.w600),
        ))
        ..add(TextSpan(
          text: text.isEmpty ? '(بحذفها)' : text,
          style: TextStyle(fontFamily: font, fontSize: 19, color: color),
        ));
    }
    return spans;
  }

  /// Groups the readings by qiraa: "نافع: X" when both of its riwayat are
  /// listed with the same text, otherwise "ورش عن نافع: X" per riwaya.
  static List<(String, Color, String, String)> _readings(List<Variant> vs) {
    final out = <(String, Color, String, String)>[];
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
        out.add((q.shortAr, q.color, r.fontFamily ?? 'Hafs', v.text));
      } else {
        for (final (r, v) in mine) {
          out.add((
            '${r.nameAr} عن ${q.shortAr}',
            q.color,
            r.fontFamily ?? 'Hafs',
            v.text,
          ));
        }
      }
    }
    return out;
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        arabicDigits(number),
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
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

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: MushafColors.frame, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: MushafColors.frame.withAlpha(20),
      ),
      child: Text(
        'سورة ${surah.nameAr}',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontFamily: 'Hafs',
          fontSize: 22,
          color: MushafColors.ink,
        ),
      ),
    );
  }
}
