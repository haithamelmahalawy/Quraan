import 'package:flutter/material.dart';

import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';

/// Choose which qiraat / riwayat to overlay on the Hafs text, and how.
class QiraatSheet extends StatelessWidget {
  const QiraatSheet({
    super.key,
    required this.settings,
    required this.variants,
    this.controller,
  });

  final ReaderSettings settings;
  final VariantRepository variants;
  final ScrollController? controller;

  static Future<void> show(
    BuildContext context,
    ReaderSettings settings,
    VariantRepository variants,
  ) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (context, controller) => QiraatSheet(
            settings: settings,
            variants: variants,
            controller: controller,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        return ListView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('القراءات', style: theme.textTheme.titleLarge),
                  ),
                  if (settings.selected.isNotEmpty)
                    TextButton(
                      onPressed: () => settings.setSelected({}),
                      child: const Text('حفص فقط'),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'النص الأساسي رواية حفص عن عاصم. اختر قراءة أو أكثر لإظهار '
                'مواضع الخلاف في الصفحة.',
              ),
            ),
            for (final q in qiraat) _QiraaTile(q, settings, variants),
            const Divider(height: 32),
            _section(context, 'طريقة العرض'),
            RadioGroup<DisplayMode>(
              groupValue: settings.mode,
              onChanged: (v) => settings.mode = v!,
              child: Column(
                children: [
                  for (final m in DisplayMode.values)
                    RadioListTile<DisplayMode>(
                      value: m,
                      title: Text(m.labelAr),
                      subtitle: m == DisplayMode.replace
                          ? const Text('متاح عند اختيار رواية واحدة')
                          : null,
                      enabled: m != DisplayMode.replace ||
                          settings.selected.length == 1,
                    ),
                ],
              ),
            ),
            const Divider(height: 32),
            _section(context, 'أنواع الخلاف المعروضة'),
            for (final k in VariantKind.values)
              CheckboxListTile(
                value: settings.kinds.contains(k),
                title: Text(k.labelAr),
                onChanged: (v) => settings.toggleKind(k, v!),
              ),
            const Divider(height: 32),
            SwitchListTile(
              value: settings.showMutashabihat,
              title: const Text('إظهار المتشابهات اللفظية'),
              subtitle: const Text(
                  'خط منقط تحت الكلمات المتكررة في آيات متشابهة، اضغط عليها للتنقل بين مواضعها'),
              onChanged: (v) => settings.showMutashabihat = v,
            ),
            SwitchListTile(
              value: settings.blinkToOpen,
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text('التحكم بالعينين'),
              subtitle: const Text(
                  'رمشتان متتاليتان: الصفحة التالية. تتم المعالجة على الجهاز '
                  'دون تسجيل أو إرسال أي صورة.'),
              onChanged: (v) => settings.blinkToOpen = v,
            ),
            const Divider(height: 32),
            SwitchListTile(
              value: settings.qcfFont,
              secondary: const Icon(Icons.brush_outlined),
              title: const Text('خط مصحف المدينة'),
              subtitle: const Text(
                  'رسم الصفحات بخط المصحف المطبوع (خطوط مجمع الملك فهد QCF)، '
                  'ويُنزَّل خط كل صفحة مرة واحدة عند فتحها لأول مرة.'),
              onChanged: (v) => settings.qcfFont = v,
            ),
            SwitchListTile(
              value: settings.printedLines,
              secondary: const Icon(Icons.format_line_spacing),
              title: const Text('أسطر المصحف المطبوع'),
              subtitle: const Text(
                  'الصفحة بأسطرها الخمسة عشر كما في مصحف المدينة. عند الإيقاف '
                  'تُرتَّب كلمات الصفحة نفسها في أسطر أكبر تملأ الشاشة.'),
              onChanged: (v) => settings.printedLines = v,
            ),
            const Divider(height: 32),
            _section(context, 'المظهر'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('داكن'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('فاتح'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('حسب الجهاز'),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.themeMode = s.single,
              ),
            ),
            const Divider(height: 32),
            _section(context, 'حجم الخط (العرض المتدفق)'),
            Slider(
              value: settings.fontSize,
              min: 16,
              max: 40,
              divisions: 12,
              label: settings.fontSize.round().toString(),
              onChanged: (v) => settings.fontSize = v,
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'المصادر: نصوص وخطوط مجمع الملك فهد لطباعة المصحف الشريف للروايات الثماني، '
                'والروايات الاثنتا عشرة الأخرى من بيانات الموسوعة القرآنية quranpedia.net '
                '(نسخة 2026-10-17)، محفوظة في التطبيق، '
                'وبيانات المتشابهات من مشروع Quran Mutashabihat Data (Waqar144) '
                'عن عمل القارئ إدريس العاصم رحمه الله. أوصاف الخلاف مولّدة آليًا '
                'وتحتاج إلى مراجعة متخصص.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _QiraaTile extends StatelessWidget {
  const _QiraaTile(this.qiraa, this.settings, this.variants);

  final Qiraa qiraa;
  final ReaderSettings settings;
  final VariantRepository variants;

  @override
  Widget build(BuildContext context) {
    final usable = [
      for (final r in qiraa.riwayat)
        if (r.id != hafsId && variants.isAvailable(r.id)) r.id,
    ];
    final chosen = usable.where(settings.selected.contains).length;
    final bool? state = chosen == 0
        ? false
        : chosen == usable.length
            ? true
            : null;

    void set(Iterable<String> ids, bool on) {
      final next = {...settings.selected};
      on ? next.addAll(ids) : next.removeAll(ids);
      settings.setSelected(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          tristate: true,
          value: state,
          enabled: usable.isNotEmpty,
          activeColor: qiraa.color,
          secondary: CircleAvatar(radius: 7, backgroundColor: qiraa.color),
          title: Text(
            qiraa.nameAr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: usable.isEmpty && qiraa.id != 'asim'
              ? const Text('لا تتوفر بيانات هذه القراءة بعد')
              : null,
          onChanged: (_) => set(usable, state != true),
        ),
        for (final r in qiraa.riwayat)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 40),
            child: CheckboxListTile(
              dense: true,
              activeColor: qiraa.color,
              value: r.id == hafsId || settings.selected.contains(r.id),
              enabled: r.id != hafsId && variants.isAvailable(r.id),
              title: Text('رواية ${r.nameAr}'),
              subtitle: r.id == hafsId
                  ? const Text('النص الأساسي')
                  : variants.isAvailable(r.id)
                      ? null
                      : const Text('غير متوفرة'),
              onChanged: (v) => set([r.id], v!),
            ),
          ),
      ],
    );
  }
}
