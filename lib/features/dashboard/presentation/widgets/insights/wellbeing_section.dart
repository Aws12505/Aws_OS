part of '../../insights_view.dart';

// Mood and energy from the debrief journal.

class _WellbeingSection extends ConsumerWidget {
  const _WellbeingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    if (rs == null) return const SizedBox.shrink();
    if (rs.daysWithDebrief == 0) return const SizedBox.shrink();

    final moodColor = context.sem.exchange.base;
    final energyColor = context.sem.tasks.base;
    final labels = _labels(rs);
    final mood = [for (final d in rs.days) d.debrief?.mood?.toDouble()];
    final energy = [for (final d in rs.days) d.debrief?.energy?.toDouble()];

    return InsightsCard(
      icon: Icons.self_improvement_rounded,
      color: context.sem.chartAt(6),
      title: 'Wellbeing',
      subtitle: '${rs.daysWithDebrief} days journaled',
      takeaway: _wellbeingTakeaway(rs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Avg mood',
                  value: rs.avgMood == 0 ? '-' : rs.avgMood.toStringAsFixed(1),
                  accent: moodColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Avg energy',
                  value: rs.avgEnergy == 0
                      ? '-'
                      : rs.avgEnergy.toStringAsFixed(1),
                  accent: energyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _legend([(moodColor, 'Mood'), (energyColor, 'Energy')]),
          const SizedBox(height: AppSpacing.sm),
          TrendLineChart(
            height: 130,
            xLabels: labels,
            leftFormatter: (v) => v.round().toString(),
            series: [
              LineSeries(values: mood, color: moodColor),
              LineSeries(values: energy, color: energyColor),
            ],
          ),
        ],
      ),
    );
  }
}


/// Mood and energy read together, since one without the other says little.
String? _wellbeingTakeaway(RangeSummary rs) {
  if (rs.daysWithDebrief < 2) return null;
  final mood = rs.avgMood;
  final energy = rs.avgEnergy;
  if (mood == 0 || energy == 0) return null;

  final moodWord = MoodColors.labelForScore(mood.round()).toLowerCase();
  final gap = mood - energy;
  if (gap >= 1) {
    return 'Mood averages $moodWord while energy runs lower, which usually '
        'means rest rather than motivation.';
  }
  if (gap <= -1) {
    return 'Energy is holding up better than mood over this range.';
  }
  return 'Mood and energy both average $moodWord across the days you '
      'journaled.';
}
