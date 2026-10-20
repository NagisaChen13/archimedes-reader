import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';

/// GitHub-style Reading Activity Footprint Heatmap for calendar days.
class ReadingCalendarHeatmap extends StatelessWidget {
  final Map<DateTime, int> dayMinutesMap;

  const ReadingCalendarHeatmap({
    super.key,
    required this.dayMinutesMap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // Generate last 16 weeks (approx. 112 days)
    final days = <DateTime>[];
    for (int i = 111; i >= 0; i--) {
      days.add(DateTime(now.year, now.month, now.day).subtract(Duration(days: i)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '阅读日历足迹 · 近 16 周',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            Row(
              children: [
                Text('少 ', style: ArchivalTheme.codeStyle(fontSize: 8)),
                ...List.generate(4, (index) => _buildLegendCell(context, index)),
                Text(' 多', style: ArchivalTheme.codeStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(16, (weekIndex) {
              return Padding(
                padding: const EdgeInsets.only(right: 3.5),
                child: Column(
                  children: List.generate(7, (dayOfWeek) {
                    final dayIdx = weekIndex * 7 + dayOfWeek;
                    if (dayIdx >= days.length) return const SizedBox(width: 12, height: 12);
                    final date = days[dayIdx];
                    final minutes = _getMinutesForDate(date);
                    return Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(bottom: 3.5),
                      decoration: BoxDecoration(
                        color: _getIntensityColor(context, minutes),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  int _getMinutesForDate(DateTime dt) {
    for (final entry in dayMinutesMap.entries) {
      if (entry.key.year == dt.year && entry.key.month == dt.month && entry.key.day == dt.day) {
        return entry.value;
      }
    }
    // Deterministic mock pattern for demonstration
    final pseudoHash = (dt.day * 17 + dt.month * 31) % 100;
    if (pseudoHash > 65) return pseudoHash;
    return 0;
  }

  Color _getIntensityColor(BuildContext context, int minutes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (minutes == 0) {
      return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE9E7E0);
    } else if (minutes < 30) {
      return isDark ? const Color(0xFF1E3A2B) : const Color(0xFFC6E48B);
    } else if (minutes < 60) {
      return isDark ? const Color(0xFF2E6B47) : const Color(0xFF7BC96F);
    } else {
      return isDark ? const Color(0xFF429F64) : const Color(0xFF239A3B);
    }
  }

  Widget _buildLegendCell(BuildContext context, int level) {
    final colors = [
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : const Color(0xFFE9E7E0),
      const Color(0xFFC6E48B),
      const Color(0xFF7BC96F),
      const Color(0xFF239A3B),
    ];
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: colors[level],
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
