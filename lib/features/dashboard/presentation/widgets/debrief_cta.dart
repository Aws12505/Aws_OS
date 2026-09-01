part of '../dashboard_screen.dart';

// Prompt into the end-of-day journal.

class _DebriefCta extends ConsumerWidget {
  const _DebriefCta({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isToday = date.isSameDay(DateTime.now());
    final reviewed = ref.watch(debriefForDayProvider(date)).value != null;
    return AppCard(
      style: CardStyle.block,
      borderColor: cs.primary.withValues(alpha: 0.35),
      onTap: () => context.push('/debrief?date=${date.toIso8601String()}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              reviewed
                  ? Icons.event_available_rounded
                  : Icons.auto_awesome_rounded,
              color: cs.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Close your day' : 'Debrief this day',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  reviewed
                      ? 'Reviewed, tap to revisit'
                      : 'Reflect, see trends & plan tomorrow',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: cs.primary, size: 20),
        ],
      ),
    );
  }
}
