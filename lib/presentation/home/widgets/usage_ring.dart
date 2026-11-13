import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Anneau de progression léger (CustomPainter, aucune dépendance).
class UsageRing extends StatelessWidget {
  const UsageRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.trackColor,
    this.size = 128,
    this.strokeWidth = 14,
    this.child,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          fraction: value,
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
        ),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, base..color = trackColor);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
