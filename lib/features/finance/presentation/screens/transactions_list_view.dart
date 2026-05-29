import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../data/finance_dao.dart';
import '../providers.dart';

class TransactionsListView extends ConsumerWidget {
  const TransactionsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(recentTransactionsStreamProvider);
    final currenciesAsync = ref.watch(currenciesStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (items) {
        if (items.isEmpty) {
          return const _Empty();
        }
        final currencies = {
          for (final c in (currenciesAsync.value ?? const <Currency>[]))
            c.id: c,
        };
        final accounts = {
          for (final a in (accountsAsync.value ?? const <Account>[]))
            a.id: a,
        };
        final categoriesAsync = ref.watch(allCategoriesProvider);
        final typesAsync = ref.watch(allTypesProvider);
        final categoryNames = {
          for (final c in (categoriesAsync.value ?? const <Category>[]))
            c.id: c.name,
        };
        final typeNames = {
          for (final t in (typesAsync.value ?? const <CategoryType>[]))
            t.id: t.name,
        };
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: items.length,
          itemBuilder: (_, i) => _TransactionTile(
            entry: items[i],
            currencies: currencies,
            accounts: accounts,
            categoryNames: categoryNames,
            typeNames: typeNames,
            onDelete: () async {
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
                    .deleteTransaction(items[i].transaction.id);
              }
            },
          ),
        );
      },
    );
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
      final amt = NumberFormat.decimalPatternDigits(decimalDigits: dp)
          .format(l.amount);
      return '${acc?.name ?? '?'}: $amt ${cur?.code ?? ''}';
    }).join('  •  ');

    final icon = switch (tx.kind) {
      'income' => Icons.trending_up_rounded,
      'expense' => Icons.trending_down_rounded,
      'exchange' => Icons.swap_horiz_rounded,
      'transfer' => Icons.compare_arrows_rounded,
      _ => Icons.receipt_long_rounded,
    };
    final color = switch (tx.kind) {
      'income' => const Color(0xFF22C55E),
      'expense' => const Color(0xFFEF4444),
      'transfer' => const Color(0xFF3B82F6),
      'exchange' => const Color(0xFF8B5CF6),
      _ => Theme.of(context).colorScheme.secondary,
    };

    final categoryLabel = tx.categoryId == null
        ? null
        : categoryNames[tx.categoryId];
    final typeLabel = tx.typeId == null ? null : typeNames[tx.typeId];
    final tag = [
      ?categoryLabel,
      ?typeLabel,
    ].join(' / ');

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
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
                        tx.kind[0].toUpperCase() + tx.kind.substring(1),
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
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_rounded,
                  size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No transactions yet',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add income, expense, transfer, or exchange.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
