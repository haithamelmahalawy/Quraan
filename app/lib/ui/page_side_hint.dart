import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The open mushaf: the current page (pictured, outlined) on its side and
/// the facing page dimmed beside it.
class OpenMushafView extends StatelessWidget {
  const OpenMushafView({
    super.key,
    required this.right,
    required this.width,
    this.current,
    this.facing,
  });

  final bool right;
  final double width;
  final ui.Image? current;
  final ui.Image? facing;

  @override
  Widget build(BuildContext context) {
    final pageWidth = (width - width * 0.03) / 2;
    final pageHeight = current == null
        ? pageWidth * 1.6
        : pageWidth * current!.height / current!.width;
    final border = width < 80 ? 1.5 : 3.0;

    Widget sheet({required bool isCurrent}) {
      final image = isCurrent ? current : facing;
      return Container(
        width: pageWidth,
        height: pageHeight,
        decoration: BoxDecoration(
          color: MushafColors.page,
          border: Border.all(
            color: isCurrent ? MushafColors.green : MushafColors.gold,
            width: isCurrent ? border : border / 2,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: MushafColors.green.withAlpha(150),
                    blurRadius: width < 80 ? 4 : 18,
                  ),
                ]
              : null,
        ),
        child: image == null
            ? null
            : Opacity(
                opacity: isCurrent ? 1 : 0.35,
                child: RawImage(image: image, fit: BoxFit.fill),
              ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      // The right page first, as the mushaf lies open.
      textDirection: TextDirection.rtl,
      children: [
        sheet(isCurrent: right),
        Container(
          width: width * 0.03,
          height: pageHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withAlpha(20),
                Colors.black.withAlpha(90),
                Colors.black.withAlpha(20),
              ],
            ),
          ),
        ),
        sheet(isCurrent: !right),
      ],
    );
  }
}

/// Shown when a page opens: the open mushaf, large, with the page lit on its
/// side; then it shrinks and flies up to the small icon at [target].
class PageSideHint extends StatelessWidget {
  const PageSideHint({
    super.key,
    required this.page,
    required this.right,
    required this.progress,
    required this.target,
    this.current,
    this.facing,
  });

  final int page;

  /// The page lies on the right of the open mushaf
  /// ([QuranRepository.isRightPage]).
  final bool right;

  /// 0..1 of the animation.
  final double progress;

  /// Where the small icon sits (alignment within the reader).
  final Alignment target;

  final ui.Image? current;
  final ui.Image? facing;

  @override
  Widget build(BuildContext context) {
    final t = progress;
    // Appear (0–0.12), hold (–0.5), fly to the icon (–1).
    final appear = Curves.easeOutBack.transform((t / 0.12).clamp(0.0, 1.0));
    final fly = Curves.easeInCubic.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0));
    final scale = (0.7 + 0.3 * appear) * (1 - 0.88 * fly);
    final labelOpacity = (1 - fly * 3).clamp(0.0, 1.0);
    final width = MediaQuery.sizeOf(context).width * 0.85;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.lerp(Alignment.center, target, fly)!,
        child: Opacity(
          opacity: (t / 0.08).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: MushafColors.paper.withAlpha((240 * (1 - fly)).round()),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((110 * (1 - fly)).round()),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OpenMushafView(
                    right: right,
                    width: width - 32,
                    current: current,
                    facing: facing,
                  ),
                  Opacity(
                    opacity: labelOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        right
                            ? 'صفحة $page في يمين المصحف'
                            : 'صفحة $page في يسار المصحف',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: MushafColors.green,
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
    );
  }
}
