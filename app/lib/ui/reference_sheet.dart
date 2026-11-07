import 'package:flutter/material.dart';

import '../data/reading_comparison.dart';
import '../data/kharouf.dart';
import '../data/manzumat.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'kharouf_section.dart';
import 'poem_verse.dart';
import 'theme.dart';
import 'quran_word_text.dart';

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
  Widget build(BuildContext context) => ListView(
    controller: PrimaryScrollController.of(context),
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
    children: [
      QuranWordText(
        word,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: 26,
          color: MushafColors.ink,
        ),
      ),
      const SizedBox(height: 4),
      ReadingReferences(
        readings: readings,
        word: word,
        surah: surah,
        surahNames: surahNames,
      ),
    ],
  );
}

/// Shared evidence for the word-details sheet and the margin's reference
/// sheet. It joins the parent's scroll view rather than creating another one.
class ReadingReferences extends StatefulWidget {
  const ReadingReferences({
    super.key,
    required this.readings,
    required this.word,
    required this.surah,
    required this.surahNames,
    this.showBook = true,
  });

  final List<Variant> readings;
  final String word;
  final int surah;
  final List<String> surahNames;
  final bool showBook;

  @override
  State<ReadingReferences> createState() => _ReadingReferencesState();
}

class _ReadingReferencesState extends State<ReadingReferences> {
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الدليل من الشاطبية والدرة',
              textAlign: TextAlign.center,
              style: TextStyle(color: MushafColors.frame),
            ),
            // The certified source first: the verses it cites for the word.
            if (widget.showBook && widget.readings.isNotEmpty)
              KharoufSection(
                surah: widget.readings.first.surah,
                ayah: widget.readings.first.ayah,
                word: widget.readings.first.word,
                riwayat: {for (final v in widget.readings) v.riwayaId},
                showVerses: false,
              ),
            for (final v in citedReadings(widget.readings)) ...[
              const SizedBox(height: 14),
              _ReadingReference(
                // Its own state for each reading: the chapter shown or not.
                key: ValueKey(
                  'reading-reference:${v.riwayaId}:${v.surah}:${v.ayah}:'
                  '${v.word}:${v.rule}:${v.text}',
                ),
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
    super.key,
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

  /// No bayt names the word: the chapter's are shown only when asked for.
  bool _chapter = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.reading;
    final r = widget.reference;
    final q = qiraaOf(v.riwayaId);
    final named = [
      for (final b in r.verses)
        if (r.mention.contains(b.n)) b,
    ];
    final preview = named.isEmpty ? r.verses.take(5).toList() : named;
    final canExpand = preview.length < r.verses.length;
    final shown = named.isEmpty && !_chapter
        ? const <Bayt>[]
        : _whole
        ? r.verses
        : preview;
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
            QuranWordText(
              v.text,
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
          // No witness: told so, the chapter's first bayts behind a button.
          if (named.isEmpty && !_chapter) ...[
            Text(
              'لم تذكر ${r.poem.nameAr} هذه الكلمة، فليس لها شاهد فيها.',
              key: const ValueKey('reference-no-witness'),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('reference-show-chapter'),
                onPressed: () => setState(() => _chapter = true),
                icon: const Icon(Icons.unfold_more),
                label: const Text('اعرض أول 5 أبيات من الباب'),
              ),
            ),
          ],
          if (named.isEmpty && _chapter)
            Text(
              _whole || !canExpand
                  ? 'أبيات الباب كاملة'
                  : 'أول 5 أبيات من الباب',
            ),
          if (_whole && canExpand)
            TextButton.icon(
              onPressed: () => setState(() => _whole = false),
              icon: const Icon(Icons.unfold_less),
              label: const Text('إخفاء المزيد'),
            ),
          for (final b in shown)
            PoemVerse(
              key: ValueKey('${r.poem.name}-${b.n}'),
              bayt: b,
              named: r.mention.contains(b.n),
              explanation: widget.manzumat.explanation(r.poem, b.n),
              bookExplanation: r.bookExplanation[b.n] ?? '',
            ),
          if (canExpand && (named.isNotEmpty || _chapter))
            TextButton.icon(
              onPressed: () => setState(() => _whole = !_whole),
              icon: Icon(_whole ? Icons.unfold_less : Icons.unfold_more),
              label: Text(
                _whole
                    ? 'إخفاء المزيد'
                    : '${named.isEmpty ? 'إظهار المزيد' : 'عرض المزيد'} '
                          '(${r.verses.length - preview.length} بيتًا من الباب)',
              ),
            ),
        ],
      ),
    );
  }
}
