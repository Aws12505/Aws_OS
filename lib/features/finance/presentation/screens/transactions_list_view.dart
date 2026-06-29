import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../data/finance_dao.dart';
import '../providers.dart';

class TransactionsListView extends ConsumerStatefulWidget {
  const TransactionsListView({super.key});

  @override
  ConsumerState<TransactionsListView> createState() =>
      _TransactionsListViewState();
}

class _TransactionsListViewState extends ConsumerState<TransactionsListView> {
  final _search = TextEditingController();
  String _query = '';
  String _kind = 'all'; // all | income | expense | transfer | exchange

  static const _kinds = ['all', 'income', 'expense', 'transfer', 'exchange'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(recentTransactionsStreamProvider);
    final currencies = {
      for (final c in (ref.watch(currenciesStreamProvider).value ??
          const <Currency>[]))
        c.id: c,
    };
    final accounts = {
      for (final a
          in (ref.watch(accountsStreamProvider).value ?? const <Account>[]))
        a.id: a,
    };
    final categoryNames = {
      for (final c
          in (ref.watch(allCategoriesProvider).value ?? const <Category>[]))
        c.id: c.name,
    };
    final typeNames = {
      for (final t
          in (ref.watch(allTypesProvider).value ?? const <CategoryType>[]))
        t.id: t.name,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
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
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final k in _kinds)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppChip(
                    label: k == 'all' ? 'All' : DomainColors.labelForTxKind(k),
                    color: k == 'all' ? null : DomainColors.forTxKind(k),
                    selected: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: txAsync.when(
            loading: () => const AppLoading(),
            error: (e, _) => AppErrorView(error: e),
            data: (items) {
              if (items.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No transactions yet',
                  message:
                      'Tap + to add income, expense, transfer, or exchange.',
                );
              }
              final filtered = items.where((e) {
                if (_kind != 'all' && e.transaction.kind != _kind) return false;
                if (_query.isEmpty) return true;
                final hay = StringBuffer()
                  ..write(e.transaction.kind)
                  ..write(' ')
                  ..write(e.transaction.note ?? '')
                  ..write(' ')
                  ..write(categoryNames[e.transaction.categoryId] ?? '')
                  ..write(' ')
                  ..write(typeNames[e.transaction.typeId] ?? '');
                for (final l in e.legs) {
                  hay
                    ..write(' ')
                    ..write(accounts[l.accountId]?.name ?? '')
                    ..write(' ')
                    ..write(l.amount.toString());
                }
                return hay.toString().toLowerCase().contains(_query);
              }).toList();

              if (filtered.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try a different search or filter.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _TransactionTile(
                  entry: filtered[i],
                  currencies: currencies,
                  accounts: accounts,
                  categoryNames: categoryNames,
                  typeNames: typeNames,
                  onDelete: () => _confirmDelete(filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(TransactionWithLegs entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(financeRepositoryProvider)
          .deleteTransaction(entry.transaction.id);
    }
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.entry,
    required this.currencies,
    required this.accounts,
    required this.categoryNames,
    required this.typeNames,
    required this.onDelete,
  });

  final TransactionWithLegs entry;
  final Map<String, Currency> currencies;
  final Map<String, Account> accounts;
  final Map<String, String> categoryNames;
  final Map<String, String> typeNames;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tx = entry.transaction;
    final summary = entry.legs.map((l) {
      final cur = currencies[l.currencyId];
      final acc = accounts[l.accountId];
      final dp = cur?.decimalPlaces ?? 2;
      final amt =
          NumberFormat.decimalPatternDigits(decimalDigits: dp).format(l.amount);
      return '${acc?.name ?? '?'}: $amt ${cur?.code ?? ''}';
    }).join('  •  ');

    final color = DomainColors.forTxKind(tx.kind);
    final icon = DomainColors.iconForTxKind(tx.kind);

    final categoryLabel =
        tx.categoryId == null ? null : categoryNames[tx.categoryId];
    final typeLabel = tx.typeId == null ? null : typeNames[tx.typeId];
    final tag = [
      ?categoryLabel,
      ?typeLabel,
    ].join(' / ');

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DomainColors.labelForTxKind(tx.kind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.note != null && tx.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat.MMMd().format(tx.occurredAt),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: cs.error),
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
