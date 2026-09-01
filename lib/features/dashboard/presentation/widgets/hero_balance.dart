part of '../dashboard_screen.dart';

// The vault total, set as the page's opening statement.
//
// The one gradient surface in the app, and it earns that by being the only
// one. Everything else on the dashboard is a tonal card; this is the thing you
// look at first, so it gets the accent at full strength.

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
    final on = cs.onPrimary;

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

    String amount(MapEntry<String, double> e) =>
        NumberFormat.decimalPatternDigits(
          decimalDigits: byCur[e.key]?.decimalPlaces ?? 2,
        ).format(e.value);
    String unit(String id) => byCur[id]?.symbol ?? byCur[id]?.code ?? '';

    final radius = BorderRadius.circular(AppRadius.xxl);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs + 2,
      ),
      child: PressableSurface(
        onTap: () => context.go('/finance'),
        borderRadius: radius,
        semanticsLabel: 'Open finance',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.55)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: context.elevation.floating,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 15,
                    color: on.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: AppSpacing.sm - 2),
                  Text(
                    'TOTAL VAULT',
                    semanticsLabel: 'Total vault',
                    style: tt.labelSmall?.copyWith(
                      color: on.withValues(alpha: 0.85),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 17,
                    color: on.withValues(alpha: 0.85),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (entries.isEmpty)
                Text(
                  'Set up your vault',
                  style: tt.headlineMedium?.copyWith(color: on),
                )
              else ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        amount(entries.first),
                        // The tabular token, resized: a balance that reflows
                        // horizontally every time a digit changes is the exact
                        // thing tabular figures exist to stop.
                        style: context.type.numericLarge.copyWith(
                          color: on,
                          fontSize: tt.displayMedium?.fontSize,
                          letterSpacing: tt.displayMedium?.letterSpacing,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        unit(entries.first.key),
                        style: tt.titleMedium?.copyWith(
                          color: on.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entries.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final e in entries.skip(1))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: on.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${amount(e)} ${unit(e.key)}',
                            style: context.type.numericSmall.copyWith(
                              color: on,
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
              value: taskTotal == 0 ? 'None' : '$taskDone/$taskTotal',
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
                  ? 'None'
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
