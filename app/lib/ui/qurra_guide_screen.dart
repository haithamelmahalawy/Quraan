import 'package:flutter/material.dart';

import '../data/qurra_biographies.dart';

/// An offline guide, separate from choosing which riwaya to read.
class QurraGuideScreen extends StatefulWidget {
  const QurraGuideScreen({super.key});

  @override
  State<QurraGuideScreen> createState() => _QurraGuideScreenState();
}

class _QurraGuideScreenState extends State<QurraGuideScreen> {
  final _search = TextEditingController();
  bool _narrators = false;
  RecitationCity? _city;
  RecitationGroup? _group;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _city = null;
    _group = null;
    _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text;
    final readers = readerBiographies
        .where((b) => _group == null || b.group == _group)
        .toList();
    final transmissions = [
      for (final b in readers)
        for (final n in b.narrators) (reader: b, narrator: n),
    ];
    final visibleReaders = readers
        .where((b) => (_city == null || b.city == _city) && b.matches(query))
        .toList();
    final visibleNarrators = transmissions
        .where(
          (t) =>
              (_city == null || t.narrator.city == _city) &&
              biographyMatches(
                query,
                '${narratorSearchText(t.narrator)} ${t.reader.fullName} ${t.reader.group.nameAr}',
              ),
        )
        .toList();
    final availableCities = {
      if (_narrators)
        ...transmissions.map((t) => t.narrator.city)
      else
        ...readers.map((b) => b.city),
    };
    final count = _narrators ? visibleNarrators.length : visibleReaders.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'القراء العشرة ورواتهم',
          style: TextStyle(fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'عن الدليل ومصادره',
            onPressed: () => _sources(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('qurra-guide-list'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '١٠ قراء • ٢٠ رواية',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'نبذة عن كل إمام وراوٍ، مع التصنيف بحسب بلد الإقراء أو الاشتهار. يمكنك تصفح القراء أو الرواة والبحث بأسمائهم.',
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('القراء'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('الرواة'),
                ),
              ],
              selected: {_narrators},
              onSelectionChanged: (selected) => setState(() {
                _narrators = selected.single;
                _city = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('biography-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'ابحث عن قارئ أو راوٍ أو مدينة',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('التصنيف', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                ChoiceChip(
                  label: const Text('العشرة جميعًا'),
                  selected: _group == null,
                  onSelected: (_) => setState(() {
                    _group = null;
                    _city = null;
                  }),
                ),
                for (final g in RecitationGroup.values)
                  ChoiceChip(
                    label: Text(g.nameAr),
                    selected: _group == g,
                    onSelected: (_) => setState(() {
                      _group = g;
                      _city = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _narrators ? 'بلد الراوي' : 'بلد القارئ',
              style: theme.textTheme.titleSmall,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                ChoiceChip(
                  label: const Text('كل البلدان'),
                  selected: _city == null,
                  onSelected: (_) => setState(() => _city = null),
                ),
                for (final c in RecitationCity.values.where(
                  availableCities.contains,
                ))
                  ChoiceChip(
                    key: ValueKey('city-${c.name}'),
                    label: Text(c.nameAr),
                    selected: _city == c,
                    onSelected: (_) => setState(() => _city = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'النتائج: ${_digits(count)} ${_narrators ? 'رواية' : 'من القراء'}',
              style: theme.textTheme.labelLarge,
              key: const ValueKey('biography-count'),
            ),
            if (count == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Text('لا توجد نتائج مطابقة للبحث والتصنيف الحالي.'),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('إظهار الجميع'),
                    ),
                  ],
                ),
              ),
            for (final c in RecitationCity.values) ...[
              if ((_city == null || _city == c) &&
                  (_narrators
                      ? visibleNarrators.any((t) => t.narrator.city == c)
                      : visibleReaders.any((b) => b.city == c))) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          c.nameAr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_narrators)
                  for (final t in visibleNarrators.where(
                    (t) => t.narrator.city == c,
                  ))
                    Card(
                      key: ValueKey('narrator-${t.narrator.riwayaId}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NarratorInfo(
                              narrator: t.narrator,
                              showReader: true,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.reader.group.nameAr,
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                else
                  for (final b in visibleReaders.where((b) => b.city == c))
                    _ReaderCard(
                      key: ValueKey('reader-${b.qiraaId}'),
                      biography: b,
                      query: query,
                    ),
              ],
            ],
            const SizedBox(height: 18),
            const Text(
              'الدوري راوٍ عن أبي عمرو والكسائي، وخلف راوٍ عن حمزة وإمام القراءة العاشرة. لذا يُعرض كل دور ضمن الإمام الذي تتبعه روايته.',
            ),
            TextButton.icon(
              onPressed: () => _sources(context),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('مصادر النبذات ومعنى القراءة والرواية'),
            ),
          ],
        ),
      ),
    );
  }

  void _sources(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('عن الدليل ومصادره'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'القراءة تنسب إلى إمام من أئمة القراء، والرواية تنسب إلى من نقل قراءته، مباشرة أو بإسناد. يعرض هذا الدليل الراويين المشهورين لكل إمام في القراءات العشر.',
            ),
            const SizedBox(height: 12),
            const Text(
              'البلد يبيّن موطن الإقراء أو الاشتهار المذكور في النبذة. والسبعة والثلاثة معًا هم القراء العشرة.',
            ),
            const SizedBox(height: 12),
            for (final source in biographySources) ...[
              Text(
                source.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                source.url,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({super.key, required this.biography, required this.query});
  final ReaderBiography biography;
  final String query;

  @override
  Widget build(BuildContext context) {
    final b = biography;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: b.qiraa.color.withAlpha(28),
                      child: Icon(Icons.person_outline, color: b.qiraa.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b.qiraa.nameAr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: b.qiraa.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  b.fullName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(b.brief, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 8),
                _Tag(text: b.group.nameAr),
              ],
            ),
          ),
          ExpansionTile(
            key: ValueKey('reader-narrators-${b.qiraaId}:$query'),
            initiallyExpanded:
                query.trim().isNotEmpty &&
                b.narrators.any(
                  (n) => biographyMatches(query, narratorSearchText(n)),
                ),
            title: const Text('الراويان'),
            subtitle: Text(b.narrators.map((n) => n.riwaya.nameAr).join(' • ')),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              for (final (i, n) in b.narrators.indexed) ...[
                if (i > 0) const Divider(height: 24),
                _NarratorInfo(narrator: n),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NarratorInfo extends StatelessWidget {
  const _NarratorInfo({required this.narrator, this.showReader = false});
  final NarratorBiography narrator;
  final bool showReader;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        showReader ? narrator.title : narrator.riwaya.nameAr,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: narrator.qiraa.color,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        narrator.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 5),
      _Tag(text: narrator.city.nameAr),
      const SizedBox(height: 6),
      Text(narrator.brief, style: const TextStyle(height: 1.6)),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      ),
    ),
  );
}

String _digits(int n) => '$n'.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
);
