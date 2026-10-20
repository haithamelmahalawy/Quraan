import 'package:flutter/material.dart';

import '../data/manzumat.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'kharouf_section.dart';
import 'theme.dart';

/// Where the readings of a word are stated: for each, the verses of the
/// Shatibiyya (the seven) or the Durrah (the three) that name the word, in
/// the chapter of its surah or of its rule, and the whole chapter on demand.
class ReferenceSheet extends StatelessWidget {
  const ReferenceSheet({
    super.key,
    required this.readings,
    required this.word,
    required this.surah,
    required this.surahNames,
  });

  final List<Variant> readings;

  /// The word as shown on the page.
  final String word;
  final int surah;
  final List<String> surahNames;

  static Future<void> show(
    BuildContext context, {
    required List<Variant> readings,
    required String word,
    required int surah,
    required List<String> surahNames,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MushafColors.paper,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => PrimaryScrollController(
        controller: controller,
        child: ReferenceSheet(
          readings: readings,
          word: word,
          surah: surah,
          surahNames: surahNames,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Manzumat>(
      future: Manzumat.load(),
      builder: (context, snapshot) {
        final manzumat = snapshot.data;
        if (manzumat == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          controller: PrimaryScrollController.of(context),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            Text(
              word,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Hafs',
                fontSize: 26,
                color: MushafColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الدليل من الشاطبية والدرة',
              textAlign: TextAlign.center,
              style: TextStyle(color: MushafColors.frame),
            ),
            // The certified source first: the verses it cites for the word.
            if (readings.isNotEmpty)
              KharoufSection(
                surah: readings.first.surah,
                ayah: readings.first.ayah,
                word: readings.first.word,
              ),
            for (final v in readings) ...[
              const SizedBox(height: 14),
              _ReadingReference(
                reading: v,
                reference: manzumat.referenceOf(v, word, surah, surahNames),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'المصدر: ${Manzumat.source}. الأبيات المعروضة أولًا هي التي '
              'تذكر الكلمة؛ وقد يكون الدليل في بيت آخر من الباب.',
              style: TextStyle(color: MushafColors.frame, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _ReadingReference extends StatefulWidget {
  const _ReadingReference({required this.reading, required this.reference});

  final Variant reading;
  final Reference reference;

  @override
  State<_ReadingReference> createState() => _ReadingReferenceState();
}

class _ReadingReferenceState extends State<_ReadingReference> {
  bool _whole = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.reading;
    final r = widget.reference;
    final q = qiraaOf(v.riwayaId);
    final named = [
      for (final b in r.verses)
        if (r.mention.contains(b.n)) b,
    ];
    final shown = _whole || named.isEmpty ? r.verses : named;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MushafColors.page,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: q.color.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'رواية ${riwayaById(v.riwayaId).nameAr} عن ${q.shortAr}',
            style: TextStyle(color: q.color, fontWeight: FontWeight.bold),
          ),
          if (v.text.isNotEmpty)
            Text(
              v.text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Hafs',
                fontSize: 20,
                color: MushafColors.ink,
              ),
            ),
          if (v.description.isNotEmpty)
            Text(v.description, style: TextStyle(color: MushafColors.frame)),
          const Divider(height: 18),
          Text(
            '${r.poem.nameAr} • ${r.chapter}',
            style: TextStyle(
              color: MushafColors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          for (final b in shown)
            _Verse(bayt: b, named: r.mention.contains(b.n)),
          if (named.isNotEmpty && named.length < r.verses.length)
            TextButton.icon(
              onPressed: () => setState(() => _whole = !_whole),
              icon: Icon(_whole ? Icons.unfold_less : Icons.unfold_more),
              label: Text(
                _whole
                    ? 'الأبيات التي تذكر الكلمة فقط'
                    : 'عرض الباب كاملًا (${r.verses.length} بيتًا)',
              ),
            ),
        ],
      ),
    );
  }
}

/// A verse: its number and its two halves, one under the other; marked when
/// it names the word.
class _Verse extends StatelessWidget {
  const _Verse({required this.bayt, required this.named});

  final Bayt bayt;
  final bool named;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 16,
      height: 1.8,
      color: MushafColors.ink,
      fontWeight: named ? FontWeight.w600 : FontWeight.normal,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: named ? MushafColors.goldLight.withAlpha(90) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              '${bayt.n}',
              style: TextStyle(color: MushafColors.frame, fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(bayt.sadr, textDirection: TextDirection.rtl, style: style),
                Text(
                  bayt.ajz,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.end,
                  style: style,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
