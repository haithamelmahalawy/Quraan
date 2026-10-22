import 'package:flutter/material.dart';

import '../data/kharouf.dart';
import '../data/library_search.dart';
import '../data/manzumat.dart';
import '../data/quran_repository.dart';
import '../models/qiraat_catalog.dart';
import 'guide_depth.dart';
import 'kharouf_section.dart';
import 'poem_verse.dart';

enum _LibraryBook {
  shatibiyya(
    'متن الشاطبية',
    'حرز الأماني ووجه التهاني — الإمام الشاطبي',
    'القراءات السبع • النص الكامل وأبوابه',
    Color(0xFF2F785C),
    Poem.shatibiyya,
  ),
  durrah(
    'متن الدرة',
    'الدرة المضية في القراءات الثلاث — الإمام ابن الجزري',
    'القراءات الثلاث المتممة للعشر • النص الكامل وأبوابه',
    Color(0xFF7660A3),
    Poem.durrah,
  ),
  tasheel(
    'التسهيل لقراءات التنزيل',
    'إعداد الشيخ محمد فهد خاروف • مراجعة الشيخ كريم راجح',
    'قراءات الكتاب وأدلته مرتبة بحسب السور والآيات',
    Color(0xFF9A712A),
    null,
  );

  const _LibraryBook(
    this.title,
    this.author,
    this.brief,
    this.color,
    this.poem,
  );
  final String title, author, brief;
  final Color color;
  final Poem? poem;
}

/// The existing offline texts, directly accessible from the home page.
class ReadingLibraryScreen extends StatefulWidget {
  const ReadingLibraryScreen({super.key, required this.quran});
  final QuranRepository quran;

  @override
  State<ReadingLibraryScreen> createState() => _ReadingLibraryScreenState();
}

