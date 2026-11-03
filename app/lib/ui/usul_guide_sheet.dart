import 'package:flutter/material.dart';

import '../data/kharouf.dart';
import '../data/manzumat.dart';
import '../data/quran_repository.dart';
import '../data/reading_comparison.dart';
import '../data/usul_guide.dart';
import '../data/usul_text.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'poem_verse.dart';
import 'quran_word_text.dart';
import 'reading_colors.dart';
import 'theme.dart';
import 'usul_labels.dart';

/// The general rules of [riwaya], by the label of the page's key, in mushaf
/// order: what the guide lists and explains.
Map<String, List<Variant>> usulOfRiwaya(
  VariantRepository variants,
  QuranRepository quran,
  String riwaya,
) {
  final out = <String, List<Variant>>{};
  for (final v in variants.allOf(riwaya)) {
    if (v.inHamesh ||
        isRoutineMadd(v) ||
        v.rule == 'naql_source' ||
        v.rule == 'hamza_source') {
      continue;
    }
    final words = quran.ayah(v.surah, v.ayah).words;
    if (v.word < 0 ||
        v.word >= words.length ||
        !showYaqubMimExample(v, words[v.word])) {
      continue;
    }
    for (final (label, _) in usulKindsOf(v)) {
      (out[usulGuideLabel(label)] ??= []).add(v);
    }
  }
  return out;
}

/// A rule of the page's key explained: what it is, how each riwaya reads it
/// with examples of each of its kinds, and the verses of the poems on it.
class UsulGuideSheet extends StatefulWidget {
  const UsulGuideSheet({
    super.key,
    required this.label,
    required this.riwayat,
    required this.variants,
    required this.quran,
  });

  final String label;
  final List<String> riwayat;
  final VariantRepository variants;
  final QuranRepository quran;

  static Future<void> show(
    BuildContext context, {
    required String label,
    required List<String> riwayat,
    required VariantRepository variants,
    required QuranRepository quran,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MushafColors.paper,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => PrimaryScrollController(
        controller: controller,
        child: UsulGuideSheet(
          label: usulGuideLabel(label),
          riwayat: riwayat,
          variants: variants,
          quran: quran,
        ),
      ),
    ),
  );

  @override
  State<UsulGuideSheet> createState() => _UsulGuideSheetState();
}

class _UsulGuideSheetState extends State<UsulGuideSheet> {
  late final Future<(Manzumat, Kharouf)> _sources = _load();

  Future<(Manzumat, Kharouf)> _load() async {
    await widget.variants.ensureLoaded(widget.riwayat);
    return (await Manzumat.load(), await Kharouf.load());
  }

  @override
  Widget build(BuildContext context) {
    final color = ReadingColors.forLabel(widget.label);
    final list = ListView(
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Text(
          widget.label,
          key: const ValueKey('usul-guide-title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          usulDefinition(widget.label),
          key: const ValueKey('usul-guide-definition'),
          style: TextStyle(height: 1.8, color: MushafColors.ink),
        ),
        FutureBuilder<(Manzumat, Kharouf)>(
          future: _sources,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('تعذر تحميل مصادر الشرح.'),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final id in widget.riwayat)
                  _RiwayaSection(
                    key: ValueKey('usul-guide-riwaya:$id'),
                    label: widget.label,
                    riwaya: id,
                    color: color,
                    variants: widget.variants,
                    quran: widget.quran,
                    manzumat: data.$1,
                    book: data.$2,
                  ),
                const SizedBox(height: 12),
                Text(
                  'نص المنظومتين: ${Manzumat.source}.',
                  style: TextStyle(color: MushafColors.frame, fontSize: 11),
                ),
              ],
            );
          },
        ),
      ],
    );
    return Directionality(textDirection: TextDirection.rtl, child: list);
  }
}

class _RiwayaSection extends StatelessWidget {
  const _RiwayaSection({
    super.key,
    required this.label,
    required this.riwaya,
    required this.color,
    required this.variants,
    required this.quran,
    required this.manzumat,
    required this.book,
  });

  final String label, riwaya;
  final Color color;
  final VariantRepository variants;
  final QuranRepository quran;
  final Manzumat manzumat;
  final Kharouf book;

  /// How many kinds, and how many examples of each, are shown.
  static const _kinds = 10, _examples = 6, _rulings = 4;

