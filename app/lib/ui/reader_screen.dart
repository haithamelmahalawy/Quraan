import 'package:flutter/material.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'mushaf_page.dart';
import 'mutashabihat_sheet.dart';
import 'qiraat_sheet.dart';
import 'surah_index.dart';
import 'theme.dart';
import 'variant_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
  });

  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
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

  /// Qiraat differences open the readings sheet (with a way on to the
  /// mutashabihat); a word that only belongs to a mutashabih opens those.
  void _openWord(Ayah ayah, int word) {
    final places = widget.settings.showMutashabihat
        ? widget.mutashabihat.placesFor(ayah.surah, ayah.number, word)
        : const <MutashabihPlace>[];
    final hasReadings = widget.variants
        .at(widget.settings.selected, ayah.surah, ayah.number, word)
        .isNotEmpty;
    if (!hasReadings && places.length > 1) {
      _openMutashabihat(places);
      return;
    }
    VariantSheet.show(
      context,
      VariantSheet(
        ayah: ayah,
        word: word,
        surahName: widget.quran.surah(ayah.surah).nameAr,
        settings: widget.settings,
        variants: widget.variants,
        onMutashabihat: places.length > 1
            ? () {
                Navigator.of(context).pop();
                _openMutashabihat(places);
              }
            : null,
      ),
    );
  }

  void _openMutashabihat(List<MutashabihPlace> places) =>
      MutashabihatSheet.show(
        context,
        places: places,
        quran: widget.quran,
        onGo: _goToPage,
      );

  void _goToPage(int page) => _controller.animateToPage(
        page - 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );

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
            Text(
              'سورة ${widget.quran.surah(first.surah).nameAr}',
              style: const TextStyle(
                fontFamily: 'Hafs',
                fontSize: 24,
                color: MushafColors.green,
              ),
            ),
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
          mutashabihat: widget.mutashabihat,
          settings: widget.settings,
          onWordTap: _openWord,
        ),
      ),
      bottomNavigationBar: _PageBar(
        page: _page,
        surahName: widget.quran.surah(first.surah).nameAr,
        onChanged: (p) => _controller.jumpToPage(p - 1),
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

/// Bottom bar: the current surah and page, and a slider to any page.
class _PageBar extends StatefulWidget {
  const _PageBar({
    required this.page,
    required this.surahName,
    required this.onChanged,
  });

  final int page;
  final String surahName;
  final ValueChanged<int> onChanged;

  @override
  State<_PageBar> createState() => _PageBarState();
}

class _PageBarState extends State<_PageBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? widget.page.toDouble();
    return SafeArea(
      top: false,
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        decoration: BoxDecoration(
          color: MushafColors.paper,
          border: Border(
            top: BorderSide(color: MushafColors.gold.withAlpha(160)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MushafColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${value.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: MushafColors.green,
                  inactiveTrackColor: MushafColors.gold.withAlpha(90),
                  thumbColor: MushafColors.green,
                  trackHeight: 3,
                ),
                child: Slider(
                  min: 1,
                  max: QuranRepository.pageCount.toDouble(),
                  value: value,
                  label: '${value.round()}',
                  onChanged: (v) => setState(() => _dragging = v),
                  onChangeEnd: (v) {
                    setState(() => _dragging = null);
                    widget.onChanged(v.round());
                  },
                ),
              ),
            ),
            Text(
              widget.surahName,
              style: const TextStyle(
                fontFamily: 'Hafs',
                fontSize: 18,
                color: MushafColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
