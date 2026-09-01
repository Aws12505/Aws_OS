part of '../../screens/day_detail_screen.dart';

/// One exercise and its sets.
class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.dayId,
    required this.exercise,
    this.inside = false,
  });

  final String dayId;
  final DayExercise exercise;

  /// True when nested inside a superset group, which supplies its own frame.
  final bool inside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync = ref.watch(
      prescriptionsForExerciseProvider(exercise.id),
    );
    // The query orders each set_index group newest-first, so index 0 is the
    // current prescription and index 1 is what it was before that.
    final byIndex = <int, List<ExerciseSetPrescription>>{};
    for (final p
        in (prescriptionsAsync.value ?? const <ExerciseSetPrescription>[])) {
      byIndex.putIfAbsent(p.setIndex, () => []).add(p);
    }

    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExerciseAvatar(name: exercise.exerciseName),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(exercise.exerciseName, style: tt.titleMedium),
            ),
            Text(
              '${exercise.targetSets} sets',
              style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
            ),
            IconButton(
              tooltip: 'History for ${exercise.exerciseName}',
              icon: const Icon(Icons.history_rounded, size: 20),
              onPressed: () =>
                  _showExerciseHistory(context, exercise: exercise),
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions for ${exercise.exerciseName}',
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    _showAddExercise(
                      context,
                      dayId: exercise.dayId,
                      supersetGroupId: exercise.supersetGroupId,
                      nextPosition: exercise.position,
                      existing: exercise,
                    );
                  case 'delete':
                    final ok = await showAppConfirmDialog(
                      context,
                      title: 'Remove ${exercise.exerciseName}?',
                      message:
                          'Its logged reps and weights go with it, and that '
                          'cannot be undone.',
                      confirmLabel: 'Remove',
                      destructive: true,
                    );
                    if (ok) {
                      await ref
                          .read(gymDaoProvider)
                          .deleteExercise(exercise.id);
                    }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 1; i <= exercise.targetSets; i++)
          _SetRow(
            dayId: dayId,
            exerciseId: exercise.id,
            setIndex: i,
            current: (byIndex[i]?.isNotEmpty ?? false) ? byIndex[i]![0] : null,
            previous: (byIndex[i]?.length ?? 0) > 1 ? byIndex[i]![1] : null,
          ),
      ],
    );

    if (inside) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: content,
      );
    }
    return AppCard(
      style: CardStyle.block,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: content,
    );
  }
}
