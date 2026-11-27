import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../services/qcf_fonts.dart';
import '../state/reader_settings.dart';
import 'mushaf_page.dart';

/// The opening of the app (the user, 2026-11-27): a mushaf alone in the
/// middle of the screen opens slowly on the page of «يَٰيَحۡيَىٰ خُذِ ٱلۡكِتَٰبَ
/// بِقُوَّةٖۖ» (مريم ١٢), in Hafs's rasm with every riwaya in its hamesh, the
/// ayah shaded; the ayah alone recited by Muhammad Siddiq al-Minshawi
/// (murattal), low, a faint sad echo behind his voice
/// (assets/audio/intro_yahya.wav, made as tool/intro_audio.md tells). Then
/// [next], the start page; a tap goes to it at once.
class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    required this.next,
    required this.mushafs,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
    this.sound = true,
  });

  /// The start page.
  final WidgetBuilder next;

  final Mushafs mushafs;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;

  /// The reader's settings, copied in memory for the page: never changed.
  final ReaderSettings settings;

  /// The recitation played (not in the tests).
  final bool sound;

  /// The whole opening.
  static const duration = Duration(milliseconds: 9500);

  /// When the recitation starts: as the page is seen.
  static const soundAt = Duration(milliseconds: 2600);

  /// The ayah.
  static const surah = 19, ayah = 12;

  /// The page drawn at this size, then fitted into the open mushaf.
  static const pageSize = Size(560, 860);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final _t =
      AnimationController(vsync: this, duration: IntroScreen.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _go();
        })
        ..forward();
  AudioPlayer? _player;
  Timer? _soundTimer;
  bool _gone = false;

  late final _quran = widget.mushafs.of(MushafEdition.madani);
  late final _page = _quran.pageOf(IntroScreen.surah, IntroScreen.ayah);

  /// Hafs's page, every riwaya in its hamesh.
  late final _all = {
    for (final q in qiraat)
      for (final r in q.riwayat)
        if (widget.variants.isAvailable(r.id)) r.id,
  };
  late final _settings = widget.settings.withChosen(_all)
    ..mode = DisplayMode.hamesh
    ..displayed = null;
  bool _loaded = false;

  /// The page as drawn, before it is fitted into the mushaf.
  final _pageBox = GlobalKey();

  /// Where «يَٰيَحۡيَىٰ خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖۖ» is on the page drawn, for the
  /// zoom on it; measured once the page is laid, again when it is drawn anew.
  Rect? _phrase;
  String? _measuredFor;
  bool _measuring = false;

  void _measure(String pageKey) {
    _measuring = false;
    final context = _pageBox.currentContext;
    final page = context?.findRenderObject();
    if (context == null || page is! RenderBox || !mounted) return;
    Rect? found;
    void visit(Element e) {
      final key = e.widget.key;
      if (key is ValueKey<String> &&
          key.value.startsWith(
            'ayah-shade:${IntroScreen.surah}:${IntroScreen.ayah}:',
          )) {
        final box = e.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final r = MatrixUtils.transformRect(
            box.getTransformTo(page),
            Offset.zero & box.size,
          );
          found = found?.expandToInclude(r) ?? r;
        }
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (found == null) return;
    setState(() {
      _phrase = found;
      _measuredFor = pageKey;
    });
  }

  @override
  void initState() {
    super.initState();
    // The page's riwayat and its print's font, while the mushaf is shut.
    _loaded = _all.every(widget.variants.isLoaded);
    if (!_loaded) {
      widget.variants.ensureLoaded(_all).then((_) {
        if (mounted) setState(() => _loaded = true);
      }, onError: (Object _) {});
    }
    QcfFonts.instance.addListener(_fontReady);
    QcfFonts.instance.ensure([_page]);
    if (widget.sound) _soundTimer = Timer(IntroScreen.soundAt, _play);
  }

  void _fontReady() {
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    try {
      final player = _player = AudioPlayer();
      await player.setAsset('assets/audio/intro_yahya.wav');
      await player.setVolume(.8);
      if (!_gone) await player.play();
    } catch (_) {
      // No sound on this device: the opening without it.
    }
  }

  void _go() {
    if (_gone || !mounted) return;
    _gone = true;
    _soundTimer?.cancel();
    _player?.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (context, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _t.dispose();
    _soundTimer?.cancel();
    QcfFonts.instance.removeListener(_fontReady);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qcf = QcfFonts.instance.isReady(_page);
    // Built again only when its font or its riwayat come, not each frame.
    final pageKey = 'intro-page:$qcf:$_loaded';
    final page = MushafPage(
      key: ValueKey(pageKey),
      page: _page,
      quran: _quran,
      variants: widget.variants,
      mutashabihat: widget.mutashabihat,
      settings: _settings,
      onWordTap: (_, _) {},
      qcf: qcf,
      showHamesh: _loaded,
      // The ayah shaded.
      ayahShade: (a) =>
          a.surah == IntroScreen.surah && a.number == IntroScreen.ayah
          ? _Book.shade.withValues(alpha: .4)
          : null,
      // «يَٰيَحۡيَىٰ خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖۖ» alone, not the rest of the ayah.
      shadeWord: (_, w) => w < 4,
    );
    return GestureDetector(
      key: const ValueKey('intro'),
      behavior: HitTestBehavior.opaque,
      onTap: _go,
      child: Scaffold(
        backgroundColor: _Book.ground,
        body: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              // The phrase measured once the page has come, before the zoom.
              if (_t.value > .3 && _measuredFor != pageKey && !_measuring) {
                _measuring = true;
                SchedulerBinding.instance.addPostFrameCallback(
                  (_) => _measure(pageKey),
                );
              }
              return _Book(
                t: _t.value,
                area: box.biggest,
                page: page,
                pageBox: _pageBox,
                phrase: _phrase,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 0 before [a], 1 after [b], eased between.
double _fade(double t, double a, double b) =>
    Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// The mushaf: shut in the middle, its cover turning slowly open on its
/// spine (on the right, as an Arabic mushaf), the page beneath; then the
/// page brought near.
class _Book extends StatelessWidget {
  const _Book({
    required this.t,
    required this.area,
    required this.page,
    required this.pageBox,
    required this.phrase,
  });

  final double t;
  final Size area;
  final Widget page;
  final GlobalKey pageBox;

  /// «يَٰيَحۡيَىٰ خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖۖ» on the page drawn; null until measured.
  final Rect? phrase;

  static const ground = Color(0xFF071B15);
  static const shade = Color(0xFFE8B84A);
  static const gold = Color(0xFFE8B84A);
  static const paleGold = Color(0xFFF3D98B);

  @override
  Widget build(BuildContext context) {
    final shown = _fade(t, 0, .08) * (1 - _fade(t, .93, 1));
    final open = _fade(t, .085, .3);
    final near = _fade(t, .28, .4);
    // Then the ayah alone, brought near, the rest of the mushaf hidden (the
    // user, 2026-11-27).
    final zoom = phrase == null ? 0.0 : _fade(t, .45, .6);
    final ratio = IntroScreen.pageSize.width / IntroScreen.pageSize.height;
    // Shut: a book in the middle; open: the page filling the screen.
    final shutW = math.min(area.width * .62, area.height * .5 * ratio);
    final fullW = math.min(area.width * .98, area.height * .96 * ratio);
    final w = shutW + (fullW - shutW) * near;
    final h = w / ratio;
    final cover = open * math.pi;
    // The zoom: the phrase's middle to the screen's, as wide as most of it.
    final k = w / IntroScreen.pageSize.width;
    final origin = area.center(Offset.zero) - Offset(w / 2, h / 2);
    final center = area.center(Offset.zero);
    final p = phrase == null ? center : origin + phrase!.center * k;
    final most = phrase == null
        ? 1.0
        : math.min(
            area.width * .84 / (phrase!.width * k),
            area.height * .3 / (phrase!.height * k),
          );
    final scale = 1 + (most - 1) * zoom;
    final to = Offset.lerp(p, center, zoom)!;
    Offset seen(Offset q) => to + (q - p) * scale;
    final zoomed = Matrix4.identity()
      ..translateByDouble(to.dx, to.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);
    Matrix4 turned() => Matrix4.identity()
      ..setEntry(3, 2, .0012)
      ..rotateY(-cover);
    return Opacity(
      opacity: shown,
      // As big as the screen, the mushaf in its middle.
      child: SizedBox.fromSize(
        size: area,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Its light behind it.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: .75,
                    colors: [
                      Color.lerp(
                        ground,
                        const Color(0xFF1F5E47),
                        .6 + .4 * open,
                      )!,
                      ground,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform(
                transform: zoomed,
                child: Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The page, seen as the cover opens.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF6E9),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: gold.withValues(
                                    alpha: .25 + .25 * open,
                                  ),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: Opacity(
                              opacity: _fade(t, .14, .3),
                              child: FittedBox(
                                child: SizedBox.fromSize(
                                  key: pageBox,
                                  size: IntroScreen.pageSize,
                                  child: IgnorePointer(child: page),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The cover turning on the spine at the right; past the
                        // half, its lining.
                        if (cover < math.pi / 2)
                          Positioned.fill(
                            child: Transform(
                              alignment: Alignment.centerRight,
                              transform: turned(),
                              child: const _Cover(),
                            ),
                          )
                        else if (cover < math.pi * .98)
                          Positioned.fill(
                            child: Transform(
                              alignment: Alignment.centerRight,
                              transform: turned(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F3E30),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: gold, width: 2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The rest of the mushaf hidden, the phrase alone left lit.
            if (zoom > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Spot(
                      hole: Rect.fromPoints(
                        seen(origin + phrase!.topLeft * k),
                        seen(origin + phrase!.bottomRight * k),
                      ),
                      amount: zoom,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: .55 * _fade(t, .1, .2) * (1 - _fade(t, .9, 1)),
                child: const Text(
                  'المس الشاشة للمتابعة',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: 14,
                    color: paleGold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dark over all but the phrase: the screen's ground, a soft-edged
/// hole where the phrase is.
class _Spot extends CustomPainter {
  _Spot({required this.hole, required this.amount});

  final Rect hole;
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.saveLayer(all, Paint());
    canvas.drawRect(
      all,
      Paint()..color = _Book.ground.withValues(alpha: amount),
    );
    final pad = hole.height * .25;
    canvas.drawRRect(
      // Narrow at the sides: not the next word's first letter.
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          hole.left - pad * .15,
          hole.top - pad,
          hole.right + pad * .15,
          hole.bottom + pad,
        ),
        Radius.circular(pad),
      ),
      Paint()
        ..blendMode = BlendMode.clear
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pad * .35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Spot old) => old.hole != hole || old.amount != amount;
}

/// The mushaf's cover: green leather, a gold frame and its corners, a ring
/// and two stars, «القرآن الكريم» in gold in the middle.
class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      TextStyle title(double size) => TextStyle(
        fontFamily: 'Hafs',
        fontSize: w * size,
        height: 1.3,
        color: _Book.gold,
        shadows: const [Shadow(color: Color(0x88000000), blurRadius: 4)],
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D6B52), Color(0xFF14523F), Color(0xFF0B3528)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _CoverOrnament(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'القرآن',
                  textDirection: TextDirection.rtl,
                  style: title(.17),
                ),
                Text(
                  'الكريم',
                  textDirection: TextDirection.rtl,
                  style: title(.13),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CoverOrnament extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final w = size.width;
    final gold = Paint()
      ..color = _Book.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .014;
    // The spine on the right.
    canvas.drawRect(
      Rect.fromLTRB(r.right - w * .07, r.top, r.right, r.bottom),
      Paint()..color = const Color(0x44000000),
    );
    final frame = RRect.fromRectAndRadius(
      r.deflate(w * .07),
      Radius.circular(w * .02),
    );
    canvas.drawRRect(frame, gold);
    canvas.drawRRect(frame.deflate(w * .025), gold..strokeWidth = w * .006);
    // The ring round the title, a star above and below it.
    final c = r.center;
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * .62, height: w * .62),
      Paint()
        ..color = _Book.gold.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .008,
    );
    for (final dy in [-1.0, 1.0]) {
      _star(canvas, c + Offset(0, dy * size.height * .33), w * .07);
    }
    // A small star in each corner.
    for (final corner in [
      frame.outerRect.topLeft,
      frame.outerRect.topRight,
      frame.outerRect.bottomLeft,
      frame.outerRect.bottomRight,
    ]) {
      final toward = c - corner;
      _star(canvas, corner + toward / toward.distance * w * .09, w * .035);
    }
  }

  void _star(Canvas canvas, Offset c, double m) {
    final star = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 - math.pi / 2;
      final rr = i.isEven ? m : m * .6;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = _Book.gold);
  }

  @override
  bool shouldRepaint(_CoverOrnament old) => false;
}
