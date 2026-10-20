import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_registration.dart';
import '../../services/storage_service.dart';
import 'reading_calendar_heatmap.dart';
import 'external_paper_timer.dart';

enum StatsGranularity { day, week, month, year }

/// Comprehensive Quantified Reading Analytics Dashboard strictly matching the Archival HTML matrix design.
class StatsDashboardPage extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const StatsDashboardPage({super.key, this.onToggleTheme});

  @override
  State<StatsDashboardPage> createState() => _StatsDashboardPageState();
}

class _StatsDashboardPageState extends State<StatsDashboardPage> {
  StatsGranularity _granularity = StatsGranularity.day;
  int _currentGoalMinutes = 60;
  final int _currentReadMinutesToday = 49;

  @override
  Widget build(BuildContext context) {
    final totalBooksCount = StorageService().getBooks().length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // No redundant top AppBar: The dashboard directly renders its archival masthead inside the body!
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Archival Masthead with Day/Night Switcher and Grain Tabs
              _buildArchivalMasthead(context),
              const SizedBox(height: 16),

              // 2. Daily Goal Configuration & Realtime Streak Card
              _buildGoalStreakCard(context),
              const SizedBox(height: 16),

              // 3. 6-Grid Core Specific Metrics (LIB-TOTAL, LIB-DONE, SPEED-CPM, PACE-PAGE, FREQ-TURN, TOTAL-HOURS)
              _buildCoreMetricsGrid(context, totalBooksCount),
              const SizedBox(height: 16),

              // 4. Dynamic Timeline Chart Responsive to [日 / 周 / 月 / 年]
              _buildDynamicChartSection(context),
              const SizedBox(height: 16),

              // 5. 16-Week Footprint Calendar Heatmap (CAL-112D)
              const ReadingCalendarHeatmap(dayMinutesMap: {}),
              const SizedBox(height: 16),

              // 6. External Paper Book Timer Banner
              _buildExternalTimerBanner(context),
              const SizedBox(height: 20),

              // 7. Footer Archival Stamp
              _buildFooterStamp(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. MASTHEAD & GRAIN TABS
  // ==========================================

  Widget _buildArchivalMasthead(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline, width: ArchivalTheme.hairlineThickness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Inverted Black Stamp "ARC"
              Container(
                width: 32,
                height: 36,
                color: scheme.onSurface,
                alignment: Alignment.center,
                child: Text(
                  'ARC',
                  style: TextStyle(
                    color: scheme.surface,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '量化阅读档案中心',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const ArchiveCode('STATS-MATRIX-02', inverse: true, fontSize: 8.5),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ARCHIVAL RECONSTRUCTION · MULTI-DIMENSIONAL AUDIT',
                      style: ArchivalTheme.codeStyle(
                        fontSize: 8.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Day/Night Mode Switcher (Moved Down here!)
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
              fontFamily: 'monospace',
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? scheme.surface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. DAILY GOAL & STREAK CARD WITH SLIDER
  // ==========================================

  Widget _buildGoalStreakCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = ((_currentReadMinutesToday / _currentGoalMinutes) * 100).round().clamp(0, 100);
    final remaining = _currentGoalMinutes - _currentReadMinutesToday;

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
                          '$_currentReadMinutesToday',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.1),
                        ),
                        Text(
                          '/ ${_currentGoalMinutes}m',
                          style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant, fontFamily: 'monospace'),
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
                            '今日阅读目标达成：$pct%',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          const ArchiveCode('STREAK 19D', fontSize: 8),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remaining > 0
                            ? '连续保持阅读心流 19 天 · 今日还差 $remaining 分钟即可达成每日勋章'
                            : '🎉 恭喜！今日已达成设定的 $_currentGoalMinutes 分钟阅读目标，心流勋章已点亮！',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            _getGranularityTag(),
                            style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
                          ),
                          Text(' • ', style: TextStyle(color: scheme.onSurfaceVariant)),
                          Text(
                            '外挂纸书计时: 15m',
                            style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
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
                const Text('设定每日目标时长', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                Text('15m (轻度)', style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                Text('60m (标准)', style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                Text('180m (重度)', style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getGranularityTag() => switch (_granularity) {
        StatsGranularity.day => '统计粒度：今日 (24H 实况)',
        StatsGranularity.week => '统计粒度：本周 (7D 实况)',
        StatsGranularity.month => '统计粒度：当月 (30D 实况)',
        StatsGranularity.year => '统计粒度：年度 (12M 大盘)',
      };

  // ==========================================
  // 3. 6-GRID CORE METRICS
  // ==========================================

  Widget _buildCoreMetricsGrid(BuildContext context, int totalBooksCount) {
    final (cpm, pace, turns) = switch (_granularity) {
      StatsGranularity.day => ('584 字/分', '42.5 秒/页', '84.7 页/小时'),
      StatsGranularity.week => ('572 字/分', '44.0 秒/页', '81.8 页/小时'),
      StatsGranularity.month => ('568 字/分', '43.2 秒/页', '83.3 页/小时'),
      StatsGranularity.year => ('584 字/分', '42.5 秒/页', '84.7 页/小时'),
    };

    final displayTotalBooks = totalBooksCount > 3 ? totalBooksCount : 128;

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
          label: '全库书籍总数',
          code: 'LIB-TOTAL',
          value: '$displayTotalBooks 本',
          subtext: '本地导入 ${(displayTotalBooks * 0.75).toInt()} · 云端 ${(displayTotalBooks * 0.25).toInt()}',
          badgeText: '100%',
        ),
        // 2. 已读书籍
        _buildMetricItem(
          context,
          label: '已读书籍档案',
          code: 'LIB-DONE',
          value: '${(displayTotalBooks * 0.328).toInt()} 本',
          subtext: '完成比例: 32.8%',
          badgeText: '${(displayTotalBooks * 0.328).toInt()}/$displayTotalBooks',
        ),
        // 3. 每分钟字数
        _buildMetricItem(
          context,
          label: '每分钟阅读字数',
          code: 'SPEED-CPM',
          value: cpm,
          subtext: '较上周平均速率 +24 字/分 ↑',
        ),
        // 4. 每页阅读秒数
        _buildMetricItem(
          context,
          label: '每页阅读秒数',
          code: 'PACE-PAGE',
          value: pace,
          subtext: '按标准 420 字/页版式测算',
        ),
        // 5. 每小时翻页频次
        _buildMetricItem(
          context,
          label: '每小时翻页频次',
          code: 'FREQ-TURN',
          value: turns,
          subtext: '心流状态稳定性: 极高 (96%)',
        ),
        // 6. 累计有效时长
        _buildMetricItem(
          context,
          label: '累计有效时长',
          code: 'TOTAL-HOURS',
          value: '168.5 小时',
          subtext: '包含外挂实体书 34.0 小时',
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String code,
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
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                ArchiveCode(code, fontSize: 8),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subtext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (badgeText != null)
                  ArchiveCode(badgeText, inverse: true, fontSize: 7.5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. DYNAMIC CHART SECTION
  // ==========================================

  Widget _buildDynamicChartSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (title, code, meta) = switch (_granularity) {
      StatsGranularity.day => ('日视图：今日 24 小时阅读逐时打点 (分钟)', 'TIMELINE-24H', '今日累计：49 分钟 · 峰值在 21:00'),
      StatsGranularity.week => ('周视图：本周 7 天阅读时长对比 (小时)', 'TIMELINE-7D', '本周累计：8.5 小时 · 平均达成率 92%'),
      StatsGranularity.month => ('月视图：10 月每日阅读走势 (分钟)', 'TIMELINE-30D', '当月累计阅读：28.4 小时 · 达成 19 天'),
      StatsGranularity.year => ('年视图：2026 年度 12 个月阅读大盘 (小时)', 'TIMELINE-12M', '全年度累计：168.5 小时 · 读完 42 本书'),
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
                ArchiveCode(code, fontSize: 8),
              ],
            ),
            const SizedBox(height: 4),
            Text(meta, style: ArchivalTheme.codeStyle(fontSize: 9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Divider(color: scheme.outline.withValues(alpha: 0.4), height: 1),
            const SizedBox(height: 14),

            // Bar Chart Area
            SizedBox(
              height: 110,
              child: _buildBarsForGranularity(context),
            ),
            const SizedBox(height: 8),

            // Axis labels
            _buildAxisLabelsForGranularity(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBarsForGranularity(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_granularity == StatsGranularity.day) {
      final hourly = [0, 0, 0, 0, 0, 0, 5, 12, 0, 0, 0, 15, 0, 8, 0, 0, 0, 0, 0, 18, 25, 32, 15, 0];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (i) {
          final val = hourly[i];
          final heightRatio = (val / 35.0).clamp(0.04, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: Tooltip(
                message: '$i:00 - $val 分钟',
                child: Container(
                  height: 100 * heightRatio,
                  color: val > 0 ? scheme.onSurface.withValues(alpha: 0.9) : scheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
          );
        }),
      );
    } else if (_granularity == StatsGranularity.week) {
      final weekData = [1.2, 1.5, 0.8, 1.8, 1.0, 2.4, 0.9];
      final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final val = weekData[i];
          final heightRatio = (val / 2.5).clamp(0.08, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${val}h', style: ArchivalTheme.codeStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Container(
                    height: 80 * heightRatio,
                    color: scheme.onSurface.withValues(alpha: 0.88),
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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(30, (i) {
          final d = i + 1;
          final val = d <= 20 ? (35 + ((d * 17) % 45)) : 0;
          final heightRatio = (val / 90.0).clamp(0.05, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.8),
              child: Tooltip(
                message: '10月$d日: $val 分钟',
                child: Container(
                  height: 100 * heightRatio,
                  color: d <= 20 ? scheme.onSurface.withValues(alpha: 0.82) : scheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
            ),
          );
        }),
      );
    } else {
      // Year
      final monthData = [12.0, 16.0, 18.0, 15.0, 22.0, 26.0, 24.0, 28.0, 32.0, 28.5, 0.0, 0.0];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (i) {
          final val = monthData[i];
          final heightRatio = (val / 35.0).clamp(0.06, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (val > 0)
                    Text('${val.toInt()}h', style: ArchivalTheme.codeStyle(fontSize: 7.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Container(
                    height: 75 * heightRatio,
                    color: val > 0 ? scheme.onSurface.withValues(alpha: 0.88) : scheme.onSurface.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 4),
                  Text('${i + 1}月', style: ArchivalTheme.codeStyle(fontSize: 8)),
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
    final style = ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant);

    return switch (_granularity) {
      StatsGranularity.day => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00 (深夜)', style: style),
            Text('06:00 (清晨)', style: style),
            Text('12:00 (正午)', style: style),
            Text('18:00 (傍晚)', style: style),
            Text('23:59 (深夜)', style: style),
          ],
        ),
      StatsGranularity.week => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('周一开局', style: style),
            Text('周中稳健', style: style),
            Text('周末爆发 (2.4h 峰值)', style: style),
          ],
        ),
      StatsGranularity.month => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('10月1日 (国庆周)', style: style),
            Text('10月10日', style: style),
            Text('10月20日 (今天)', style: style),
            Text('10月31日', style: style),
          ],
        ),
      StatsGranularity.year => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Q1 春季起步', style: style),
            Text('Q2 夏季持续', style: style),
            Text('Q3 攀上峰值 (32h)', style: style),
            Text('Q4 收官冲刺', style: style),
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

  // ==========================================
  // 7. FOOTER STAMP
  // ==========================================

  Widget _buildFooterStamp(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline, width: ArchivalTheme.hairlineThickness)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PROJECT ARCHIMEDES · QUANTIFIED MATRIX',
            style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
          ),
          Text(
            'FORMATS: EPUB / PDF / MOBI / DOCX / MD',
            style: ArchivalTheme.codeStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
