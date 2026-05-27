import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';
import '../widgets/currency_form_sheet.dart';

class CurrenciesScreen extends ConsumerWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currenciesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Currencies')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: items.length,
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
    return Card(
      child: ListTile(
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
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: Text('Delete ${currency.code}?'),
                    content: const Text(
                        'Accounts or transactions using this currency will fail to load. '
                        'Use only if nothing depends on it.'),
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
      ),
    );
  }
}
