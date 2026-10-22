import 'package:flutter/material.dart';

import '../data/qurra_biographies.dart';
import '../data/qurra_graph.dart';
import 'guide_depth.dart';
import 'qurra_graph_view.dart';

/// An offline guide, separate from choosing which riwaya to read.
class QurraGuideScreen extends StatefulWidget {
  const QurraGuideScreen({super.key});

  @override
  State<QurraGuideScreen> createState() => _QurraGuideScreenState();
}

class _QurraGuideScreenState extends State<QurraGuideScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _camera = QurraGraphCamera();
  bool _graphMode = true;
  bool _fullGraph = false;
  String? _selectedNode;
  bool _narrators = false;
  RecitationCity? _city;
  RecitationGroup? _group;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _camera.dispose();
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
    final count = _narrators ? visibleNarrators.length : visibleReaders.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'القراء العشرة ورواتهم',
          style: TextStyle(fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: _graphMode ? 'عرض القائمة' : 'عرض الشبكة ثلاثية الأبعاد',
            onPressed: () {
              _camera.setRotating(false);
              setState(() => _graphMode = !_graphMode);
            },
            icon: Icon(
              _graphMode ? Icons.view_list_outlined : Icons.hub_outlined,
            ),
          ),
          if (_graphMode)
            IconButton(
              tooltip: _fullGraph ? 'إظهار أدوات البحث' : 'ملء الشاشة بالشبكة',
              onPressed: () => setState(() => _fullGraph = !_fullGraph),
              icon: Icon(_fullGraph ? Icons.fullscreen_exit : Icons.fullscreen),
            ),
          IconButton(
            tooltip: 'تصفية الدليل',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _city != null || _group != null,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          IconButton(
            tooltip: 'عن الدليل ومصادره',
            onPressed: () => _sources(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _graphMode
            ? _graphBody(context)
            : ListView(
                key: const ValueKey('qurra-guide-list'),
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const _GuideHero(),
                  const SizedBox(height: 4),
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
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(90),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('تصفية'),
                      ),
                      if (_city != null)
                        InputChip(
                          label: Text(_city!.nameAr),
                          onDeleted: () => setState(() => _city = null),
                        ),
                      if (_group != null)
                        InputChip(
                          label: Text(_group!.nameAr),
                          onDeleted: () => setState(() => _group = null),
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
                          const Text(
                            'لا توجد نتائج مطابقة للبحث والتصنيف الحالي.',
                          ),
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
                          GuideDepthSurface(
                            accent: t.narrator.qiraa.color,
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
                        for (final b in visibleReaders.where(
                          (b) => b.city == c,
                        ))
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

  Widget _graphBody(BuildContext context) {
    final graph = QurraGraph.build(
      query: _search.text,
      city: _city,
      group: _group,
      narratorCity: _narrators,
    );
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('biography-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'ابحث عن قارئ أو راوٍ أو مدينة',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.clear),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('تصفية'),
              ),
              if (_city != null)
                InputChip(
                  label: Text(_city!.nameAr),
                  onDeleted: () => setState(() => _city = null),
                ),
              if (_group != null)
                InputChip(
                  label: Text(_group!.nameAr),
                  onDeleted: () => setState(() => _group = null),
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _narrators = !_narrators;
                  _city = null;
                }),
                icon: const Icon(Icons.location_on_outlined, size: 17),
                label: Text(
                  _narrators ? 'التصفية ببلد الراوي' : 'التصفية ببلد القارئ',
                ),
              ),
            ],
          ),
          Text(
            '${_digits(graph.readerCount)} قراء • ${_digits(graph.narratorCount)} رواية',
            key: const ValueKey('biography-count'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
    final network = Column(
      children: [
        Expanded(
          child: graph.nodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('لا توجد نتائج مطابقة للبحث والتصنيف الحالي.'),
                      TextButton(
                        onPressed: _reset,
                        child: const Text('إظهار الجميع'),
                      ),
                    ],
                  ),
                )
              : QurraGraphView(
                  key: const ValueKey('qurra-3d-view'),
                  graph: graph,
                  camera: _camera,
                  selected: _selectedNode,
                  onSelect: _showGraphNode,
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            'مرّر لاستعراض الفروع • إصبعان للتكبير\nزر التدوير لتحريك المنظور • اضغط الاسم للنبذة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_fullGraph) return network;
        if (constraints.maxWidth > constraints.maxHeight * 1.3) {
          return Row(
            children: [
              SizedBox(width: 220, child: SingleChildScrollView(child: header)),
              Expanded(child: network),
            ],
          );
        }
        return Column(
          children: [
            header,
            Expanded(child: network),
          ],
        );
      },
    );
  }

  void _showGraphNode(QurraGraphNode node) {
    _camera.setRotating(false);
    setState(() => _selectedNode = node.id);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (node.kind == QurraNodeKind.reader)
                  _ReaderCard(biography: node.reader!, query: '')
                else if (node.kind == QurraNodeKind.narrator) ...[
                  _NarratorInfo(narrator: node.narrator!, showReader: true),
                  const SizedBox(height: 12),
                  Text(
                    'عن القارئ ${node.reader!.qiraa.nameAr} • ${node.reader!.group.nameAr}',
                  ),
                ] else if (node.kind == QurraNodeKind.city) ...[
                  Text(
                    node.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'بلد الإقراء أو الاشتهار، كما تذكره النبذات. قد يختلف بلد الراوي عن بلد القارئ الذي يروي عنه.',
                  ),
                  for (final narrators in [false, true])
                    TextButton.icon(
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: Text(
                        narrators
                            ? 'عرض رواة هذه المدينة وروابطهم'
                            : 'عرض قراء هذه المدينة ورواتهم',
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() {
                          _city = node.city;
                          _narrators = narrators;
                        });
                      },
                    ),
                ] else ...[
                  Text(
                    'القراء العشرة ورواتهم',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تُرتّب الفروع حسب بلد القارئ، ويظهر كل قارئ فوق راوييه بخطين واضحين. بلد كل راوٍ مكتوب تحت اسمه، والإطار الذهبي يميّز القراء الثلاثة المتممين للعشرة.',
                  ),
                ],
                if (node.kind == QurraNodeKind.root ||
                    node.narrator?.personId == 'duri' ||
                    node.narrator?.personId == 'khalaf' ||
                    node.reader?.qiraaId == 'khalaf') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'للدوري روايتان عن أبي عمرو والكسائي، وخلف راوٍ عن حمزة وهو أيضًا إمام القراءة العاشرة. يظهر كل دور في الفرع الذي ينتمي إليه.',
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('العودة إلى الشبكة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    _camera.setRotating(false);
    FocusScope.of(context).unfocus();
    final selected =
        await showModalBottomSheet<
          ({RecitationCity? city, RecitationGroup? group})
        >(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: .88,
            child: _GuideFilterSheet(
              narrators: _narrators,
              city: _city,
              group: _group,
              query: _search.text,
            ),
          ),
        );
    if (selected != null && mounted) {
      setState(() {
        _city = selected.city;
        _group = selected.group;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
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

class _GuideHero extends StatelessWidget {
  const _GuideHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuideDepthSurface(
      accent: theme.colorScheme.primary,
      depth: 6,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أئمة القراءة',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '١٠ قراء • ٢٠ رواية',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تعرّف إلى القراء ورواتهم، واستكشف مدارس الإقراء بحسب المدن.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const SizedBox(
            width: 90,
            height: 126,
            child: FittedBox(child: GuideBookSculpture()),
          ),
        ],
      ),
    );
  }
}

class _GuideFilterSheet extends StatefulWidget {
  const _GuideFilterSheet({
    required this.narrators,
    required this.city,
    required this.group,
    required this.query,
  });
  final bool narrators;
  final RecitationCity? city;
  final RecitationGroup? group;
  final String query;
  @override
  State<_GuideFilterSheet> createState() => _GuideFilterSheetState();
}

class _GuideFilterSheetState extends State<_GuideFilterSheet> {
  late RecitationCity? _city = widget.city;
  late RecitationGroup? _group = widget.group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readers = readerBiographies
        .where((b) => _group == null || b.group == _group)
        .toList();
    final narrators = [
      for (final b in readers)
        for (final n in b.narrators) (reader: b, narrator: n),
    ];
    final available = {
      if (widget.narrators)
        ...narrators.map((t) => t.narrator.city)
      else
        ...readers.map((b) => b.city),
    };
    final matches = widget.narrators
        ? [
            for (final t in narrators)
              if (biographyMatches(
                widget.query,
                '${narratorSearchText(t.narrator)} ${t.reader.fullName} ${t.reader.group.nameAr}',
              ))
                t.narrator.city,
          ]
        : [
            for (final b in readers)
              if (b.matches(widget.query)) b.city,
          ];
    final count = matches.where((c) => _city == null || c == _city).length;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'تصفية الدليل',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _city = null;
                    _group = null;
                  }),
                  child: const Text('مسح التصفية'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('guide-filter-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('التصنيف', style: theme.textTheme.titleSmall),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
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
                  const SizedBox(height: 16),
                  Text(
                    widget.narrators ? 'بلد الراوي' : 'بلد القارئ',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 600 ? 3 : 2;
                      final width =
                          (constraints.maxWidth - 12 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          SizedBox(
                            width: width,
                            child: _CityFilterTile(
                              key: const ValueKey('city-all'),
                              city: null,
                              count: matches.length,
                              selected: _city == null,
                              onTap: () => setState(() => _city = null),
                            ),
                          ),
                          for (final c in RecitationCity.values.where(
                            available.contains,
                          ))
                            SizedBox(
                              width: width,
                              child: _CityFilterTile(
                                key: ValueKey('city-${c.name}'),
                                city: c,
                                count: matches.where((m) => m == c).length,
                                selected: _city == c,
                                onTap: () => setState(() => _city = c),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.dividerColor.withAlpha(40)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('apply-guide-filters'),
                onPressed: () =>
                    Navigator.pop(context, (city: _city, group: _group)),
                icon: const Icon(Icons.check_rounded),
                label: Text('عرض النتائج (${_digits(count)})'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityFilterTile extends StatelessWidget {
  const _CityFilterTile({
    super.key,
    required this.city,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final RecitationCity? city;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (city) {
      RecitationCity.madinah => const Color(0xFF2E7D60),
      RecitationCity.makkah => const Color(0xFF9C752A),
      RecitationCity.kufa => const Color(0xFF805CB0),
      RecitationCity.basra => const Color(0xFF23848E),
      RecitationCity.damascus => const Color(0xFF477EB0),
      RecitationCity.baghdad => const Color(0xFFB66D45),
      RecitationCity.egypt => const Color(0xFFA86D30),
      RecitationCity.raqqa => const Color(0xFF5C8492),
      null => scheme.primary,
    };
    final icon = switch (city) {
      RecitationCity.madinah => Icons.mosque_outlined,
      RecitationCity.makkah => Icons.place_outlined,
      RecitationCity.kufa => Icons.account_balance_outlined,
      RecitationCity.basra => Icons.water_outlined,
      RecitationCity.damascus => Icons.fort_outlined,
      RecitationCity.baghdad => Icons.location_city_outlined,
      RecitationCity.egypt => Icons.landscape_outlined,
      RecitationCity.raqqa => Icons.waves_outlined,
      null => Icons.public,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: GuideDepthSurface(
        accent: selected ? scheme.primary : accent,
        depth: selected ? 3 : 6,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GuideSeal(color: accent, icon: icon, size: 36),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? scheme.primary : scheme.outline,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  city?.nameAr ?? 'كل البلدان',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_digits(count)} نتيجة',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({super.key, required this.biography, required this.query});
  final ReaderBiography biography;
  final String query;

  @override
  Widget build(BuildContext context) {
    final b = biography;
    final theme = Theme.of(context);
    return GuideDepthSurface(
      accent: b.qiraa.color,
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
                    GuideSeal(
                      color: b.qiraa.color,
                      icon: Icons.menu_book_rounded,
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
      Row(
        children: [
          GuideSeal(
            color: narrator.qiraa.color,
            icon: Icons.account_tree_outlined,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              showReader ? narrator.title : narrator.riwaya.nameAr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: narrator.qiraa.color,
              ),
            ),
          ),
        ],
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
