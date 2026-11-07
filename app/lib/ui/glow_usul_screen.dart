import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'reading_colors.dart';
import 'theme.dart';
import 'usul_guide_sheet.dart';

/// Held, the lamp opens the usul of the riwayat chosen for the hamesh, each
/// with its switch: the words of an asl switched on glow under the lamp,
/// those of one switched off do not. All are on at first.
class GlowUsulScreen extends StatelessWidget {
  const GlowUsulScreen({
    super.key,
    required this.settings,
    required this.variants,
    required this.quran,
  });

  final ReaderSettings settings;
  final VariantRepository variants;
  final QuranRepository quran;

  static Future<void> open(
    BuildContext context, {
    required ReaderSettings settings,
    required VariantRepository variants,
    required QuranRepository quran,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          GlowUsulScreen(settings: settings, variants: variants, quran: quran),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final riwayat = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (settings.selected.contains(r.id)) r.id,
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: MushafColors.paper,
        appBar: AppBar(title: const Text('أصول التوهج')),
        body: riwayat.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لم يُختر راوٍ للهامش بعد؛ فاختر من الروايات ليظهر هنا '
                  'أصول من اخترت.',
                  style: TextStyle(height: 1.8),
                ),
              )
            : FutureBuilder<void>(
                future: variants.ensureLoaded(riwayat),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Each asl with the riwayat that have it, in their order.
                  final usul = <String, List<String>>{};
                  final count = <String, int>{};
                  for (final id in riwayat) {
                    for (final MapEntry(key: label, value: rows)
                        in usulOfRiwaya(variants, quran, id).entries) {
                      (usul[label] ??= []).add(id);
                      count[label] = (count[label] ?? 0) + rows.length;
                    }
                  }
                  final labels =
                      usul.keys.where((l) => l != 'أصول أخرى').toList()
                        ..sort((a, b) => count[b]!.compareTo(count[a]!));
                  if (usul.containsKey('أصول أخرى')) labels.add('أصول أخرى');
                  return ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) {
                      final unlit = settings.unlitUsul;
                      final allLit = labels.every((l) => !unlit.contains(l));
                      final noneLit = labels.every(unlit.contains);
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Row(
                              children: [
                                FilledButton.tonal(
                                  key: const ValueKey('glow-usul-all'),
                                  onPressed: allLit
                                      ? null
                                      : settings.lightAllUsul,
                                  child: const Text('تفعيل الكل'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  key: const ValueKey('glow-usul-none'),
                                  onPressed: noneLit
                                      ? null
                                      : () => settings.putOutUsul(labels),
                                  child: const Text('إلغاء الكل'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: labels.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final label = labels[i];
                                final lit = !unlit.contains(label);
                                return SwitchListTile(
                                  key: ValueKey('glow-usul:$label'),
                                  value: lit,
                                  onChanged: (on) =>
                                      settings.setUsulLit(label, on),
                                  secondary: CircleAvatar(
                                    radius: 6,
                                    backgroundColor: ReadingColors.forLabel(
                                      label,
                                    ),
                                  ),
                                  title: Text(label),
                                  subtitle: Text(
                                    usul[label]!
                                        .map((id) => riwayaById(id).nameAr)
                                        .join('، '),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
