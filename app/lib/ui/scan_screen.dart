import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/page_matcher.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../services/page_scanner.dart';
import '../state/reader_settings.dart';
import 'theme.dart';

/// Point the camera at a page of a printed mushaf: once at least one riwaya
/// is chosen, the camera keeps reading until it recognises the page, then
/// opens it in the app with those riwayat.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.settings,
    required this.onOpen,
  });

  final QuranRepository quran;
  final VariantRepository variants;
  final ReaderSettings settings;

  /// Opens the mushaf at a page.
  final ValueChanged<int> onOpen;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  late final _scanner = PageScanner(PageMatcher(widget.quran));
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  String? _error;
  bool _running = true;
  bool _opened = false;
  Completer<Frame>? _wantFrame;
  int? _lastPage;
  int _attempts = 0;

  bool get _ready => widget.settings.selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    _startCamera();
  }

  @override
  void dispose() {
    _running = false;
    widget.settings.removeListener(_onSettings);
    _sweep.dispose();
    final camera = _camera;
    _camera = null;
    camera?.stopImageStream().catchError((_) {}).whenComplete(camera.dispose);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  Future<void> _startCamera() async {
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
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      await camera.setFocusMode(FocusMode.auto).catchError((_) {});
      final rotation = Platform.isIOS ? 0 : back.sensorOrientation;
      // Keep only a frame that the reading loop asked for.
      await camera.startImageStream((image) {
        final want = _wantFrame;
        if (want != null && !want.isCompleted) {
          _wantFrame = null;
          want.complete(Frame.copy(image, rotation));
        }
      });
      setState(() => _camera = camera);
      _loop();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تشغيل الكاميرا: $e');
    }
  }

  /// Reads a frame every ~1.5 s while at least one riwaya is chosen, until
  /// the page is recognised.
  Future<void> _loop() async {
    while (_running && mounted && !_opened) {
      if (!_ready) {
        await Future.delayed(const Duration(milliseconds: 400));
        continue;
      }
      final started = DateTime.now();
      try {
        final want = _wantFrame = Completer<Frame>();
        final frame = await want.future.timeout(const Duration(seconds: 3));
        final found = await _scanner.scan(frame);
        if (!mounted || !_running) return;
        setState(() => _attempts++);
        // Confident at once, or the same page twice in a row.
        if (found != null && (found.score >= 40 || found.page == _lastPage)) {
          _open(found.page);
          return;
        }
        _lastPage = found?.page;
      } catch (e) {
        debugPrint('scan: $e');
      }
      final spent = DateTime.now().difference(started);
      if (spent < const Duration(milliseconds: 1500)) {
        await Future.delayed(const Duration(milliseconds: 1500) - spent);
      }
    }
  }

  void _open(int page) {
    _opened = true;
    _running = false;
    HapticFeedback.heavyImpact();
    widget.onOpen(page);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            Center(child: CameraPreview(camera))
          else
            Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
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
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.88,
                heightFactor: 0.66,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: MushafColors.gold, width: 2.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _ready
                      ? AnimatedBuilder(
                          animation: _sweep,
                          builder: (context, _) => Align(
                            alignment: Alignment(0, _sweep.value * 2 - 1),
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: MushafColors.gold,
                                boxShadow: [
                                  BoxShadow(
                                    color: MushafColors.gold.withAlpha(160),
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
                _TopPanel(variants: widget.variants, settings: widget.settings),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                              : _attempts == 0
                                  ? 'جارٍ قراءة الصفحة… اجعلها كاملة داخل الإطار.'
                                  : 'جارٍ البحث عن الصفحة… قرّب الكاميرا وثبّتها (محاولة $_attempts).',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      margin: const EdgeInsets.all(10),
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
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text('الروايات التي تظهر على الصفحة:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final q in qiraat)
                  for (final r in q.riwayat)
                    if (r.id != hafsId && variants.isAvailable(r.id))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: FilterChip(
                          label: Text(r.nameAr),
                          selected: settings.selected.contains(r.id),
                          selectedColor: q.color.withAlpha(120),
                          avatar: CircleAvatar(backgroundColor: q.color),
                          showCheckmark: false,
                          onSelected: (on) {
                            final next = {...settings.selected};
                            on ? next.add(r.id) : next.remove(r.id);
                            settings.setSelected(next);
                          },
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
