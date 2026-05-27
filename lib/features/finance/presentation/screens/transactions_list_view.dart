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
    final dateStr = DateFormat.yMMMd().add_Hm().format(tx.occurredAt);
    final summary = entry.legs.map((l) {
      final cur = currencies[l.currencyId];
      final acc = accounts[l.accountId];
      final dp = cur?.decimalPlaces ?? 2;
      final amt = NumberFormat.decimalPatternDigits(decimalDigits: dp)
          .format(l.amount);
      return '${acc?.name ?? '?'}: $amt ${cur?.code ?? ''}';
    }).join('  •  ');

    final icon = switch (tx.kind) {
      'income' => Icons.trending_up,
      'expense' => Icons.trending_down,
      'exchange' => Icons.swap_horiz,
      'transfer' => Icons.compare_arrows,
      _ => Icons.receipt,
    };
    final color = switch (tx.kind) {
      'income' => Colors.green,
      'expense' => Colors.red,
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Row(
          children: [
            Text(
              tx.kind[0].toUpperCase() + tx.kind.substring(1),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (tag.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· $tag',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary),
            Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
            if (tx.note != null && tx.note!.isNotEmpty)
              Text(tx.note!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      )),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No transactions yet.\nTap + to add an income, expense, transfer, or exchange.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
