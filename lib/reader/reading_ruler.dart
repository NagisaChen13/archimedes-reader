import 'package:flutter/material.dart';

enum RulerStyle {
  yellowHighlight,
  cyanFocusBar,
  underlineGuide,
  gradientDimmer,
  frostedGlass,
  nightAmber,
}

/// 6-Style Focus Reading Ruler Overlay (`RulerView`).
class ReadingRulerOverlay extends StatefulWidget {
  final bool visible;
  final RulerStyle style;
  final double rulerHeight;
  final ValueChanged<double>? onPositionChanged;

  const ReadingRulerOverlay({
    super.key,
    required this.visible,
    this.style = RulerStyle.yellowHighlight,
    this.rulerHeight = 36.0,
    this.onPositionChanged,
  });

  @override
  State<ReadingRulerOverlay> createState() => _ReadingRulerOverlayState();
}

class _ReadingRulerOverlayState extends State<ReadingRulerOverlay> {
  double _yOffset = 220.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Positioned(
      left: 0,
      right: 0,
      top: _yOffset.clamp(50.0, size.height - widget.rulerHeight - 50.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          setState(() {
            _yOffset += details.delta.dy;
          });
          widget.onPositionChanged?.call(_yOffset);
        },
        child: Container(
          height: widget.rulerHeight,
          decoration: _getRulerDecoration(widget.style),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.drag_handle,
                  size: 16.0,
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _getRulerDecoration(RulerStyle style) {
    switch (style) {
      case RulerStyle.yellowHighlight:
        return BoxDecoration(
          color: const Color(0xFFFFEB3B).withValues(alpha: 0.28),
          border: const Border(
            top: BorderSide(color: Color(0xFFFBC02D), width: 1.2),
            bottom: BorderSide(color: Color(0xFFFBC02D), width: 1.2),
          ),
        );
      case RulerStyle.cyanFocusBar:
        return BoxDecoration(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
          border: const Border(
            top: BorderSide(color: Color(0xFF00B0FF), width: 1.2),
            bottom: BorderSide(color: Color(0xFF00B0FF), width: 1.2),
          ),
        );
      case RulerStyle.underlineGuide:
        return const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.redAccent, width: 2.0),
          ),
        );
      case RulerStyle.gradientDimmer:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.05),
              Colors.black.withValues(alpha: 0.20),
              Colors.black.withValues(alpha: 0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        );
      case RulerStyle.frostedGlass:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4.0,
            ),
          ],
        );
      case RulerStyle.nightAmber:
        return BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.20),
          border: const Border(
            top: BorderSide(color: Color(0xFFF57C00), width: 1.0),
            bottom: BorderSide(color: Color(0xFFF57C00), width: 1.0),
          ),
        );
    }
  }
}
