import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_registration.dart';

/// Reading Activity Footprint Heatmap for calendar days (12 Weeks x 7 Days = 84 Days).
class ReadingCalendarHeatmap extends StatelessWidget {
  final Map<DateTime, int> dayMinutesMap;

  const ReadingCalendarHeatmap({
    super.key,
    required this.dayMinutesMap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // 12 weeks * 7 days = 84 days ending today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(84, (index) {
      final daysAgo = 83 - index;
      return today.subtract(Duration(days: daysAgo));
    });

    return ArchiveRegistration(
      inset: 2.0,
      child: Container(
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
          border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  '近 12 周每日日历足迹热力图',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                const ArchiveCode('12周足迹', fontSize: 9),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: scheme.outline.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 12),

            // Heatmap Grid: 7 rows x 12 columns
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(12, (weekIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.5),
                    child: Column(
                      children: List.generate(7, (dayOfWeek) {
                        final dayIdx = weekIndex * 7 + dayOfWeek;
                        if (dayIdx >= days.length) return const SizedBox(width: 13, height: 13);
                        final date = days[dayIdx];
                        final minutes = dayMinutesMap[date] ?? 0;

                        return Tooltip(
                          message: '${date.month}月${date.day}日: ${minutes == 0 ? "未阅读" : "$minutes 分钟"}',
                          child: Container(
                            width: 13,
                            height: 13,
                            margin: const EdgeInsets.only(bottom: 4.5),
                            decoration: BoxDecoration(
                              color: _getCellColor(minutes, isDark),
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),

            // Bottom Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '随真实阅读逐步点亮记录',
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
                Row(
                  children: [
                    Text('少 ', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                    _buildLegendBox(_level0Color(isDark)),
                    _buildLegendBox(_level1Color(isDark)),
                    _buildLegendBox(_level2Color(isDark)),
                    _buildLegendBox(_level3Color(isDark)),
                    Text(' 多', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Color _level0Color(bool isDark) => isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E7E0);
  Color _level1Color(bool isDark) => isDark ? const Color(0xFF1E3A2B) : const Color(0xFFC6E48B);
  Color _level2Color(bool isDark) => isDark ? const Color(0xFF2E6B47) : const Color(0xFF7BC96F);
  Color _level3Color(bool isDark) => isDark ? const Color(0xFF429F64) : const Color(0xFF239A3B);

  Color _getCellColor(int minutes, bool isDark) {
    if (minutes <= 0) return _level0Color(isDark);
    if (minutes < 15) return _level1Color(isDark);
    if (minutes < 45) return _level2Color(isDark);
    return _level3Color(isDark);
  }
}
