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
  static const duration = Duration(milliseconds: 10000);

  /// When the recitation starts: as the open mushaf is laid flat.
  static const soundAt = Duration(milliseconds: 3800);

  /// The ayah.
  static const surah = 19, ayah = 12;

  /// A page drawn at this size, the open mushaf's measure.
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
    QcfFonts.instance.ensure([_page - 1, _page]);
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
    final qcfRight = QcfFonts.instance.isReady(_page - 1);
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
    // The page before it, on the right of the open mushaf.
    final right = MushafPage(
      key: ValueKey('intro-right:$qcfRight:$_loaded'),
      page: _page - 1,
      quran: _quran,
      variants: widget.variants,
      mutashabihat: widget.mutashabihat,
      settings: _settings,
      onWordTap: (_, _) {},
      qcf: qcfRight,
      showHamesh: _loaded,
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
                left: page,
                right: right,
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

/// A point of the scene on the screen, through [m].
Offset _on(Matrix4 m, double x, double y, double z) {
  final s = m.storage;
  final w = s[3] * x + s[7] * y + s[11] * z + s[15];
  return Offset(
    (s[0] * x + s[4] * y + s[8] * z + s[12]) / w,
    (s[1] * x + s[5] * y + s[9] * z + s[13]) / w,
  );
}

/// Twice the area of [q] on the screen: above 0 when it faces the eye.
double _area(List<Offset> q) {
  var s = 0.0;
  for (var i = 0; i < q.length; i++) {
    final a = q[i], b = q[(i + 1) % q.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s;
}

/// A face of the mushaf seen: its corners on the screen, its colour, and the
/// lines of the leaves' edges on it.
class _Face {
  _Face(this.corners, this.color, [this.lines = const []]);

  final List<Offset> corners;
  final Color color;
  final List<(Offset, Offset)> lines;
}

class _Faces extends CustomPainter {
  _Faces(this.faces);

  final List<_Face> faces;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..strokeWidth = .7
      ..color = const Color(0x66896A2C);
    for (final f in faces) {
      canvas.drawPath(
        Path()..addPolygon(f.corners, true),
        Paint()..color = f.color,
      );
      for (final (a, b) in f.lines) {
        canvas.drawLine(a, b, line);
      }
    }
  }

  @override
  bool shouldRepaint(_Faces old) => true;
}

/// The shadow of the mushaf on the table.
class _Shadow extends CustomPainter {
  _Shadow(this.corners, this.blur);

  final List<Offset> corners;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()..addPolygon(corners, true),
    Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );

  @override
  bool shouldRepaint(_Shadow old) => true;
}

/// The mushaf, a real one (the user, 2026-11-28): shut on a table, seen
/// from above and in front, its leather cover, its boards and the gilt edges
/// of its leaves showing how thick it is; its cover and half its leaves
/// turning on the spine at the right, as an Arabic mushaf opens, so that the
/// two pages lie open, page 305 on the right and page 306 on the left, each
/// on its stack of leaves; then laid flat before the eye and the ayah brought
/// near, the rest hidden.
class _Book extends StatelessWidget {
  const _Book({
    required this.t,
    required this.area,
    required this.left,
    required this.right,
    required this.pageBox,
    required this.phrase,
  });

  final double t;
  final Size area;

  /// Page 306, the ayah's, on the left; page 305 on the right.
  final Widget left, right;
  final GlobalKey pageBox;

  /// «يَٰيَحۡيَىٰ خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖۖ» on the page drawn; null until measured.
  final Rect? phrase;

  static const ground = Color(0xFF071B15);
  static const shade = Color(0xFFE8B84A);
  static const gold = Color(0xFFE8B84A);
  static const paleGold = Color(0xFFF3D98B);
  static const paper = Color(0xFFFBF6E9);
  static const leatherEdge = Color(0xFF0B3528);
  static const lining = Color(0xFF0F3E30);
  static const gilt = Color(0xFFE2C98A);

  // The mushaf's measures, in the page's units: a page, the cover past the
  // leaves, each half's leaves, a board.
  static final pw = IntroScreen.pageSize.width;
  static final ph = IntroScreen.pageSize.height;
  static const over = 12.0;
  static const leaves = 46.0;
  static const board = 8.0;
  static final cw = pw + over;
  static final ch = ph + 2 * over;

  /// The open pages above the table; the spine turns there.
  static const top = board + leaves;

  @override
  Widget build(BuildContext context) {
    final shown = _fade(t, 0, .06) * (1 - _fade(t, .94, 1));
    final open = _fade(t, .07, .36);
    final flat = _fade(t, .3, .46);
    final grow = _fade(t, .1, .44);
    final zoom = phrase == null ? 0.0 : _fade(t, .48, .62);
    final angle = open * math.pi;
    final tilt = (.7 - .2 * open) * (1 - flat);
    // Shut, turned a little: the gilt edge of its leaves seen on the left.
    final yaw = .38 * (1 - open);
    final shutK = math.min(area.width * .58 / cw, area.height * .46 / ch);
    final openK = math.min(area.width * .92 / (2 * cw), area.height * .9 / ch);
    final k = shutK + (openK - shutK) * grow;
    final center = area.center(Offset.zero);
    // On the shut mushaf, then on its spine, the middle of the open pages.
    final camX = -cw / 2 * (1 - open);
    final camera = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy + (1 - shown) * 24, 0, 1)
      ..multiply(
        Matrix4.identity()
          ..setEntry(3, 2, -1 / (3 * math.max(area.width, area.height))),
      )
      ..rotateX(tilt)
      ..rotateY(yaw)
      ..scaleByDouble(k, k, k, 1)
      ..translateByDouble(-camX, -ph / 2, -top, 1);
    // The cover and the leaves on it, turning on the spine: laid open at
    // [angle] π, its leaves above the table between -leaves and 0.
    final leaf = camera.clone()
      ..translateByDouble(0, 0, top, 1)
      ..rotateY(angle - math.pi);

    // A box's sides seen, between z0 and z1 over [r].
    List<_Face> sides(
      Matrix4 m,
      Rect r,
      double z0,
      double z1,
      Color color, {
      bool edges = false,
    }) {
      final c = [r.bottomLeft, r.bottomRight, r.topRight, r.topLeft];
      return [
        for (var i = 0; i < 4; i++)
          if (([
                _on(m, c[i].dx, c[i].dy, z0),
                _on(m, c[i].dx, c[i].dy, z1),
                _on(m, c[(i + 1) % 4].dx, c[(i + 1) % 4].dy, z1),
                _on(m, c[(i + 1) % 4].dx, c[(i + 1) % 4].dy, z0),
              ])
              case final q when _area(q) > 0)
            _Face(
              q,
              // Darker on the far sides.
              Color.lerp(color, Colors.black, const [0.0, .18, .32, .18][i])!,
              [
                if (edges)
                  for (var j = 1; j < 14; j++)
                    (
                      _on(m, c[i].dx, c[i].dy, z0 + (z1 - z0) * j / 14),
                      _on(
                        m,
                        c[(i + 1) % 4].dx,
                        c[(i + 1) % 4].dy,
                        z0 + (z1 - z0) * j / 14,
                      ),
                    ),
              ],
            ),
      ];
    }

    // A flat face at z over [r], facing up (or down).
    List<_Face> face(
      Matrix4 m,
      Rect r,
      double z,
      Color color, {
      bool up = true,
    }) {
      final q = [
        for (final p in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft])
          _on(m, p.dx, p.dy, z),
      ];
      final seen = up ? q : q.reversed.toList();
      return [if (_area(seen) > 0) _Face(seen, color)];
    }

    // The half lying still, on the left: its board, its leaves, page 306.
    final backBoard = Rect.fromLTRB(-cw, -over, 0, ph + over);
    final stillLeaves = Rect.fromLTRB(-pw, 0, 0, ph);
    final still = [
      ...sides(camera, backBoard, 0, board, leatherEdge),
      ...face(camera, backBoard, board, lining),
      ...sides(camera, stillLeaves, board, top, gilt, edges: true),
    ];
    // The half turning: shut, its cover seen; open, page 305.
    final turnBoard = Rect.fromLTRB(0, -over, cw, ph + over);
    final turnLeaves = Rect.fromLTRB(0, 0, pw, ph);
    final shut = angle < math.pi / 2;
    final turning = shut
        ? [
            ...sides(leaf, turnLeaves, -leaves, 0, gilt, edges: true),
            ...sides(leaf, turnBoard, -leaves - board, -leaves, leatherEdge),
          ]
        : [
            ...sides(leaf, turnBoard, -leaves - board, -leaves, leatherEdge),
            ...face(leaf, turnBoard, -leaves, lining),
            ...sides(leaf, turnLeaves, -leaves, 0, gilt, edges: true),
          ];
    // Light falls less on what is raised towards the eye.
    final raised = math.sin(angle);

    Widget placed(Matrix4 m, Size size, Widget child) => Positioned(
      left: 0,
      top: 0,
      width: size.width,
      height: size.height,
      child: Transform(transform: m, child: child),
    );

    // A page and the shadow of the spine on it.
    Widget pageOf(Widget page, {required bool onLeft, GlobalKey? key}) =>
        DecoratedBox(
          decoration: const BoxDecoration(color: paper),
          position: DecorationPosition.background,
          child: Stack(
            children: [
              SizedBox.fromSize(
                key: key,
                size: IntroScreen.pageSize,
                child: IgnorePointer(child: page),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: onLeft
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: onLeft
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        colors: const [
                          Color(0x55000000),
                          Color(0x14000000),
                          Color(0x00000000),
                        ],
                        stops: const [0, .06, .16],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    // Its shadow on the table, as far as it reaches.
    final reach = math.max(0.0, -math.cos(angle)) * cw;
    final shadow = [
      for (final p in [
        Offset(-cw - 6, -over + 4),
        Offset(reach + 6, -over + 4),
        Offset(reach + 10, ph + over + 16),
        Offset(-cw - 10, ph + over + 16),
      ])
        _on(camera, p.dx, p.dy, 0),
    ];

    // The zoom on the phrase, once the mushaf lies flat before the eye.
    final pageM = camera.clone()..translateByDouble(-pw, 0, top, 1);
    Rect? hole;
    if (phrase != null) {
      final q = [
        for (final p in [
          phrase!.topLeft,
          phrase!.topRight,
          phrase!.bottomLeft,
          phrase!.bottomRight,
        ])
          _on(pageM, p.dx, p.dy, 0),
      ];
      hole = Rect.fromPoints(
        q[0],
        q[3],
      ).expandToInclude(Rect.fromPoints(q[1], q[2]));
    }
    final p = hole?.center ?? center;
    final most = hole == null
        ? 1.0
        : math.min(
            area.width * .84 / hole.width,
            area.height * .3 / hole.height,
          );
    final scale = 1 + (most - 1) * zoom;
    final to = Offset.lerp(p, center, zoom)!;
    Offset seen(Offset q) => to + (q - p) * scale;
    final zoomed = Matrix4.identity()
      ..translateByDouble(to.dx, to.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);

    return Opacity(
      opacity: shown,
      child: SizedBox.fromSize(
        size: area,
        child: Stack(
          children: [
            // The light on the table.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: .8,
                    colors: [
                      Color.lerp(
                        ground,
                        const Color(0xFF1F5E47),
                        .55 + .45 * open,
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _Shadow(shadow, 22 * k)),
                    ),
                    Positioned.fill(child: CustomPaint(painter: _Faces(still))),
                    placed(
                      pageM,
                      IntroScreen.pageSize,
                      pageOf(left, onLeft: true, key: pageBox),
                    ),
                    Positioned.fill(
                      child: CustomPaint(painter: _Faces(turning)),
                    ),
                    if (shut)
                      placed(
                        leaf.clone()
                          ..translateByDouble(cw, -over, -leaves - board, 1)
                          ..scaleByDouble(-1, 1, 1, 1),
                        Size(cw, ch),
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            const _Cover(),
                            ColoredBox(
                              color: Colors.black.withValues(
                                alpha: .45 * raised,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      placed(
                        leaf,
                        IntroScreen.pageSize,
                        Stack(
                          children: [
                            pageOf(right, onLeft: false),
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.black.withValues(
                                  alpha: .4 * raised,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // The rest of the mushaf hidden, the phrase alone left lit.
            if (zoom > 0 && hole != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Spot(
                      hole: Rect.fromPoints(
                        seen(hole.topLeft),
                        seen(hole.bottomRight),
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
