import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';

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
    this.onMutashabihat,
  });

  final Ayah ayah;
  final int word;
  final String surahName;
  final ReaderSettings settings;
  final VariantRepository variants;

  /// Opens the similar ayahs of this word, when it belongs to a mutashabih.
  final VoidCallback? onMutashabihat;

  static Future<void> show(BuildContext context, VariantSheet sheet) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, controller) => PrimaryScrollController(
            controller: controller,
            child: sheet,
          ),
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
        final ready = snapshot.connectionState == ConnectionState.done;
        // The Hafs span covered by any reading of this word.
        var from = word, to = word + 1;
        if (ready) {
          for (final v in variants.at(
              [...settings.selected, ...others], ayah.surah, ayah.number, word)) {
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
              color: qiraaOf(hafsId).color,
              title: 'حفص عن عاصم (النص الأساسي)',
              text: ayah.words.sublist(from, to).join(' '),
              font: 'Hafs',
            ),
            if (!ready)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (settings.selected.isNotEmpty) ...[
                _header(context, 'القراءات المختارة'),
                for (final id in _ordered(settings.selected))
                  _tile(id, from, to),
              ],
              if (others.isNotEmpty) ...[
                _header(context, 'بقية الروايات المتوفرة'),
                for (final id in others) _tile(id, from, to),
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
  Widget _tile(String id, int from, int to) {
    final riwaya = riwayaById(id);
    final qiraa = qiraaOf(id);
    final list = variants.at([id], ayah.surah, ayah.number, word).toList();
    final title = '${qiraa.nameAr} - رواية ${riwaya.nameAr}';
    if (list.isEmpty) {
      return _ReadingTile(
        color: qiraa.color,
        title: title,
        text: 'كقراءة حفص',
        dimmed: true,
      );
    }
    final v = list.first;
    final before = ayah.words.sublist(from, v.word).join(' ');
    final after = ayah.words.sublist(v.word + v.count, to).join(' ');
    return _ReadingTile(
      color: qiraa.color,
      title: title,
      text: v.text.isEmpty && v.description.isNotEmpty
          ? ayah.words.sublist(from, to).join(' ')
          : [before, v.text.isEmpty ? '(بحذف الكلمة)' : v.text, after]
              .where((t) => t.isNotEmpty)
              .join(' '),
      font: riwaya.fontFamily ?? 'Hafs',
      kind: v.kind,
      description: v.description,
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
  });

  final Color color;
  final String title;
  final String text;
  final String? font;
  final VariantKind? kind;
  final String description;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textDirection: TextDirection.rtl,
            style: font == null
                ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)
                : TextStyle(fontFamily: font, fontSize: 26, color: color),
          ),
          if (description.isNotEmpty)
            Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
