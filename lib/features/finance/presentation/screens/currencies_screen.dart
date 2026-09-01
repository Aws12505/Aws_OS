import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../providers.dart';
import '../widgets/currency_form_sheet.dart';
import '../../../../shared/widgets/app_card.dart';

class CurrenciesScreen extends ConsumerWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currenciesStreamProvider);
    return AppScaffold(
      appBar: AppBar(title: const Text('Currencies')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorView(error: e),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No currencies. Tap + to add one (e.g. USD, SYP).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            // Rows on the page, ruled between. A Card per row put a border and
            // a radius round every single line of a settings-style list.
            padding: const EdgeInsets.only(bottom: AppInsets.listBottomNoFab),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const AppRule(indent: AppSpacing.xl, endIndent: AppSpacing.xl),
            itemBuilder: (_, i) => _CurrencyTile(currency: items[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Currency'),
        onPressed: () => showCurrencyFormSheet(context),
      ),
    );
  }
}

class _CurrencyTile extends ConsumerWidget {
  const _CurrencyTile({required this.currency});
  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text('${currency.code} (${currency.symbol})'),
      subtitle: Text(
        '${currency.decimalPlaces} decimal places  •  '
        '${currency.isActive ? 'active' : 'inactive'}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'edit':
              showCurrencyFormSheet(context, existing: currency);
            case 'delete':
              final ok = await showAppConfirmDialog(
                context,
                title: 'Delete ${currency.code}?',
                message:
                    'Accounts or transactions using this currency will fail to load. '
                    'Use only if nothing depends on it.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok) {
                await ref
                    .read(financeRepositoryProvider)
                    .deleteCurrency(currency.id);
              }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () => showCurrencyFormSheet(context, existing: currency),
    );
  }
}
