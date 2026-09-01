part of '../../screens/day_detail_screen.dart';

/// Full, all-time prescription history for one exercise: every set index, every
/// edit. Opened as a sheet over the day screen so nobody has to leave the
/// workout to check their progression.
void _showExerciseHistory(
  BuildContext context, {
  required DayExercise exercise,
}) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx2, ref, _) {
        final prescriptionsAsync = ref.watch(
          prescriptionsForExerciseProvider(exercise.id),
        );
        final byIndex = <int, List<ExerciseSetPrescription>>{};
        for (final p
            in (prescriptionsAsync.value ??
                const <ExerciseSetPrescription>[])) {
          byIndex.putIfAbsent(p.setIndex, () => []).add(p);
        }
        final indices = byIndex.keys.toList()..sort();

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx3, scrollController) => Builder(
              builder: (ctx4) {
                final surfaces = ctx4.surfaces;
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.xxl),
                  children: [
                    Row(
                      children: [
                        ExerciseAvatar(name: exercise.exerciseName, size: 34),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            exercise.exerciseName,
                            style: Theme.of(ctx4).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (indices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: Text(
                          'No history yet. Tick a set off to start logging.',
                        ),
                      )
                    else
                      for (final i in indices) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.lg,
                            bottom: AppSpacing.xs,
                          ),
                          child: Text(
                            'Set $i',
                            style: Theme.of(ctx4).textTheme.labelMedium
                                ?.copyWith(color: surfaces.textSecondary),
                          ),
                        ),
                        for (final p in byIndex[i]!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${p.reps} x ${_fmtSetWeight(p.weight)}',
                                    style: ctx4.type.numeric,
                                  ),
                                ),
                                Text(
                                  DateFormat.yMMMd().add_jm().format(
                                    p.effectiveFrom,
                                  ),
                                  style: Theme.of(ctx4).textTheme.bodySmall
                                      ?.copyWith(color: surfaces.textTertiary),
                                ),
                              ],
                            ),
                          ),
                      ],
                  ],
                );
              },
          ),
        );
      },
    ),
  );
}
