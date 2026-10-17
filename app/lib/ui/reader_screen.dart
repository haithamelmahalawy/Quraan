import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../state/reader_settings.dart';
import 'book_pager.dart';
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
  final _pager = GlobalKey<BookPagerState>();
  late int _page = widget.settings.page;
  bool _loading = false;

  /// Full-screen reading: no bars, no hamesh.
  bool _fullScreen = false;

  /// While a page is zoomed in, drags pan it instead of turning pages.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    _onSettings();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Loads newly selected riwayat before the pages are redrawn with them.
  Future<void> _onSettings() async {
    final missing = widget.settings.selected
        .where((id) => !widget.variants.isLoaded(id))
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _loading = true);
      await widget.variants.ensureLoaded(missing);
      if (mounted) setState(() => _loading = false);
    }
    await _fetchOnline(_page);
    if (mounted) setState(() {});
  }

  bool _offlineNoticeShown = false;

  /// Riwayat read online are fetched for the page shown and the next one.
  Future<void> _fetchOnline(int page) async {
    if (!widget.settings.selected.any(widget.variants.isOnline)) return;
    setState(() => _loading = true);
    try {
      await widget.variants.ensureAyahs(widget.quran.page(page));
      if (mounted) setState(() {});
      if (page < QuranRepository.pageCount) {
        await widget.variants.ensureAyahs(widget.quran.page(page + 1));
      }
    } catch (_) {
      if (mounted && !_offlineNoticeShown) {
        _offlineNoticeShown = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحميل بعض الروايات من الإنترنت. '
              'تحقق من الاتصال ثم أعد فتح الصفحة.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  void _goToPage(int page) => _pager.currentState?.jumpTo(page - 1);

  void _setFullScreen(bool on) {
    SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    setState(() => _fullScreen = on);
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.quran.page(_page).first;
    final selected = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (widget.settings.selected.contains(r.id)) r,
    ];
    final pages = BookPager(
      key: _pager,
      itemCount: QuranRepository.pageCount,
      initialIndex: _page - 1,
      enabled: !_zoomed,
      onPageChanged: (i) {
        setState(() {
          _page = i + 1;
          _zoomed = false;
        });
        widget.settings.page = i + 1;
        _fetchOnline(i + 1);
      },
      // An opaque sheet, so a turning page never shows the one beneath.
      itemBuilder: (context, i) => ColoredBox(
        color: MushafColors.paper,
        child: MushafPage(
          page: i + 1,
          quran: widget.quran,
          variants: widget.variants,
          mutashabihat: widget.mutashabihat,
          settings: widget.settings,
          onWordTap: _openWord,
          showHamesh: !_fullScreen,
          onZoomChanged: (z) => setState(() => _zoomed = z),
        ),
      ),
    );

    if (_fullScreen) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: SafeArea(child: pages)),
            // Below the page, where it never covers the text.
            PositionedDirectional(
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              start: 16,
              child: Material(
                color: MushafColors.green.withAlpha(150),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'إنهاء ملء الشاشة',
                  color: Colors.white,
                  icon: const Icon(Icons.fullscreen_exit),
                  onPressed: () => _setFullScreen(false),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'سورة ${widget.quran.surah(first.surah).nameAr}',
              style: TextStyle(
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
        leading: IconButton(
          tooltip: 'ملء الشاشة',
          icon: const Icon(Icons.fullscreen),
          onPressed: () => _setFullScreen(true),
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
              if (page != null) _goToPage(page);
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
      body: pages,
      bottomNavigationBar: _PageBar(
        page: _page,
        surahName: widget.quran.surah(first.surah).nameAr,
        onChanged: _goToPage,
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
              style: TextStyle(
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
