import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/reading_comparison.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'quran_word_text.dart';
import 'reading_colors.dart';
import 'theme.dart';

/// The place of a word on the page, carried by its widget for «الكشاف» to
/// find under its beam.
class WordTag {
  const WordTag(this.ayah, this.word);

  final Ayah ayah;
  final int word;

  @override
  bool operator ==(Object other) =>
      other is WordTag &&
      other.ayah.surah == ayah.surah &&
      other.ayah.number == ayah.number &&
      other.word == word;

  @override
  int get hashCode => Object.hash(ayah.surah, ayah.number, word);
}

/// One reading of a word told in the flashlight's panel.
typedef FlashReading = ({
  String title,
  String text,
  String description,
  Color color,
});

/// Every difference of the word [word] on the page (the user, 2026-11-26):
/// the shown riwaya's own rows, usul or farsh, then each chosen riwaya that
/// reads it otherwise; those reading it as the shown riwaya left out.
List<FlashReading> wordDifferences(
  VariantRepository variants,
  ReaderSettings settings,
  Ayah ayah,
  int word,
) {
  final out = <FlashReading>[];
  final displayed = settings.displayed;
  String nameOf(String id) =>
      '${riwayaById(id).nameAr} عن ${qiraaOf(id).shortAr}';
  if (displayed != null && variants.isLoaded(displayed)) {
    final own = variants
        .at([displayed], ayah.surah, ayah.number, word)
        .where((v) => v.word == word && v.riwayaId == displayed)
        .toList();
    if (own.isNotEmpty) {
      out.add((
        title: '${nameOf(displayed)} (المعروضة)',
        text: readingText(variants, displayed, ayah, word, word + 1),
        description: {
          for (final v in own)
            if (v.shownDescription.isNotEmpty) v.shownDescription,
        }.join('؛ '),
        color: ReadingColors.of(own.first),
      ));
    }
  }
  final compared = {
    ...settings.selected.where(variants.isLoaded),
    if (settings.compareHafs || displayed == null) hafsId,
  }..remove(displayed ?? hafsId);
  for (final q in qiraat) {
    for (final r in q.riwayat) {
      if (!compared.contains(r.id)) continue;
      final rows = compareReadings(
        repository: variants,
        ayah: ayah,
        word: word,
        displayed: displayed,
        selected: [r.id],
      );
      if (rows.isEmpty) continue;
      final first = rows.where((v) => v.inHamesh).firstOrNull ?? rows.first;
      final from = rows.map((v) => v.word).reduce((a, b) => a < b ? a : b);
      final to = rows
          .map((v) => v.word + v.count)
          .reduce((a, b) => a > b ? a : b);
      final text = readingText(variants, r.id, ayah, from, to);
      out.add((
        title: r.id == hafsId ? 'حفص عن عاصم' : nameOf(r.id),
        text: text.isEmpty ? '(بحذف الكلمة)' : text,
        description: {
          for (final v in rows)
            if (v.shownDescription.isNotEmpty) v.shownDescription,
        }.join('؛ '),
        color: ReadingColors.of(first),
      ));
    }
  }
  return out;
}

/// «الكشاف»: a flashlight laid on the mushaf's frame, dragged over the page;
/// over a word read otherwise it shows at once, above the word, a panel of
/// every riwaya's difference in it (the user, 2026-11-26).
class Flashlight extends StatefulWidget {
  const Flashlight({super.key, required this.settings, required this.variants});

  final ReaderSettings settings;
  final VariantRepository variants;

  /// The flashlight's size.
  static const size = 44.0;

  @override
  State<Flashlight> createState() => _FlashlightState();
}

class _FlashlightState extends State<Flashlight> {
  /// Its place over the area, in fractions of its width and height.
  late Offset _at = widget.settings.flashlightAt ?? const Offset(.04, .9);

  /// The word under the beam, its readings and its box in the area.
  WordTag? _tag;
  List<FlashReading> _readings = const [];
  Rect? _wordRect;

  /// The beam's tip, above the flashlight's head.
  Offset _tip(Size area) => Offset(
    _at.dx * area.width + Flashlight.size / 2,
    _at.dy * area.height - 6,
  );

  void _probe(Size area) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final global = box.localToGlobal(_tip(area));
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      global,
      View.of(context).viewId,
    );
    WordTag? tag;
    Rect? rect;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is WordTag) {
        tag = target.metaData as WordTag;
        final topLeft = box.globalToLocal(target.localToGlobal(Offset.zero));
        rect = topLeft & target.size;
        break;
      }
    }
    if (tag == _tag) {
      if (rect != null && rect != _wordRect) setState(() => _wordRect = rect);
      return;
    }
    setState(() {
      _tag = tag;
      _wordRect = rect;
      _readings = tag == null
          ? const []
          : wordDifferences(
              widget.variants,
              widget.settings,
              tag.ayah,
              tag.word,
            );
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final area = constraints.biggest;
      final left = (_at.dx * area.width).clamp(
        0.0,
        area.width - Flashlight.size,
      );
      final top = (_at.dy * area.height).clamp(
        0.0,
        area.height - Flashlight.size,
      );
      final rect = _wordRect;
      final showPanel = _readings.isNotEmpty && rect != null;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (showPanel) _panel(area, rect),
          Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              key: const ValueKey('flashlight'),
              onPanUpdate: (d) {
                setState(() {
                  _at = Offset(
                    ((_at.dx * area.width + d.delta.dx) / area.width).clamp(
                      0.0,
                      (area.width - Flashlight.size) / area.width,
                    ),
                    ((_at.dy * area.height + d.delta.dy) / area.height).clamp(
                      0.0,
                      (area.height - Flashlight.size) / area.height,
                    ),
                  );
                });
                _probe(area);
              },
              onPanEnd: (_) => widget.settings.flashlightAt = _at,
              // A tap puts the panel away.
              onTap: () => setState(() {
                _tag = null;
                _readings = const [];
                _wordRect = null;
              }),
              child: Tooltip(
                triggerMode: TooltipTriggerMode.manual,
                message: 'الكشاف: اسحبه على كلمة لترى اختلاف القراء فيها',
                child: Container(
                  width: Flashlight.size,
                  height: Flashlight.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MushafColors.gold.withAlpha(_tag == null ? 60 : 120),
                    border: Border.all(color: MushafColors.gold, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Icon(
                    _tag == null
                        ? Icons.flashlight_off_rounded
                        : Icons.flashlight_on_rounded,
                    color: MushafColors.green,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  /// The panel right above the word (under it, where the page's top leaves
  /// no room), across most of the page.
  Widget _panel(Size area, Rect word) {
    final width = area.width * .92;
    final left = ((word.center.dx - width / 2).clamp(
      4.0,
      area.width - width - 4,
    )).toDouble();
    final maxHeight = area.height * .45;
    final above = word.top > area.height * .35;
    return Positioned(
      key: const ValueKey('flashlight-panel'),
      left: left,
      width: width,
      top: above ? null : word.bottom + 6,
      bottom: above ? area.height - word.top + 6 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: MushafColors.page.withAlpha(250),
          elevation: 6,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            children: [
              for (final r in _readings)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: r.color.withAlpha(22),
                    borderRadius: BorderRadius.circular(8),
                    border: BorderDirectional(
                      start: BorderSide(color: r.color, width: 3),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        r.title,
                        style: TextStyle(
                          color: r.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      QuranWordText(
                        r.text,
                        style: TextStyle(
                          fontFamily: 'Hafs',
                          fontSize: 22,
                          color: r.color,
                        ),
                      ),
                      if (r.description.isNotEmpty)
                        Text(
                          r.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
