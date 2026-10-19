import 'package:flutter/material.dart';

import 'theme.dart';

/// A raised, softly lit surface: lit from above, with a gloss on its upper
/// half and a shadow beneath; it sinks a little when pressed.
class Raised extends StatefulWidget {
  const Raised({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.depth = 1,
    this.tooltip,
    this.circle = false,
  });

  final Widget child;

  /// The surface colour; the page colour by default.
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// How high it stands: the size of its shadow.
  final double depth;
  final String? tooltip;
  final bool circle;

  @override
  State<Raised> createState() => _RaisedState();
}

class _RaisedState extends State<Raised> {
  bool _pressed = false;

  void _press(bool down) {
    if (widget.onTap != null && _pressed != down) {
      setState(() => _pressed = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? MushafColors.page;
    final dark = MushafColors.isDark;
    final depth = widget.depth * (_pressed ? 0.35 : 1);
    final shape = widget.circle ? null : BorderRadius.circular(widget.radius);
    final boxShape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.identity()
        ..scaleByDouble(_pressed ? 0.97 : 1, _pressed ? 0.97 : 1, 1, 1),
      transformAlignment: Alignment.center,
      padding: widget.padding,
      decoration: BoxDecoration(
        shape: boxShape,
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, dark ? 0.06 : 0.22)!,
            color,
            Color.lerp(color, Colors.black, dark ? 0.25 : 0.12)!,
          ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha(dark ? 22 : 150),
          width: 1,
        ),
        boxShadow: [
          // The shadow it casts.
          BoxShadow(
            color: Color.lerp(
              color,
              Colors.black,
              0.6,
            )!.withAlpha(dark ? 160 : 90),
            offset: Offset(0, 7 * depth),
            blurRadius: 16 * depth,
            spreadRadius: -2,
          ),
          // Light on its upper edge.
          if (!dark)
            BoxShadow(
              color: Colors.white.withAlpha(200),
              offset: Offset(0, -2 * depth),
              blurRadius: 6 * depth,
              spreadRadius: -2,
            ),
        ],
      ),
      // The gloss on its upper half.
      foregroundDecoration: BoxDecoration(
        shape: boxShape,
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withAlpha(dark ? 18 : 55),
            Colors.white.withAlpha(0),
          ],
        ),
      ),
      child: widget.child,
    );
    if (widget.onTap != null) {
      surface = Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: widget.onTap,
          child: surface,
        ),
      );
    }
    if (widget.tooltip != null) {
      surface = Tooltip(message: widget.tooltip!, child: surface);
    }
    return surface;
  }
}

/// A small round raised button with an icon, for the bars.
class RaisedIcon extends StatelessWidget {
  const RaisedIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 36,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Raised(
        circle: true,
        depth: 0.6,
        tooltip: tooltip,
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: size * 0.55,
            color: color ?? MushafColors.green,
          ),
        ),
      ),
    );
  }
}
