import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/form_sheet.dart';
import '../providers.dart';
import 'confirm_occurrence_sheet.dart';

/// Every occurrence (pending, confirmed, skipped) for a single recurrence —
/// lets a user review or skip any one of them directly, independent of the
/// other occurrences in the series.
Future<void> showOccurrenceHistorySheet(
  BuildContext context, {
  required Recurrence recurrence,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _Sheet(recurrence: recurrence),
  );
}

class _Sheet extends ConsumerWidget {
  const _Sheet({required this.recurrence});
  final Recurrence recurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occsAsync =
        ref.watch(occurrencesForRecurrenceProvider(recurrence.id));
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSheetHeader(
              icon: DomainColors.iconForTxKind(recurrence.kind),
              color: DomainColors.forTxKind(recurrence.kind),
              title: recurrence.noteTemplate ??
                  (recurrence.kind == 'income' ? 'Income' : 'Expense'),
            ),
            const SizedBox(height: 4),
            Text('All occurrences — review or skip any of them directly.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Flexible(
              child: occsAsync.when(
                loading: () =>
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString()),
                ),
                data: (occs) {
                  if (occs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No occurrences yet.'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: occs.length,
                    itemBuilder: (_, i) {
                      final o = occs[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(DateFormat.yMMMd().format(o.dueAt)),
                        subtitle: Text(_statusLabel(o.status)),
                        trailing: o.status == 'pending'
                            ? FilledButton(
                                onPressed: () => showConfirmOccurrenceSheet(
                                  context,
                                  occurrence: o,
                                ),
                                child: const Text('Review'),
                              )
                            : Icon(
                                o.status == 'confirmed'
                                    ? Icons.check_circle_rounded
                                    : Icons.skip_next_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'pending' => 'Pending',
        'confirmed' => 'Confirmed',
        'skipped' => 'Skipped',
        _ => status,
      };
}
