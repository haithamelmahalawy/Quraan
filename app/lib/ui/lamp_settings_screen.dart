import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'reading_colors.dart';
import 'theme.dart';
import 'usul_guide_sheet.dart';

/// Held, the lamp opens its settings in two parts (the user, 2026-11-27): on
/// the right the usul of the riwayat chosen for the hamesh, each with its
/// switch (the words of an asl switched on glow under the lamp, those of one
/// switched off do not; all on at first); on the left the ways it tells a
/// word under its light, as «الكشاف» did: all, the ten, the shown riwaya, the
/// hamesh.
class LampSettingsScreen extends StatelessWidget {
  const LampSettingsScreen({
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
      builder: (_) => LampSettingsScreen(
        settings: settings,
        variants: variants,
        quran: quran,
      ),
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
        appBar: AppBar(title: const Text('ضبط المصباح')),
        // The usul on the right, the ways on the left.
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _title('الأصول'),
                  _hint('تفعيل أو عدم تفعيل تظليل الأصول في المصحف.'),
                  Expanded(child: _usul(riwayat)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _modes()),
          ],
        ),
      ),
    );
  }

  /// A part's title.
  static Widget _title(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: MushafColors.green,
      ),
    ),
  );

  /// A part's short description, under its title (the user, 2026-11-27).
  static Widget _hint(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.6,
        color: MushafColors.ink.withValues(alpha: .75),
      ),
    ),
  );

  /// The left: the ways the lamp tells a word, the chosen one marked.
  Widget _modes() => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final now = settings.flashMode;
      return ListView(
        children: [
          _title('طريقة العرض'),
          _hint(
            'اسحب المصباح حتى يقع ضوؤه على كلمة، فتظهر فوقها لوحة '
            'باختلافات الروايات فيها. واختر هنا الروايات التي تُعرض في '
            'هذه اللوحة.',
          ),
          for (final mode in FlashMode.values)
            ListTile(
              key: ValueKey('flash-mode:${mode.name}'),
              selected: mode == now,
              selectedColor: MushafColors.green,
              leading: Icon(
                mode == now
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: mode == now ? MushafColors.gold : null,
              ),
              title: Text(
                mode.labelAr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(mode.hintAr),
              onTap: () => settings.flashMode = mode,
            ),
        ],
      );
    },
  );

  /// The right: the usul of the hamesh, each lit or not.
  Widget _usul(List<String> riwayat) {
    if (riwayat.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'لم يُختر راوٍ للهامش بعد؛ فاختر من الروايات ليظهر هنا '
          'أصول من اخترت.',
          style: TextStyle(height: 1.8),
        ),
      );
    }
    return FutureBuilder<void>(
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
        final labels = usul.keys.where((l) => l != 'أصول أخرى').toList()
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
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton.tonal(
                        key: const ValueKey('glow-usul-all'),
                        onPressed: allLit ? null : settings.lightAllUsul,
                        child: const Text('تفعيل الكل'),
                      ),
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
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final label = labels[i];
                      final lit = !unlit.contains(label);
                      return SwitchListTile(
                        key: ValueKey('glow-usul:$label'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        value: lit,
                        onChanged: (on) => settings.setUsulLit(label, on),
                        secondary: CircleAvatar(
                          radius: 6,
                          backgroundColor: ReadingColors.forLabel(label),
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
    );
  }
}
