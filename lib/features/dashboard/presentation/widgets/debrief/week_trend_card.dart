part of '../../debrief_screen.dart';

// The last seven days at a glance.

class _WeekTrendCard extends ConsumerWidget {
  const _WeekTrendCard({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeAsync = ref.watch(
      rangeSummaryProvider((start: day.addDays(-6), end: day)),
    );
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week',
            style: tt.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          rangeAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: AppLoading(),
            ),
            error: (e, _) =>
                Text('$e', style: tt.bodySmall?.copyWith(color: cs.error)),
            data: (range) {
              final maxNet = range.days
                  .map(
                    (d) => d.netByCurrency.values
                        .fold<double>(0, (s, v) => s + v)
                        .abs(),
                  )
                  .fold<double>(1, (a, b) => a > b ? a : b);
              return Column(
                children: [
                  SizedBox(
                    height: 132,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in range.days)
                          Expanded(
                            child: _DayBar(
                              completion: d.taskCompletion,
                              hasTasks: d.tasksDue > 0,
                              workedOut: d.workedOut,
                              mood: d.debrief?.mood,
                              label: DateFormat('E').format(d.date)[0],
                              isToday: d.date.isSameDay(DateTime.now()),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(
                        label: 'Workouts',
                        value: '${range.totalWorkouts}',
                      ),
                      _MiniStat(
                        label: 'Tasks done',
                        value: '${range.totalTasksDone}',
                      ),
                      _MiniStat(
                        label: 'Avg mood',
                        value: range.avgMood == 0
                            ? '-'
                            : range.avgMood.toStringAsFixed(1),
                      ),
                    ],
                  ),
                  if (maxNet < 0) const SizedBox.shrink(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.completion,
    required this.hasTasks,
    required this.workedOut,
    required this.mood,
    required this.label,
    required this.isToday,
  });

  final double completion;
  final bool hasTasks;
  final bool workedOut;
  final int? mood;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Fully dynamic: the bar lives in an Expanded area and is sized as a
    // fraction of whatever height is available, so it can never overflow.
    return Column(
      children: [
        SizedBox(
          height: 14,
          child: workedOut
              ? Icon(
                  Icons.fitness_center_rounded,
                  size: 12,
                  color: context.sem.gym.base,
                )
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: hasTasks ? (0.06 + completion * 0.94) : 0.06,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: hasTasks
                        ? (completion >= 1
                                  ? context.sem.income.base
                                  : context.sem.tasks.base)
                              .withValues(alpha: 0.85)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // A colour-only dot says nothing to a screen reader, and nothing
        // useful to a red-green colourblind reader either. The word goes to
        // assistive tech; the dot stays visual.
        Semantics(
          label: mood == null
              ? 'no mood recorded'
              : 'mood ${MoodColors.labelForScore(mood!).toLowerCase()}',
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mood != null
                  ? MoodColors.forScore(mood!)
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: isToday ? cs.primary : cs.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: tt.titleLarge?.copyWith(
              letterSpacing: -0.5,
            ).weight(FontWeight.w800),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
