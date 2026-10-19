import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'raised.dart';
import 'theme.dart';

/// "الروايات ▾": a drop-down list of every available riwaya, grouped by
/// qiraa, with a check box each; it stays open while several are ticked.
class RiwayatMenu extends StatelessWidget {
  const RiwayatMenu({
    super.key,
    required this.settings,
    required this.variants,
  });

  final ReaderSettings settings;
  final VariantRepository variants;

  /// [ids] in the order of the catalogue.
  static List<String> _ordered(Set<String> ids) => [
    for (final q in qiraat)
      for (final r in q.riwayat)
        if (ids.contains(r.id)) r.id,
  ];

  void _toggle(String id, bool on) {
    final next = {...settings.selected};
    on ? next.add(id) : next.remove(id);
    settings.setSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(MushafColors.page),
          maximumSize: WidgetStatePropertyAll(
            Size(320, MediaQuery.sizeOf(context).height * 0.7),
          ),
        ),
        menuChildren: [
          // Which riwaya the page shows; the others are compared with it.
          if (settings.selected.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Text(
                'المصحف المعروض برواية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MushafColors.green,
                ),
              ),
            ),
            for (final id in [hafsId, ..._ordered(settings.selected)])
              RadioMenuButton<String>(
                value: id,
                groupValue: settings.displayed ?? hafsId,
                closeOnActivate: false,
                onChanged: (v) =>
                    settings.displayed = v == hafsId ? null : v,
                child: Text(
                  id == hafsId
                      ? 'حفص (النص الأساسي)'
                      : 'رواية ${riwayaById(id).nameAr} عن ${qiraaOf(id).shortAr}',
                ),
              ),
            const Divider(height: 12),
          ],
          if (settings.selected.isNotEmpty)
            MenuItemButton(
              leadingIcon: const Icon(Icons.clear_all),
              onPressed: () => settings.setSelected({}),
              child: const Text('إلغاء الكل (حفص فقط)'),
            ),
          for (final q in qiraat) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  CircleAvatar(radius: 5, backgroundColor: q.color),
                  const SizedBox(width: 8),
                  Text(
                    q.nameAr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: q.color,
                    ),
                  ),
                ],
              ),
            ),
            for (final r in q.riwayat)
              if (r.id != hafsId && variants.isAvailable(r.id))
                CheckboxMenuButton(
                  value: settings.selected.contains(r.id),
                  closeOnActivate: false,
                  onChanged: (v) => _toggle(r.id, v ?? false),
                  child: Text('رواية ${r.nameAr}'),
                ),
          ],
        ],
        builder: (context, controller, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Raised(
            radius: 19,
            depth: 0.6,
            color: settings.selected.isEmpty ? null : MushafColors.goldLight,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.selected.isEmpty
                      ? 'الروايات'
                      : settings.displayed == null
                      ? 'الروايات (${settings.selected.length})'
                      : 'برواية ${riwayaById(settings.displayed!).nameAr} '
                            '(${settings.selected.length})',
                  style: TextStyle(
                    color: MushafColors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: MushafColors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
