import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pages that turn like a printed mushaf: dragging lifts the page, which
/// turns over on its spine (the right edge, as in an Arabic book) and reveals
/// the next page underneath, with the shadows of a real sheet.
///
/// Dragging to the right turns to the next page, to the left goes back.
class BookPager extends StatefulWidget {
  const BookPager({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    required this.onPageChanged,
    this.enabled = true,
  });

  final int itemCount;
  final int initialIndex;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onPageChanged;

  /// False while the page is zoomed, so drags pan instead of turning.
  final bool enabled;

  @override
  State<BookPager> createState() => BookPagerState();
}

class BookPagerState extends State<BookPager>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;

  /// -1..1: positive while turning forward, negative while turning back.
  double _progress = 0;
  late final AnimationController _settle = AnimationController(vsync: this)
    ..addListener(() => setState(() => _progress = _settle.value));

  int get index => _index;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// Shows [index] at once (index, surah, mutashabih).
  void jumpTo(int index) {
    if (index == _index) return;
    _settle.stop();
    setState(() {
      _index = index.clamp(0, widget.itemCount - 1);
      _progress = 0;
    });
    widget.onPageChanged(_index);
  }

  /// Turns one page with the animation (+1 next, -1 previous).
  Future<void> turn(int direction) async {
    if (!_canTurn(direction)) return;
    _settle.value = _progress;
    await _animateTo(direction.toDouble(), const Duration(milliseconds: 520));
    _commit(direction);
  }

  bool _canTurn(int direction) =>
      direction > 0 ? _index < widget.itemCount - 1 : _index > 0;

  void _onDragUpdate(DragUpdateDetails d, double width) {
    _settle.stop();
    var p = _progress + d.primaryDelta! / width;
    if (!_canTurn(1)) p = math.min(p, 0);
    if (!_canTurn(-1)) p = math.max(p, 0);
    setState(() => _progress = p.clamp(-1.0, 1.0));
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    final v = d.primaryVelocity ?? 0;
    final direction = _progress == 0 ? 0 : _progress.sign.toInt();
    final complete = direction != 0 &&
        (_progress.abs() > 0.33 || v * direction > 700);
    _settle.value = _progress;
    if (complete) {
      await _animateTo(direction.toDouble(), const Duration(milliseconds: 380));
      _commit(direction);
    } else {
      await _animateTo(0, const Duration(milliseconds: 260));
    }
  }

  Future<void> _animateTo(double target, Duration duration) => _settle
      .animateTo(target, duration: duration, curve: Curves.easeOutCubic)
      .orCancel
      .catchError((_) {});

  void _commit(int direction) {
    HapticFeedback.lightImpact();
    setState(() {
      _index += direction;
      _progress = 0;
      _settle.value = 0;
    });
    widget.onPageChanged(_index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      Widget page(int i) => KeyedSubtree(
            key: ValueKey(i),
            child: widget.itemBuilder(context, i),
          );

      final List<Widget> layers;
      if (_progress > 0) {
        // The current page turns away, the next one lies beneath.
        layers = [
          page(_index + 1),
          _SpineShadow(strength: 1 - _progress),
          _Turning(progress: _progress, child: page(_index)),
        ];
      } else if (_progress < 0) {
        // The previous page comes back down over the current one.
        layers = [
          page(_index),
          _SpineShadow(strength: -_progress),
          _Turning(progress: 1 + _progress, child: page(_index - 1)),
        ];
      } else {
        layers = [page(_index)];
      }

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate:
            widget.enabled ? (d) => _onDragUpdate(d, width) : null,
        onHorizontalDragEnd: widget.enabled ? _onDragEnd : null,
        child: Stack(fit: StackFit.expand, children: layers),
      );
    });
  }
}

/// A page rotated on its right edge by [progress] (0 flat .. 1 turned).
class _Turning extends StatelessWidget {
  const _Turning({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi / 2;
    return IgnorePointer(
      ignoring: progress > 0,
      child: Transform(
        alignment: Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateY(angle),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // The sheet darkens as it lifts away from the light.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withAlpha((progress * 150).round()),
                      Colors.black.withAlpha((progress * 40).round()),
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
}

/// The shadow the turning sheet casts on the page below, near the spine.
class _SpineShadow extends StatelessWidget {
  const _SpineShadow({required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            stops: const [0, 0.35, 1],
            colors: [
              Colors.black.withAlpha((strength * 110).round()),
              Colors.black.withAlpha((strength * 25).round()),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
