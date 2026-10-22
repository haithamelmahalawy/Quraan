import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A raised surface with perspective on hover and a short press response.
/// Raw pointer events leave scrolling and nested buttons in charge of gestures.
class GuideDepthSurface extends StatefulWidget {
  const GuideDepthSurface({
    super.key,
    required this.child,
    required this.accent,
    this.padding = EdgeInsets.zero,
    this.depth = 7,
  });
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double depth;

  @override
  State<GuideDepthSurface> createState() => _GuideDepthSurfaceState();
}

class _GuideDepthSurfaceState extends State<GuideDepthSurface> {
  Offset _tilt = Offset.zero;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final tilt = reducedMotion ? Offset.zero : _tilt;
    final pressed = !reducedMotion && _pressed;
    final face = Color.alphaBlend(
      widget.accent.withAlpha(dark ? 22 : 9),
      scheme.surface,
    );
    final edge = Color.lerp(widget.accent, Colors.black, dark ? .6 : .3)!;
    return MouseRegion(
      onHover: (event) {
        if (reducedMotion) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final p = box.globalToLocal(event.position);
        setState(
          () => _tilt = Offset(
            (p.dx / box.size.width - .5).clamp(-.5, .5),
            (p.dy / box.size.height - .5).clamp(-.5, .5),
          ),
        );
      },
      onExit: (_) => setState(() {
        _tilt = Offset.zero;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0008)
            ..rotateX(-tilt.dy * .09)
            ..rotateY(tilt.dx * .09)
            ..translateByDouble(0, pressed ? 3 : 0, 0, 1),
          margin: EdgeInsets.only(bottom: widget.depth + 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(face, Colors.white, dark ? .045 : .65)!,
                face,
              ],
            ),
            border: Border.all(color: widget.accent.withAlpha(dark ? 75 : 55)),
            boxShadow: [
              BoxShadow(
                color: edge.withAlpha(dark ? 155 : 110),
                offset: Offset(0, pressed ? 3 : widget.depth),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(dark ? 65 : 22),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(dark ? 7 : 190),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Material(
              color: Colors.transparent,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dimensional emblem, without an invented portrait of a historical person.
class GuideSeal extends StatelessWidget {
  const GuideSeal({
    super.key,
    required this.color,
    required this.icon,
    this.size = 48,
  });
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, .22)!,
          Color.lerp(color, Colors.black, .18)!,
        ],
      ),
      border: Border.all(color: Colors.white.withAlpha(100), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Color.lerp(color, Colors.black, .4)!,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: color.withAlpha(45),
          blurRadius: 12,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * .49),
  );
}

/// Code-drawn books on a pedestal: real perspective transforms, available offline.
class GuideBookSculpture extends StatelessWidget {
  const GuideBookSculpture({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 112,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 106,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C5146), Color(0xFF10392E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(65),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 2; i >= 0; i--)
            Positioned(
              top: 9.0 + i * 8,
              left: 21.0 - i * 3,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .001)
                  ..rotateX(.25)
                  ..rotateY(-.35)
                  ..rotateZ(-math.pi / 12),
                child: Container(
                  width: 69,
                  height: 89,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: i == 0
                          ? const [Color(0xFF3A8C70), Color(0xFF17513F)]
                          : i == 1
                          ? const [Color(0xFFE4BB69), Color(0xFF997132)]
                          : const [Color(0xFF438B9C), Color(0xFF28525D)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFF1D8A5),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        offset: const Offset(5, 5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 3,
                        top: 3,
                        bottom: 3,
                        child: Container(
                          width: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(50),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFDDC38C),
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                color: Color(0xFFF8E4BB),
                                size: 29,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