  /// The reason of a numbered kind, when all its wordings have the same one.
  String? _sharedReason(List<MapEntry<String, List<Variant>>> group) {
    final reasons = {
      for (final e in group) usulKindReason(label, e.value.first, e.key),
    };
    return reasons.length == 1 ? reasons.single : null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = usulOfRiwaya(variants, quran, riwaya)[label] ?? const [];
    final kinds = <String, List<Variant>>{};
    for (final v in rows) {
      final ayah = quran.ayah(v.surah, v.ayah);
      final kind = usulKindOf(
        label,
        v,
        ayah.words[v.word],
        changedHamza: variants
            .at([riwaya], v.surah, v.ayah, v.word)
            .any((o) => o.rule == 'naql'),
        lastOfAyah: v.word == ayah.words.length - 1,
      );
      (kinds[kind] ??= []).add(v);
    }
    // How the riwaya reads it, when the kinds do not already say.
    final rulings = {
      for (final v in rows)
        if (v.description.isNotEmpty &&
            !kinds.containsKey(v.description) &&
            // سوءات and the excepted words: told with their kind. So the
            // faces of the two hamzas of a word.
            (!v.isLinHamz || v.rule == 'lin_hamz') &&
            !isWarshHamzaNaql(v) &&
            v.description != 'بترقيق الراء' &&
            label != 'الهمزتان من كلمة' &&
            label != 'الهمزتان من كلمتين' &&
            label != 'الإشمام' &&
            label != 'الهمز المفرد')
          v.description,
    }.take(_rulings).toList();
    // The numbered kinds, each with the wordings told under it.
    final grouped = <String, List<MapEntry<String, List<Variant>>>>{};
    for (final e in kinds.entries) {
      (grouped[usulKindGroup(e.key)] ??= []).add(e);
    }
    int total(List<MapEntry<String, List<Variant>>> g) =>
        g.fold(0, (n, e) => n + e.value.length);
    for (final g in grouped.values) {
      g.sort((a, b) => b.value.length.compareTo(a.value.length));
    }
    final ordered = grouped.entries.toList()
      ..sort((a, b) {
        final rank = usulKindRank(
          label,
          a.key,
        ).compareTo(usulKindRank(label, b.key));
        return rank != 0 ? rank : total(b.value).compareTo(total(a.value));
      });
    // Their kinds are few and each has its own faces: none is left out.
    final shown =
        const {
          'الهمزتان من كلمة',
          'الهمزتان من كلمتين',
          'الهمز المفرد',
          'الإشمام',
        }.contains(label)
        ? ordered
        : ordered.take(_kinds).toList();
    final poem = Poem.of(riwaya);
    final names = [for (final s in quran.surahs) s.nameAr];
    final named = <int>{};
    for (final group in shown) {
      for (final kind in group.value) {
        final v = kind.value.first;
        named.addAll(
          manzumat
              .referenceOf(
                v,
                quran.ayah(v.surah, v.ayah).words[v.word],
                v.surah,
                names,
                entries: book.at(v.surah, v.ayah, v.word),
              )
              .mention,
        );
      }
    }
    final verses = [
      for (final b in manzumat.verses(poem))
        if (named.contains(b.n) && isUsulChapter(label, b)) b,
    ];
    final chapter = verses.isEmpty
        ? usulChapterVerses(manzumat, poem, label)
        : const <Bayt>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28),
        Text(
          '${riwayaById(riwaya).nameAr} عن ${qiraaOf(riwaya).shortAr}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: qiraaOf(riwaya).color,
          ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('لا مواضع مسجلة لهذا الأصل عند هذا الراوي.'),
          )
        else ...[
          const SizedBox(height: 4),
          Text(
            'عدد المواضع المسجلة: ${arabicNumber(rows.length)}',
            style: TextStyle(color: MushafColors.frame, fontSize: 12),
          ),
          for (final ruling in rulings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ruling,
                style: TextStyle(
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: MushafColors.ink,
                ),
              ),
            ),
          if (shown.length > 1)
            _KindsChart(
              key: ValueKey('usul-guide-chart:$riwaya'),
              kinds: [for (final g in shown) (g.key, total(g.value))],
              color: color,
            ),
          for (final (i, group) in shown.indexed) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '${arabicNumber(i + 1)}- ${group.key} '
                '(${arabicNumber(total(group.value))})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            // One reason for the whole kind is told under its title.
            if (_sharedReason(group.value) case final reason?)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: MushafColors.ink,
                  ),
                ),
              ),
            for (final (j, kind) in group.value.indexed)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 18),
                child: _Kind(
                  description: _subKind(
                    group.key,
                    kind,
                    group.value.length > 1
                        ? '${arabicNumber(i + 1)}-${arabicNumber(j + 1)}'
                        : null,
                  ),
                  reason: _sharedReason(group.value) == null
                      ? usulKindReason(label, kind.value.first, kind.key)
                      : null,
                  rows: kind.value,
                  color: color,
                  examples: _examples,
                  variants: variants,
                  quran: quran,
                ),
              ),
          ],
          if (ordered.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'وأنواع أخرى أقل ورودًا: ${arabicNumber(ordered.length - shown.length)}',
                style: TextStyle(color: MushafColors.frame, fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          'الدليل من ${poem.nameAr}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        for (final b in verses)
          PoemVerse(
            bayt: b,
            named: true,
            explanation: manzumat.explanation(poem, b.n),
            bookExplanation: '',
          ),
        if (verses.isEmpty && chapter.isNotEmpty)
          ExpansionTile(
            key: ValueKey('usul-guide-chapter:$riwaya'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              'لم يتعين بيت لهذا الراوي، فهذا ${chapter.first.chapter} كاملًا',
              style: const TextStyle(fontSize: 13),
            ),
            children: [
              for (final b in chapter)
                PoemVerse(
                  bayt: b,
                  named: false,
                  explanation: manzumat.explanation(poem, b.n),
                  bookExplanation: '',
                ),
            ],
          ),
        if (verses.isEmpty && chapter.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('لم يتعين لهذا الأصل باب في المنظومة.'),
          ),
      ],
    );
  }
}

