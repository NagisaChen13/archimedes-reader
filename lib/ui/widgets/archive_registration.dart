import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Precision engineering crosshair registration marks placed at the 4 corners of cards or covers.
class ArchiveRegistration extends StatelessWidget {
  final Widget child;
  final double inset;
  final double markLength;
  final double strokeWidth;
  final Color? color;

  const ArchiveRegistration({
    super.key,
    required this.child,
    this.inset = 2.0,
    this.markLength = 8.0,
    this.strokeWidth = 0.7,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return CustomPaint(
      foregroundPainter: _RegistrationPainter(
        color: effectiveColor,
        inset: inset,
        markLength: markLength,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _RegistrationPainter extends CustomPainter {
  final Color color;
  final double inset;
  final double markLength;
  final double strokeWidth;

  const _RegistrationPainter({
    required this.color,
    required this.inset,
    required this.markLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = (Offset.zero & size).deflate(inset + 0.5);
    final len = math.min(markLength, math.min(rect.width, rect.height) / 3);
    if (len <= 0) return;

    // Top-Left corner crosshair
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, len), paint);

    // Top-Right corner crosshair
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, len), paint);

    // Bottom-Left corner crosshair
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(len, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -len), paint);

    // Bottom-Right corner crosshair
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-len, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -len), paint);
  }

  @override
  bool shouldRepaint(covariant _RegistrationPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.inset != inset ||
        oldDelegate.markLength != markLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
