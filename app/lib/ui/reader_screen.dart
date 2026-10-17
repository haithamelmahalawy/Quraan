import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'mushaf_page.dart';
import 'qiraat_sheet.dart';
import 'surah_index.dart';
import 'variant_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.settings,
  });

  final QuranRepository quran;
  final VariantRepository variants;
  final ReaderSettings settings;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final _controller = PageController(initialPage: widget.settings.page - 1);
  late int _page = widget.settings.page;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    _onSettings();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    _controller.dispose();
    super.dispose();
  }

  /// Loads newly selected riwayat before the pages are redrawn with them.
  Future<void> _onSettings() async {
    final missing = widget.settings.selected
        .where((id) => !widget.variants.isLoaded(id))
        .toList();
    if (missing.isEmpty) {
      setState(() {});
      return;
    }
    setState(() => _loading = true);
    await widget.variants.ensureLoaded(missing);
    if (mounted) setState(() => _loading = false);
  }

  void _openWord(Ayah ayah, int word) {
    VariantSheet.show(
      context,
      VariantSheet(
        ayah: ayah,
        word: word,
        surahName: widget.quran.surah(ayah.surah).nameAr,
        settings: widget.settings,
        variants: widget.variants,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.quran.page(_page).first;
    final selected = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (widget.settings.selected.contains(r.id)) r,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text('سورة ${widget.quran.surah(first.surah).nameAr}'),
            Text(
              'الجزء ${first.juz} • صفحة $_page',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'فهرس السور',
            icon: const Icon(Icons.list),
            onPressed: () async {
              final page = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => SurahIndex(quran: widget.quran),
                ),
              );
              if (page != null) _controller.jumpToPage(page - 1);
            },
          ),
          IconButton(
            tooltip: 'القراءات',
            icon: Badge(
              isLabelVisible: selected.isNotEmpty,
              label: Text('${selected.length}'),
              child: const Icon(Icons.layers_outlined),
            ),
            onPressed: () => QiraatSheet.show(
                context, widget.settings, widget.variants),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _SelectionStrip(
            selected: selected,
            loading: _loading,
            onTap: () => QiraatSheet.show(
                context, widget.settings, widget.variants),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: QuranRepository.pageCount,
        onPageChanged: (i) {
          setState(() => _page = i + 1);
          widget.settings.page = i + 1;
        },
        itemBuilder: (context, i) => MushafPage(
          page: i + 1,
          quran: widget.quran,
          variants: widget.variants,
          settings: widget.settings,
          onWordTap: _openWord,
        ),
      ),
    );
  }
}

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final List<Riwaya> selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          if (selected.isEmpty)
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('رواية حفص - اختر قراءات للمقارنة'),
              onPressed: onTap,
            ),
          for (final r in selected)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ActionChip(
                avatar: CircleAvatar(backgroundColor: qiraaOf(r.id).color),
                label: Text(r.nameAr),
                onPressed: onTap,
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
