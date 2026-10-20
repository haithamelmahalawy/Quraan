import 'package:flutter/material.dart';

import '../data/kharouf.dart';
import '../models/qiraat_catalog.dart';
import 'theme.dart';

/// Who reads a word how, as stated by the certified source, «التسهيل
/// لقراءات التنزيل»: each reading with its readers, and the verses of the
/// Shatibiyya and the Durrah it cites. Nothing when the book has no note.
class KharoufSection extends StatelessWidget {
  const KharoufSection({
    super.key,
    required this.surah,
    required this.ayah,
    required this.word,
  });

  final int surah, ayah, word;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Kharouf>(
      future: Kharouf.load(),
      builder: (context, snapshot) {
        final book = snapshot.data;
        if (book == null) return const SizedBox.shrink();
        final entries = book.at(surah, ayah, word);
        if (entries.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MushafColors.goldLight.withAlpha(70),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MushafColors.gold.withAlpha(170)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 18, color: MushafColors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'التوثيق: التسهيل لقراءات التنزيل',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: MushafColors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              for (final e in entries) ...[
                if (e.section != 'farsh')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(e.sectionAr, style: theme.textTheme.labelMedium),
                  ),
                for (final r in e.readings) _reading(theme, r),
                for (final v in e.verses)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '[$v]',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Hafs',
                        fontSize: 17,
                        height: 1.7,
                        color: MushafColors.frame,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 6),
              Text(
                book.source,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reading(ThemeData theme, KharoufReading r) {
    final who = readersAr(r.riwayat, r.disputed);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          children: [
            if (r.text.isNotEmpty)
              TextSpan(
                text: '${r.text}  ',
                style: TextStyle(
                  fontFamily: 'Hafs',
                  fontSize: 21,
                  color: r.readsAsHafs ? MushafColors.ink : MushafColors.green,
                ),
              ),
            if (r.how.isNotEmpty)
              TextSpan(text: '${r.how} ', style: theme.textTheme.bodyMedium),
            if (r.taqlil) TextSpan(text: 'بالتقليل ', style: theme.textTheme.bodyMedium),
            TextSpan(
              text: who,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (r.stopOnly)
              TextSpan(text: ' (وقفاً)', style: theme.textTheme.bodySmall),
          ],
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

/// Readers by name: a qiraa when both its riwayat are there («نافع»),
/// else each riwaya («ورش»); those with a dispute marked «بخلف».
String readersAr(List<String> riwayat, List<String> disputed) {
  // Names that are ambiguous alone, as the book writes them.
  String name(String id) => switch (id) {
    'khalaf_hamzah' => 'خلف عن حمزة',
    'duri_abuamr' => 'دوري أبي عمرو',
    'duri_kisai' => 'دوري الكسائي',
    _ => riwayaById(id).nameAr,
  };
  final parts = <String>[];
  for (final q in qiraat) {
    final ids = [for (final r in q.riwayat) r.id];
    final sure = ids.where(riwayat.contains).toList();
    final unsure = ids.where(disputed.contains).toList();
    if (sure.length == ids.length) {
      parts.add(q.shortAr);
    } else {
      parts.addAll(sure.map(name));
    }
    parts.addAll(unsure.map((id) => '${name(id)} بخلف'));
  }
  return parts.join('، ');
}
