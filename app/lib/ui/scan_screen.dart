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

/// Point the camera at a page of a printed mushaf: the page is recognised
/// and opened in the app with the riwayat chosen here.
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

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _camera;
  late final _scanner = PageScanner(PageMatcher(widget.quran));
  String? _error;
  bool _busy = false;
  ({int page, double score})? _found;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
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
      );
      await camera.initialize();
      await camera.setFocusMode(FocusMode.auto);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تشغيل الكاميرا: $e');
    }
  }


  Future<void> _scan() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() {
      _busy = true;
      _found = null;
      _notFound = false;
    });
    try {
      final photo = await camera.takePicture();
      final found = await _scanner.scan(photo.path);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _found = found;
        _notFound = found == null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة الصفحة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          // Where to put the page.
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.86,
                heightFactor: 0.62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: MushafColors.gold, width: 2.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
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
                _BottomPanel(
                  busy: _busy,
                  found: _found,
                  notFound: _notFound,
                  quran: widget.quran,
                  onScan: _scan,
                  onOpen: (page) => widget.onOpen(page),
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
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Column(
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
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.busy,
    required this.found,
    required this.notFound,
    required this.quran,
    required this.onScan,
    required this.onOpen,
  });

  final bool busy;
  final ({int page, double score})? found;
  final bool notFound;
  final QuranRepository quran;
  final VoidCallback onScan;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final f = found;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: f != null
                ? Column(
                    key: const ValueKey('found'),
                    children: [
                      Text(
                        'صفحة ${f.page} • سورة ${quran.surah(quran.page(f.page).first.surah).nameAr}',
                        style: TextStyle(
                          fontFamily: 'Hafs',
                          fontSize: 22,
                          color: MushafColors.gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MushafColors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => onOpen(f.page),
                        icon: const Icon(Icons.menu_book),
                        label: const Text('افتح الصفحة بالروايات المختارة'),
                      ),
                    ],
                  )
                : Text(
                    busy
                        ? 'جارٍ قراءة الصفحة…'
                        : notFound
                            ? 'لم أتعرف على الصفحة. قرّب الكاميرا واجعل الصفحة كاملة داخل الإطار.'
                            : 'اجعل الصفحة داخل الإطار ثم اضغط للتعرف عليها.',
                    key: ValueKey('$busy$notFound'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox.square(
            dimension: 72,
            child: busy
                ? const CircularProgressIndicator(color: Colors.white)
                : FloatingActionButton.large(
                    heroTag: 'scan',
                    backgroundColor: MushafColors.gold,
                    onPressed: onScan,
                    child: const Icon(Icons.document_scanner_outlined,
                        size: 34, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
