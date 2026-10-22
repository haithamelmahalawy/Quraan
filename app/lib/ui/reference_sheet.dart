import 'package:flutter/material.dart';

import '../data/kharouf.dart';
import '../data/manzumat.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'kharouf_section.dart';
import 'theme.dart';

/// Where the readings of a word are stated: for each, the verses of the
/// Shatibiyya (the seven) or the Durrah (the three) that name the word, in
/// the chapter of its surah or of its rule, and the whole chapter on demand.
class ReferenceSheet extends StatefulWidget {
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
  State<ReferenceSheet> createState() => _ReferenceSheetState();
}

class _ReferenceSheetState extends State<ReferenceSheet> {
  final Future<(Manzumat, Kharouf)> _sources = _loadSources();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Manzumat, Kharouf)>(
      future: _sources,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل مصادر الأدلة.'));
        }
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (manzumat, book) = data;
        return ListView(
          controller: PrimaryScrollController.of(context),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            Text(
              widget.word,
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
            if (widget.readings.isNotEmpty)
              KharoufSection(
                surah: widget.readings.first.surah,
                ayah: widget.readings.first.ayah,
                word: widget.readings.first.word,
                riwayat: {for (final v in widget.readings) v.riwayaId},
                showVerses: false,
              ),
            for (final v in widget.readings) ...[
              const SizedBox(height: 14),
              _ReadingReference(
                reading: v,
                reference: manzumat.referenceOf(
                  v,
                  widget.word,
                  widget.surah,
                  widget.surahNames,
                  entries: book.at(v.surah, v.ayah, v.word),
                ),
                manzumat: manzumat,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'أولوية اختيار الدليل لما اقتبسه كتاب التسهيل لقراءات التنزيل '
              'في الموضع. نص المنظومتين: ${Manzumat.source}.',
              style: TextStyle(color: MushafColors.frame, fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  static Future<(Manzumat, Kharouf)> _loadSources() async {
    final poem = Manzumat.load();
    final book = Kharouf.load();
    return (await poem, await book);
  }
}

class _ReadingReference extends StatefulWidget {
  const _ReadingReference({
    required this.reading,
    required this.reference,
    required this.manzumat,
  });

  final Variant reading;
  final Reference reference;
  final Manzumat manzumat;

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
    final shown = _whole ? r.verses : named;
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
          if (v.shownDescription.isNotEmpty)
            Text(
              v.shownDescription,
              style: TextStyle(color: MushafColors.frame),
            ),
          const Divider(height: 18),
          Text(
            '${r.poem.nameAr} • ${r.chapter}',
            style: TextStyle(
              color: MushafColors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (r.fromBook)
            Text(
              'الدليل المقتبس في التسهيل لقراءات التنزيل',
              style: TextStyle(color: MushafColors.green, fontSize: 12),
            ),
          if (named.isEmpty && !_whole)
            const Text(
              'لم يُحدد بيت مطابق لهذا الموضع. يمكنك عرض بقية الباب للمراجعة.',
            ),
          if (_whole && named.length < r.verses.length)
            TextButton.icon(
              onPressed: () => setState(() => _whole = false),
              icon: const Icon(Icons.unfold_less),
              label: const Text('إخفاء المزيد'),
            ),
          for (final b in shown)
            _Verse(
              key: ValueKey('${r.poem.name}-${b.n}'),
              bayt: b,
              named: r.mention.contains(b.n),
              explanation: widget.manzumat.explanation(r.poem, b.n),
              bookExplanation: r.bookExplanation[b.n] ?? '',
            ),
          if (named.length < r.verses.length)
            TextButton.icon(
              onPressed: () => setState(() => _whole = !_whole),
              icon: Icon(_whole ? Icons.unfold_less : Icons.unfold_more),
              label: Text(
                _whole
                    ? 'إخفاء المزيد'
                    : 'عرض المزيد (${r.verses.length - named.length} بيتًا من الباب)',
              ),
            ),
        ],
      ),
    );
  }
}

/// A verse: its number and its two halves, one under the other; marked when
/// it names the word.
class _Verse extends StatefulWidget {
  const _Verse({
    super.key,
    required this.bayt,
    required this.named,
    required this.explanation,
    required this.bookExplanation,
  });

  final Bayt bayt;
  final bool named;
  final BaytExplanation? explanation;
  final String bookExplanation;

  @override
  State<_Verse> createState() => _VerseState();
}

class _VerseState extends State<_Verse> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bayt = widget.bayt;
    final named = widget.named;
    final explanation = widget.explanation;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
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
                      Text(
                        bayt.sadr,
                        textDirection: TextDirection.rtl,
                        style: style,
                      ),
                      Text(
                        bayt.ajz,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.end,
                        style: style,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _expanded
                      ? 'إخفاء شرح البيت ${bayt.n}'
                      : 'شرح البيت ${bayt.n}',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.help_outline,
                    color: MushafColors.green,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(),
            if (widget.bookExplanation.isNotEmpty) ...[
              Text(
                'بيان القراءة في هذا الموضع — التسهيل لقراءات التنزيل',
                style: TextStyle(color: MushafColors.green, fontSize: 12),
              ),
              SelectableText(
                widget.bookExplanation,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
            ],
            if (explanation != null) ...[
              if (explanation.group.length > 1)
                Text(
                  'شرح مشترك للأبيات: ${explanation.group.join('، ')}',
                  style: TextStyle(color: MushafColors.frame, fontSize: 12),
                ),
              SelectableText(
                explanation.text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: MushafColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${explanation.source}\n${explanation.page}',
                style: TextStyle(color: MushafColors.frame, fontSize: 11),
              ),
            ] else if (widget.bookExplanation.isEmpty)
              const Text(
                'لا يتوفر شرح موثق لهذا البيت ضمن المصادر المحملة حاليًا.',
              ),
          ],
        ],
      ),
    );
  }
}
