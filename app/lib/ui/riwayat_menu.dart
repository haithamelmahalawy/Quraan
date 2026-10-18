import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// "الروايات ▾": a drop-down list of every available riwaya, grouped by
/// qiraa, with a check box each; it stays open while several are ticked.
class RiwayatMenu extends StatelessWidget {
  const RiwayatMenu({super.key, required this.settings, required this.variants});

  final ReaderSettings settings;
  final VariantRepository variants;

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
              Size(320, MediaQuery.sizeOf(context).height * 0.7)),
        ),
        menuChildren: [
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
        builder: (context, controller, _) => TextButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(Icons.arrow_drop_down, color: MushafColors.green),
          label: Text(
            settings.selected.isEmpty
                ? 'الروايات'
                : 'الروايات (${settings.selected.length})',
            style: TextStyle(color: MushafColors.green),
          ),
        ),
      ),
    );
  }
}
