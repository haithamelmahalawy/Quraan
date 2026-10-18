import 'package:flutter/material.dart';

import 'theme.dart';

/// Whether [page] lies on the right of the open Madinah mushaf: odd pages
/// are on the right (Al-Fatiha, page 1), even pages on the left.
bool isRightPage(int page) => page.isOdd;

/// A small open mushaf with the side of the current page filled in.
class PageSideIcon extends StatelessWidget {
  const PageSideIcon({super.key, required this.right, this.width = 40});

  final bool right;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.7,
      child: CustomPaint(painter: _OpenBook(right)),
    );
  }
}

class _OpenBook extends CustomPainter {
  _OpenBook(this.right);

  final bool right;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w / 26
      ..color = MushafColors.gold;
    final lines = Paint()
      ..strokeWidth = w / 60
      ..color = Colors.white.withAlpha(200);

    // The two pages, slightly curved like an open book.
    Path sheet(bool rightSide) {
      final x0 = rightSide ? w / 2 : w * 0.04;
      final x1 = rightSide ? w * 0.96 : w / 2;
      return Path()
        ..moveTo(x0, h * 0.14)
        ..quadraticBezierTo((x0 + x1) / 2, rightSide ? 0 : 0, x1, h * 0.14)
        ..lineTo(x1, h * 0.94)
        ..quadraticBezierTo((x0 + x1) / 2, h * 0.8, x0, h * 0.94)
        ..close();
    }

    for (final side in [true, false]) {
      final path = sheet(side);
      if (side == right) {
        canvas.drawPath(path, Paint()..color = MushafColors.green);
        // Text lines on the current page.
        final x0 = side ? w * 0.56 : w * 0.1;
        final x1 = side ? w * 0.9 : w * 0.44;
        for (var i = 0; i < 4; i++) {
          final y = h * (0.32 + i * 0.13);
          canvas.drawLine(Offset(x0, y), Offset(x1, y), lines);
        }
      } else {
        canvas.drawPath(path, Paint()..color = MushafColors.page);
      }
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_OpenBook old) => old.right != right;
}

/// Shown when a page opens: a large open mushaf with the page's side lit,
/// then it shrinks and flies up to the small icon at [target].
class PageSideHint extends StatelessWidget {
  const PageSideHint({
    super.key,
    required this.page,
    required this.progress,
    required this.target,
  });

  final int page;

  /// 0..1 of the animation.
  final double progress;

  /// Where the small icon sits (alignment within the reader).
  final Alignment target;

  @override
  Widget build(BuildContext context) {
    final right = isRightPage(page);
    final t = progress;
    // Appear (0–0.15), hold (–0.6), fly to the icon (–1).
    final appear = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
    final fly = Curves.easeInOutCubic.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));
    final scale = (0.6 + 0.4 * appear) * (1 - 0.8 * fly);
    final labelOpacity = (1 - fly * 2.5).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.lerp(Alignment.center, target, fly)!,
        child: Opacity(
          opacity: (t / 0.1).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
              decoration: BoxDecoration(
                color: MushafColors.paper.withAlpha((230 * (1 - fly)).round()),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((90 * (1 - fly)).round()),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PageSideIcon(right: right, width: 150),
                  Opacity(
                    opacity: labelOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        right
                            ? 'صفحة $page في يمين المصحف'
                            : 'صفحة $page في يسار المصحف',
                        style: TextStyle(
                          fontSize: 18,
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
