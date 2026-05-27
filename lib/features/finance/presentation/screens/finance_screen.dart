import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/add_transaction_chooser.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import 'currencies_screen.dart';
import 'recurring_screen.dart';
import 'exchange_rates_view.dart';
import 'transactions_list_view.dart';
import 'vault_view.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Vault'),
            Tab(text: 'Activity'),
            Tab(text: 'Rates'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'currencies':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CurrenciesScreen()));
                case 'accounts':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AccountsScreen()));
                case 'categories':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CategoriesScreen()));
                case 'recurring':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RecurringScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'currencies', child: Text('Manage currencies')),
              PopupMenuItem(value: 'accounts', child: Text('Manage accounts')),
              PopupMenuItem(
                  value: 'categories', child: Text('Manage categories')),
              PopupMenuItem(
                  value: 'recurring', child: Text('Recurring entries')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          VaultView(),
          TransactionsListView(),
          ExchangeRatesView(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => showAddTransactionChooser(context),
      ),
    );
  }
}
