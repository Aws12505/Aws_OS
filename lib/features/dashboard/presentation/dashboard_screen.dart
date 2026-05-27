import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../finance/data/finance_dao.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../finance/presentation/widgets/confirm_occurrence_sheet.dart';
import '../../gym/presentation/providers.dart' as gym;
import '../../notes/presentation/providers.dart' as notes;
import '../../tasks/presentation/providers.dart' as tasks;
import '../../../shared/widgets/quick_action_fab.dart';
import '../../settings/presentation/settings_screen.dart';

final _selectedDayProvider =
    StateProvider<DateTime>((_) => DateTime.now().atStartOfDay);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aws OS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            )),
          ),
        ],
      ),
      body: const _DashboardBody(),
      floatingActionButton: const QuickActionFab(),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDayProvider);
    final isToday = selected.isSameDay(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        _DayHeader(selected: selected, isToday: isToday),
        const _NeedsAttentionCard(),
        const _BalancesCard(),
        _TransactionsForDayCard(date: selected),
        _TasksForDayCard(date: selected),
        _NotesForDayCard(date: selected),
        const _GymLastSessionCard(),
        const _ExpensePieCard(),
        const _ProjectedBalanceCard(),
      ],
    );
  }
}

// ===== Day header ==========================================================

class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.selected, required this.isToday});
  final DateTime selected;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref
                  .read(_selectedDayProvider.notifier)
                  .state = selected.addDays(-1).atStartOfDay,
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    ref.read(_selectedDayProvider.notifier).state =
                        d.atStartOfDay;
                  }
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.yMMMMEEEEd().format(selected),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!isToday)
                          TextButton(
                            onPressed: () => ref
                                .read(_selectedDayProvider.notifier)
                                .state = DateTime.now().atStartOfDay,
                            child: const Text('Today'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref
                  .read(_selectedDayProvider.notifier)
                  .state = selected.addDays(1).atStartOfDay,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Needs attention =====================================================

class _NeedsAttentionCard extends ConsumerWidget {
  const _NeedsAttentionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(fin.pendingOccurrencesProvider).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active),
                const SizedBox(width: 8),
                Text('Needs your attention',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text('${pending.length} pending occurrence(s) — confirm or skip.',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(),
            for (final o in pending)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat.yMMMd().format(o.dueAt)),
                trailing: FilledButton(
                  onPressed: () => showConfirmOccurrenceSheet(
                    context,
                    occurrence: o,
                  ),
                  child: const Text('Review'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Balances =============================================================

class _BalancesCard extends ConsumerWidget {
  const _BalancesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(fin.accountsStreamProvider).value ?? const <Account>[];
    final currencies =
        ref.watch(fin.currenciesStreamProvider).value ?? const <Currency>[];
    final balances =
        ref.watch(fin.accountBalancesStreamProvider).value ?? const {};
    if (accounts.isEmpty) return const SizedBox.shrink();
    final byCur = {for (final c in currencies) c.id: c};
    final totals = <String, double>{};
    for (final a in accounts) {
      totals.update(a.currencyId, (v) => v + (balances[a.id] ?? 0),
          ifAbsent: () => balances[a.id] ?? 0);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vault', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in totals.entries)
              Row(
                children: [
                  Text(byCur[entry.key]?.code ?? '?'),
                  const Spacer(),
                  Text(
                    NumberFormat.decimalPatternDigits(
                      decimalDigits: byCur[entry.key]?.decimalPlaces ?? 2,
                    ).format(entry.value),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 4),
                  Text(byCur[entry.key]?.symbol ?? ''),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Transactions for day ===============================================

class _TransactionsForDayCard extends ConsumerWidget {
  const _TransactionsForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(fin.recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final dayTxs =
        txs.where((t) => t.transaction.occurredAt.isSameDay(date)).toList();
    if (dayTxs.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dayTxs.length} transaction(s) on this day',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in dayTxs)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (t.transaction.kind) {
                  'income' => Icons.trending_up,
                  'expense' => Icons.trending_down,
                  'exchange' => Icons.swap_horiz,
                  'transfer' => Icons.compare_arrows,
                  _ => Icons.receipt,
                }),
                title: Text(t.transaction.kind),
                subtitle: Text(t.transaction.note ?? '—'),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Tasks for day ======================================================

class _TasksForDayCard extends ConsumerWidget {
  const _TasksForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks =
        ref.watch(tasks.allTasksStreamProvider).value ?? const <Task>[];
    final today = allTasks
        .where((t) =>
            (t.dueAt != null && t.dueAt!.isSameDay(date)) ||
            (t.deadlineAt != null && t.deadlineAt!.isSameDay(date)))
        .toList();
    if (today.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks for this day',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in today)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: t.isCompleted,
                onChanged: (v) => ref
                    .read(tasks.tasksRepositoryProvider)
                    .toggleCompletion(t.id, completed: v ?? false),
                title: Text(t.title),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Notes for day ======================================================

class _NotesForDayCard extends ConsumerWidget {
  const _NotesForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allNotes = ref.watch(notes.notesStreamProvider).value ?? const <Note>[];
    final day = allNotes.where((n) => n.occurredAt.isSameDay(date)).toList();
    if (day.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notes for this day',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final n in day)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notes),
                title: Text(n.title ?? n.contentMd.split('\n').first,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Gym last session ===================================================

class _GymLastSessionCard extends ConsumerWidget {
  const _GymLastSessionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(gym.allSessionsStreamProvider).value ?? const <DaySession>[];
    if (sessions.isEmpty) return const SizedBox.shrink();
    final last = sessions.first;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: const Text('Last gym session'),
        subtitle:
            Text(DateFormat.yMMMd().add_Hm().format(last.playedAt)),
      ),
    );
  }
}

// ===== Expense pie =========================================================

class _ExpensePieCard extends ConsumerWidget {
  const _ExpensePieCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(fin.recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final cats =
        ref.watch(fin.allCategoriesProvider).value ?? const <Category>[];
    final catNames = {for (final c in cats) c.id: c.name};

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // Sum absolute expense amounts (in primary currency only for simplicity:
    // skip multi-currency complexity in the pie — group by category, summing
    // each leg's absolute amount regardless of currency.
    final perCategory = <String, double>{};
    for (final t in txs) {
      if (t.transaction.kind != 'expense') continue;
      if (t.transaction.occurredAt.isBefore(monthStart)) continue;
      final name = catNames[t.transaction.categoryId] ?? 'Uncategorized';
      final total = t.legs.fold<double>(0, (s, l) => s + l.amount.abs());
      perCategory.update(name, (v) => v + total, ifAbsent: () => total);
    }

    if (perCategory.isEmpty) return const SizedBox.shrink();

    final palette = Colors.primaries;
    final sections = <PieChartSectionData>[];
    var i = 0;
    perCategory.forEach((name, value) {
      sections.add(PieChartSectionData(
        value: value,
        title: name,
        color: palette[i % palette.length].shade400,
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      ));
      i++;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expenses this month, by category',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(sections: sections, sectionsSpace: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Projected balance ===================================================

class _ProjectedBalanceCard extends ConsumerWidget {
  const _ProjectedBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(fin.pendingOccurrencesWindowProvider(90)).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now().atStartOfDay;
    final upcomingCount = pending
        .where((o) => !o.dueAt.isBefore(today))
        .length;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.show_chart),
        title: const Text('Projected pending occurrences'),
        subtitle: Text(
            '$upcomingCount expected in the next 90 days (across all recurring entries).'),
      ),
    );
  }
}
