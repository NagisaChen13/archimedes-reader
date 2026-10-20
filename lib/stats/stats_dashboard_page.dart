import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_masthead.dart';
import 'reading_calendar_heatmap.dart';
import 'external_paper_timer.dart';

/// Comprehensive Quantified Reading Analytics Dashboard
class StatsDashboardPage extends StatelessWidget {
  const StatsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            // Daily Goal & Streak Card
            _buildGoalStreakCard(context),
            const SizedBox(height: 24),

            // Footprint Heatmap
            const ReadingCalendarHeatmap(dayMinutesMap: {}),
            const SizedBox(height: 24),

            // Reading Metrics Grid
            const ArchiveSectionHeader(title: '全库阅读资产指标', code: 'METRICS-01'),
            const SizedBox(height: 12),
            _buildMetricsGrid(context),
            const SizedBox(height: 28),

            // External Paper Book Timer Banner
            _buildExternalTimerBanner(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalStreakCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: 0.75, // 45 / 60 mins
                  strokeWidth: 6.0,
                  backgroundColor: scheme.outline,
                  color: scheme.onSurface,
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('45', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text('m', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      '今日目标达成 75%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    const ArchiveCode('GOAL-60M', inverse: true),
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

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: const [
        _MetricCard(label: '全库累计读完', value: '38 本', code: 'MET-01'),
        _MetricCard(label: '累计阅读字数', value: '412 万字', code: 'MET-02'),
        _MetricCard(label: '平均阅读速度', value: '580 字/分', code: 'MET-03'),
        _MetricCard(label: '总阅读时长', value: '142 小时', code: 'MET-04'),
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
      padding: const EdgeInsets.all(14.0),
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
              ArchiveCode(code, fontSize: 8),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
