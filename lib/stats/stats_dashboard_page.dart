import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../services/storage_service.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_registration.dart';
import 'external_paper_timer.dart';
import 'reading_calendar_heatmap.dart';

enum StatsGranularity { day, week, month, year }

/// Comprehensive Quantified Reading Analytics Dashboard.
/// Real data persistence, zero default baseline for non-book metrics,
/// 12-week heatmap footprint, and purely Chinese clean labels.
class StatsDashboardPage extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const StatsDashboardPage({super.key, this.onToggleTheme});

  @override
  State<StatsDashboardPage> createState() => _StatsDashboardPageState();
}

class _StatsDashboardPageState extends State<StatsDashboardPage> {
  StatsGranularity _granularity = StatsGranularity.day;
  int _currentGoalMinutes = 60;

  @override
  Widget build(BuildContext context) {
    final books = StorageService().getBooks();
    final sessions = StorageService().getSessions();
    final totalBooksCount = books.length;
    final readBooksCount = books.where((b) => b.currentProgress >= 0.95).length;

    // Calculate real session stats
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todaySessions = sessions.where((s) {
      return s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day;
    }).toList();

    final todaySeconds = todaySessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final todayMinutes = todaySeconds ~/ 60;

    final totalSeconds = sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final totalMinutes = totalSeconds ~/ 60;
    final totalHours = (totalSeconds / 3600.0);

    final totalWords = sessions.fold<int>(0, (sum, s) => sum + s.wordsRead);
    final totalPages = sessions.fold<int>(0, (sum, s) => sum + s.pagesRead);

    // Reading speed calculations (0 if no data)
    final wpm = totalMinutes > 0 ? (totalWords / totalMinutes).round() : 0;
    final secPerPage = totalPages > 0 ? (totalSeconds / totalPages).toStringAsFixed(1) : '0';
    final pagesPerHour = totalHours > 0 ? (totalPages / totalHours).toStringAsFixed(1) : '0';

    // Day minutes map for 12-week heatmap
    final dayMinutesMap = <DateTime, int>{};
    for (final s in sessions) {
      final d = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      dayMinutesMap[d] = (dayMinutesMap[d] ?? 0) + (s.durationSeconds ~/ 60);
    }

    // Calculate real consecutive days streak
    int streakDays = 0;
    DateTime checkDate = today;
    while (dayMinutesMap[checkDate] != null && dayMinutesMap[checkDate]! > 0) {
      streakDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    if (streakDays == 0) {
      // Check if yesterday was active
      final yesterday = today.subtract(const Duration(days: 1));
      checkDate = yesterday;
      while (dayMinutesMap[checkDate] != null && dayMinutesMap[checkDate]! > 0) {
        streakDays++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 90),
          children: [
            // 1. Archival Masthead with Day/Night Switcher and Grain Tabs
            _buildArchivalMasthead(context),
            const SizedBox(height: 16),

            // 2. Goal & Streak Card with Interactive Slider
            _buildGoalStreakCard(context, todayMinutes, streakDays),
            const SizedBox(height: 16),

            // 3. 6-Grid Core Specific Metrics
            _buildCoreMetricsGrid(
              context,
              totalBooks: totalBooksCount,
              readBooks: readBooksCount,
              wpm: wpm,
              secPerPage: secPerPage,
              pagesPerHour: pagesPerHour,
              totalHours: totalHours,
            ),
            const SizedBox(height: 16),

            // 4. Dynamic Timeline Chart (Day/Week/Month/Year)
            _buildDynamicChartSection(context, sessions),
            const SizedBox(height: 16),

            // 5. 12-Week Heatmap Footprint
            ReadingCalendarHeatmap(dayMinutesMap: dayMinutesMap),
            const SizedBox(height: 16),

            // 6. External Paper Book Timer Banner
            _buildExternalTimerBanner(context),
            const SizedBox(height: 16),

            // 7. Footer Stamp
            _buildFooterStamp(context),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. ARCHIVAL MASTHEAD
  // ==========================================

  Widget _buildArchivalMasthead(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline, width: ArchivalTheme.hairlineThickness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '阅',
                  style: TextStyle(
                    color: scheme.surface,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '阅读数据统计中心',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '多维阅读量化分析与足迹追踪',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Day/Night Mode Switcher
              if (widget.onToggleTheme != null)
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                  tooltip: '切换昼夜暗室',
                  onPressed: widget.onToggleTheme,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Time Granularity Selector Tabs (日 / 周 / 月 / 年)
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
            ),
            child: Row(
              children: [
                _buildGrainTab('日', StatsGranularity.day),
                _buildGrainTab('周', StatsGranularity.week),
                _buildGrainTab('月', StatsGranularity.month),
                _buildGrainTab('年', StatsGranularity.year),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrainTab(String label, StatsGranularity g) {
    final isSelected = _granularity == g;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _granularity = g),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: BoxDecoration(
            color: isSelected ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(2.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? scheme.surface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. DAILY GOAL & STREAK CARD
  // ==========================================

  Widget _buildGoalStreakCard(BuildContext context, int todayMinutes, int streakDays) {
    final scheme = Theme.of(context).colorScheme;
    final pct = ((todayMinutes / _currentGoalMinutes) * 100).round().clamp(0, 100);
    final remaining = _currentGoalMinutes - todayMinutes;

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
          children: [
            Row(
              children: [
                // Circular Progress Ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(
                        value: pct / 100.0,
                        strokeWidth: 5.5,
                        backgroundColor: scheme.outline.withValues(alpha: 0.35),
                        color: scheme.onSurface,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$todayMinutes',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.1),
                        ),
                        Text(
                          '/ ${_currentGoalMinutes}分',
                          style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '今日目标完成度：$pct%',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          ArchiveCode('连续 $streakDays 天', fontSize: 8),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        todayMinutes == 0
                            ? '今日尚未开始阅读 · 设定目标 ${_currentGoalMinutes} 分钟'
                            : (remaining > 0
                                ? '连续阅读 $streakDays 天 · 今日还差 $remaining 分钟达成目标'
                                : '🎉 今日已达成设定的 $_currentGoalMinutes 分钟阅读目标！'),
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getGranularityTag(),
                        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: scheme.outline.withValues(alpha: 0.4), height: 1),
            const SizedBox(height: 12),

            // In-Card Interactive Goal Slider
            Row(
              children: [
                const Text('设定每日阅读目标', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const Spacer(),
                ArchiveCode('$_currentGoalMinutes 分钟', inverse: true, fontSize: 9),
              ],
            ),
            Slider(
              value: _currentGoalMinutes.toDouble(),
              min: 15,
              max: 180,
              divisions: 33, // 5 min increments
              activeColor: scheme.onSurface,
              inactiveColor: scheme.outline.withValues(alpha: 0.4),
              onChanged: (val) {
                setState(() => _currentGoalMinutes = val.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('15分钟 (轻度)', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                Text('60分钟 (标准)', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                Text('180分钟 (进阶)', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getGranularityTag() => switch (_granularity) {
        StatsGranularity.day => '统计维度：今日阅读实况',
        StatsGranularity.week => '统计维度：本周阅读实况',
        StatsGranularity.month => '统计维度：当月阅读走势',
        StatsGranularity.year => '统计维度：年度阅读概览',
      };

  // ==========================================
  // 3. 6-GRID CORE METRICS
  // ==========================================

  Widget _buildCoreMetricsGrid(
    BuildContext context, {
    required int totalBooks,
    required int readBooks,
    required int wpm,
    required String secPerPage,
    required String pagesPerHour,
    required double totalHours,
  }) {
    final completionPct = totalBooks > 0 ? (readBooks / totalBooks * 100).toStringAsFixed(1) : '0';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.48,
      children: [
        // 1. 书籍总数
        _buildMetricItem(
          context,
          label: '书籍总数',
          value: '$totalBooks 本',
          subtext: '书架导入共计 $totalBooks 本',
          badgeText: '总计',
        ),
        // 2. 已读书籍
        _buildMetricItem(
          context,
          label: '已读书籍',
          value: '$readBooks 本',
          subtext: '完成度 $completionPct%',
          badgeText: '$readBooks/$totalBooks',
        ),
        // 3. 每分钟字数
        _buildMetricItem(
          context,
          label: '每分钟阅读字数',
          value: '$wpm 字/分',
          subtext: wpm > 0 ? '基于真实阅读测算' : '暂无阅读数据',
        ),
        // 4. 每页阅读秒数
        _buildMetricItem(
          context,
          label: '每页阅读秒数',
          value: '$secPerPage 秒/页',
          subtext: secPerPage != '0' ? '翻页间隔时间测算' : '暂无阅读数据',
        ),
        // 5. 每小时翻页
        _buildMetricItem(
          context,
          label: '每小时翻页',
          value: '$pagesPerHour 页/时',
          subtext: pagesPerHour != '0' ? '阅读专注度状态' : '暂无阅读数据',
        ),
        // 6. 累计总时长
        _buildMetricItem(
          context,
          label: '累计阅读时长',
          value: '${totalHours.toStringAsFixed(1)} 小时',
          subtext: totalHours > 0 ? '跨书本累计总阅读时长' : '暂无阅读数据',
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    required String subtext,
    String? badgeText,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return ArchiveRegistration(
      inset: 2.0,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
          border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                if (badgeText != null) ArchiveCode(badgeText, fontSize: 8),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            Text(
              subtext,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. DYNAMIC CHART SECTION
  // ==========================================

  Widget _buildDynamicChartSection(BuildContext context, List<ReadingSession> sessions) {
    final scheme = Theme.of(context).colorScheme;

    final (title, meta) = switch (_granularity) {
      StatsGranularity.day => ('日视图：今日 24 小时阅读分布', '按小时打点记录'),
      StatsGranularity.week => ('周视图：本周 7 天阅读时长', '周一至周日分布'),
      StatsGranularity.month => ('月视图：当月每日阅读走势', '每日阅读时长打点'),
      StatsGranularity.year => ('年视图：年度 12 个月阅读大盘', '各月份阅读汇总'),
    };

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
            Row(
              children: [
                Container(width: 6, height: 6, color: scheme.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scheme.onSurface),
                  ),
                ),
                Text(meta, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: scheme.outline.withValues(alpha: 0.4), height: 1),
            const SizedBox(height: 14),

            // Bar Chart Area
            SizedBox(
              height: 110,
              child: _buildBarsForGranularity(context, sessions),
            ),
            const SizedBox(height: 8),

            // Axis labels (Removed all (深夜), (清晨), etc.)
            _buildAxisLabelsForGranularity(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBarsForGranularity(BuildContext context, List<ReadingSession> sessions) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    if (_granularity == StatsGranularity.day) {
      // 24 hours of today
      final hourly = List.filled(24, 0);
      for (final s in sessions) {
        if (s.startTime.year == now.year && s.startTime.month == now.month && s.startTime.day == now.day) {
          final h = s.startTime.hour.clamp(0, 23);
          hourly[h] += (s.durationSeconds ~/ 60);
        }
      }

      final maxVal = hourly.fold<int>(0, math.max);
      final divisor = maxVal > 0 ? maxVal.toDouble() : 1.0;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (i) {
          final val = hourly[i];
          final heightRatio = val > 0 ? (val / divisor).clamp(0.08, 1.0) : 0.04;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: Tooltip(
                message: '$i:00 - $val 分钟',
                child: Container(
                  height: 100 * heightRatio,
                  color: val > 0 ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
          );
        }),
      );
    } else if (_granularity == StatsGranularity.week) {
      // 7 days of this week (Monday to Sunday)
      final weekDays = List.filled(7, 0.0);
      final currentWeekday = now.weekday; // 1 = Monday
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentWeekday - 1));

      for (final s in sessions) {
        final sessionDay = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        final diff = sessionDay.difference(monday).inDays;
        if (diff >= 0 && diff < 7) {
          weekDays[diff] += (s.durationSeconds / 3600.0);
        }
      }

      final maxVal = weekDays.fold<double>(0.0, math.max);
      final divisor = maxVal > 0 ? maxVal : 1.0;
      final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final val = weekDays[i];
          final heightRatio = val > 0 ? (val / divisor).clamp(0.08, 1.0) : 0.04;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (val > 0)
                    Text('${val.toStringAsFixed(1)}h', style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Container(
                    height: 75 * heightRatio,
                    color: val > 0 ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 4),
                  Text(days[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }),
      );
    } else if (_granularity == StatsGranularity.month) {
      // Days of this month
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final monthDays = List.filled(daysInMonth, 0);

      for (final s in sessions) {
        if (s.startTime.year == now.year && s.startTime.month == now.month) {
          final d = (s.startTime.day - 1).clamp(0, daysInMonth - 1);
          monthDays[d] += (s.durationSeconds ~/ 60);
        }
      }

      final maxVal = monthDays.fold<int>(0, math.max);
      final divisor = maxVal > 0 ? maxVal.toDouble() : 1.0;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(daysInMonth, (i) {
          final val = monthDays[i];
          final heightRatio = val > 0 ? (val / divisor).clamp(0.08, 1.0) : 0.04;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.8),
              child: Tooltip(
                message: '${now.month}月${i + 1}日: $val 分钟',
                child: Container(
                  height: 100 * heightRatio,
                  color: val > 0 ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
          );
        }),
      );
    } else {
      // 12 months of this year
      final monthHours = List.filled(12, 0.0);
      for (final s in sessions) {
        if (s.startTime.year == now.year) {
          final m = (s.startTime.month - 1).clamp(0, 11);
          monthHours[m] += (s.durationSeconds / 3600.0);
        }
      }

      final maxVal = monthHours.fold<double>(0.0, math.max);
      final divisor = maxVal > 0 ? maxVal : 1.0;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (i) {
          final val = monthHours[i];
          final heightRatio = val > 0 ? (val / divisor).clamp(0.08, 1.0) : 0.04;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (val > 0)
                    Text('${val.toInt()}h', style: TextStyle(fontSize: 7.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Container(
                    height: 75 * heightRatio,
                    color: val > 0 ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 4),
                  Text('${i + 1}月', style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }),
      );
    }
  }

  Widget _buildAxisLabelsForGranularity(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 9, color: scheme.onSurfaceVariant);

    return switch (_granularity) {
      StatsGranularity.day => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00', style: style),
            Text('06:00', style: style),
            Text('12:00', style: style),
            Text('18:00', style: style),
            Text('24:00', style: style),
          ],
        ),
      StatsGranularity.week => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('周一', style: style),
            Text('周三', style: style),
            Text('周五', style: style),
            Text('周日', style: style),
          ],
        ),
      StatsGranularity.month => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1日', style: style),
            Text('10日', style: style),
            Text('20日', style: style),
            Text('月末', style: style),
          ],
        ),
      StatsGranularity.year => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1月', style: style),
            Text('4月', style: style),
            Text('7月', style: style),
            Text('10月', style: style),
            Text('12月', style: style),
          ],
        ),
    };
  }

  // ==========================================
  // 6. EXTERNAL TIMER BANNER
  // ==========================================

  Widget _buildExternalTimerBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExternalPaperTimerPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
          border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.onSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_outlined, size: 22, color: scheme.surface),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '实体纸质书阅读计时器',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '纸书阅读时长可实时计入量化大盘',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 7. FOOTER STAMP
  // ==========================================

  Widget _buildFooterStamp(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline, width: ArchivalTheme.hairlineThickness)),
      ),
      child: Text(
        '阿基米德阅读分析中心',
        style: TextStyle(
          fontSize: 10.0,
          color: scheme.onSurfaceVariant,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