/// What a wording adds to its numbered kind: empty when nothing, and the
/// wording's number and count when the kind has several.
String _subKind(
  String group,
  MapEntry<String, List<Variant>> kind,
  String? number,
) {
  final rest = kind.key.startsWith(group)
      ? kind.key
            .substring(group.length)
            .replaceFirst(RegExp(r'^:\s*'), '')
            .trim()
      : kind.key;
  if (number == null) return rest;
  return '$number $rest (${arabicNumber(kind.value.length)})';
}

/// The numbered kinds of a rule at a glance: how many words each has.
class _KindsChart extends StatelessWidget {
  const _KindsChart({super.key, required this.kinds, required this.color});

  final List<(String, int)> kinds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final most = kinds.map((k) => k.$2).reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (final (i, (name, count)) in kinds.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      '${arabicNumber(i + 1)}- $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: MushafColors.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: (count / most).clamp(0.02, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius:
                              const BorderRadiusDirectional.horizontal(
                                end: Radius.circular(4),
                              ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      arabicNumber(count),
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 11, color: MushafColors.frame),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Kind extends StatelessWidget {
  const _Kind({
    required this.description,
    this.reason,
    required this.rows,
    required this.color,
    required this.examples,
    required this.variants,
    required this.quran,
  });

  /// What it adds to its numbered kind; empty when nothing.
  final String description;

  /// Why its faces are so, when the rule tells.
  final String? reason;
  final List<Variant> rows;
  final Color color;
  final int examples;
  final VariantRepository variants;
  final QuranRepository quran;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description.isNotEmpty)
          Text(
            description,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        if (reason != null)
          Text(
            reason!,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: MushafColors.ink,
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [for (final v in _spread(rows, examples)) _example(v)],
        ),
      ],
    ),
  );

  /// [count] of [rows], spread across the mushaf.
  static List<Variant> _spread(List<Variant> rows, int count) {
    if (rows.length <= count) return rows;
    return [for (var i = 0; i < count; i++) rows[i * rows.length ~/ count]];
  }

  Widget _example(Variant v) {
    final ayah = quran.ayah(v.surah, v.ayah);
    final surahEnd = quran.surah(v.surah).ayahCount;
    // A rule on two words (ٱلسُّفَهَآءُ أَلَآ) is shown on both.
    final word = v.usulText.contains(' ')
        ? usulReadingText(
            v,
            ayah,
            variants,
            nextAyah: v.ayah < surahEnd
                ? quran.ayah(v.surah, v.ayah + 1)
                : null,
            previousAyah: v.word == 0 && v.ayah > 1
                ? quran.ayah(v.surah, v.ayah - 1)
                : null,
          )
        : v.text.isNotEmpty
        ? v.text
        : readingText(variants, v.riwayaId, ayah, v.word, v.word + v.count);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuranWordText(
          word,
          style: TextStyle(fontFamily: 'Hafs', fontSize: 20, color: color),
        ),
        Text(
          '${quran.surah(v.surah).nameAr} ${arabicNumber(v.ayah)}، '
          'ص ${arabicNumber(ayah.page)}',
          style: TextStyle(fontSize: 10.5, color: MushafColors.frame),
        ),
      ],
    );
  }
}

/// All the usul of one riwaya, each opening its explanation: reached from the
/// guide of the ten readers.
class RiwayaUsulScreen extends StatelessWidget {
  const RiwayaUsulScreen({
    super.key,
    required this.riwaya,
    required this.variants,
    required this.quran,
  });

  final String riwaya;
  final VariantRepository variants;
  final QuranRepository quran;

  @override
  Widget build(BuildContext context) {
    final name = riwayaById(riwaya).nameAr;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: MushafColors.paper,
        appBar: AppBar(title: Text('أصول $name')),
        body: FutureBuilder<void>(
          future: variants.ensureLoaded([riwaya]),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final usul = usulOfRiwaya(variants, quran, riwaya);
            if (usul.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد لهذا الراوي فروق مسجلة؛ فنص المصحف المعروض هو '
                  'روايته، والأصول هنا تعرض بالمقارنة به.',
                  style: TextStyle(height: 1.8),
                ),
              );
            }
            final labels = usul.keys.where((l) => l != 'أصول أخرى').toList()
              ..sort((a, b) => usul[b]!.length.compareTo(usul[a]!.length));
            if (usul.containsKey('أصول أخرى')) labels.add('أصول أخرى');
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: labels.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final label = labels[i];
                return ListTile(
                  key: ValueKey('riwaya-usul:$label'),
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: ReadingColors.forLabel(label),
                  ),
                  title: Text(label),
                  subtitle: Text('${arabicNumber(usul[label]!.length)} موضعًا'),
                  onTap: () => UsulGuideSheet.show(
                    context,
                    label: label,
                    riwayat: [riwaya],
                    variants: variants,
                    quran: quran,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// [n] in Arabic digits.
String arabicNumber(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
