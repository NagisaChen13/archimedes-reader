import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_masthead.dart';
import '../../services/storage_service.dart';
import 'reading_calendar_heatmap.dart';
import 'external_paper_timer.dart';

enum StatsGranularity { day, week, month, year }

/// Comprehensive Quantified Reading Analytics Dashboard
class StatsDashboardPage extends StatefulWidget {
  const StatsDashboardPage({super.key});

  @override
  State<StatsDashboardPage> createState() => _StatsDashboardPageState();
}

class _StatsDashboardPageState extends State<StatsDashboardPage> {
  StatsGranularity _granularity = StatsGranularity.day;
  int _dailyGoalMinutes = 60;
  int _currentReadMinutesToday = 45;

  late final Map<DateTime, int> _mockDayMinutesMap;

  @override
  void initState() {
    super.initState();
    _mockDayMinutesMap = _generateMockHeatmapData();
  }

  Map<DateTime, int> _generateMockHeatmapData() {
    final map = <DateTime, int>{};
    final now = DateTime.now();
    for (int i = 0; i < 112; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      // Simulate reading patterns with activity clusters
      if (i % 7 == 0 || i % 7 == 6) {
        map[date] = (i * 17) % 95; // weekends
      } else if (i % 3 == 0) {
        map[date] = (i * 23) % 70;
      } else if (i % 5 == 0) {
        map[date] = 0;
      } else {
        map[date] = (i * 13) % 45;
      }
    }
    map[DateTime(now.year, now.month, now.day)] = _currentReadMinutesToday;
    return map;
  }

  void _showSetGoalDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final options = [15, 30, 45, 60, 90, 120];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '设定每日阅读目标',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ArchiveCode('GOAL-${_dailyGoalMinutes}M', inverse: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '量化每一天的心流阅读时长，形成持续专注的阅读习惯。',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: options.map((m) {
                      final selected = _dailyGoalMinutes == m;
                      return ChoiceChip(
                        label: Text('$m 分钟'),
                        selected: selected,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => _dailyGoalMinutes = m);
                            setState(() => _dailyGoalMinutes = m);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.onSurface,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('保存目标配置'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBooksCount = StorageService().getBooks().length;

    return Scaffold(
      appBar: const ArchiveMasthead(
        title: '量化阅读数据中心',
        code: 'STATS-HUB-01',
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Granularity Switcher: Day, Week, Month, Year
            _buildGranularitySwitcher(),
            const SizedBox(height: 16),

            // Daily Goal & Streak Card
            _buildGoalStreakCard(context),
            const SizedBox(height: 24),

            // Footprint Heatmap
            ReadingCalendarHeatmap(dayMinutesMap: _mockDayMinutesMap),
            const SizedBox(height: 24),

            // Reading Metrics Grid
            ArchiveSectionHeader(
              title: _getSectionTitleByGranularity(_granularity),
              code: 'METRICS-01',
            ),
            const SizedBox(height: 12),
            _buildMetricsGrid(context, totalBooksCount),
            const SizedBox(height: 24),

            // External Paper Book Timer Banner
            _buildExternalTimerBanner(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _getSectionTitleByGranularity(StatsGranularity g) => switch (g) {
        StatsGranularity.day => '今日阅读深度指标',
        StatsGranularity.week => '本周阅读资产指标',
        StatsGranularity.month => '本月阅读资产指标',
        StatsGranularity.year => '年度阅读资产指标',
      };

  Widget _buildGranularitySwitcher() {
    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: ArchivalTheme.hairlineThickness,
        ),
      ),
      child: Row(
        children: [
          _buildGranularityTab('日统计', StatsGranularity.day),
          _buildGranularityTab('周统计', StatsGranularity.week),
          _buildGranularityTab('月统计', StatsGranularity.month),
          _buildGranularityTab('年统计', StatsGranularity.year),
        ],
      ),
    );
  }

  Widget _buildGranularityTab(String label, StatsGranularity g) {
    final isSelected = _granularity == g;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _granularity = g),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? scheme.surface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalStreakCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (_currentReadMinutesToday / _dailyGoalMinutes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
        border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
      ),
      child: Row(
        children: [
          // Circular Goal Progress
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 6.5,
                  backgroundColor: scheme.outline.withValues(alpha: 0.4),
                  color: scheme.onSurface,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentReadMinutesToday',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Text(
                    '/ ${_dailyGoalMinutes}m',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '今日目标达成 ${(percent * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showSetGoalDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.onSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '设置目标',
                          style: TextStyle(fontSize: 10, color: scheme.surface, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '已连续打卡阅读 18 天 · 保持专注心流',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, int totalBooksCount) {
    // Dynamic values based on selected granularity
    final (readDuration, readWords, cpmSpeed, secPerPage, turnsPerHour, finishedBooks) = switch (_granularity) {
      StatsGranularity.day => ('45 分钟', '2.8 万字', '620 字/分', '26 秒/页', '138 页/时', '0 本'),
      StatsGranularity.week => ('6.2 小时', '18.4 万字', '615 字/分', '27 秒/页', '132 页/时', '1 本'),
      StatsGranularity.month => ('28.5 小时', '86.2 万字', '635 字/分', '28 秒/页', '128 页/时', '4 本'),
      StatsGranularity.year => ('142.5 小时', '412 万字', '642 字/分', '28 秒/页', '128 页/时', '14 本'),
    };

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        _MetricCard(label: '书籍总数', value: '$totalBooksCount 本', code: 'BOOK-ALL'),
        _MetricCard(label: '已读书籍', value: finishedBooks, code: 'BOOK-FIN'),
        _MetricCard(label: '每分钟阅读字数', value: cpmSpeed, code: 'CPM-SPD'),
        _MetricCard(label: '每页阅读秒数', value: secPerPage, code: 'SEC-PAGE'),
        _MetricCard(label: '每小时翻页', value: turnsPerHour, code: 'PAGE-HR'),
        _MetricCard(label: '阅读时长', value: readDuration, code: 'DUR-TIME'),
        _MetricCard(label: '阅读字数', value: readWords, code: 'WORD-CNT'),
        const _MetricCard(label: '连续打卡', value: '18 天', code: 'STREAK'),
      ],
    );
  }

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
                    '开启外挂实体书计时器',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '读纸质书或听播客的时长亦可无缝并入统计',
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
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String code;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ArchiveCode(code, fontSize: 7.5),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
