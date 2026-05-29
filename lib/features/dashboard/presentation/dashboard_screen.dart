import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../../shared/widgets/glass.dart';
import '../../finance/data/finance_dao.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../finance/presentation/widgets/confirm_occurrence_sheet.dart';
import '../../gym/presentation/providers.dart' as gym;
import '../../notes/presentation/providers.dart' as notes;
import '../../tasks/presentation/providers.dart' as tasks;
import '../../../shared/widgets/quick_action_fab.dart';
import 'package:go_router/go_router.dart';

final _selectedDayProvider = StateProvider<DateTime>(
  (_) => DateTime.now().atStartOfDay,
);

Color _txColor(String kind) => switch (kind) {
      'income' => const Color(0xFF22C55E),
      'expense' => const Color(0xFFEF4444),
      'transfer' => const Color(0xFF3B82F6),
      'exchange' => const Color(0xFF8B5CF6),
      _ => const Color(0xFF6B7280),
    };

IconData _txIcon(String kind) => switch (kind) {
      'income' => Icons.trending_up_rounded,
      'expense' => Icons.trending_down_rounded,
      'transfer' => Icons.compare_arrows_rounded,
      'exchange' => Icons.swap_horiz_rounded,
      _ => Icons.receipt_long_rounded,
    };

String _txLabel(String kind) =>
    kind.isEmpty ? kind : kind[0].toUpperCase() + kind.substring(1);

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
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
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          const _TopBar(),
          const SizedBox(height: 8),
          const _HeroBalance(),
          const _StatRow(),
          const _NeedsAttentionCard(),
          _DaySelector(selected: selected, isToday: isToday),
          _TransactionsForDayCard(date: selected),
          _TasksForDayCard(date: selected),
          _NotesForDayCard(date: selected),
          const _ExpensePieCard(),
          const _ProjectedBalanceCard(),
        ],
      ),
    );
  }
}

// ── top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Aws OS',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

// ── hero balance ─────────────────────────────────────────────────────────────

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
      totals.update(a.currencyId, (v) => v + (balances[a.id] ?? 0),
          ifAbsent: () => balances[a.id] ?? 0);
    }
    final entries = totals.entries.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
      child: Material(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () => context.push('/finance'),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  Color.lerp(cs.primary, cs.tertiary, 0.6)!,
                ],
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
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: cs.onPrimary.withValues(alpha: 0.8)),
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
                    Icon(Icons.arrow_outward_rounded,
                        size: 18,
                        color: cs.onPrimary.withValues(alpha: 0.8)),
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
                  Builder(builder: (_) {
                    final main = entries.first;
                    final cur = byCur[main.key];
                    final formatted = NumberFormat.decimalPatternDigits(
                      decimalDigits: cur?.decimalPlaces ?? 2,
                    ).format(main.value);
                    return RichText(
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
                    );
                  }),
                  if (entries.length > 1) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in entries.skip(1))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cs.onPrimary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
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

// ── stat row (bento) ─────────────────────────────────────────────────────────

class _StatRow extends ConsumerWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().atStartOfDay;
    final allTasks =
        ref.watch(tasks.allTasksStreamProvider).value ?? const <Task>[];
    final todays = allTasks.where((t) =>
        (t.dueAt != null && t.dueAt!.isSameDay(today)) ||
        (t.deadlineAt != null && t.deadlineAt!.isSameDay(today)));
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
            child: _StatTile(
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF14B8A6),
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
            child: _StatTile(
              icon: Icons.fitness_center_rounded,
              color: const Color(0xFFEF4444),
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sub,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── day selector ─────────────────────────────────────────────────────────────

class _DaySelector extends ConsumerWidget {
  const _DaySelector({required this.selected, required this.isToday});
  final DateTime selected;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: cs.onSurfaceVariant,
              onPressed: () => ref.read(_selectedDayProvider.notifier).state =
                  selected.addDays(-1).atStartOfDay,
            ),
            Expanded(
              child: GestureDetector(
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
                child: Column(
                  children: [
                    Text(
                      isToday
                          ? 'Today'
                          : DateFormat('EEEE').format(selected),
                      style: tt.labelMedium?.copyWith(
                        color: isToday ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, y').format(selected),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: cs.onSurfaceVariant,
              onPressed: () => ref.read(_selectedDayProvider.notifier).state =
                  selected.addDays(1).atStartOfDay,
            ),
          ],
        ),
      ),
    );
  }
}

// ── needs attention ──────────────────────────────────────────────────────────

