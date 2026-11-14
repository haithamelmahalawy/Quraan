import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../data/background_json.dart';
import '../data/kharouf.dart';
import '../data/manzumat.dart';
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
import 'glow_usul_screen.dart';
import 'jam_screen.dart';
import 'mushaf_page.dart';
import 'page_side_hint.dart';
import 'mutashabihat_sheet.dart';
import 'raised.dart';
import 'mushaf_style_sheet.dart';
import 'riwayat_panel.dart';
import 'search_screen.dart';
import 'surah_index.dart';
import 'page_slider.dart';
import 'theme.dart';
import 'variant_sheet.dart';

/// «الرواة» in the top bar: lets the riwayat's panel down beneath it, or
/// sends it back up.
class _RiwayatButton extends StatelessWidget {
  const _RiwayatButton({required this.open, this.small = false});

  final ValueNotifier<bool> open;

  /// Beside the handle of the top bar folded away.
  final bool small;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: open,
    builder: (context, on, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        expanded: on,
        child: Raised(
          key: const ValueKey('riwayat-panel-toggle'),
          radius: small ? 11 : 19,
          depth: small ? 0.3 : 0.6,
          color: on ? MushafColors.goldLight : null,
          tooltip: on ? 'إخفاء الرواة' : 'إظهار الرواة',
          onTap: () => open.value = !on,
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          // Tapped, the panel down; again, up. Gold while it is down; its
          // icon, its name and an arrow down while the riwayat are hidden,
          // up while they show (the user, 2026-11-13).
          child: riwayatLabel(open: on, size: small ? 11 : 14),
        ),
      ),
    ),
  );
}

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

  /// The middle of each page's header, as each page near reported it: the
  /// arrow follows the page turned to without building it again.
  final _middles = <int, double>{};

  /// Bumped whenever what the pages are drawn with changes (the settings,
  /// the riwayat loaded, the page fonts): the pager keeps the pages built
  /// until then.
  int _pagesRevision = 0;

  /// Where the surah's name of the page read is, on the screen.
  /// The riwayat's panel, opened from the top bar.
  final _riwayatOpen = ValueNotifier<bool>(false);

  /// The small icon of the side the page lies on, beside the lamp: where the
  /// hint of the open mushaf flies to.
  final _sideIcon = GlobalKey();

  /// The page area the hint flies over.
  final _hintArea = GlobalKey();

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

  /// Folded away at first, in every view (the user, 2026-11-13).
  bool _topBarOpen = false;
  bool _bottomBarOpen = false;

  /// The ring of the looks of the mushaf open over the page (the user,
  /// 2026-11-14).
  bool _stylesOpen = false;
  bool get _twoPages => widget.settings.twoPages && !_landscape;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape == _landscape) return;
    _landscape = landscape;
    // Folded away at first, upright or turned (the user, 2026-11-13).
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
    if (_twoPages || !showMushafSide) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pager = _pager.currentState;
      if (pager != null) {
        final index = _indexOf(_page);
        final facing = _quran.isRightPage(_page) ? index + 1 : index - 1;
        _currentPicture?.dispose();
        _facingPicture?.dispose();
        // A small picture: the screen's full pixels cost a weak phone
        // much, after every turn.
        _currentPicture = pager.capture(index, pixelRatio: 1);
        _facingPicture = pager.capture(facing, pixelRatio: 1);
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
    // The poems, their sharhs and the book read ahead, after the page is up,
    // so the first word opened shows its witnesses at once.
    if (!runningTests) {
      _readAhead = Timer(const Duration(seconds: 2), () {
        Manzumat.load();
        Kharouf.load();
      });
    }
  }

  Timer? _readAhead;

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
    _pendingWord?.cancel();
    _readAhead?.cancel();
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
    // The page fonts draw the pages only when chosen, and a page is drawn
    // again only when its own font is ready: the fonts loaded ahead after
    // each turn (two pages on) built the pages near again, the longest
    // frame of a turn on a weak phone.
    if (!widget.settings.qcfFont || _quran.edition != MushafEdition.madani) {
      return;
    }
    final near = _fontsNearNow();
    if (near.length == _fontsNear.length && near.containsAll(_fontsNear)) {
      return;
    }
    _fontsNear = near;
    _pagesRevision++;
    if (mounted) setState(() {});
  }

  /// The pages near (the pager's built ones) whose page font is ready.
  Set<int> _fontsNear = {};
  Set<int> _fontsNearNow() => _fontsNearOf(_page);

  /// The pages the pager builds around [page] (the page and its
  /// neighbours, or their spreads) whose page font is ready; the fonts
  /// loaded further ahead do not touch them.
  Set<int> _fontsNearOf(int page) {
    final i = _indexOf(page);
    return {
      for (var j = i - 1; j <= i + 1; j++)
        for (final p in [_pageAt(j), if (_twoPages) _pageAt(j) + 1])
          if (QcfFonts.instance.isReady(p)) p,
    };
  }

  /// The printed-mushaf fonts of the pages around [page].
  void _loadFonts(int page) {
    if (!widget.settings.qcfFont || _quran.edition != MushafEdition.madani) {
      return;
    }
    // Ahead in batches: only when a page near has none yet, the next dozen
    // pages at once (each registering lays out every text again).
    final fonts = QcfFonts.instance;
    if ([for (var p = page - 2; p <= page + 3; p++) p]
        .where((p) => p >= 1 && p <= 604)
        .every(fonts.isReady)) {
      return;
    }
    fonts.ensure([for (var p = page - 4; p <= page + 12; p++) p]);
  }

  /// Loads newly selected riwayat before the pages are redrawn with them.
  Future<void> _onSettings() async {
    _pagesRevision++;
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
      _pagesRevision++;
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) setState(() {});
  }

  /// Qiraat differences open the readings sheet (with a way on to the
  /// mutashabihat); a word that only belongs to a mutashabih opens those.
  /// A word tapped: opened a moment later, unless a second tap makes the
  /// two a double tap (full screen), anywhere on the page, the middle of
  /// an ayah too (the user, 2026-11-13).
  Timer? _pendingWord;

  /// The tap that made a double one: its word is not opened.
  bool _swallowWord = false;

  static const _doubleTapWait = Duration(milliseconds: 250);

  void _wordTapped(Ayah ayah, int word) {
    if (_swallowWord) return;
    _pendingWord?.cancel();
    _pendingWord = Timer(_doubleTapWait, () {
      _pendingWord = null;
      if (mounted) _openWord(ayah, word);
    });
  }

  void _doubleTapped() {
    _pendingWord?.cancel();
    _pendingWord = null;
    // The second tap's own word, told after this in the same touch.
    _swallowWord = true;
    scheduleMicrotask(() => _swallowWord = false);
    _setFullScreen(!_fullScreen);
  }

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

  /// «الانتقال إلى المصحف» in the jam': the mushaf at the page read there.
  void _backFromJam(int? page) {
    if (mounted && page != null && page != _page) _goToPage(page);
  }

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
      onWordTap: _wordTapped,
      onAyahTap: _openAyah,
      onAyahWordTap: (ayah, word) => _openAyah(ayah, word: word),
      showHamesh: hamesh,
      onZoomChanged: (z) => setState(() => _zoomed = z),
      // Zoomed in on a word, the page still turns from its side.
      onEdgeTurn: (direction) => _pager.currentState?.turn(direction),
      // Two quick taps: «ملء الشاشة» of the top panel, on or off.
      onDoubleTap: _doubleTapped,
      // The riwayat chosen, on the frame: gone between without their panel.
      onShowRiwaya: (id) => widget.settings.displayed = id,
      onPageNumberTap: _pickPage,
      // The arrow of the riwayat over the middle of the header in sight.
      onHeaderMiddle: (x) {
        _middles[number] = x;
        if (number == _page) _headerMiddle.value = x;
      },
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
      revision: (_pagesRevision, _fullScreen, two, _quran.edition),
      onPageChanged: (i) {
        final number = _pageAt(i);
        if (_middles[number] case final x?) _headerMiddle.value = x;
        // The fonts ready by the pages now near, as they are built.
        _fontsNear = _fontsNearOf(number);
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
      // Its button in the top bar; with the bar folded away, and in full
      // screen, over the page's header, the lamp and the rest beside it.
      open: _riwayatOpen,
      tab: _fullScreen,
      // Full screen: a little apart (the user, 2026-11-13).
      beside: _tools(small: true, gap: 8),
      // «الجمع للقراءات العشر»: a screen of its own, at the page read.
      onJam: () => Navigator.of(context)
          .push(
            MaterialPageRoute<int>(
              builder: (_) => JamScreen(
                quran: _quran,
                variants: widget.variants,
                page: _page,
                settings: widget.settings,
              ),
            ),
          )
          .then(_backFromJam),
      // «جمع الروايات المختارة»: the same, the riwayat chosen alone.
      onJamSelected: (chosen) => Navigator.of(context)
          .push(
            MaterialPageRoute<int>(
              builder: (_) => JamScreen(
                quran: _quran,
                variants: widget.variants,
                page: _page,
                settings: widget.settings,
                riwayat: chosen,
              ),
            ),
          )
          .then(_backFromJam),
      child: _withHint(book),
    );

    if (_fullScreen) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: SafeArea(child: pages)),
            // Below the frame, on the line of the page's number: it never
            // covers the text nor the frame's band.
            PositionedDirectional(
              bottom: MediaQuery.paddingOf(context).bottom + 1,
              start: 16,
              child: Material(
                color: MushafColors.green.withAlpha(170),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Tooltip(
                  message: 'إنهاء ملء الشاشة',
                  child: InkWell(
                    key: const ValueKey('exit-full-screen'),
                    onTap: () => _setFullScreen(false),
                    child: const SizedBox.square(
                      dimension: 24,
                      child: Icon(
                        Icons.fullscreen_exit,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
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
                      _RiwayatButton(open: _riwayatOpen),
                      _tools(small: false),
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
                      // «شكل المصحف»: its frames and colours on a ring (the
                      // user, 2026-11-14).
                      RaisedIcon(
                        key: const ValueKey('mushaf-style-button'),
                        icon: Icons.palette_outlined,
                        tooltip: 'شكل المصحف',
                        color: _stylesOpen ? MushafColors.gold : null,
                        onTap: () => setState(() => _stylesOpen = !_stylesOpen),
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
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  _CollapsibleReaderBar(open: _topBarOpen, child: topBar),
                  if (_topBarOpen)
                    _barHandle(top: true)
                  else
                    const SizedBox(height: _handleHeight),
                  // Over the page, the page in sight below it: a look
                  // touched is seen on it at once.
                  if (_stylesOpen) MushafStyleRing(settings: widget.settings),
                  Expanded(child: pages),
                  if (_landscape) ...[
                    _barHandle(top: false),
                    _CollapsibleReaderBar(
                      open: _bottomBarOpen,
                      child: bottomBar,
                    ),
                  ] else
                    bottomBar,
                ],
              ),
            ),
            // Over the page: its side of the mushaf reaching down to the frame.
            if (!_topBarOpen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _barHandle(top: true),
              ),
          ],
        ),
      ),
    );
  }

  /// Beside «الرواة»: the lamp, the mutashabihat's button and the small icon
  /// of the side of the mushaf the page lies on; [small] on the page's
  /// header, clear of the frame.
  Widget _tools({required bool small, bool side = true, double? gap}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: gap ?? (small ? 3 : 2)),
        child: _GlowLamp(
          settings: widget.settings,
          small: small,
          gap: gap ?? 4,
          onTap: _toggleGlow,
          onLongPress: () => GlowUsulScreen.open(
            context,
            settings: widget.settings,
            variants: widget.variants,
            quran: _quran,
          ),
        ),
      ),
      if (side)
        _side(
          width: small ? 24 : 32,
          // One icon flown to: the one in sight.
          keyed: small ? _fullScreen : _topBarOpen,
        ),
    ],
  );

  /// The small icon of the side of the mushaf the page lies on: off for
  /// now (the user, 2026-11-12), its two pictures after every turn a cost
  /// to weak phones. True brings it back.
  static const showMushafSide = true;

  /// The small icon of the side of the mushaf the page lies on.
  Widget _side({required double width, required bool keyed, double? height}) =>
      _twoPages || _turning || !showMushafSide
      ? const SizedBox()
      : Tooltip(
          message: _quran.isRightPage(_page)
              ? 'الصفحة في يمين المصحف'
              : 'الصفحة في يسار المصحف',
          child: GestureDetector(
            onTap: () => _showSide(fly: true),
            child: OpenMushafView(
              key: keyed ? _sideIcon : null,
              right: _quran.isRightPage(_page),
              width: width,
              height: height,
              current: _currentPicture,
              facing: _facingPicture,
            ),
          ),
        );

  /// The top bar folded away: «الرواة», the lamp and the rest beside its
  /// handle, over the top of the page; the side of the mushaf as tall as the
  /// room down to the frame, small again while the riwayat are let down.
  Widget _foldedBar(Widget handle) => ValueListenableBuilder(
    valueListenable: _riwayatOpen,
    builder: (context, open, _) {
      Widget band(Widget child) => SizedBox(
        height: _handleHeight,
        child: Center(child: child),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          band(_RiwayatButton(open: _riwayatOpen, small: true)),
          band(_tools(small: true, side: false)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            // As tall as the buttons, down to their lower edge: taller, in
            // landscape, it came down over the bar of the riwayat above the
            // page (the user, 2026-11-13).
            child: _side(width: 24, height: _handleHeight - 2, keyed: true),
          ),
          const SizedBox(width: 10),
          band(handle),
        ],
      );
    },
  );

  static const _handleHeight = 24.0;

  Widget _barHandle({required bool top}) {
    final open = top ? _topBarOpen : _bottomBarOpen;
    final label = top ? 'الشريط العلوي' : 'شريط التنقل السفلي';
    final handle = Semantics(
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
              // The ring of the looks folded away with the bar it opens from.
              if (open) _stylesOpen = false;
              // The riwayat folded away with the bar they open from.
              if (open) _riwayatOpen.value = false;
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
                // The top bar folded: the icon of a menu, to open it (the
                // user, 2026-11-13); open, an arrow up to fold it. The bar
                // below the other way about.
                top
                    ? (open ? Icons.keyboard_arrow_up : Icons.menu_rounded)
                    : (open
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up),
                key: ValueKey(
                  top && !open ? 'top-bar-menu-icon' : 'bar-arrow-icon',
                ),
                size: 22,
                color: MushafColors.green,
              ),
            ),
          ),
        ),
      ),
    );
    // The top bar folded away: its room kept, the row over the page.
    if (top && !open) return _foldedBar(handle);
    return SizedBox(
      height: _handleHeight,
      child: Center(child: handle),
    );
  }

  /// The page area with the right / left hint flying to the top bar.
  Widget _withHint(Widget pages) => Stack(
    key: _hintArea,
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
            // Just under the small icon beside the lamp.
            target: _hintTarget(),
          ),
        ),
    ],
  );

  /// Where the small icon of the page's side is, over the page area, as
  /// laid out last.
  Alignment _hintTarget() {
    final icon = _sideIcon.currentContext?.findRenderObject();
    final area = _hintArea.currentContext?.findRenderObject();
    if (icon is! RenderBox ||
        area is! RenderBox ||
        !icon.hasSize ||
        !area.hasSize ||
        !icon.attached ||
        !area.attached) {
      return const Alignment(0, -1.04);
    }
    final at = area.globalToLocal(
      icon.localToGlobal(icon.size.bottomCenter(Offset.zero)),
    );
    return Alignment(
      at.dx / area.size.width * 2 - 1,
      at.dy / area.size.height * 2 - 1,
    );
  }

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

