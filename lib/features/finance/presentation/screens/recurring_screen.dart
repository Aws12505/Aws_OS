import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/design/surface_scope.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../providers.dart';
import '../widgets/confirm_occurrence_sheet.dart';
import '../widgets/occurrence_history_sheet.dart';
import '../widgets/recurrence_form_sheet.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(recurrencesStreamProvider);
    final pendingAsync = ref.watch(allPendingOccurrencesProvider);
    final recsById = {
      for (final r in recsAsync.value ?? const <Recurrence>[]) r.id: r,
    };
    return AppScaffold(
      mode: SurfaceMode.working,
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            tooltip: 'Re-materialize',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(recurrenceServiceProvider).materializeAll(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, AppInsets.listBottomNoFab),
        children: [
          pendingAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (pending) {
              if (pending.isEmpty) return const SizedBox.shrink();
              return Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Needs your review',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          '${pending.length} pending occurrence(s). Review any of them, in any order.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const Divider(),
                      for (final o in pending)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              recsById[o.recurrenceId]?.noteTemplate ??
                                  (recsById[o.recurrenceId]?.kind == 'income'
                                      ? 'Income'
                                      : 'Expense')),
                          subtitle:
                              Text('Due ${DateFormat.yMMMd().format(o.dueAt)}'),
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
            },
          ),
          recsAsync.when(
            loading: () =>
                const AppLoading(),
            error: (e, _) => AppErrorView(error: e),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No recurring entries yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in items)
                    _RecurrenceTile(recurrence: r),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Recurring'),
        onPressed: () => showRecurrenceFormSheet(context),
      ),
    );
  }
}

class _RecurrenceTile extends ConsumerWidget {
  const _RecurrenceTile({required this.recurrence});
  final Recurrence recurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = RecurrenceRule.parse(recurrence.ruleJson);
    final freqLabel = switch (rule.freq) {
      RecurrenceFreq.daily => 'day(s)',
      RecurrenceFreq.weekly => 'week(s)',
      RecurrenceFreq.monthly => 'month(s)',
      RecurrenceFreq.yearly => 'year(s)',
    };
    final next = recurrence.nextDueAt;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (recurrence.kind == 'expense' ? Colors.red : Colors.green)
                  .withValues(alpha: 0.15),
          foregroundColor:
              recurrence.kind == 'expense' ? Colors.red : Colors.green,
          child: Icon(recurrence.kind == 'expense'
              ? Icons.trending_down
              : Icons.trending_up),
        ),
        title: Text(
          recurrence.noteTemplate ??
              '${recurrence.kind == 'expense' ? 'Expense' : 'Income'} every ${rule.interval} $freqLabel',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Every ${rule.interval} $freqLabel'
              ' • starts ${DateFormat.yMMMd().format(recurrence.startDate)}',
            ),
            if (next != null)
              Text('Next: ${DateFormat.yMMMd().format(next)}',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'occurrences':
                showOccurrenceHistorySheet(context, recurrence: recurrence);
              case 'edit':
                showRecurrenceFormSheet(context, existing: recurrence);
              case 'delete':
                final ok = await showAppConfirmDialog(
                  context,
                  title: 'Delete recurring entry?',
                  message: 'Pending occurrences will be removed. Already-confirmed transactions are kept.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (ok) {
                  await ref
                      .read(financeRepositoryProvider)
                      .deleteRecurrence(recurrence.id);
                }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'occurrences', child: Text('View occurrences')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () =>
            showRecurrenceFormSheet(context, existing: recurrence),
      ),
    );
  }
}
