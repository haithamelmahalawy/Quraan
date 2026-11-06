import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/quran.dart';
import '../services/ayah_player.dart';
import '../services/blink_detector.dart';
import '../services/qcf_fonts.dart';
import '../state/reader_settings.dart';
import 'ayah_sheet.dart';
import 'book_pager.dart';
import 'jam_screen.dart';
import 'mushaf_page.dart';
import 'page_side_hint.dart';
import 'mutashabihat_sheet.dart';
import 'raised.dart';
import 'riwayat_panel.dart';
import 'search_screen.dart';
import 'surah_index.dart';
import 'page_slider.dart';
import 'theme.dart';
import 'variant_sheet.dart';

/// Collapses in the layout, keeping the bars outside Quran lines and giving
/// the landscape margin the same available height as the printed page.
class _CollapsibleReaderBar extends StatelessWidget {
  const _CollapsibleReaderBar({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: open ? 1 : 0),
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeInOutCubic,
    child: ExcludeSemantics(
      excluding: !open,
      child: ExcludeFocus(
        excluding: !open,
        child: IgnorePointer(ignoring: !open, child: child),
      ),
    ),
    builder: (context, value, child) => ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: value,
        child: child,
      ),
    ),
  );
}

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
  final _headerMiddle = ValueNotifier<double?>(null);

  /// Where the surah's name of the page read is, on the screen.
  final _surahName = ValueNotifier<Rect?>(null);

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

  bool _landscape = false;
  bool _topBarOpen = false;
  bool _bottomBarOpen = false;
  bool get _twoPages => widget.settings.twoPages && !_landscape;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape == _landscape) return;
    _landscape = landscape;
    _topBarOpen = false;
    _bottomBarOpen = false;
    // Landscape reads a single enlarged page in sections. Keep the saved
    // spread preference for portrait and retain the current page number.
    _pager = GlobalKey<BookPagerState>();
    _zoomed = false;
  }

  /// The mushaf shown, and the one the pager was built for.
  QuranRepository get _quran => widget.mushafs.of(widget.settings.edition);
  late MushafEdition _edition = widget.settings.edition;

  /// Pager positions: a page, or a spread of two from the mushaf's first
  /// page ((1, 2), (3, 4) in the Madinah mushaf; (2, 3) in the Shamarly).
  int _indexOf(int page) {
    final i = page - _quran.firstPage;
    return _twoPages ? i ~/ 2 : i;
  }

  int _pageAt(int index) => _quran.firstPage + (_twoPages ? 2 * index : index);

  /// Switches the mushaf, at the place read.
  void _setEdition(MushafEdition edition) {
    if (edition == widget.settings.edition) return;
    widget.settings.openEdition(
      edition,
      widget.mushafs.convert(_page, widget.settings.edition, edition),
    );
  }

  /// Once the page is drawn: picture it and its facing page for the small
  /// icon; with [fly] (the icon tapped), show where it lies in the open
  /// mushaf too. Turning pages shows only the icon.
  void _showSide({bool fly = false}) {
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
      fly ? _hint.forward(from: 0) : setState(() {});
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
    AyahPlayer.instance.addListener(_onRecitation);
    _onSettings();
    _showSide();
  }

  /// The ayah recited when last seen.
  (int, int)? _recited;

  /// Following the recitation from ayah to ayah: the page turns with it.
  void _onRecitation() {
    final player = AyahPlayer.instance;
    final c = player.current;
    final now = c == null ? null : (c.surah, c.ayah);
    if (now == _recited) return;
    final before = _recited;
    _recited = now;
    if (c == null || before == null || !player.continuous) return;
    final page = _quran.pageOf(c.surah, c.ayah);
    if (page != _page) _goToPage(page);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AyahPlayer.instance.removeListener(_onRecitation);
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
      _openAyah(ayah, word: word);
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
        surahNames: [for (final s in _quran.surahs) s.nameAr],
        onAyah: () {
          Navigator.of(context).pop();
          _openAyah(ayah, word: word);
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

  void _openAyah(Ayah ayah, {int word = 0}) => AyahSheet.show(
    context,
    ayah: ayah,
    quran: _quran,
    settings: widget.settings,
    word: word,
    variants: widget.variants,
  );

  Future<void> _openMutashabihat(List<MutashabihPlace> places) =>
      MutashabihatSheet.show(
        context,
        places: places,
        quran: _quran,
        onGo: _goToPage,
      );

  void _goToPage(int page) => _pager.currentState?.jumpTo(_indexOf(page));

  /// «تنبيه الاختلافات»: the lamp lights the words that differ from Hafs,
  /// or puts them out.
  void _toggleGlow() => widget.settings.diffAlert =
      widget.settings.diffAlert == null ? DiffAlert.glow : null;

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
      onAyahWordTap: (ayah, word) => _openAyah(ayah, word: word),
      showHamesh: hamesh,
      onZoomChanged: (z) => setState(() => _zoomed = z),
      onPageNumberTap: _pickPage,
      // The arrow of the riwayat over the middle of the header in sight.
      onHeaderMiddle: number == _page ? (x) => _headerMiddle.value = x : null,
      onSurahName: number == _page ? (r) => _surahName.value = r : null,
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
    // «الرواة» at the top, the mushaf shorter beneath it.
    final pages = RiwayatPanel(
      settings: widget.settings,
      variants: widget.variants,
      arrowAt: two ? null : _headerMiddle,
      // «الجمع للقراءات العشر»: a screen of its own, at the page read.
      onJam: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JamScreen(
            quran: _quran,
            variants: widget.variants,
            page: _page,
            settings: widget.settings,
          ),
        ),
      ),
      child: _withHint(book),
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

    final topBar = Padding(
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
                        padding: const EdgeInsets.symmetric(horizontal: 3),
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
                            horizontal: 10,
                            vertical: 8,
                          ),
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
                      PopupMenuButton<MarginLayout>(
                        tooltip: 'طريقة العرض',
                        initialValue: widget.settings.marginLayout,
                        icon: const Icon(Icons.view_sidebar_outlined),
                        onSelected: (value) =>
                            widget.settings.marginLayout = value,
                        itemBuilder: (_) => [
                          for (final layout in MarginLayout.values)
                            CheckedPopupMenuItem(
                              value: layout,
                              checked: widget.settings.marginLayout == layout,
                              child: Text(layout.labelAr),
                            ),
                        ],
                      ),
                      RaisedIcon(
                        icon: Icons.search_rounded,
                        tooltip: 'بحث',
                        onTap: () async {
                          final page = await Navigator.of(context).push<int>(
                            MaterialPageRoute(
                              builder: (_) => SearchScreen(quran: _quran),
                            ),
                          );
                          if (page != null) _goToPage(page);
                        },
                      ),
                      RaisedIcon(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: 'فهرس السور',
                        onTap: () async {
                          final page = await Navigator.of(context).push<int>(
                            MaterialPageRoute(
                              builder: (_) => SurahIndex(quran: _quran),
                            ),
                          );
                          if (page != null) _goToPage(page);
                        },
                      ),
                      if (!_landscape)
                        RaisedIcon(
                          icon: two
                              ? Icons.crop_portrait_rounded
                              : Icons.auto_stories_rounded,
                          tooltip: two ? 'صفحة واحدة' : 'صفحتان متقابلتان',
                          onTap: () {
                            setState(() {
                              _pager = GlobalKey<BookPagerState>();
                              _zoomed = false;
                            });
                            widget.settings.twoPages = !two;
                          },
                        ),
                      // The double blink: turns the front camera on
                      // or off.
                      RaisedIcon(
                        icon: widget.settings.blinkToOpen
                            ? Icons.remove_red_eye_rounded
                            : Icons.visibility_off_outlined,
                        tooltip: widget.settings.blinkToOpen
                            ? 'إيقاف التقليب بالرمش مرتين'
                            : 'التقليب بالرمش مرتين (الكاميرا الأمامية)',
                        color: widget.settings.blinkToOpen
                            ? MushafColors.gold
                            : null,
                        onTap: () => widget.settings.blinkToOpen =
                            !widget.settings.blinkToOpen,
                      ),
                      RaisedIcon(
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'ملء الشاشة',
                        onTap: () => _setFullScreen(true),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.settings.blinkToOpen && _blink.isRunning)
                _EyeIndicator(blink: _blink, flash: _blinkFlash),
              if (!two && !_turning)
                Tooltip(
                  message: _quran.isRightPage(_page)
                      ? 'الصفحة في يمين المصحف'
                      : 'الصفحة في يسار المصحف',
                  child: GestureDetector(
                    onTap: () => _showSide(fly: true),
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
    );
    final bottomBar = PageSlider(quran: _quran, page: _page, onGo: _goToPage);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_landscape) ...[
              _CollapsibleReaderBar(open: _topBarOpen, child: topBar),
              _barHandle(top: true),
            ] else
              topBar,
            Expanded(child: pages),
            if (_landscape) ...[
              _barHandle(top: false),
              _CollapsibleReaderBar(open: _bottomBarOpen, child: bottomBar),
            ] else
              bottomBar,
          ],
        ),
      ),
    );
  }

  Widget _barHandle({required bool top}) {
    final open = top ? _topBarOpen : _bottomBarOpen;
    final label = top ? 'الشريط العلوي' : 'شريط التنقل السفلي';
    return SizedBox(
      height: 24,
      child: Center(
        child: Semantics(
          button: true,
          expanded: open,
          child: Material(
            color: MushafColors.green.withAlpha(24),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: ValueKey(top ? 'top-bar-toggle' : 'bottom-bar-toggle'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                if (top) {
                  _topBarOpen = !open;
                } else {
                  _bottomBarOpen = !open;
                }
              }),
              child: Tooltip(
                message: '${open ? 'إخفاء' : 'إظهار'} $label',
                child: SizedBox(
                  width: 48,
                  height: 24,
                  child: Icon(
                    top == open
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 22,
                    color: MushafColors.green,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The page area with the right / left hint flying to the top bar.
  Widget _withHint(Widget pages) => Stack(
    children: [
      Positioned.fill(child: pages),
      Positioned.fill(
        child: _GlowLamp(
          settings: widget.settings,
          surahName: _surahName,
          onTap: _toggleGlow,
        ),
      ),
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

/// What the front camera sees of the eyes, live: no face (grey), eyes open
/// (green) or closed (gold); it beats at every blink and grows when a double
/// blink turns the page. So the reader sees at once whether it follows them.
class _EyeIndicator extends StatelessWidget {
  const _EyeIndicator({required this.blink, required this.flash});

  final BlinkDetector blink;

  /// A double blink was just recognised.
  final bool flash;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: blink.blinks,
      builder: (context, count, _) => ValueListenableBuilder<EyeState>(
        valueListenable: blink.eyes,
        builder: (context, eyes, _) {
          final (icon, color, tip) = switch (eyes) {
            EyeState.noFace => (
              Icons.face_retouching_off_rounded,
              MushafColors.frame,
              'لا تظهر عيناك للكاميرا الأمامية: قرّب وجهك وأضئ المكان',
            ),
            EyeState.open => (
              Icons.visibility_rounded,
              MushafColors.green,
              'الكاميرا ترى عينيك: ارمش مرتين للصفحة التالية',
            ),
            EyeState.closed => (
              Icons.visibility_off_rounded,
              MushafColors.gold,
              'عيناك مغمضتان',
            ),
          };
          return Tooltip(
            message: tip,
            child: TweenAnimationBuilder<double>(
              // Restarts at each blink: a short beat.
              key: ValueKey(count),
              tween: Tween(begin: count == 0 ? 1 : 1.35, end: 1),
              duration: const Duration(milliseconds: 250),
              builder: (context, beat, child) =>
                  Transform.scale(scale: flash ? 1.5 : beat, child: child),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(icon, size: 22, color: color),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Beside the surah's name: the lamp of «تنبيه الاختلافات» (a tap lights
/// the words that differ from Hafs, its rays flickering, or puts them out)
/// and the button of the mutashabihat. Dragged, they stay where they are
/// left; a long press brings them back beside the name.
class _GlowLamp extends StatefulWidget {
  const _GlowLamp({
    required this.settings,
    required this.surahName,
    required this.onTap,
  });

  final ReaderSettings settings;
  final ValueListenable<Rect?> surahName;
  final VoidCallback onTap;

  @override
  State<_GlowLamp> createState() => _GlowLampState();
}

class _GlowLampState extends State<_GlowLamp>
    with SingleTickerProviderStateMixin {
  static const _size = 34.0;
  static const _gap = 4.0;
  static const _width = 2 * _size + _gap;

  /// The rays: flickering only while the lamp is lit, so nothing moves
  /// (nor is drawn again) when it is out.
  late final _rays = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Where the lamp is while dragged, in pixels.
  Offset? _dragged;

  @override
  void dispose() {
    _rays.dispose();
    super.dispose();
  }

  void _syncRays(bool lit) {
    if (!lit) {
      if (_rays.isAnimating) _rays.stop();
      _rays.value = 0;
    } else if (!_rays.isAnimating) {
      _rays.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.settings, widget.surahName]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final room = Size(
          math.max(box.maxWidth - _width, 1),
          math.max(box.maxHeight - _size, 1),
        );
        final lit = widget.settings.diffAlert != null;
        _syncRays(lit);
        final at = _dragged ?? _place(context, room);
        return Stack(
          children: [
            Positioned(
              left: at.dx.clamp(0.0, room.width),
              top: at.dy.clamp(0.0, room.height),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => _dragged = at,
                onPanUpdate: (d) => setState(() {
                  final p = (_dragged ?? at) + d.delta;
                  _dragged = Offset(
                    p.dx.clamp(0.0, room.width),
                    p.dy.clamp(0.0, room.height),
                  );
                }),
                onPanEnd: (_) {
                  final p = _dragged;
                  _dragged = null;
                  if (p != null) {
                    widget.settings.lampAt = Offset(
                      p.dx / room.width,
                      p.dy / room.height,
                    );
                  }
                },
                onLongPress: () => widget.settings.lampAt = null,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _lamp(lit),
                      const SizedBox(width: _gap),
                      _mutashabihat(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  /// Where it was left; else beside the surah's name, to its left.
  Offset _place(BuildContext context, Size room) {
    final left = widget.settings.lampAt;
    if (left != null) {
      return Offset(left.dx * room.width, left.dy * room.height);
    }
    final name = widget.surahName.value;
    final box = context.findRenderObject();
    if (name == null || box is! RenderBox || !box.attached) {
      return Offset(room.width, 0);
    }
    final local = box.globalToLocal(name.centerLeft);
    return Offset(local.dx - _gap - _width, local.dy - _size / 2);
  }

  Widget _lamp(bool lit) => Tooltip(
    // The long press brings it back beside the name.
    triggerMode: TooltipTriggerMode.manual,
    message: lit ? 'إطفاء توهج الاختلافات' : 'توهج الاختلافات',
    child: GestureDetector(
      key: const ValueKey('glow-lamp'),
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: CustomPaint(
          key: lit ? const ValueKey('glow-rays') : null,
          painter: lit ? _Rays(_rays, MushafColors.gold) : null,
          child: Opacity(
            opacity: lit ? .9 : .65,
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (lit ? MushafColors.gold : MushafColors.green).withAlpha(
                  lit ? 70 : 35,
                ),
                border: Border.all(
                  color: (lit ? MushafColors.gold : MushafColors.green)
                      .withAlpha(150),
                ),
              ),
              child: Icon(
                lit ? Icons.lightbulb : Icons.lightbulb_outline,
                size: 20,
                color: lit ? MushafColors.gold : MushafColors.green,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _mutashabihat() {
    final on = widget.settings.showMutashabihat;
    final colour = on ? MushafColors.gold : MushafColors.green;
    return Tooltip(
      triggerMode: TooltipTriggerMode.manual,
      message: on ? 'إخفاء تظليل المتشابهات' : 'إظهار تظليل المتشابهات',
      child: GestureDetector(
        key: const ValueKey('mutashabihat-toggle'),
        onTap: () => widget.settings.showMutashabihat = !on,
        child: Opacity(
          opacity: on ? .9 : .65,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colour.withAlpha(on ? 70 : 35),
              border: Border.all(color: colour.withAlpha(150)),
            ),
            // Two pages alike, one over the other.
            child: Icon(
              on ? Icons.difference_rounded : Icons.difference_outlined,
              size: 19,
              color: colour,
            ),
          ),
        ),
      ),
    );
  }
}

/// Short rays around the lit lamp, coming and going.
class _Rays extends CustomPainter {
  _Rays(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeInOut.transform(t.value);
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: .25 + .75 * v)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 2), c + d * (r + 3 + 4 * v), paint);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => old.color != color;
}
