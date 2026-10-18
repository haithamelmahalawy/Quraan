import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../services/blink_detector.dart';
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

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final _pager = GlobalKey<BookPagerState>();
  late int _page = widget.settings.page;
  bool _loading = false;

  /// Full-screen reading: no bars, no hamesh.
  bool _fullScreen = false;

  /// While a page is zoomed in, drags pan it instead of turning pages.
  bool _zoomed = false;

  /// Double blink: opens the mutashabihat of the focused word (or the first
  /// on the page); while they are open, moves to the next place.
  final _blink = BlinkDetector();
  StreamSubscription<void>? _blinks;
  final _advance = ValueNotifier(0);
  bool _sheetOpen = false;
  bool _blinkFlash = false;
  bool _resumed = true;
  (Ayah, int)? _focus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettings);
    _blinks = _blink.doubleBlinks.listen((_) => _onDoubleBlink());
    _onSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettings);
    _blinks?.cancel();
    _blink.dispose();
    _advance.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  /// The camera runs only while blinking is enabled and the app is in front.
  Future<void> _syncCamera() async {
    if (widget.settings.blinkToOpen && _resumed) {
      if (_blink.isRunning) return;
      try {
        await _blink.start();
        if (mounted) setState(() {});
      } catch (_) {
        if (!mounted) return;
        widget.settings.blinkToOpen = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تشغيل الكاميرا الأمامية. تحقق من إذن الكاميرا.'),
        ));
      }
    } else {
      await _blink.stop();
    }
  }

  void _onDoubleBlink() {
    HapticFeedback.mediumImpact();
    setState(() => _blinkFlash = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _blinkFlash = false);
    });
    if (_sheetOpen) {
      _advance.value++;
      return;
    }
    final target = _focus ?? _firstMutashabih();
    if (target == null) return;
    final (ayah, word) = target;
    final places =
        widget.mutashabihat.placesFor(ayah.surah, ayah.number, word);
    if (places.length > 1) _openMutashabihat(places);
  }

  (Ayah, int)? _firstMutashabih() {
    for (final a in widget.quran.page(_page)) {
      for (var w = 0; w < a.words.length; w++) {
        if (widget.mutashabihat.isShared(a.surah, a.number, w)) return (a, w);
      }
    }
    return null;
  }

  /// Loads newly selected riwayat before the pages are redrawn with them.
  Future<void> _onSettings() async {
    _syncCamera();
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
    // A tapped mutashabih becomes the target of the double blink.
    if (places.length > 1) setState(() => _focus = (ayah, word));
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

  Future<void> _openMutashabihat(List<MutashabihPlace> places) async {
    _sheetOpen = true;
    await MutashabihatSheet.show(
      context,
      places: places,
      quran: widget.quran,
      onGo: _goToPage,
      advance: _advance,
    );
    _sheetOpen = false;
  }

  void _goToPage(int page) => _pager.currentState?.jumpTo(page - 1);

  void _setFullScreen(bool on) {
    SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    setState(() => _fullScreen = on);
  }

  @override
  Widget build(BuildContext context) {
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
          _focus = null;
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
          onPageNumberTap: _pickPage,
          focus: _focus == null
              ? null
              : VariantRepository.key(
                  _focus!.$1.surah, _focus!.$1.number, _focus!.$2),
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

    // The page takes the whole screen; a slim row of small controls stays
    // above it.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  _BarButton(
                    tooltip: 'القراءات',
                    icon: Badge(
                      isLabelVisible: selected.isNotEmpty,
                      label: Text('${selected.length}'),
                      child: const Icon(Icons.layers_outlined, size: 22),
                    ),
                    onPressed: () => QiraatSheet.show(
                        context, widget.settings, widget.variants),
                  ),
                  _BarButton(
                    tooltip: 'فهرس السور',
                    icon: const Icon(Icons.list, size: 22),
                    onPressed: () async {
                      final page = await Navigator.of(context).push<int>(
                        MaterialPageRoute(
                          builder: (_) => SurahIndex(quran: widget.quran),
                        ),
                      );
                      if (page != null) _goToPage(page);
                    },
                  ),
                  _BarButton(
                    tooltip: 'ملء الشاشة',
                    icon: const Icon(Icons.fullscreen, size: 24),
                    onPressed: () => _setFullScreen(true),
                  ),
                  if (widget.settings.blinkToOpen && _blink.isRunning)
                    Tooltip(
                      message: 'الرمش مرتين يفتح المتشابهات',
                      child: AnimatedScale(
                        scale: _blinkFlash ? 1.5 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _blinkFlash
                              ? Icons.visibility
                              : Icons.visibility_outlined,
                          size: 20,
                          color: MushafColors.green,
                        ),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickPage,
                    child: Text(
                      'صفحة $_page',
                      style: TextStyle(color: MushafColors.green),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: pages),
          ],
        ),
      ),
    );
  }

  /// Small dialog to go to any page.
  Future<void> _pickPage() async {
    var value = _page.toDouble();
    final page = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final first = widget.quran.page(value.round()).first;
          return AlertDialog(
            title: Text(
              'صفحة ${value.round()} • سورة ${widget.quran.surah(first.surah).nameAr}',
              style: TextStyle(color: MushafColors.green, fontSize: 18),
            ),
            content: Slider(
              min: 1,
              max: QuranRepository.pageCount.toDouble(),
              divisions: QuranRepository.pageCount - 1,
              value: value,
              label: '${value.round()}',
              onChanged: (v) => setDialog(() => value = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(value.round()),
                child: const Text('اذهب'),
              ),
            ],
          );
        },
      ),
    );
    if (page != null) _goToPage(page);
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        color: MushafColors.green,
        icon: icon,
        onPressed: onPressed,
      );
}
