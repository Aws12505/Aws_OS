part of '../dashboard_screen.dart';

// Recurring entries waiting on a decision.

class _NeedsAttentionCard extends ConsumerWidget {
  const _NeedsAttentionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(fin.pendingOccurrencesProvider).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final amber = context.sem.warning.base;
    return GlassCard(
      borderColor: amber.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: Icons.notifications_active_rounded,
                color: amber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Needs attention',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              MiniPill(label: '${pending.length}', color: amber),
            ],
          ),
          const SizedBox(height: 12),
          for (final o in pending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(DateFormat.yMMMd().format(o.dueAt))),
                  FilledButton(
                    onPressed: () =>
                        showConfirmOccurrenceSheet(context, occurrence: o),
                    style: FilledButton.styleFrom(
                      backgroundColor: amber,
                      foregroundColor: context.sem.warning.onContainer,
                      minimumSize: const Size(70, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    child: const Text('Review'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
