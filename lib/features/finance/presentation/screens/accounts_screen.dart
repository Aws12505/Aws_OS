import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/design/surface_scope.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../providers.dart';
import '../widgets/account_form_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final currencies = ref.watch(currenciesStreamProvider).value ?? const [];
    final byId = {for (final c in currencies) c.id: c};

    return AppScaffold(
      mode: SurfaceMode.working,
      appBar: AppBar(title: const Text('Accounts')),
      body: accountsAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorView(error: e),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No accounts yet. Add one (e.g. Cash USD, Bank SYP).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, AppInsets.listBottomNoFab),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final a = items[i];
              final currency = byId[a.currencyId];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.account_balance_wallet)),
                  title: Text(a.name),
                  subtitle: Text(
                    '${currency?.code ?? '?'}  •  ${a.kind}'
                    '${a.archived ? '  •  archived' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'edit':
                          showAccountFormSheet(context, existing: a);
                        case 'delete':
                          final ok = await showAppConfirmDialog(
                            context,
                            title: 'Delete ${a.name}?',
                            message: 'Linked transactions will keep the account id reference. '
                                  'Consider archiving instead.',
                            confirmLabel: 'Delete',
                            destructive: true,
                          );
                          if (ok) {
                            await ref
                                .read(financeRepositoryProvider)
                                .deleteAccount(a.id);
                          }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => showAccountFormSheet(context, existing: a),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Account'),
        onPressed: () {
          if (currencies.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Add a currency first.'),
            ));
            return;
          }
          showAccountFormSheet(context);
        },
      ),
    );
  }
}
