part of '../../insights_view.dart';

// Task completion over the range.

class _ProductivitySection extends ConsumerWidget {
  const _ProductivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    final prod = ref.watch(productivityForecastProvider).value;
    if (rs == null) return const _LoadingCard();
    if (rs.totalTasksDue == 0 && (prod?.overdue ?? 0) == 0) {
      return const SizedBox.shrink();
    }
    final labels = _labels(rs);
    final series = [
      for (final d in rs.days) d.tasksDue > 0 ? d.taskCompletion * 100 : null,
    ];

    return InsightsCard(
      icon: Icons.task_alt_rounded,
      color: context.sem.tasks.base,
      title: 'Productivity',
      subtitle: '${rs.totalTasksDone}/${rs.totalTasksDue} tasks completed',
      takeaway: _productivityTakeaway(rs, prod),
      onTap: () => context.go('/tasks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Completion',
                  value: rs.totalTasksDue == 0
                      ? '-'
                      : '${(rs.avgTaskCompletion * 100).round()}%',
                  accent: context.sem.tasks.base,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Done',
                  value: '${rs.totalTasksDone}',
                  accent: context.sem.tasks.base,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Overdue',
                  value: '${prod?.overdue ?? 0}',
                  accent: context.sem.warning.base,
                  valueColor: (prod?.overdue ?? 0) > 0
                      ? context.sem.warning.base
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Daily completion rate',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendLineChart(
            height: 140,
            xLabels: labels,
            leftFormatter: (v) => '${v.round()}%',
            series: [
              LineSeries(values: series, color: context.sem.tasks.base, fill: true),
            ],
          ),
        ],
      ),
    );
  }
}


/// What the completion line actually says. Overdue work outranks a good
/// average, because that is the thing you can act on today.
String? _productivityTakeaway(RangeSummary rs, ProductivityForecast? prod) {
  final overdue = prod?.overdue ?? 0;
  if (overdue > 0) {
    return overdue == 1
        ? '1 task is overdue. Clear or reschedule it before anything else.'
        : '$overdue tasks are overdue. Clear or reschedule them before '
              'anything else.';
  }
  if (rs.totalTasksDue == 0) return null;
  final percent = (rs.avgTaskCompletion * 100).round();
  if (percent >= 90) return 'You are closing almost everything you plan.';
  if (percent >= 60) {
    return 'You finish about $percent% of what you plan on a given day.';
  }
  return 'You finish about $percent% of what you plan, so the daily list is '
      'probably longer than the day.';
}
