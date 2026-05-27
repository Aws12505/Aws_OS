import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/money.dart';
import '../providers.dart';
import 'accounts_screen.dart';
import 'currencies_screen.dart';

class VaultView extends ConsumerWidget {
  const VaultView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(currenciesStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final balancesAsync = ref.watch(accountBalancesStreamProvider);

    return currenciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(e.toString()),
      data: (currencies) {
        if (currencies.isEmpty) {
          return _EmptyState(
            title: 'No currencies yet',
            message:
                'Add a currency before creating accounts (e.g. USD, SYP).',
            actionLabel: 'Add currency',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CurrenciesScreen())),
          );
        }
        return accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorBox(e.toString()),
          data: (accounts) {
            if (accounts.isEmpty) {
              return _EmptyState(
                title: 'No accounts yet',
                message: 'Add at least one account to start tracking balances.',
                actionLabel: 'Add account',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AccountsScreen())),
              );
            }
            final balances = balancesAsync.value ?? const <String, double>{};
            return _VaultBody(
              currencies: currencies,
              accounts: accounts,
              balances: balances,
            );
          },
        );
      },
    );
  }
}

class _VaultBody extends StatelessWidget {
  const _VaultBody({
    required this.currencies,
    required this.accounts,
    required this.balances,
  });
  final List<Currency> currencies;
  final List<Account> accounts;
  final Map<String, double> balances;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in currencies) c.id: c};
    // Totals per currency.
    final totals = <String, double>{};
    for (final a in accounts) {
      final bal = balances[a.id] ?? 0.0;
      totals.update(a.currencyId, (v) => v + bal, ifAbsent: () => bal);
    }
    final grouped = accounts.groupListsBy((a) => a.currencyId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total per currency',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (totals.isEmpty) const Text('—'),
                for (final entry in totals.entries)
                  _TotalRow(
                    currency: byId[entry.key],
                    amount: entry.value,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final currencyId in grouped.keys) ...[
          _CurrencyHeader(byId[currencyId]),
          for (final account in grouped[currencyId]!)
            _AccountTile(
              account: account,
              currency: byId[account.currencyId],
              balance: balances[account.id] ?? 0.0,
            ),
        ],
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.currency, required this.amount});
  final Currency? currency;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final code = currency?.code ?? '???';
    final symbol = currency?.symbol ?? '';
    final dp = currency?.decimalPlaces ?? 2;
    final text = Money(amount, currency?.id ?? '').formatPlain(dp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(code, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text('$text $symbol',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CurrencyHeader extends StatelessWidget {
  const _CurrencyHeader(this.currency);
  final Currency? currency;

  @override
  Widget build(BuildContext context) {
    if (currency == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Text(
        '${currency!.code} accounts',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.currency,
    required this.balance,
  });
  final Account account;
  final Currency? currency;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final dp = currency?.decimalPlaces ?? 2;
    final formatted = Money(balance, account.currencyId).formatPlain(dp);
    final symbol = currency?.symbol ?? '';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
        title: Text(account.name),
        subtitle: Text(account.kind),
        trailing: Text(
          '$formatted $symbol',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message)));
}
