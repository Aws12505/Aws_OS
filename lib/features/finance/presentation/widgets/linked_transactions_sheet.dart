import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/form_sheet.dart';
import '../../data/finance_dao.dart';
import '../providers.dart';
import 'link_transaction_sheet.dart';

/// Shows every transaction linked to [transactionId] (0, 1, or many — the
/// relationship is many-to-many and unrestricted by kind) and lets the user
/// add another link or remove an existing one. This is the single place that
/// manages links, regardless of how many already exist.
Future<void> showLinkedTransactionsSheet(
  BuildContext context, {
  required String transactionId,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LinkedTransactionsSheet(transactionId: transactionId),
  );
}

class _LinkedTransactionsSheet extends ConsumerWidget {
  const _LinkedTransactionsSheet({required this.transactionId});
  final String transactionId;

  Future<void> _addLink(
    BuildContext context,
    WidgetRef ref,
    List<String> currentLinkedIds,
  ) async {
    final excludeIds = [transactionId, ...currentLinkedIds];
    final pickedId =
        await showLinkTransactionPicker(context, excludeIds: excludeIds);
    if (pickedId == null) return;
    await ref
        .read(financeRepositoryProvider)
        .linkTransactions(transactionId, pickedId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedAsync = ref.watch(linkedTransactionsProvider(transactionId));
    final currencies = {
      for (final c
          in (ref.watch(currenciesStreamProvider).value ?? const <Currency>[]))
        c.id: c,
    };
    final accounts = {
      for (final a
          in (ref.watch(accountsStreamProvider).value ?? const <Account>[]))
        a.id: a,
    };
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final linked = linkedAsync.value ?? const <TransactionWithLegs>[];

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSheetHeader(
              icon: Icons.link_rounded,
              color: cs.primary,
              title: 'Linked transactions',
              subtitle: linked.isEmpty
                  ? 'No transactions linked yet.'
                  : '${linked.length} linked',
            ),
            const SizedBox(height: 16),
            Flexible(
              child: linkedAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoading(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e'),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Link this to another income or expense, such as a '
                        'refund or repayment, so the two stay connected.',
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _LinkedRow(
                      entry: items[i],
                      currencies: currencies,
                      accounts: accounts,
                      onUnlink: () => ref
                          .read(financeRepositoryProvider)
                          .unlinkTransactionPair(
                              transactionId, items[i].transaction.id),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Link another transaction',
              icon: Icons.add_link_rounded,
              expand: true,
              onPressed: () => _addLink(
                context,
                ref,
                linked.map((e) => e.transaction.id).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedRow extends StatelessWidget {
  const _LinkedRow({
    required this.entry,
    required this.currencies,
    required this.accounts,
    required this.onUnlink,
  });

  final TransactionWithLegs entry;
  final Map<String, Currency> currencies;
  final Map<String, Account> accounts;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final tx = entry.transaction;
    final color = context.sem.forTxKind(tx.kind).base;
    final icon = DomainColors.iconForTxKind(tx.kind);
    final summary = entry.legs.map((l) {
      final cur = currencies[l.currencyId];
      final acc = accounts[l.accountId];
      final dp = cur?.decimalPlaces ?? 2;
      final amt = NumberFormat.decimalPatternDigits(decimalDigits: dp)
          .format(l.amount);
      return '${acc?.name ?? '?'}: $amt ${cur?.code ?? ''}';
    }).join('  •  ');
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      margin: EdgeInsets.zero,
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DomainColors.labelForTxKind(tx.kind)} · ${DateFormat.MMMd().format(tx.occurredAt)}',
                  style: tt.labelMedium?.weight(FontWeight.w700),
                ),
                Text(
                  summary,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tx.note != null && tx.note!.isNotEmpty)
                  Text(
                    tx.note!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Unlink',
            icon: Icon(Icons.link_off_rounded, size: 18, color: cs.error),
            onPressed: onUnlink,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
