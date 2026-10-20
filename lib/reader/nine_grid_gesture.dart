import 'package:flutter/material.dart';

enum GridZone {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum GestureType {
  singleTap,
  doubleTap,
  longPress,
}

/// 9-Square Grid Touch Detector dividing the reading surface into 3x3 zones.
class NineGridGestureDetector extends StatelessWidget {
  final Widget child;
  final void Function(GridZone zone, GestureType type) onZoneTriggered;

  const NineGridGestureDetector({
    super.key,
    required this.child,
    required this.onZoneTriggered,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(child: child),
            // Invisible touch layer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final zone = _resolveZone(details.localPosition, w, h);
                  onZoneTriggered(zone, GestureType.singleTap);
                },
                onDoubleTapDown: (details) {
                  final zone = _resolveZone(details.localPosition, w, h);
                  onZoneTriggered(zone, GestureType.doubleTap);
                },
                onLongPressStart: (details) {
                  final zone = _resolveZone(details.localPosition, w, h);
                  onZoneTriggered(zone, GestureType.longPress);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  GridZone _resolveZone(Offset pos, double width, double height) {
    final col = (pos.dx / (width / 3.0)).floor().clamp(0, 2);
    final row = (pos.dy / (height / 3.0)).floor().clamp(0, 2);

    if (row == 0) {
      if (col == 0) return GridZone.topLeft;
      if (col == 1) return GridZone.topCenter;
      return GridZone.topRight;
    } else if (row == 1) {
      if (col == 0) return GridZone.centerLeft;
      if (col == 1) return GridZone.center;
      return GridZone.centerRight;
    } else {
      if (col == 0) return GridZone.bottomLeft;
      if (col == 1) return GridZone.bottomCenter;
      return GridZone.bottomRight;
    }
  }
}