class _NeedsAttentionCard extends ConsumerWidget {
  const _NeedsAttentionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(fin.pendingOccurrencesProvider).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    const amber = Color(0xFFF59E0B);
    return GlassCard(
      borderColor: amber.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.notifications_active_rounded, color: amber),
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
                  Icon(Icons.schedule_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(DateFormat.yMMMd().format(o.dueAt))),
                  FilledButton(
                    onPressed: () =>
                        showConfirmOccurrenceSheet(context, occurrence: o),
                    style: FilledButton.styleFrom(
                      backgroundColor: amber,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(70, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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

// ── transactions for day ─────────────────────────────────────────────────────

class _TransactionsForDayCard extends ConsumerWidget {
  const _TransactionsForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(fin.recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final cats =
        ref.watch(fin.allCategoriesProvider).value ?? const <Category>[];
    final catNames = {for (final c in cats) c.id: c.name};
    final dayTxs =
        txs.where((t) => t.transaction.occurredAt.isSameDay(date)).toList();
    if (dayTxs.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                  icon: Icons.receipt_long_rounded, color: cs.tertiary),
              const SizedBox(width: 12),
              Text('Transactions',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              MiniPill(label: '${dayTxs.length}', color: cs.tertiary),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in dayTxs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _txColor(t.transaction.kind)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(_txIcon(t.transaction.kind),
                        color: _txColor(t.transaction.kind), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_txLabel(t.transaction.kind),
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (catNames[t.transaction.categoryId] != null ||
                            t.transaction.note != null)
                          Text(
                            catNames[t.transaction.categoryId] ??
                                t.transaction.note ??
                                '',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(DateFormat.Hm().format(t.transaction.occurredAt),
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── tasks for day ────────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final done = today.where((t) => t.isCompleted).length;
    final progress = today.isEmpty ? 0.0 : done / today.length;
    const teal = Color(0xFF14B8A6);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.task_alt_rounded, color: teal),
              const SizedBox(width: 12),
              Text('Tasks',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$done / ${today.length}',
                  style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: progress == 1.0 ? const Color(0xFF22C55E) : teal,
            ),
          ),
          const SizedBox(height: 12),
          for (final t in today)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ref
                        .read(tasks.tasksRepositoryProvider)
                        .toggleCompletion(t.id, completed: !t.isCompleted),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: t.isCompleted
                            ? const Color(0xFF22C55E)
                            : Colors.transparent,
                        border: Border.all(
                          color: t.isCompleted
                              ? const Color(0xFF22C55E)
                              : cs.outline.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: t.isCompleted
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.title,
                      style: tt.bodyMedium?.copyWith(
                        color:
                            t.isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                        decoration: t.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── notes for day ────────────────────────────────────────────────────────────

class _NotesForDayCard extends ConsumerWidget {
  const _NotesForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allNotes =
        ref.watch(notes.notesStreamProvider).value ?? const <Note>[];
    final day = allNotes.where((n) => n.occurredAt.isSameDay(date)).toList();
    if (day.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const violet = Color(0xFF8B5CF6);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.sticky_note_2_rounded, color: violet),
              const SizedBox(width: 12),
              Text('Notes',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          for (final n in day)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: violet,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title?.isNotEmpty == true
                              ? n.title!
                              : _firstLine(n.contentMd),
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (n.title?.isNotEmpty == true)
                          Text(
                            _firstLine(n.contentMd),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _firstLine(String md) {
    final lines = md.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.isEmpty ? '' : lines.first.replaceAll(RegExp(r'^#+\s*'), '');
  }
}

// ── expense pie ──────────────────────────────────────────────────────────────

class _ExpensePieCard extends ConsumerWidget {
  const _ExpensePieCard();

  static const _palette = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(fin.recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final cats =
        ref.watch(fin.allCategoriesProvider).value ?? const <Category>[];
    final catNames = {for (final c in cats) c.id: c.name};
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final perCategory = <String, double>{};
    for (final t in txs) {
      if (t.transaction.kind != 'expense') continue;
      if (t.transaction.occurredAt.isBefore(monthStart)) continue;
      final name = catNames[t.transaction.categoryId] ?? 'Other';
      final total = t.legs.fold<double>(0, (s, l) => s + l.amount.abs());
      perCategory.update(name, (v) => v + total, ifAbsent: () => total);
    }
    if (perCategory.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final entries = perCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      sections.add(PieChartSectionData(
        value: entries[i].value,
        color: _palette[i % _palette.length],
        radius: 50,
        showTitle: false,
      ));
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.pie_chart_rounded, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expenses',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(DateFormat('MMMM y').format(now),
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: PieChart(PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < entries.length && i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entries[i].key,
                                  style: tt.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    if (entries.length > 5)
                      Text('+${entries.length - 5} more',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── projected ────────────────────────────────────────────────────────────────

class _ProjectedBalanceCard extends ConsumerWidget {
  const _ProjectedBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(fin.pendingOccurrencesWindowProvider(90)).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now().atStartOfDay;
    final upcoming = pending.where((o) => !o.dueAt.isBefore(today)).length;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GlassCard(
      child: Row(
        children: [
          _IconBadge(icon: Icons.show_chart_rounded, color: cs.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upcoming recurring',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('$upcoming in the next 90 days',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── shared bits ──────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
