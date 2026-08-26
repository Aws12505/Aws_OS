part of '../../screens/day_detail_screen.dart';

/// A superset: exercises done back to back, resting only after the last.
///
/// The round count is editable here. The column and the DAO method for it have
/// always existed, but nothing ever called them, so every superset in the app
/// was permanently stuck at three rounds.
class _SupersetCard extends ConsumerWidget {
  const _SupersetCard({
    required this.dayId,
    required this.group,
    required this.members,
  });

  final String dayId;
  final SupersetGroup group;
  final List<DayExercise> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = context.sem.gym;
    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      tone: SurfaceTone.raised,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: accent.fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Superset',
                  style: tt.labelLarge?.copyWith(color: accent.fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _RoundsControl(group: group),
              IconButton(
                tooltip: 'Remove superset',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () async {
                  final ok = await showAppConfirmDialog(
                    context,
                    title: 'Remove this superset?',
                    message: members.isEmpty
                        ? 'It has no exercises in it yet.'
                        : 'The ${members.length} exercises inside go too, '
                              'along with their logged reps and weights.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (ok) {
                    await ref.read(gymDaoProvider).deleteSuperset(group.id);
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: AppSpacing.xs),
            child: Text(
              'Back to back, rest after the last one.',
              style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
            ),
          ),
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const SizedBox(width: 13),
                    Icon(Icons.add_rounded, size: 14, color: accent.base),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Divider(color: surfaces.hairline)),
                  ],
                ),
              ),
            _ExerciseCard(dayId: dayId, exercise: members[i], inside: true),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add to superset'),
              onPressed: () => _showAddExercise(
                context,
                dayId: dayId,
                supersetGroupId: group.id,
                nextPosition: members.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounds for a superset, adjustable in place.
class _RoundsControl extends ConsumerWidget {
  const _RoundsControl({required this.group});

  final SupersetGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;

    Future<void> set(int rounds) async {
      if (rounds < 1 || rounds > 20) return;
      HapticFeedback.selectionClick();
      await ref
          .read(gymDaoProvider)
          .updateSuperset(group.id, targetSets: rounds);
    }

    return Semantics(
      label: '${group.targetSets} rounds',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'One round fewer',
            icon: const Icon(Icons.remove_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: group.targetSets > 1
                ? () => set(group.targetSets - 1)
                : null,
          ),
          Text(
            '${group.targetSets}',
            style: context.type.numeric.copyWith(color: surfaces.textPrimary),
          ),
          const SizedBox(width: 3),
          Text(
            group.targetSets == 1 ? 'round' : 'rounds',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: surfaces.textTertiary,
            ),
          ),
          IconButton(
            tooltip: 'One round more',
            icon: const Icon(Icons.add_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => set(group.targetSets + 1),
          ),
        ],
      ),
    );
  }
}
