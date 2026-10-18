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
import 'book_pager.dart';
import 'mushaf_page.dart';
import 'page_side_hint.dart';
import 'mutashabihat_sheet.dart';
import 'qiraat_sheet.dart';
import 'riwayat_menu.dart';
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

  /// Double blink: opens the mutashabih on the line being looked at; while
  /// the mutashabihat are open, moves to the next place.
  final _blink = BlinkDetector();
  StreamSubscription<EyeGesture>? _blinks;

  /// Calibration: 0 waits for a double blink on the first line, 1 on the
  /// last line; -1 when calibrated (or blinking is off).
  int _calibration = -1;
  double? _calibrationTop;
  final _steps = StreamController<int>.broadcast();

  /// The action just done by an eye gesture, shown briefly.
  String? _gestureLabel;
  Timer? _gestureLabelTimer;
  bool _sheetOpen = false;
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

  bool get _twoPages => widget.settings.twoPages;

  /// Once the page is drawn: picture it and its facing page, then show
  /// where it lies in the open mushaf.
  void _showSide() {
    if (_twoPages) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pager = _pager.currentState;
      if (pager != null) {
        final index = _page - 1;
        final facing = isRightPage(_page) ? index + 1 : index - 1;
        _currentPicture?.dispose();
        _facingPicture?.dispose();
        _currentPicture = pager.capture(index);
        _facingPicture = pager.capture(facing);
      }
      _hint.forward(from: 0);
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
    _steps.close();
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
        _calibration = -1;
        if (!mounted) return;
        widget.settings.blinkToOpen = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تشغيل الكاميرا الأمامية. تحقق من إذن الكاميرا.'),
        ));
      }
    } else {
      await _blink.stop();
    }
    final calibrate = widget.settings.blinkToOpen &&
        !widget.settings.gazeCalibrated &&
        _blink.isRunning;
    if (calibrate && _calibration < 0) {
      setState(() => _calibration = 0);
    } else if (!calibrate && _calibration >= 0) {
      setState(() => _calibration = -1);
    }
  }

  /// Eye gestures: winks turn pages (or move between mutashabihat places),
  /// three blinks open / close the mutashabihat of the line looked at, one
  /// deliberate blink moves to the next place.
  void _onGesture(EyeGesture gesture) {
    switch (gesture) {
      case Wink(:final left):
        final next = left != widget.settings.swapEyes;
        if (_calibration >= 0) return;
        if (_sheetOpen) {
          _steps.add(next ? 1 : -1);
          _announce(next ? 'الموضع التالي' : 'الموضع السابق');
        } else if (!_zoomed) {
          _pager.currentState?.turn(next ? 1 : -1);
          _announce(next ? 'الصفحة التالية' : 'الصفحة السابقة');
        }
      case DeliberateBlink():
        if (_sheetOpen && _calibration < 0) {
          _steps.add(1);
          _announce('الموضع التالي');
        }
      case TripleBlink(:final gaze):
        _onTripleBlink(gaze);
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

  void _onTripleBlink(double? gaze) {
    if (_calibration >= 0) {
      _announce(_calibration == 0 ? 'السطر الأول ✓' : 'السطر الأخير ✓');
      if (gaze == null) return;
      if (_calibration == 0) {
        setState(() {
          _calibrationTop = gaze;
          _calibration = 1;
        });
      } else {
        widget.settings.setGaze(_calibrationTop, gaze);
        setState(() => _calibration = -1);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تمت المعايرة. انظر إلى سطر فيه متشابه وارمش ثلاث مرات.'),
        ));
      }
      return;
    }
    if (_sheetOpen) {
      Navigator.of(context).pop(); // the mutashabihat sheet
      _announce('إغلاق المتشابهات');
      return;
    }
    final target = _mutashabihAt(_gazeFraction(gaze));
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا توجد متشابهات في هذه الصفحة.'),
      ));
      return;
    }
    final (ayah, word) = target;
    _announce('فتح المتشابهات');
    _openMutashabihat(
        widget.mutashabihat.placesFor(ayah.surah, ayah.number, word));
  }

  /// How far down the page the reader looks: 0 first line .. 1 last line.
  double? _gazeFraction(double? gaze) {
    final s = widget.settings;
    if (gaze == null || !s.gazeCalibrated) return null;
    return ((gaze - s.gazeTop!) / (s.gazeBottom! - s.gazeTop!)).clamp(0.0, 1.0);
  }

  /// The mutashabih on the page's line nearest to [fraction] of the page
  /// (the first on the page without a gaze).
  (Ayah, int)? _mutashabihAt(double? fraction) {
    final lines = widget.quran.lines(_page);
    (Ayah, int)? best;
    var bestDistance = double.infinity;
    void consider(Ayah a, int w, double position) {
      if (!widget.mutashabihat.isShared(a.surah, a.number, w)) return;
      if (widget.mutashabihat.placesFor(a.surah, a.number, w).length < 2) return;
      final d = fraction == null ? position : (position - fraction).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = (a, w);
      }
    }

    if (lines == null) {
      for (final a in widget.quran.page(_page)) {
        for (var w = 0; w < a.words.length; w++) {
          consider(a, w, 0);
        }
      }
      return best;
    }
    for (final (i, line) in lines.indexed) {
      if (line is! TextLine) continue;
      final position = lines.length < 2 ? 0.0 : i / (lines.length - 1);
      for (final (a, w) in line.words) {
        consider(a, w, position);
      }
    }
    return best;
  }

  void _onFonts() {
    if (mounted) setState(() {});
  }

  /// The printed-mushaf fonts of the pages around [page].
  void _loadFonts(int page) {
    if (widget.settings.qcfFont) {
      QcfFonts.instance.ensure([page, page + 1, page - 1, page + 2, page - 2]);
    }
  }

  /// Loads newly selected riwayat before the pages are redrawn with them.
  Future<void> _onSettings() async {
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

  Future<void> _openMutashabihat(List<MutashabihPlace> places) async {
    _sheetOpen = true;
    await MutashabihatSheet.show(
      context,
      places: places,
      quran: widget.quran,
      onGo: _goToPage,
      steps: _steps.stream,
    );
    _sheetOpen = false;
  }

  void _goToPage(int page) =>
      _pager.currentState?.jumpTo(_twoPages ? (page - 1) ~/ 2 : page - 1);

  void _setFullScreen(bool on) {
    SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    setState(() => _fullScreen = on);
  }

  @override
  Widget build(BuildContext context) {
    Widget page(int number, {required bool hamesh}) => MushafPage(
          page: number,
          quran: widget.quran,
          variants: widget.variants,
          mutashabihat: widget.mutashabihat,
          settings: widget.settings,
          onWordTap: _openWord,
          showHamesh: hamesh,
          onZoomChanged: (z) => setState(() => _zoomed = z),
          onPageNumberTap: _pickPage,
          qcf: widget.settings.qcfFont && QcfFonts.instance.isReady(number),
        );

    final two = _twoPages;
    final book = BookPager(
      key: _pager,
      // Two-page view turns a spread at a time: pages (1, 2), (3, 4), ...
      itemCount: two
          ? (QuranRepository.pageCount + 1) ~/ 2
          : QuranRepository.pageCount,
      initialIndex: two ? (_page - 1) ~/ 2 : _page - 1,
      enabled: !_zoomed,
      onPageChanged: (i) {
        final number = two ? 2 * i + 1 : i + 1;
        setState(() {
          _page = number;
          _zoomed = false;
        });
        widget.settings.page = number;
        _fetchOnline(number);
        _loadFonts(number);
        if (two && number < QuranRepository.pageCount) _fetchOnline(number + 1);
        _showSide();
      },
      // An opaque sheet, so a turning page never shows the one beneath.
      itemBuilder: (context, i) => ColoredBox(
        color: MushafColors.paper,
        child: two
            ? Row(
                // The right page (odd) first, as the mushaf lies open.
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(child: page(2 * i + 1, hamesh: false)),
                  const _Spine(),
                  Expanded(
                    child: 2 * i + 2 <= QuranRepository.pageCount
                        ? page(2 * i + 2, hamesh: false)
                        : const SizedBox(),
                  ),
                ],
              )
            : page(i + 1, hamesh: !_fullScreen),
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
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  _BarButton(
                    tooltip: 'الإعدادات',
                    icon: const Icon(Icons.tune, size: 22),
                    onPressed: () => QiraatSheet.show(
                        context, widget.settings, widget.variants),
                  ),
                  RiwayatMenu(
                    settings: widget.settings,
                    variants: widget.variants,
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
                    tooltip: two ? 'صفحة واحدة' : 'صفحتان متقابلتان',
                    icon: Icon(
                      two ? Icons.crop_portrait : Icons.auto_stories_outlined,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _pager = GlobalKey<BookPagerState>();
                        _zoomed = false;
                      });
                      widget.settings.twoPages = !two;
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
                  if (!two)
                    Tooltip(
                      message: isRightPage(_page)
                          ? 'الصفحة في يمين المصحف'
                          : 'الصفحة في يسار المصحف',
                      child: GestureDetector(
                        onTap: _showSide,
                        child: OpenMushafView(
                          right: isRightPage(_page),
                          width: 44,
                          current: _currentPicture,
                          facing: _facingPicture,
                        ),
                      ),
                    ),
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

  /// The page area with the right / left hint flying to the top bar, the
  /// gaze marker and the calibration prompt.
  Widget _withHint(Widget pages) => Stack(
        children: [
          Positioned.fill(child: pages),
          if (_blink.isRunning && widget.settings.gazeCalibrated)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<double?>(
                  valueListenable: _blink.gaze,
                  builder: (context, gaze, _) {
                    final f = _gazeFraction(gaze);
                    if (f == null) return const SizedBox();
                    return AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      // Lines span roughly 8%–92% of the page area.
                      alignment: Alignment(-1, -0.84 + f * 1.68),
                      child: const _GazeMarker(),
                    );
                  },
                ),
              ),
            ),
          if (_calibration >= 0)
            Positioned.fill(
              child: _CalibrationPrompt(firstLine: _calibration == 0),
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
                        horizontal: 18, vertical: 10),
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
                              color: Colors.white, fontWeight: FontWeight.bold),
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

/// Where the camera estimates the reader is looking: a soft glowing eye at
/// the page edge.
class _GazeMarker extends StatelessWidget {
  const _GazeMarker();

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MushafColors.green.withAlpha(60),
          boxShadow: [
            BoxShadow(color: MushafColors.green.withAlpha(120), blurRadius: 12),
          ],
        ),
        child: Icon(Icons.remove_red_eye, size: 16, color: MushafColors.green),
      );
}

/// Calibration: look at the first (then the last) line and blink twice.
class _CalibrationPrompt extends StatelessWidget {
  const _CalibrationPrompt({required this.firstLine});

  final bool firstLine;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: firstLine ? const Alignment(0, -0.82) : const Alignment(0, 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: MushafColors.paper.withAlpha(235),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MushafColors.green, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 18),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                firstLine ? Icons.arrow_upward : Icons.arrow_downward,
                color: MushafColors.green,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  firstLine
                      ? 'معايرة النظر (١/٢): انظر إلى السطر الأول من الصفحة ثم ارمش ثلاث مرات.'
                      : 'معايرة النظر (٢/٢): انظر الآن إلى السطر الأخير ثم ارمش ثلاث مرات.',
                  style: TextStyle(color: MushafColors.ink, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
