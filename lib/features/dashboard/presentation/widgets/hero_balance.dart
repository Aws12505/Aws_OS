part of '../dashboard_screen.dart';

// The one gradient surface in the app. It earns that by being unique.

class _HeroBalance extends ConsumerWidget {
  const _HeroBalance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(fin.accountsStreamProvider).value ?? const <Account>[];
    final currencies =
        ref.watch(fin.currenciesStreamProvider).value ?? const <Currency>[];
    final balances =
        ref.watch(fin.accountBalancesStreamProvider).value ?? const {};
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final byCur = {for (final c in currencies) c.id: c};
    final totals = <String, double>{};
    for (final a in accounts) {
      totals.update(
        a.currencyId,
        (v) => v + (balances[a.id] ?? 0),
        ifAbsent: () => balances[a.id] ?? 0,
      );
    }
    final entries = totals.entries.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () => context.push('/finance'),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              gradient: LinearGradient(
                colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.6)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: cs.onPrimary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TOTAL VAULT',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: cs.onPrimary.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Text(
                    'Set up your vault',
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else ...[
                  Builder(
                    builder: (_) {
                      final main = entries.first;
                      final cur = byCur[main.key];
                      final formatted = NumberFormat.decimalPatternDigits(
                        decimalDigits: cur?.decimalPlaces ?? 2,
                      ).format(main.value);
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: formatted,
                                style: tt.displaySmall?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              TextSpan(
                                text: '  ${cur?.symbol ?? cur?.code ?? ''}',
                                style: tt.titleMedium?.copyWith(
                                  color: cs.onPrimary.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (entries.length > 1) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in entries.skip(1))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.onPrimary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              '${NumberFormat.decimalPatternDigits(decimalDigits: byCur[e.key]?.decimalPlaces ?? 2).format(e.value)} ${byCur[e.key]?.symbol ?? byCur[e.key]?.code ?? ''}',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends ConsumerWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().atStartOfDay;
    final allTasks =
        ref.watch(tasks.allTasksStreamProvider).value ?? const <Task>[];
    final todays = allTasks.where(
      (t) =>
          (t.dueAt != null && t.dueAt!.isSameDay(today)) ||
          (t.deadlineAt != null && t.deadlineAt!.isSameDay(today)),
    );
    final taskDone = todays.where((t) => t.isCompleted).length;
    final taskTotal = todays.length;

    final sessions =
        ref.watch(gym.allSessionsStreamProvider).value ?? const <DaySession>[];
    final gymDays = sessions.isEmpty
        ? null
        : DateTime.now().difference(sessions.first.playedAt).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.task_alt_rounded,
              color: context.sem.tasks.base,
              label: "Today's tasks",
              value: taskTotal == 0 ? '—' : '$taskDone/$taskTotal',
              sub: taskTotal == 0
                  ? 'Nothing due'
                  : taskDone == taskTotal
                  ? 'All done'
                  : '${taskTotal - taskDone} left',
              onTap: () => context.go('/tasks'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              icon: Icons.fitness_center_rounded,
              color: context.sem.expense.base,
              label: 'Last workout',
              value: gymDays == null
                  ? '—'
                  : gymDays == 0
                  ? 'Today'
                  : '${gymDays}d',
              sub: gymDays == null
                  ? 'No sessions'
                  : gymDays == 0
                  ? 'Great job'
                  : 'days ago',
              onTap: () => context.go('/gym'),
            ),
          ),
        ],
      ),
    );
  }
}
