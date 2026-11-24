import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mood_repository.dart';
import '../domain/mood.dart';

/// Weekly / monthly view of the student's OWN entries. Purely descriptive –
/// no scores, risk levels or interpretations.
class MoodAnalyticsScreen extends ConsumerStatefulWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  ConsumerState<MoodAnalyticsScreen> createState() => _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends ConsumerState<MoodAnalyticsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(moodEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your mood patterns')),
      body: AsyncValueView<List<MoodEntry>>(
        value: entries,
        onRetry: () => ref.invalidate(moodEntriesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          title: 'Nothing to chart yet',
          message: 'Check in for a few days and your patterns will appear here.',
          icon: Icons.insights_rounded,
          actionLabel: 'Check in now',
          onAction: () => context.go(AppRoutes.mood),
        ),
        data: (all) {
          final cutoff = DateTime.now().subtract(Duration(days: _days));
          final inRange = all.where((e) => e.createdAt.isAfter(cutoff)).toList();
          final stats = MoodStats(inRange);
          final streak = MoodStats(all).streak();
          return PageBody(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('Week'), icon: Icon(Icons.view_week_outlined)),
                  ButtonSegment(value: 30, label: Text('Month'), icon: Icon(Icons.calendar_month_outlined)),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
              AppSpacing.gapMd,
              ResponsiveGrid(
                minTileWidth: 140,
                children: [
                  _StatTile(label: 'Check-ins', value: '${inRange.length}', icon: Icons.check_circle_outline),
                  _StatTile(label: 'Day streak', value: '$streak', icon: Icons.local_fire_department_outlined),
                  _StatTile(
                    label: 'Most often',
                    value: stats.mostCommon == null ? '–' : '${stats.mostCommon!.emoji} ${stats.mostCommon!.label}',
                    icon: Icons.favorite_border_rounded,
                  ),
                  _StatTile(
                    label: 'Common reason',
                    value: stats.topReason?.label ?? '–',
                    icon: Icons.label_outline_rounded,
                  ),
                ],
              ),
              const SectionHeader(title: 'Daily mood'),
              AppCard(
                child: SizedBox(
                  height: 220,
                  child: Semantics(
                    label: 'Line chart of your average daily mood over the last $_days days',
                    child: _MoodLineChart(averages: stats.dailyAverages(_days), days: _days),
                  ),
                ),
              ),
              const SectionHeader(title: 'How often you felt each mood'),
              AppCard(
                child: SizedBox(
                  height: 200,
                  child: Semantics(
                    label: 'Bar chart: ${stats.counts.entries.map((e) => '${e.key.label} ${e.value}').join(', ')}',
                    child: _MoodBarChart(counts: stats.counts),
                  ),
                ),
              ),
              AppSpacing.gapMd,
              const InfoBanner(
                message: 'These charts simply reflect what you recorded. They are not an '
                    'assessment. If you are finding things hard, talking to a counsellor can help.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary),
          AppSpacing.gapXs,
          Text(value, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _MoodLineChart extends StatelessWidget {
  const _MoodLineChart({required this.averages, required this.days});

  final List<double?> averages;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final today = DateUtils.dateOnly(DateTime.now());
    final spots = [
      for (var i = 0; i < averages.length; i++)
        averages[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), averages[i]!),
    ];
    final labelEvery = days <= 7 ? 1 : 7;
    return LineChart(
      LineChartData(
        minY: 0.5,
        maxY: 5.5,
        minX: 0,
        maxX: (days - 1).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 34,
              getTitlesWidget: (v, meta) {
                final m = Mood.values.where((m) => m.score == v.round() && v == v.roundToDouble());
                return SideTitleWidget(
                  meta: meta,
                  child: Text(m.isEmpty ? '' : m.first.emoji, style: const TextStyle(fontSize: 16)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                final daysAgo = days - 1 - i;
                if (v != v.roundToDouble() || daysAgo % labelEvery != 0) {
                  return const SizedBox.shrink();
                }
                final d = today.subtract(Duration(days: daysAgo));
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    days <= 7 ? DateFormat('E').format(d) : DateFormat('d/M').format(d),
                    style: context.text.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: scheme.primary.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}

class _MoodBarChart extends StatelessWidget {
  const _MoodBarChart({required this.counts});

  final Map<Mood, int> counts;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: (maxCount == 0 ? 1 : maxCount) * 1.2,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) {
                final m = Mood.values[v.toInt()];
                return SideTitleWidget(
                  meta: meta,
                  child: Column(
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 18)),
                      Text('${counts[m]}', style: context.text.labelSmall),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < Mood.values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: counts[Mood.values[i]]!.toDouble(),
                  color: Mood.values[i].color,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
