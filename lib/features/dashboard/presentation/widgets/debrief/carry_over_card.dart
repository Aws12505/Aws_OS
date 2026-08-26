part of '../../debrief_screen.dart';

// Unfinished work, and moving it forward.

class _CarryOverCard extends ConsumerWidget {
  const _CarryOverCard({required this.day, required this.summary});
  final DateTime day;
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unfinished = summary.tasksDue - summary.tasksDone;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (unfinished <= 0) return const SizedBox.shrink();
    final target = day.addDays(1);
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.sem.warning.base.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.arrow_circle_right_rounded,
              color: context.sem.warning.base,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan tomorrow',
                  style: tt.titleSmall?.weight(FontWeight.w700),
                ),
                Text(
                  '$unfinished unfinished task${unfinished == 1 ? '' : 's'} can move to ${DateFormat('MMM d').format(target)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: () async {
              final moved = await ref
                  .read(tasks.tasksRepositoryProvider)
                  .carryOverUnfinished(from: day);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved $moved to tomorrow')),
              );
            },
            child: const Text('Carry over'),
          ),
        ],
      ),
    );
  }
}