class _ReadingLibraryScreenState extends State<ReadingLibraryScreen> {
  final _search = TextEditingController();
  int _category = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = _LibraryBook.values
        .where(
          (b) =>
              (_category == 0 ||
                  (_category == 1 ? b.poem != null : b.poem == null)) &&
              librarySearchMatches(
                _search.text,
                librarySearchText('${b.title} ${b.author} ${b.brief}'),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المتون ومصادر القراءات')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('reading-library-list'),
          padding: const EdgeInsets.all(16),
          children: [
            GuideDepthSurface(
              accent: theme.colorScheme.primary,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مكتبة القراءات العشر',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'اقرأ المتون، وابحث في الأبيات والقراءات، وتصفح الأبواب والأدلة دون اتصال بالإنترنت.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 78,
                    height: 105,
                    child: FittedBox(child: GuideBookSculpture()),
                  ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('library-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ابحث عن متن أو مصدر',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (i, label) in ['الكل', 'المتون', 'المصادر'].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: _category == i,
                    onSelected: (_) => setState(() => _category = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (books.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد نتائج مطابقة.'),
              ),
            for (final book in books)
              GuideDepthSurface(
                key: ValueKey('library-${book.name}'),
                accent: book.color,
                child: InkWell(
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => book.poem == null
                          ? TasheelLibraryScreen(quran: widget.quran)
                          : PoemLibraryScreen(poem: book.poem!),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GuideSeal(
                          color: book.color,
                          icon: book.poem == null
                              ? Icons.library_books_outlined
                              : Icons.auto_stories_rounded,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(book.author),
                              const SizedBox(height: 8),
                              Text(
                                book.brief,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    'فتح وقراءة',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_left, size: 20),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PoemLibraryScreen extends StatefulWidget {
  const PoemLibraryScreen({super.key, required this.poem});
  final Poem poem;

  @override
  State<PoemLibraryScreen> createState() => _PoemLibraryScreenState();
}

class _PoemLibraryScreenState extends State<PoemLibraryScreen> {
  final _data = Manzumat.load();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _chapter;
  double _fontSize = 18;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('متن ${widget.poem.nameAr}'),
      actions: [
        IconButton(
          tooltip: 'تصغير الخط',
          onPressed: _fontSize <= 16
              ? null
              : () => setState(() => _fontSize -= 2),
          icon: const Icon(Icons.text_decrease),
        ),
        IconButton(
          tooltip: 'تكبير الخط',
          onPressed: _fontSize >= 30
              ? null
              : () => setState(() => _fontSize += 2),
          icon: const Icon(Icons.text_increase),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<Manzumat>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('تعذر تحميل المتن. أعد فتحه للمحاولة مجددًا.'),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final verseNumber = int.tryParse(
            librarySearchText(_search.text).trim(),
          );
          final verses = data
              .verses(widget.poem)
              .where(
                (b) =>
                    (_chapter == null || b.chapter == _chapter) &&
                    (verseNumber != null
                        ? b.n == verseNumber
                        : librarySearchMatches(
                            _search.text,
                            librarySearchText(
                              '${b.n} ${b.sadr} ${b.ajz} ${b.chapter}',
                            ),
                          )),
              )
              .toList();
          return ListView.builder(
            key: const ValueKey('poem-library-list'),
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: verses.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.poem.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'نص المتن: ${Manzumat.source}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('poem-search'),
                      controller: _search,
                      onChanged: (_) => _filter(() {}),
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'ابحث في الأبيات أو برقم البيت',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LibrarySelect<String>(
                      label: 'الباب',
                      all: 'كل الأبواب',
                      value: _chapter,
                      items: {for (final c in data.chapters(widget.poem)) c: c},
                      onChanged: (c) => _filter(() => _chapter = c),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الأبيات المعروضة: ${verses.length} من ${data.verses(widget.poem).length}',
                      key: const ValueKey('poem-result-count'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اضغط علامة الشرح بجوار البيت لعرض الشرح المتاح أو إخفائه.',
                    ),
                    if (verses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد أبيات مطابقة.'),
                      ),
                  ],
                );
              }
              final b = verses[i - 1];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (i == 1 || verses[i - 2].chapter != b.chapter)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        b.chapter,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  Card(
                    child: PoemVerse(
                      key: ValueKey('library-verse-${widget.poem.name}-${b.n}'),
                      bayt: b,
                      named: false,
                      explanation: data.explanation(widget.poem, b.n),
                      bookExplanation: '',
                      fontSize: _fontSize,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}

class TasheelLibraryScreen extends StatefulWidget {
  const TasheelLibraryScreen({super.key, required this.quran});
  final QuranRepository quran;

  @override
  State<TasheelLibraryScreen> createState() => _TasheelLibraryScreenState();
}

class _TasheelLibraryScreenState extends State<TasheelLibraryScreen> {
  final _data = Kharouf.load();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<_BookNote>? _notes;
  int? _surah;
  String? _riwaya, _section;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'التسهيل لقراءات التنزيل',
        style: TextStyle(fontSize: 18),
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<Kharouf>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('تعذر تحميل مادة الكتاب. أعد فتحه للمحاولة مجددًا.'),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = _notes ??= [
            for (final e in data.entries) _BookNote(e, widget.quran),
          ];
          final notes = all
              .where(
                (n) =>
                    (_surah == null || n.entry.surah == _surah) &&
                    (_section == null || n.entry.section == _section) &&
                    (_riwaya == null ||
                        n.entry.readings.any(
                          (r) =>
                              r.riwayat.contains(_riwaya) ||
                              r.disputed.contains(_riwaya),
                        )) &&
                    librarySearchMatches(_search.text, n.searchText),
              )
              .toList();
          final ids = {
            for (final q in qiraat)
              for (final r in q.riwayat) r.id,
          };
          final selected = _riwaya == null ? ids : {_riwaya!};
          return ListView.builder(
            key: const ValueKey('tasheel-library-list'),
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: notes.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      data.source,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'قراءات الكتاب وأدلته المنقولة في عرض نصي مرتب بحسب السور والآيات.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('tasheel-search'),
                      controller: _search,
                      onChanged: (_) => _filter(() {}),
                      decoration: const InputDecoration(
                        labelText: 'ابحث في الكلمات والقراءات والأدلة',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LibrarySelect<int>(
                      label: 'السورة',
                      all: 'كل السور',
                      value: _surah,
                      items: {
                        for (final s in widget.quran.surahs) s.number: s.nameAr,
                      },
                      onChanged: (v) => _filter(() => _surah = v),
                    ),
                    const SizedBox(height: 10),
                    _LibrarySelect<String>(
                      label: 'الرواية',
                      all: 'كل الروايات',
                      value: _riwaya,
                      items: {
                        for (final id in ids) id: readersAr([id], []),
                      },
                      onChanged: (v) => _filter(() => _riwaya = v),
                    ),
                    const SizedBox(height: 10),
                    _LibrarySelect<String>(
                      label: 'القسم',
                      all: 'كل الأقسام',
                      value: _section,
                      items: const {
                        'farsh': 'الفرش',
                        'mumal': 'الممال',
                        'mudgham': 'المدغم',
                      },
                      onChanged: (v) => _filter(() => _section = v),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'المواضع المعروضة: ${notes.length} من ${all.length}',
                          key: const ValueKey('tasheel-result-count'),
                        ),
                        TextButton(
                          onPressed: () => _filter(() {
                            _surah = null;
                            _riwaya = null;
                            _section = null;
                            _search.clear();
                          }),
                          child: const Text('إظهار الجميع'),
                        ),
                      ],
                    ),
                    if (notes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد مواضع مطابقة.'),
                      ),
                  ],
                );
              }
              final note = notes[i - 1];
              final e = note.entry;
              return Card(
                key: ObjectKey(note),
                child: ExpansionTile(
                  key: ValueKey(
                    'tasheel-note-${e.surah}-${e.ayah}-${e.word}-${e.section}',
                  ),
                  title: Text(
                    note.word,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Hafs', fontSize: 23),
                  ),
                  subtitle: Text(
                    '${widget.quran.surah(e.surah).nameAr} • الآية ${e.ayah} • ${e.sectionAr}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in e.readings)
                      if (r.riwayat.any(selected.contains) ||
                          r.disputed.any(selected.contains))
                        KharoufReadingText(reading: r, riwayat: selected),
                    if (e.verses.isNotEmpty) ...[
                      const Divider(),
                      const Text('الأبيات المستشهد بها في الكتاب'),
                      for (final v in e.verses)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SelectableText(
                            v,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 17, height: 1.8),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _BookNote {
  _BookNote(this.entry, QuranRepository quran) {
    word = quran
        .ayah(entry.surah, entry.ayah)
        .words
        .skip(entry.word)
        .take(entry.count)
        .join(' ');
    searchText = librarySearchText(
      [
        word,
        quran.surah(entry.surah).nameAr,
        '${entry.ayah}',
        entry.sectionAr,
        for (final r in entry.readings) ...[
          r.text,
          r.how,
          readersAr(r.riwayat, r.disputed),
          for (final (note, _) in r.notes) note,
        ],
        ...entry.verses,
      ].join(' '),
    );
  }
  final KharoufEntry entry;
  late final String word, searchText;
}

class _LibrarySelect<T> extends StatelessWidget {
  const _LibrarySelect({
    required this.label,
    required this.all,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label, all;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        key: ValueKey('library-filter-$label'),
        isExpanded: true,
        isDense: true,
        value: value,
        hint: Text(all),
        items: [
          DropdownMenuItem<T>(value: null, child: Text(all)),
          for (final item in items.entries)
            DropdownMenuItem<T>(
              value: item.key,
              child: Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}
