import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/page_matcher.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/quran.dart';
import '../services/page_scanner.dart';
import '../services/qcf_fonts.dart';
import '../state/reader_settings.dart';
import 'mushaf_page.dart';
import 'riwayat_panel.dart';
import 'theme.dart';
import 'ayah_sheet.dart';
import 'variant_sheet.dart';

/// Point the camera at a page of a printed mushaf: once at least one riwaya
/// is chosen, the camera keeps reading, and each page it recognises is shown
/// over it as in the mushaf, with those riwayat, ready to open in the mushaf.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
    required this.onOpen,
  });

  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;

  /// Opens the mushaf at a page; completes when the reader comes back.
  final Future<void> Function(int page) onOpen;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _camera;
  late final _scanner = PageScanner(PageMatcher(widget.quran));
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  String? _error;

  /// The camera reads frames while this screen is in front.
  bool _running = true;
  Completer<Frame?>? _wantFrame;
  int _cameraGeneration = 0;
  Future<void> _cameraTasks = Future<void>.value();
  int? _lastPage;
  int _attempts = 0;

  /// The page last recognised, whose readings are shown over the camera.
  int? _found;

  bool get _ready => widget.settings.selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettings);
    _onSettings();
    unawaited(
      _scanner.warmUp().catchError((Object e) {
        debugPrint('scan warmup: $e');
      }),
    );
    _startCamera();
  }

  @override
  void dispose() {
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettings);
    _sweep.dispose();
    _stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_running) return; // the mushaf is open over this screen
      _startCamera();
    } else {
      _stopCamera();
    }
  }

  /// The readings of newly chosen riwayat are loaded, then shown.
  Future<void> _onSettings() async {
    if (mounted) setState(() {});
    await widget.variants.ensureLoaded(widget.settings.selected);
    if (mounted) setState(() {});
  }

  Future<void> _stopCamera() {
    _cameraGeneration++;
    final camera = _camera;
    _camera = null;
    final pending = _wantFrame;
    _wantFrame = null;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    return _cameraTasks = _cameraTasks.then((_) async {
      if (camera == null) return;
      await camera.stopImageStream().catchError((_) {});
      await camera.dispose().catchError((_) {});
    });
  }

  Future<void> _startCamera() {
    if (_camera != null) return Future<void>.value();
    final generation = ++_cameraGeneration;
    return _cameraTasks = _cameraTasks.then(
      (_) => _initializeCamera(generation),
    );
  }

  Future<void> _initializeCamera(int generation) async {
    if (!mounted || !_running || generation != _cameraGeneration) return;
    CameraController? opening;
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      opening = camera;
      await camera.initialize();
      if (!mounted || !_running || generation != _cameraGeneration) {
        await camera.dispose();
        return;
      }
      await camera.setFocusMode(FocusMode.auto).catchError((_) {});
      // Keep only a frame that the reading loop asked for.
      await camera.startImageStream((image) {
        final want = _wantFrame;
        if (want != null && !want.isCompleted) {
          _wantFrame = null;
          final rotation = Platform.isIOS
              ? 0
              : scanFrameRotation(
                  back.sensorOrientation,
                  camera.value.deviceOrientation,
                );
          want.complete(Frame.copy(image, rotation));
        }
      });
      if (!mounted || !_running || generation != _cameraGeneration) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
      _loop(camera);
    } catch (e) {
      await opening?.dispose().catchError((_) {});
      if (mounted && generation == _cameraGeneration) {
        setState(() => _error = 'تعذر تشغيل الكاميرا: $e');
      }
    }
  }

  /// Reads frames one after the other while at least one riwaya is chosen,
  /// for as long as [camera] is open: each page recognised replaces the
  /// last one.
  Future<void> _loop(CameraController camera) async {
    while (_running && mounted && identical(_camera, camera)) {
      if (!_ready) {
        await Future.delayed(const Duration(milliseconds: 400));
        continue;
      }
      try {
        await _scanner.idle;
        if (!mounted || !identical(_camera, camera)) return;
        final want = _wantFrame = Completer<Frame?>();
        final frame = await want.future.timeout(const Duration(seconds: 3));
        if (frame == null || !mounted || !identical(_camera, camera)) return;
        final found = await _scanner.scan(
          frame,
          mode: widget.settings.scanMode,
        );
        if (!mounted || !identical(_camera, camera)) return;
        _attempts++;
        // Confident at once (photographed pages read as noise score up to
        // ~20), or the same page twice in a row.
        if (found != null &&
            found.page != _found &&
            (found.score >= 34 || found.page == _lastPage)) {
          HapticFeedback.heavyImpact();
          setState(() => _found = found.page);
        } else if (_found == null) {
          setState(() {});
        }
        _lastPage = found?.page;
      } catch (e) {
        debugPrint('scan: $e');
        // No frame or a failed read: a moment before the next.
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// Opens the page in the mushaf with the chosen riwayat; the camera is
  /// closed meanwhile and reads again on coming back.
  Future<void> _open(int page) async {
    _running = false;
    await _stopCamera();
    if (mounted) setState(() {});
    await widget.onOpen(page);
    if (!mounted) return;
    _running = true;
    _lastPage = null;
    _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final found = _found;
    final mode = widget.settings.scanMode;
    return Scaffold(
      backgroundColor: Colors.black,
      // The riwayat chosen as in the mushaf: «الرواة» at the top.
      // Below the phone's own bar: there, «الرواة» could not be touched.
      body: SafeArea(
        bottom: false,
        child: RiwayatPanel(
          settings: widget.settings,
          variants: widget.variants,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (camera != null && camera.value.isInitialized)
                Center(
                  child: CameraPreview(
                    camera,
                    // Over the picture itself, where the frame is read.
                    child: mode == ScanMode.page || !_ready
                        ? null
                        : _BoxGuide(mode: mode, sweep: _sweep),
                  ),
                )
              else
                Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                ),
              // Blurred until a riwaya is chosen.
              if (!_ready)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: ColoredBox(color: Colors.black.withAlpha(90)),
                  ),
                ),
              // The guide frame, with a sweeping line while reading.
              if (mode == ScanMode.page)
                IgnorePointer(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.88,
                      heightFactor: 0.66,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: MushafColors.gold,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: _ready
                            ? AnimatedBuilder(
                                animation: _sweep,
                                builder: (context, _) => Align(
                                  alignment: Alignment(0, _sweep.value * 2 - 1),
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MushafColors.gold,
                                      boxShadow: [
                                        BoxShadow(
                                          color: MushafColors.gold.withAlpha(
                                            160,
                                          ),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    _TopPanel(
                      variants: widget.variants,
                      settings: widget.settings,
                    ),
                    const Spacer(),
                    if (found != null && _ready)
                      _PageReadings(
                        page: found,
                        quran: widget.quran,
                        variants: widget.variants,
                        mutashabihat: widget.mutashabihat,
                        settings: widget.settings,
                        onOpen: () => _open(found),
                      )
                    else
                      _hint(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the circle read last: the number, a «؟» for a digit not read.
  String get _lastRead {
    final n = _scanner.lastNumber;
    if (n == null) return 'لم يظهر رقم في الدائرة بعد.';
    final shown = n.runes
        .map((c) => c == 0x3F ? '؟' : String.fromCharCode(c - 0x30 + 0x0660))
        .join();
    return 'قرأت: $shown';
  }

  Widget _hint() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(160),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(
          _ready ? Icons.document_scanner : Icons.touch_app,
          color: MushafColors.gold,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            !_ready
                ? 'اختر رواية واحدة على الأقل من الأعلى لبدء التعرف على الصفحة.'
                : switch (widget.settings.scanMode) {
                    ScanMode.number =>
                      'ضع رقم الصفحة داخل الدائرة أسفل الشاشة، ولك أن تقرّبه.'
                          '${_attempts == 0 ? '' : '\n$_lastRead'}',
                    ScanMode.line => 'ضع سطرًا من منتصف الصفحة داخل المستطيل.',
                    ScanMode.page =>
                      _attempts == 0
                          ? 'وجّه الكاميرا للصفحة داخل الإطار وثبّتها لحظة.'
                          : 'جارٍ التعرف… اجعل سطور منتصف الصفحة واضحة (محاولة $_attempts).',
                  },
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

/// The page recognised, over the camera, drawn as in the mushaf: the chosen
/// riwayat on its words and in its hamesh. A button opens it in the mushaf;
/// it folds down to its title so the camera can be aimed at another page,
/// which then takes its place.
class _PageReadings extends StatefulWidget {
  const _PageReadings({
    required this.page,
    required this.quran,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
    required this.onOpen,
  });

  final int page;
  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;
  final VoidCallback onOpen;

  @override
  State<_PageReadings> createState() => _PageReadingsState();
}

class _PageReadingsState extends State<_PageReadings> {
  bool _folded = false;

  @override
  void initState() {
    super.initState();
    _loadFont();
  }

  @override
  void didUpdateWidget(_PageReadings old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      _folded = false; // a new page opens unfolded
      _loadFont();
    }
  }

  void _loadFont() {
    if (widget.settings.qcfFont) QcfFonts.instance.ensure([widget.page]);
  }

  void _openWord(Ayah ayah, int word) {
    final readings = widget.variants
        .at(widget.settings.selected, ayah.surah, ayah.number, word)
        .isNotEmpty;
    if (!readings) return _openAyah(ayah);
    VariantSheet.show(
      context,
      VariantSheet(
        ayah: ayah,
        word: word,
        surahName: widget.quran.surah(ayah.surah).nameAr,
        settings: widget.settings,
        variants: widget.variants,
        surahNames: [for (final s in widget.quran.surahs) s.nameAr],
        onAyah: () {
          Navigator.of(context).pop();
          _openAyah(ayah);
        },
      ),
    );
  }

  void _openAyah(Ayah ayah) => AyahSheet.show(
    context,
    ayah: ayah,
    quran: widget.quran,
    settings: widget.settings,
    variants: widget.variants,
  );

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final surah = widget.quran
        .surah(widget.quran.page(page).first.surah)
        .nameAr;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: _folded ? 'إظهار الصفحة' : 'طي الصفحة',
            icon: Icon(_folded ? Icons.expand_less : Icons.expand_more),
            color: MushafColors.green,
            onPressed: () => setState(() => _folded = !_folded),
          ),
          Expanded(
            child: Text(
              'صفحة $page • سورة $surah',
              style: TextStyle(
                color: MushafColors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onOpen,
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('فتح في المصحف'),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      height: _folded ? null : MediaQuery.sizeOf(context).height * 0.62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MushafColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MushafColors.gold, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (!_folded)
            Expanded(
              child: ListenableBuilder(
                listenable: QcfFonts.instance,
                builder: (context, _) => MushafPage(
                  key: ValueKey(page),
                  page: page,
                  quran: widget.quran,
                  variants: widget.variants,
                  mutashabihat: widget.mutashabihat,
                  settings: widget.settings,
                  onWordTap: _openWord,
                  onAyahTap: _openAyah,
                  qcf:
                      widget.settings.qcfFont &&
                      QcfFonts.instance.isReady(page),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Title, back button and the riwayat to show once the page is open.
class _TopPanel extends StatelessWidget {
  const _TopPanel({required this.variants, required this.settings});

  final VariantRepository variants;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Room above it for the arrow of «الرواة».
      margin: const EdgeInsets.fromLTRB(10, 30, 10, 10),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  'وجّه الكاميرا إلى صفحة من المصحف',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // What is read of the page: its number is the quickest.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: SegmentedButton<ScanMode>(
              key: const ValueKey('scan-mode'),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: MushafColors.gold,
                side: BorderSide(color: MushafColors.gold),
              ),
              segments: [
                for (final m in ScanMode.values)
                  ButtonSegment(
                    value: m,
                    label: Text(m.labelAr),
                    icon: Icon(switch (m) {
                      ScanMode.number => Icons.tag,
                      ScanMode.line => Icons.short_text,
                      ScanMode.page => Icons.document_scanner,
                    }),
                  ),
              ],
              selected: {settings.scanMode},
              onSelectionChanged: (m) => settings.scanMode = m.single,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where [mode] reads the frame, drawn over the camera's picture at the
/// same place: a small circle for the page number, a strip for a line.
class _BoxGuide extends StatelessWidget {
  const _BoxGuide({required this.mode, required this.sweep});

  final ScanMode mode;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final box = mode == ScanMode.number ? numberBox : lineBox;
    final round = mode == ScanMode.number;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, size) {
          final w = size.maxWidth * box.width, h = w * box.aspect;
          return Stack(
            children: [
              Positioned(
                key: ValueKey('scan-box-${mode.name}'),
                left: size.maxWidth * box.x - w / 2,
                top: size.maxHeight * box.y - h / 2,
                width: w,
                height: h,
                child: AnimatedBuilder(
                  animation: sweep,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      shape: round ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: round ? null : BorderRadius.circular(8),
                      border: Border.all(color: MushafColors.gold, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: MushafColors.gold.withAlpha(
                            (60 + 120 * sweep.value).round(),
                          ),
                          blurRadius: 14,
                        ),
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
  }
}
