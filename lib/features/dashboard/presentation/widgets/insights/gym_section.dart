part of '../../insights_view.dart';

// Training and body measurements.

class _GymSection extends ConsumerWidget {
  const _GymSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    final gym = ref.watch(gymForecastProvider).value;
    if (rs == null) return const _LoadingCard();
    final measurements = gym?.measurements ?? const <MeasurementTrend>[];
    if (rs.totalWorkouts == 0 && measurements.isEmpty) {
      return const SizedBox.shrink();
    }

    // Weekly workout counts across the range.
    final weekly = <DateTime, int>{};
    for (final d in rs.days) {
      final wk = _mondayOf(d.date);
      weekly.update(
        wk,
        (v) => v + d.sessionCount,
        ifAbsent: () => d.sessionCount,
      );
    }
    final weeks = weekly.keys.toList()..sort();
    final weekLabels = [for (final w in weeks) DateFormat('d/M').format(w)];
    final weekValues = [for (final w in weeks) weekly[w]!.toDouble()];

    return InsightsCard(
      icon: Icons.fitness_center_rounded,
      color: context.sem.gym.base,
      title: 'Gym & body',
      takeaway: _gymTakeaway(rs, gym),
      subtitle: gym == null
          ? null
          : '${gym.sessionsPerWeek.toStringAsFixed(1)}/wk · streak ${gym.currentWeekStreak}w',
      onTap: () => context.go('/gym'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weekValues.any((v) => v > 0)) ...[
            Text(
              'Workouts per week',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GroupedBarChart(
              height: 130,
              xLabels: weekLabels,
              series: [
                BarSeries(
                  label: 'Workouts',
                  color: context.sem.gym.base,
                  values: weekValues,
                ),
              ],
            ),
          ],
          if (measurements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Body measurements',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final m in measurements.take(4)) _MeasurementRow(trend: m),
          ],
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.trend});
  final MeasurementTrend trend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final up = trend.change > 0;
    final flat = trend.change.abs() < 1e-9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              trend.name,
              style: tt.bodySmall?.weight(FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Sparkline(
              values: trend.series,
              color: cs.primary,
              height: 28,
              fill: true,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_trim(trend.latest)}${trend.unit}',
                style: tt.bodySmall?.weight(FontWeight.w700),
              ),
              Row(
                children: [
                  Icon(
                    flat
                        ? Icons.remove_rounded
                        : up
                        ? Icons.north_east_rounded
                        : Icons.south_east_rounded,
                    size: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${_trim(trend.change.abs())}${trend.unit}',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}


/// Training frequency, said plainly.
String? _gymTakeaway(RangeSummary rs, GymForecast? gym) {
  if (gym == null || !gym.hasData) return null;
  final perWeek = gym.sessionsPerWeek;
  if (perWeek <= 0) return null;
  final rounded = perWeek.toStringAsFixed(1);
  if (gym.currentWeekStreak > 1) {
    return 'About $rounded sessions a week, ${gym.currentWeekStreak} weeks '
        'running.';
  }
  if (perWeek >= 3) return 'About $rounded sessions a week, which is steady.';
  return 'About $rounded sessions a week.';
}
