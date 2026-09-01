part of '../../debrief_screen.dart';

// What the day already contains, before you write anything.

class _GlanceCard extends ConsumerWidget {
  const _GlanceCard({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies =
        ref.watch(fin.currenciesStreamProvider).value ?? const <Currency>[];
    final byId = {for (final c in currencies) c.id: c};
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final net = summary.netByCurrency.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final netLabel = net.isEmpty
        ? '-'
        : _fmtMoney(net.first.value, byId[net.first.key], signed: true);
    final netColor = net.isEmpty
        ? null
        : (net.first.value >= 0 ? context.sem.income.base : context.sem.expense.base);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'The day at a glance',
                style: tt.titleMedium,
              ),
              const Spacer(),
              if (summary.taskStreak > 0)
                MiniPill(
                  label: '${summary.taskStreak}d',
                  icon: Icons.local_fire_department_rounded,
                  color: context.sem.warning.base,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Tasks',
                  value: summary.tasksDue == 0
                      ? '-'
                      : '${summary.tasksDone}/${summary.tasksDue}',
                  icon: Icons.task_alt_rounded,
                  accent: context.sem.tasks.base,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Net',
                  value: netLabel,
                  icon: Icons.account_balance_wallet_rounded,
                  accent: cs.tertiary,
                  valueColor: netColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Workout',
                  value: summary.workedOut
                      ? (summary.sessionCount > 1
                            ? '${summary.sessionCount}×'
                            : 'Done')
                      : '-',
                  icon: Icons.fitness_center_rounded,
                  accent: context.sem.gym.base,
                  valueColor: summary.workedOut ? context.sem.income.base : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Notes',
                  value: '${summary.notesCount}',
                  icon: Icons.sticky_note_2_rounded,
                  accent: context.sem.notes.base,
                ),
              ),
            ],
          ),
          if (summary.tasksDue > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: summary.taskCompletion,
                minHeight: 8,
                backgroundColor: context.surfaces.sunken,
                color: summary.taskCompletion >= 1
                    ? context.sem.income.base
                    : context.sem.tasks.base,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(summary.taskCompletion * 100).round()}% of today\'s tasks done',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (summary.topExpenseCategories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (
                  var i = 0;
                  i < summary.topExpenseCategories.length && i < 3;
                  i++
                )
                  MiniPill(
                    label: summary.topExpenseCategories[i].name,
                    color: ChartPalette.at(i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
