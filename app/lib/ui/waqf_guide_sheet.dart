import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/waqf_guide.dart';
import 'quran_word_text.dart';
import 'theme.dart';

/// What stopping and starting are, their kinds with examples from the mushaf,
/// and its signs.
class WaqfGuideSheet extends StatelessWidget {
  const WaqfGuideSheet({super.key, required this.quran, this.controller});

  final QuranRepository quran;
  final ScrollController? controller;

  static Future<void> show(BuildContext context, QuranRepository quran) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .85,
          maxChildSize: .95,
          builder: (context, controller) =>
              WaqfGuideSheet(quran: quran, controller: controller),
        ),
      );

  /// The quoted words, as the mushaf writes them.
  String _words(WaqfQuote q) {
    final words = quran.ayah(q.surah, q.ayah).words;
    final from = q.from < 0 ? words.length + q.from : q.from;
    return words.sublist(from, q.to ?? words.length).join(' ');
  }

  String _place(WaqfQuote q) => 'سورة ${quran.surah(q.surah).nameAr} ${q.ayah}';

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: MushafColors.green,
      ),
    ),
  );

  Widget _quote(WaqfQuote q, Color color) => QuranWordText(
    '﴿${_words(q)}﴾',
    style: TextStyle(fontFamily: 'Hafs', fontSize: 20, color: color),
  );

  Widget _example(WaqfExample e) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: MushafColors.goldLight.withAlpha(50),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الوقف على:',
          style: TextStyle(fontSize: 12, color: MushafColors.frame),
        ),
        _quote(e.stop, MushafColors.ink),
        if (e.next != null) ...[
          Text(
            'وما بعده:',
            style: TextStyle(fontSize: 12, color: MushafColors.frame),
          ),
          _quote(e.next!, MushafColors.ink),
        ],
        Text(
          '${e.note} (${_place(e.stop)})',
          style: TextStyle(fontSize: 13, height: 1.6, color: MushafColors.ink),
        ),
      ],
    ),
  );

  Widget _entry(WaqfEntry e) => Container(
    key: ValueKey('waqf-guide-${e.title}'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: MushafColors.gold.withAlpha(160)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          e.sign == null ? e.title : '${e.title} (${e.sign})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: MushafColors.frame,
          ),
        ),
        const SizedBox(height: 4),
        Text(e.meaning, style: const TextStyle(height: 1.6)),
        Text(
          'حكمه: ${e.ruling}',
          style: const TextStyle(height: 1.6, fontWeight: FontWeight.w600),
        ),
        for (final x in e.examples) _example(x),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      key: const ValueKey('waqf-guide'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        const Text(
          'الوقف والابتداء',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        _heading('تعريفات'),
        for (final (name, meaning) in waqfDefinitions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: meaning),
                ],
              ),
              style: const TextStyle(height: 1.6),
            ),
          ),
        _heading('أنواع الوقف الاختياري'),
        for (final e in waqfDegrees) _entry(e),
        _heading('أنواع أخرى للوقف'),
        for (final e in waqfOthers) _entry(e),
        _heading('علامات الوقف في مصحف المدينة'),
        for (final e in waqfSigns) _entry(e),
        const SizedBox(height: 8),
        Text(
          'تقسيم الوقف إلى تام وكاف وحسن وقبيح هو المشهور عند أهل هذا الفن، '
          'كالداني في المكتفى. وقد يختلف العلماء في نوع الموضع الواحد بحسب '
          'الإعراب والتفسير والقراءة.',
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: MushafColors.frame,
          ),
        ),
      ],
    ),
  );
}
