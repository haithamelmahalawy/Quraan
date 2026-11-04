import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../data/reading_comparison.dart';
import '../data/usul_text.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'kharouf_section.dart';
import 'reference_sheet.dart';
import 'reading_colors.dart';
import 'quran_word_text.dart';

/// How each riwaya reads one Hafs word: the selected riwayat first, then
/// every other riwaya that has data.
class VariantSheet extends StatelessWidget {
  const VariantSheet({
    super.key,
    required this.ayah,
    required this.word,
    required this.surahName,
    required this.settings,
    required this.variants,
    required this.surahNames,
    this.onMutashabihat,
    this.onAyah,
  });

  final Ayah ayah;
  final int word;
  final String surahName;
  final ReaderSettings settings;
  final VariantRepository variants;

  /// Opens the similar ayahs of this word, when it belongs to a mutashabih.
  final VoidCallback? onMutashabihat;

  /// Opens the ayah: its tafsir and recitation.
  final VoidCallback? onAyah;

  /// The surah names of the mushaf: with them, a reading opens its place
  /// in the Shatibiyya or the Durrah.
  final List<String> surahNames;

  static Future<void> show(BuildContext context, VariantSheet sheet) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, controller) =>
              PrimaryScrollController(controller: controller, child: sheet),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (r.id != hafsId &&
              variants.isAvailable(r.id) &&
              !settings.selected.contains(r.id))
            r.id,
    ];
    return FutureBuilder(
      future: variants.ensureLoaded([...settings.selected, ...others]),
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        final ready =
            snapshot.connectionState == ConnectionState.done ||
            [...settings.selected, ...others].every(variants.isLoaded);
        final comparedIds = {
          ...settings.selected,
          if (settings.compareHafs) hafsId,
        }..remove(settings.displayed ?? hafsId);
        final selectedReadings = ready
            ? wordEvidence(
                repository: variants,
                ayah: ayah,
                word: word,
                displayed: settings.displayed,
                selected: settings.selected,
                compared: comparedIds,
              )
            : <Variant>[];
        // The Hafs span covered by any reading of this word.
        var from = word, to = word + 1;
        if (ready) {
          for (final v in variants.at(
            [...settings.selected, ...others],
            ayah.surah,
            ayah.number,
            word,
          )) {
            if (v.word < from) from = v.word;
            if (v.word + v.count > to) to = v.word + v.count;
          }
        }
        return ListView(
          primary: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'سورة $surahName - الآية ${ayah.number}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (onAyah != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: FilledButton.tonalIcon(
                      onPressed: onAyah,
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('التفسير والاستماع'),
                    ),
                  ),
                if (onMutashabihat != null)
                  FilledButton.tonalIcon(
                    onPressed: onMutashabihat,
                    icon: const Text('🔁'),
                    label: const Text('المتشابهات'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ReadingTile(
              color: qiraaOf(settings.displayed ?? hafsId).color,
              title: settings.displayed == null
                  ? 'حفص عن عاصم (النص الأساسي)'
                  : '${riwayaById(settings.displayed!).nameAr} عن '
                        '${qiraaOf(settings.displayed!).shortAr} (الرواية المعروضة)',
              text: readingText(variants, settings.displayed, ayah, from, to),
              font: 'Hafs',
            ),
            KharoufSection(
              surah: ayah.surah,
              ayah: ayah.number,
              word: word,
              // The book's note told of the riwayat on the page only.
              riwayat: {
                ...settings.selected,
                if (settings.displayed != null) settings.displayed!,
                if (settings.displayed == null || settings.compareHafs) 'hafs',
              },
              showVerses: false,
            ),
            if (!ready)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (selectedReadings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ReadingReferences(
                    key: const ValueKey('word-reading-evidence'),
                    readings: selectedReadings,
                    word: ayah.words.sublist(from, to).join(' '),
                    surah: ayah.surah,
                    surahNames: surahNames,
                    showBook: false,
                  ),
                ),
              if (comparedIds.isNotEmpty) ...[
                _header(context, 'القراءات المختارة'),
                for (final id in _ordered(comparedIds))
                  _tile(context, id, from, to),
              ],
              if (others.isNotEmpty) ...[
                _header(context, 'بقية الروايات المتوفرة'),
                for (final id in others) _tile(context, id, from, to),
              ],
            ],
          ],
        );
      },
    );
  }

  Iterable<String> _ordered(Set<String> ids) => [
    for (final q in qiraat)
      for (final r in q.riwayat)
        if (ids.contains(r.id)) r.id,
  ];

  Widget _header(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  /// The reading of Hafs words [from, to) in riwaya [id].
  Widget _tile(BuildContext context, String id, int from, int to) {
    final riwaya = riwayaById(id);
    final qiraa = qiraaOf(id);
    final compared = compareReadings(
      repository: variants,
      ayah: ayah,
      word: word,
      displayed: settings.displayed,
      selected: [id],
    );
    final list = compared;
    final title = '${qiraa.nameAr} - رواية ${riwaya.nameAr}';
    if (list.isEmpty) {
      // A rule of the displayed riwaya it does not read: its own reading, not
      // «as the displayed» (وَٱلصَّٰبِـِٔينَ of Hafs under Abu Ja'far's).
      final unread = displayedRulesNotReadBy(
        repository: variants,
        ayah: ayah,
        word: word,
        displayed: settings.displayed,
        id: id,
      ).where((v) => !isRoutineMadd(v));
      if (unread.isNotEmpty) {
        return _ReadingTile(
          color: qiraa.color,
          title: title,
          text: readingText(variants, id, ayah, from, to),
          font: riwaya.fontFamily ?? 'Hafs',
          description:
              'بخلاف الرواية المعروضة: '
              '${unread.map((v) => v.shownDescription).join('؛ ')}',
        );
      }
      return _ReadingTile(
        color: qiraa.color,
        title: title,
        text: settings.displayed == null ? 'كقراءة حفص' : 'كالرواية المعروضة',
        dimmed: true,
      );
    }
    final v = list.where((v) => v.inHamesh).firstOrNull ?? list.first;
    return _ReadingTile(
      color: ReadingColors.of(v),
      title: title,
      text: readingText(variants, id, ayah, from, to).isEmpty
          ? '(بحذف الكلمة)'
          : readingText(variants, id, ayah, from, to),
      font: riwaya.fontFamily ?? 'Hafs',
      kind: v.kind,
      description: v.shownDescription,
      // Beside the farsh, readings the certified source does not state.
      uncertified: !v.certified && !v.isUsul && v.rule != 'comparison',
      onTap: () => ReferenceSheet.show(
        context,
        readings: [v],
        word: ayah.words.sublist(from, to).join(' '),
        surah: ayah.surah,
        surahNames: surahNames,
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.color,
    required this.title,
    required this.text,
    this.font,
    this.kind,
    this.description = '',
    this.dimmed = false,
    this.uncertified = false,
    this.onTap,
  });

  final Color color;
  final String title;
  final String text;
  final String? font;
  final VariantKind? kind;
  final String description;
  final bool dimmed;
  final bool uncertified;

  /// Opens where the reading is stated (Shatibiyya, Durrah).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(onTap: onTap, child: _box(theme));
  }

  Widget _box(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(dimmed ? 10 : 22),
        borderRadius: BorderRadius.circular(8),
        border: BorderDirectional(start: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
              if (kind != null)
                Text(kind!.labelAr, style: theme.textTheme.labelSmall),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Tooltip(
                    message: 'الدليل من الشاطبية أو الدرة',
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          QuranWordText(
            text,
            style:
                (font == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      )
                    : TextStyle(
                        fontFamily: font,
                        fontSize: 26,
                        color: color,
                      )) ??
                const TextStyle(),
          ),
          if (description.isNotEmpty)
            Text(description, style: theme.textTheme.bodyMedium),
          if (uncertified)
            Text(
              'غير مذكور في التسهيل لقراءات التنزيل',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
        ],
      ),
    );
  }
}
