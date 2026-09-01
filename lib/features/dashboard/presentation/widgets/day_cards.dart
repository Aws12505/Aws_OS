part of '../dashboard_screen.dart';

// The three day-scoped cards. Same shape, three sources.

class _TransactionsForDayCard extends ConsumerWidget {
  const _TransactionsForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs =
        ref.watch(fin.recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final cats =
        ref.watch(fin.allCategoriesProvider).value ?? const <Category>[];
    final catNames = {for (final c in cats) c.id: c.name};
    final currencies =
        ref.watch(fin.currenciesStreamProvider).value ?? const <Currency>[];
    final byCur = {for (final c in currencies) c.id: c};
    final dayTxs = txs
        .where((t) => t.transaction.occurredAt.isSameDay(date))
        .toList();
    if (dayTxs.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.receipt_long_rounded, color: cs.tertiary),
              const SizedBox(width: 12),
              Text(
                'Transactions',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
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
                      color: DomainColors.forTxKind(
                        t.transaction.kind,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      DomainColors.iconForTxKind(t.transaction.kind),
                      color: DomainColors.forTxKind(t.transaction.kind),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DomainColors.labelForTxKind(t.transaction.kind),
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (catNames[t.transaction.categoryId] != null ||
                            t.transaction.note != null)
                          Text(
                            catNames[t.transaction.categoryId] ??
                                t.transaction.note ??
                                '',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _amountLabel(t, byCur),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DomainColors.forTxKind(t.transaction.kind),
                          ),
                        ),
                        Text(
                          DateFormat.Hm().format(t.transaction.occurredAt),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
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

  /// Compact signed amount per currency for a transaction. Falls back to the
  /// gross moved amount when legs net to zero (e.g. a same-currency transfer).
  String _amountLabel(TransactionWithLegs t, Map<String, Currency> byCur) {
    final net = <String, double>{};
    for (final l in t.legs) {
      net[l.currencyId] = (net[l.currencyId] ?? 0) + l.amount;
    }
    final allZero = net.values.every((v) => v.abs() < 1e-9);
    if (allZero && t.legs.isNotEmpty) {
      net.clear();
      for (final l in t.legs) {
        if (l.amount > 0) {
          net[l.currencyId] = (net[l.currencyId] ?? 0) + l.amount;
        }
      }
    }
    final parts = <String>[];
    net.forEach((curId, amount) {
      final c = byCur[curId];
      final dp = c?.decimalPlaces ?? 2;
      final formatted = NumberFormat.decimalPatternDigits(
        decimalDigits: dp,
      ).format(amount);
      final sign = amount > 0 ? '+' : '';
      parts.add('$sign$formatted ${c?.symbol ?? c?.code ?? ''}'.trim());
    });
    return parts.join('  ');
  }
}

class _TasksForDayCard extends ConsumerWidget {
  const _TasksForDayCard({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks =
        ref.watch(tasks.allTasksStreamProvider).value ?? const <Task>[];
    final today = allTasks
        .where(
          (t) =>
              (t.dueAt != null && t.dueAt!.isSameDay(date)) ||
              (t.deadlineAt != null && t.deadlineAt!.isSameDay(date)),
        )
        .toList();
    if (today.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final done = today.where((t) => t.isCompleted).length;
    final progress = today.isEmpty ? 0.0 : done / today.length;
    final teal = context.sem.tasks.base;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.task_alt_rounded, color: teal),
              const SizedBox(width: 12),
              Text(
                'Tasks',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$done / ${today.length}',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.surfaces.sunken,
              color: progress == 1.0 ? context.sem.income.base : teal,
            ),
          ),
          const SizedBox(height: 12),
          for (final t in today)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(tasks.tasksRepositoryProvider)
                          .toggleCompletion(t.id, completed: !t.isCompleted);
                    },
                    child: AnimatedContainer(
                      duration: context.motion.short,
                      curve: context.motion.standardCurve,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: t.isCompleted
                            ? context.sem.income.base
                            : Colors.transparent,
                        border: Border.all(
                          color: t.isCompleted
                              ? context.sem.income.base
                              : cs.outline.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: t.isCompleted
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: context.sem.income.onContainer,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: t.id),
                            ),
                          ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: tt.bodyMedium?.copyWith(
                              color: t.isCompleted
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface,
                              decoration: t.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_taskSubtitle(t) != null)
                            Text(
                              _taskSubtitle(t)!,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A compact "category • due time" subtitle, or null when there's nothing
  /// extra to show.
  String? _taskSubtitle(Task t) {
    final bits = <String>[];
    if (t.category != null && t.category!.trim().isNotEmpty) {
      bits.add(t.category!.trim());
    }
    final due = t.dueAt;
    if (due != null && (due.hour != 0 || due.minute != 0)) {
      bits.add(DateFormat.Hm().format(due));
    }
    return bits.isEmpty ? null : bits.join('  •  ');
  }
}

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
    final violet = context.sem.exchange.base;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.sticky_note_2_rounded, color: violet),
              const SizedBox(width: 12),
              Text(
                'Notes',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
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
                      borderRadius: BorderRadius.circular(AppRadius.xs),
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
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (n.title?.isNotEmpty == true)
                          Text(
                            _firstLine(n.contentMd),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
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
