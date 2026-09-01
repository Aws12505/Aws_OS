part of '../dashboard_screen.dart';

// Where the balance is heading.

class _ProjectedBalanceCard extends ConsumerWidget {
  const _ProjectedBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(fin.pendingOccurrencesWindowProvider(90)).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now().atStartOfDay;
    final upcoming = pending.where((o) => !o.dueAt.isBefore(today)).length;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          _IconBadge(icon: Icons.show_chart_rounded, color: cs.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming recurring',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$upcoming in the next 90 days',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
