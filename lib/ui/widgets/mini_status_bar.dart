import 'package:flutter/material.dart';

/// Ultra-compact micro status bar for the bottom of reading pages.
class MiniStatusBar extends StatelessWidget {
  final String chapterTitle;
  final double progressPercent;
  final int batteryLevel;
  final String currentTime;

  const MiniStatusBar({
    super.key,
    required this.chapterTitle,
    required this.progressPercent,
    this.batteryLevel = 85,
    this.currentTime = '14:20',
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    final textStyle = TextStyle(
      fontSize: 10.0,
      color: textColor,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w500,
    );

    return Container(
      height: 16.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Chapter title
          Expanded(
            child: Text(
              chapterTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          const SizedBox(width: 12),
          // Progress %
          Text(
            '${(progressPercent * 100).toStringAsFixed(1)}%',
            style: textStyle,
          ),
          const SizedBox(width: 12),
          // Battery icon & Time
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBatteryIcon(batteryLevel, textColor),
              const SizedBox(width: 6),
              Text(currentTime, style: textStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIcon(int level, Color color) {
    return Container(
      width: 18.0,
      height: 9.0,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 0.8),
        borderRadius: BorderRadius.circular(2.0),
      ),
      padding: const EdgeInsets.all(1.0),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: (level / 100.0).clamp(0.1, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
      ),
    );
  }
}
