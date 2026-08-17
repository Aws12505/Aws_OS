import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../data/finance_dao.dart';
import '../providers.dart';

/// Search + pick a single existing transaction to link. Can be opened
/// repeatedly to add more than one link — callers pass [excludeIds] (the
/// current transaction plus anything already linked to it) so the same pair
/// can't be picked twice.
Future<String?> showLinkTransactionPicker(
  BuildContext context, {
  required List<String> excludeIds,
}) {
  return showAppModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LinkPickerSheet(excludeIds: excludeIds),
  );
}

class _LinkPickerSheet extends ConsumerStatefulWidget {
  const _LinkPickerSheet({required this.excludeIds});
  final List<String> excludeIds;

  @override
  ConsumerState<_LinkPickerSheet> createState() => _LinkPickerSheetState();
}

class _LinkPickerSheetState extends ConsumerState<_LinkPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(linkPickerTransactionsProvider);
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

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Link to a transaction',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search transactions',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: txAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e'),
                ),
                data: (items) {
                  final candidates = items
                      .where((e) => !widget.excludeIds.contains(e.transaction.id))
                      .where((e) {
                    if (_query.isEmpty) return true;
                    final hay = StringBuffer()
                      ..write(e.transaction.kind)
                      ..write(' ')
                      ..write(e.transaction.note ?? '');
                    for (final l in e.legs) {
                      hay
                        ..write(' ')
                        ..write(accounts[l.accountId]?.name ?? '')
                        ..write(' ')
                        ..write(l.amount.toString());
                    }
                    return hay.toString().toLowerCase().contains(_query);
                  }).toList();

                  if (candidates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No matching transactions.'),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, i) => _PickRow(
                      entry: candidates[i],
                      currencies: currencies,
                      accounts: accounts,
                      onTap: () =>
                          Navigator.of(context).pop(candidates[i].transaction.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.entry,
    required this.currencies,
    required this.accounts,
    required this.onTap,
  });

  final TransactionWithLegs entry;
  final Map<String, Currency> currencies;
  final Map<String, Account> accounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = entry.transaction;
    final color = DomainColors.forTxKind(tx.kind);
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
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
                      style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        summary,
                        if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
                      ].join('  —  '),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
