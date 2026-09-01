import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
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
      loading: () => const AppLoading(),
      error: (e, _) => _ErrorBox(e.toString()),
      data: (currencies) {
        if (currencies.isEmpty) {
          return _EmptyState(
            title: 'No currencies yet',
            message:
                'Add a currency before creating accounts (e.g. USD, SYP).',
            actionLabel: 'Add currency',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CurrenciesScreen()),
            ),
          );
        }
        return accountsAsync.when(
          loading: () => const AppLoading(),
          error: (e, _) => _ErrorBox(e.toString()),
          data: (accounts) {
            if (accounts.isEmpty) {
              return _EmptyState(
                title: 'No accounts yet',
                message: 'Add at least one account to start tracking balances.',
                actionLabel: 'Add account',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, AppInsets.listBottomNoFab),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.55
                    : 0.72),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.account_balance_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Total per currency',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (totals.isEmpty) const Text('-'),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              code,
              style: tt.labelSmall?.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$text $symbol',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium?.copyWith(
                letterSpacing: -0.3,
              ),
            ),
          ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Text(
            '${currency!.code} Accounts',
            style: tt.labelLarge?.copyWith(
              color: cs.primary,
              letterSpacing: 0.5,
            ).weight(FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: context.surfaces.hairline,
            ),
          ),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPositive = balance >= 0;
    return AppCard(
      style: CardStyle.block,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 5),
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: cs.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name,
                      style: tt.titleSmall
                          ?.weight(FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    account.kind,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                '$formatted $symbol',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: tt.titleMedium?.copyWith(
                  color: isPositive ? cs.onSurface : cs.error,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
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
