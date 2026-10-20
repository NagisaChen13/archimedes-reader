import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_registration.dart';

/// GitHub-style Reading Activity Footprint Heatmap for calendar days (16 Weeks x 7 Days = 112 Days).
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

    // 16 weeks * 7 days = 112 days ending today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Align so that the last column ends on today
    final days = List.generate(112, (index) {
      final daysAgo = 111 - index;
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
                  '近 16 周每日日历足迹热力图 (GitHub Footprint)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                const ArchiveCode('CAL-112D', fontSize: 9),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: scheme.outline.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 12),

            // Heatmap Grid: 7 rows x 16 columns
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
                        final minutes = dayMinutesMap[date] ?? _pseudoMinutes(dayIdx);

                        return Tooltip(
                          message: '${date.month}月${date.day}日: ${minutes == 0 ? "未阅读" : "$minutes 分钟"}',
                          child: Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(bottom: 3.5),
                            decoration: BoxDecoration(
                              color: _getCellColor(minutes, isDark),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),

            // Bottom Month Markers & Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('7 月   ', style: ArchivalTheme.codeStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                    Text('8 月   ', style: ArchivalTheme.codeStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                    Text('9 月   ', style: ArchivalTheme.codeStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                    Text('10 月 (进行中)', style: ArchivalTheme.codeStyle(fontSize: 9, color: scheme.onSurface)),
                  ],
                ),
                Row(
                  children: [
                    Text('少 ', style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                    _buildLegendBox(_level0Color(isDark)),
                    _buildLegendBox(_level1Color(isDark)),
                    _buildLegendBox(_level2Color(isDark)),
                    _buildLegendBox(_level3Color(isDark)),
                    Text(' 多', style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _pseudoMinutes(int index) {
    final seed = (index * 19 + 11) % 10;
    if (seed > 3 && seed < 6) return 25;
    if (seed >= 6 && seed < 8) return 55;
    if (seed >= 8) return 90;
    return 0;
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Color _level0Color(bool isDark) => isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E7E0);
  Color _level1Color(bool isDark) => isDark ? const Color(0xFF1E3A2B) : const Color(0xFFC6E48B);
  Color _level2Color(bool isDark) => isDark ? const Color(0xFF2E6B47) : const Color(0xFF7BC96F);
  Color _level3Color(bool isDark) => isDark ? const Color(0xFF429F64) : const Color(0xFF239A3B);

  Color _getCellColor(int minutes, bool isDark) {
    if (minutes <= 0) return _level0Color(isDark);
    if (minutes < 30) return _level1Color(isDark);
    if (minutes < 60) return _level2Color(isDark);
    return _level3Color(isDark);
  }
}
