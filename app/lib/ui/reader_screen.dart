import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/quran.dart';
import '../services/blink_detector.dart';
import '../services/qcf_fonts.dart';
import '../state/reader_settings.dart';
import 'ayah_sheet.dart';
import 'book_pager.dart';
import 'mushaf_page.dart';
import 'page_side_hint.dart';
import 'mutashabihat_sheet.dart';
import 'raised.dart';
import 'riwayat_menu.dart';
import 'search_screen.dart';
import 'surah_index.dart';
import 'surah_slider.dart';
import 'theme.dart';
import 'variant_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.mushafs,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
  });

  /// The printed mushafs; [ReaderSettings.edition] is the one shown.
  final Mushafs mushafs;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Replaced when switching one / two pages: the pager counts pages or
  /// spreads, so its position must not carry over.
  var _pager = GlobalKey<BookPagerState>();
  late int _page = widget.settings.page;
  bool _loading = false;

  /// Full-screen reading: no bars, no hamesh.
  bool _fullScreen = false;

  /// While a page is zoomed in, drags pan it instead of turning pages.
  bool _zoomed = false;

  /// Double blink: turns to the next page.
  final _blink = BlinkDetector();
  StreamSubscription<EyeGesture>? _blinks;

  /// The action just done by an eye gesture, shown briefly.
  String? _gestureLabel;
  Timer? _gestureLabelTimer;
  bool _blinkFlash = false;
  bool _resumed = true;

  /// Right / left of the open mushaf, shown briefly when a page opens.
  late final _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addListener(() => setState(() {}));

  /// Pictures of the current page and the page facing it, for the hint and
  /// the small icon.
  ui.Image? _currentPicture, _facingPicture;

  /// Pages are being turned: the right / left of the mushaf is shown only
  /// once the reader stays on a page.
  bool _turning = false;
  Timer? _settle;

  bool get _twoPages => widget.settings.twoPages;

  /// The mushaf shown, and the one the pager was built for.
  QuranRepository get _quran => widget.mushafs.of(widget.settings.edition);
  late MushafEdition _edition = widget.settings.edition;

  /// Pager positions: a page, or a spread of two from the mushaf's first
  /// page ((1, 2), (3, 4) in the Madinah mushaf; (2, 3) in the Shamarly).
  int _indexOf(int page) {
    final i = page - _quran.firstPage;
    return _twoPages ? i ~/ 2 : i;
  }

  int _pageAt(int index) =>
      _quran.firstPage + (_twoPages ? 2 * index : index);

  /// Switches the mushaf, at the place read.
  void _setEdition(MushafEdition edition) {
    if (edition == widget.settings.edition) return;
    widget.settings.openEdition(
      edition,
      widget.mushafs.convert(_page, widget.settings.edition, edition),
    );
  }

  /// Once the page is drawn: picture it and its facing page, then show
  /// where it lies in the open mushaf.
  void _showSide() {
    if (_twoPages) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pager = _pager.currentState;
      if (pager != null) {
        final index = _indexOf(_page);
        final facing = _quran.isRightPage(_page) ? index + 1 : index - 1;
        _currentPicture?.dispose();
        _facingPicture?.dispose();
        _currentPicture = pager.capture(index);
        _facingPicture = pager.capture(facing);
      }
      _hint.forward(from: 0);
    });
  }

  /// A page was turned: hide the side of the mushaf until the reader stays.
  void _onTurn() {
    _settle?.cancel();
    _hint.reset();
    if (!_turning) setState(() => _turning = true);
    _settle = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _turning = false);
      _showSide();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettings);
    QcfFonts.instance.addListener(_onFonts);
    _blinks = _blink.gestures.listen(_onGesture);
    _onSettings();
    _showSide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettings);
    QcfFonts.instance.removeListener(_onFonts);
    _blinks?.cancel();
    _blink.dispose();
    _settle?.cancel();
    _gestureLabelTimer?.cancel();
    _hint.dispose();
    _currentPicture?.dispose();
    _facingPicture?.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تشغيل الكاميرا الأمامية. تحقق من إذن الكاميرا.',
            ),
          ),
        );
      }
    } else {
      await _blink.stop();
      if (mounted) setState(() {});
    }
  }

  /// Eye gestures: a double blink turns to the next page.
  void _onGesture(EyeGesture gesture) {
    switch (gesture) {
      case DoubleBlink():
        if (_zoomed) return;
        _pager.currentState?.turn(1);
        _announce('الصفحة التالية');
    }
  }

  void _announce(String label) {
    HapticFeedback.mediumImpact();
    _gestureLabelTimer?.cancel();
    setState(() {
      _gestureLabel = label;
      _blinkFlash = true;
    });
    _gestureLabelTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() {
          _gestureLabel = null;
          _blinkFlash = false;
        });
      }
    });
  }

  void _onFonts() {
    if (mounted) setState(() {});
  }

  /// The printed-mushaf fonts of the pages around [page].
  void _loadFonts(int page) {
    if (widget.settings.qcfFont && _quran.edition == MushafEdition.madani) {
      QcfFonts.instance.ensure([page, page + 1, page - 1, page + 2, page - 2]);
    }
  }

  /// Loads newly selected riwayat before the pages are redrawn with them.
  Future<void> _onSettings() async {
    // Another mushaf: a new pager, at the page of the place read.
    if (widget.settings.edition != _edition) {
      setState(() {
        _edition = widget.settings.edition;
        _page = widget.settings.page;
        _pager = GlobalKey<BookPagerState>();
        _zoomed = false;
      });
      _showSide();
    }
    _syncCamera();
    _loadFonts(_page);
    final missing = widget.settings.selected
        .where((id) => !widget.variants.isLoaded(id))
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _loading = true);
      await widget.variants.ensureLoaded(missing);
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) setState(() {});
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
    // A word with nothing to compare opens its ayah: tafsir, recitation.
    if (!hasReadings) {
      _openAyah(ayah);
      return;
    }
    VariantSheet.show(
      context,
      VariantSheet(
        ayah: ayah,
        word: word,
        surahName: _quran.surah(ayah.surah).nameAr,
        settings: widget.settings,
        variants: widget.variants,
        onAyah: () {
          Navigator.of(context).pop();
          _openAyah(ayah);
        },
        onMutashabihat: places.length > 1
            ? () {
                Navigator.of(context).pop();
                _openMutashabihat(places);
              }
            : null,
      ),
    );
  }

  void _openAyah(Ayah ayah) => AyahSheet.show(
    context,
    ayah: ayah,
    quran: _quran,
    settings: widget.settings,
  );

  Future<void> _openMutashabihat(List<MutashabihPlace> places) =>
      MutashabihatSheet.show(
        context,
        places: places,
        quran: _quran,
        onGo: _goToPage,
      );

  void _goToPage(int page) => _pager.currentState?.jumpTo(_indexOf(page));

  void _setFullScreen(bool on) {
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    setState(() => _fullScreen = on);
  }

  @override
  Widget build(BuildContext context) {
    Widget page(int number, {required bool hamesh}) => MushafPage(
      page: number,
      quran: _quran,
      variants: widget.variants,
      mutashabihat: widget.mutashabihat,
      settings: widget.settings,
      onWordTap: _openWord,
      onAyahTap: _openAyah,
      showHamesh: hamesh,
      onZoomChanged: (z) => setState(() => _zoomed = z),
      onPageNumberTap: _pickPage,
      // The QCF page fonts draw the Madinah pages only.
      qcf:
          widget.settings.qcfFont &&
          _quran.edition == MushafEdition.madani &&
          QcfFonts.instance.isReady(number),
    );

    final two = _twoPages;
    final book = BookPager(
      key: _pager,
      // Two-page view turns a spread at a time (see _indexOf).
      itemCount: two ? (_quran.pageCount + 1) ~/ 2 : _quran.pageCount,
      initialIndex: _indexOf(_page),
      enabled: !_zoomed,
      onPageChanged: (i) {
        final number = _pageAt(i);
        setState(() {
          _page = number;
          _zoomed = false;
        });
        widget.settings.page = number;
        _loadFonts(number);
        _onTurn();
      },
      // An opaque sheet, so a turning page never shows the one beneath.
      itemBuilder: (context, i) => ColoredBox(
        color: MushafColors.paper,
        child: two
            ? Row(
                // The right page (odd) first, as the mushaf lies open.
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(child: page(_pageAt(i), hamesh: false)),
                  const _Spine(),
                  Expanded(
                    child: _pageAt(i) + 1 <= _quran.lastPage
                        ? page(_pageAt(i) + 1, hamesh: false)
                        : const SizedBox(),
                  ),
                ],
              )
            : page(_pageAt(i), hamesh: !_fullScreen),
      ),
    );
    final pages = _withHint(book);

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
            // The controls, raised above the page; those that do not fit
            // scroll sideways, the page's place stays in view.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Raised(
                radius: 26,
                depth: 0.8,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: SizedBox(
                  height: 38,
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              RaisedIcon(
                                icon: Icons.home_rounded,
                                tooltip: 'الصفحة الرئيسية',
                                onTap: () =>
                                    Navigator.of(context)
                                        .popUntil((route) => route.isFirst),
                              ),
                              // Madinah or Shamarly, at the place read.
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: Raised(
                                  radius: 19,
                                  depth: 0.6,
                                  tooltip: 'التبديل بين مصحف المدينة والشمرلي',
                                  onTap: () => _setEdition(
                                    _edition == MushafEdition.madani
                                        ? MushafEdition.shamarly
                                        : MushafEdition.madani,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Text(
                                    _edition == MushafEdition.madani
                                        ? 'المدينة'
                                        : 'الشمرلي',
                                    style: TextStyle(
                                      color: MushafColors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              RiwayatMenu(
                                settings: widget.settings,
                                variants: widget.variants,
                              ),
                              RaisedIcon(
                                icon: Icons.search_rounded,
                                tooltip: 'بحث',
                                onTap: () async {
                                  final page = await Navigator.of(context)
                                      .push<int>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SearchScreen(quran: _quran),
                                        ),
                                      );
                                  if (page != null) _goToPage(page);
                                },
                              ),
                              RaisedIcon(
                                icon: Icons.format_list_bulleted_rounded,
                                tooltip: 'فهرس السور',
                                onTap: () async {
                                  final page = await Navigator.of(context)
                                      .push<int>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SurahIndex(quran: _quran),
                                        ),
                                      );
                                  if (page != null) _goToPage(page);
                                },
                              ),
                              RaisedIcon(
                                icon: two
                                    ? Icons.crop_portrait_rounded
                                    : Icons.auto_stories_rounded,
                                tooltip: two
                                    ? 'صفحة واحدة'
                                    : 'صفحتان متقابلتان',
                                onTap: () {
                                  setState(() {
                                    _pager = GlobalKey<BookPagerState>();
                                    _zoomed = false;
                                  });
                                  widget.settings.twoPages = !two;
                                },
                              ),
                              RaisedIcon(
                                icon: widget.settings.showMutashabihat
                                    ? Icons.highlight_rounded
                                    : Icons.highlight_off_rounded,
                                tooltip: widget.settings.showMutashabihat
                                    ? 'إخفاء تظليل المتشابهات'
                                    : 'إظهار تظليل المتشابهات',
                                color: widget.settings.showMutashabihat
                                    ? MushafColors.gold
                                    : null,
                                onTap: () => widget.settings.showMutashabihat =
                                    !widget.settings.showMutashabihat,
                              ),
                              RaisedIcon(
                                icon: Icons.fullscreen_rounded,
                                tooltip: 'ملء الشاشة',
                                onTap: () => _setFullScreen(true),
                              ),
                              if (widget.settings.blinkToOpen &&
                                  _blink.isRunning)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Tooltip(
                                    message:
                                        'الرمش مرتين ينقلك إلى الصفحة التالية',
                                    child: AnimatedScale(
                                      scale: _blinkFlash ? 1.5 : 1,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        _blinkFlash
                                            ? Icons.visibility
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: MushafColors.green,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: SizedBox.square(
                                    dimension: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (!two && !_turning)
                        Tooltip(
                          message: _quran.isRightPage(_page)
                              ? 'الصفحة في يمين المصحف'
                              : 'الصفحة في يسار المصحف',
                          child: GestureDetector(
                            onTap: _showSide,
                            child: OpenMushafView(
                              right: _quran.isRightPage(_page),
                              width: 44,
                              current: _currentPicture,
                              facing: _facingPicture,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Raised(
                        color: MushafColors.green,
                        radius: 19,
                        depth: 0.6,
                        tooltip: 'اختر صفحة',
                        onTap: _pickPage,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'ص $_page',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: pages),
            SurahSlider(quran: _quran, page: _page, onGo: _goToPage),
          ],
        ),
      ),
    );
  }

  /// The page area with the right / left hint flying to the top bar.
  Widget _withHint(Widget pages) => Stack(
    children: [
      Positioned.fill(child: pages),
      // What the last eye gesture did.
      Positioned(
        left: 0,
        right: 0,
        bottom: 24,
        child: IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              opacity: _gestureLabel == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MushafColors.green.withAlpha(220),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _gestureLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_hint.isAnimating)
        Positioned.fill(
          child: PageSideHint(
            page: _page,
            right: _quran.isRightPage(_page),
            progress: _hint.value,
            current: _currentPicture,
            facing: _facingPicture,
            // Just under the small icon by the page number.
            target: const Alignment(-0.78, -1.04),
          ),
        ),
    ],
  );

  /// Small dialog to go to any page.
  Future<void> _pickPage() async {
    var value = _page.toDouble();
    final page = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final first = _quran.page(value.round()).first;
          return AlertDialog(
            title: Text(
              'صفحة ${value.round()} • سورة ${_quran.surah(first.surah).nameAr}',
              style: TextStyle(color: MushafColors.green, fontSize: 18),
            ),
            content: Slider(
              min: _quran.firstPage.toDouble(),
              max: _quran.lastPage.toDouble(),
              divisions: _quran.pageCount - 1,
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

/// The fold between two facing pages.
class _Spine extends StatelessWidget {
  const _Spine();

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.black.withAlpha(10),
          Colors.black.withAlpha(90),
          Colors.black.withAlpha(10),
        ],
      ),
    ),
  );
}
