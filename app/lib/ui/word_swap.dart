import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/reader_settings.dart';

/// A word of the page that, when another riwaya changes it, gives way to
/// the new one by [style]: faded, swapped from above, turned or scaled
/// (the user, 2026-11-25). A word the riwayat read alike keeps its
/// [swapKey] and does not move.
class WordSwapper extends StatelessWidget {
  const WordSwapper({
    super.key,
    required this.style,
    required this.swapKey,
    required this.child,
  });

  final WordSwap style;
  final Key swapKey;
  final Widget child;

  static const duration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    if (style == WordSwap.none) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // The old word over the new, both on the line, the line's size the
      // new one's.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final p in previous) Positioned.fill(child: p),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) => _transition(child, animation),
      child: KeyedSubtree(key: swapKey, child: child),
    );
  }

  Widget _transition(Widget child, Animation<double> animation) =>
      switch (style) {
        WordSwap.none => child,
        WordSwap.fade => FadeTransition(opacity: animation, child: child),
        WordSwap.slide => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -.6),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        WordSwap.flip => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            // The old word turns away in the first half, the new turns in in
            // the second.
            final t = animation.value;
            return Opacity(
              opacity: t < .5 ? 0 : 1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .002)
                  ..rotateX((1 - t) * math.pi),
                child: child,
              ),
            );
          },
        ),
        WordSwap.scale => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .4, end: 1.0).animate(animation),
            child: child,
          ),
        ),
      };
}