/// Beside «الرواة»: the lamp of «تنبيه الاختلافات» (a tap lights the words
/// that differ from Hafs, its rays flickering, or puts them out; held, it
/// opens the usul it lights) and the button of the mutashabihat.
class _GlowLamp extends StatefulWidget {
  const _GlowLamp({
    required this.settings,
    this.small = false,
    required this.onTap,
    required this.onLongPress,
    this.gap = 4,
  });

  /// On the page's header: smaller, clear of the frame.
  final bool small;

  /// Between the lamp and the mutashabihat's button.
  final double gap;

  final ReaderSettings settings;
  final VoidCallback onTap;

  /// Held: the usul of the hamesh, each lit or not.
  final VoidCallback onLongPress;

  @override
  State<_GlowLamp> createState() => _GlowLampState();
}

class _GlowLampState extends State<_GlowLamp>
    with SingleTickerProviderStateMixin {
  double get _size => widget.small ? 18 : 30;

  /// The rays: drawn still while the lamp is lit, not flickering: their
  /// flicker drew the whole screen again (the glow's shadows with it) some
  /// 26 times a second, the weak phone kept busy without a touch (the
  /// user, 2026-11-12).
  late final _rays = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _rays.dispose();
    super.dispose();
  }

  void _syncRays(bool lit) {
    if (_rays.isAnimating) _rays.stop();
    _rays.value = lit ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final lit = widget.settings.diffAlert != null;
      _syncRays(lit);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _lamp(lit),
          SizedBox(width: widget.gap),
          _mutashabihat(),
        ],
      );
    },
  );

  Widget _lamp(bool lit) => Tooltip(
    // Held, it opens the usul it lights.
    triggerMode: TooltipTriggerMode.manual,
    message: lit ? 'إطفاء توهج الاختلافات' : 'توهج الاختلافات',
    child: GestureDetector(
      key: const ValueKey('glow-lamp'),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
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
                size: widget.small ? 12 : 18,
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
              size: widget.small ? 11 : 17,
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
