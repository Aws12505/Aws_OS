import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/design/surface_scope.dart';
import '../../../../shared/widgets/segmented_control.dart';
import '../../data/finance_dao.dart';
import '../providers.dart';
import 'accounts_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'currencies_screen.dart';
import 'finance_insights_view.dart';
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
  static const _labels = ['Vault', 'Activity', 'Insights', 'Rates'];
  static const _icons = [
    Icons.account_balance_wallet_rounded,
    Icons.swap_vert_rounded,
    Icons.insights_rounded,
    Icons.currency_exchange_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambient host so the aurora shows through on the Insights tab. The three
    // dense tabs cover it with their own working canvas.
    return AppScaffold(
      mode: SurfaceMode.ambient,
      body: Column(
        children: [
          SectionHeader(
            // No status line here: the month summary directly below is the
            // live line, and saying it twice would just push the tabs down.
            title: 'Finance',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Finance mentor',
                  icon: const Icon(Icons.psychology_rounded),
                  onPressed: () => context.push('/mentor?kind=finance'),
                ),
                _ManageMenu(),
              ],
            ),
          ),
          const _MonthSummary(),
          SegmentedControl(
            labels: _labels,
            icons: _icons,
            index: _tabs.index,
            onTap: (i) => _tabs.animateTo(i),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                WorkingSurface(child: VaultView()),
                WorkingSurface(child: TransactionsListView()),
                FinanceInsightsView(),
                WorkingSurface(child: ExchangeRatesView()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune_rounded),
      onSelected: (v) {
        final routes = {
          'currencies': const CurrenciesScreen(),
          'accounts': const AccountsScreen(),
          'categories': const CategoriesScreen(),
          'budgets': const BudgetsScreen(),
          'recurring': const RecurringScreen(),
        };
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => routes[v]!));
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'currencies', child: Text('Manage currencies')),
        PopupMenuItem(value: 'accounts', child: Text('Manage accounts')),
        PopupMenuItem(value: 'categories', child: Text('Manage categories')),
        PopupMenuItem(value: 'budgets', child: Text('Budgets')),
        PopupMenuItem(value: 'recurring', child: Text('Recurring entries')),
      ],
    );
  }
}

/// Net flow this month — a quick editorial summary above the tabs.
class _MonthSummary extends ConsumerWidget {
  const _MonthSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs =
        ref.watch(recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    var income = 0.0;
    var expense = 0.0;
    for (final t in txs) {
      if (t.transaction.occurredAt.isBefore(monthStart)) continue;
      final amt = t.legs.fold<double>(0, (s, l) => s + l.amount.abs());
      if (t.transaction.kind == 'income') income += amt;
      if (t.transaction.kind == 'expense') expense += amt;
    }
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.compact();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _FlowChip(
              label: 'In',
              value: fmt.format(income),
              color: context.sem.income.base,
              icon: Icons.south_west_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FlowChip(
              label: 'Out',
              value: fmt.format(expense),
              color: context.sem.expense.base,
              icon: Icons.north_east_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FlowChip(
              label: 'Net',
              value: fmt.format(income - expense),
              color: cs.primary,
              icon: Icons.balance_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ).weight(FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: tt.titleMedium?.copyWith(
                color: color,
                letterSpacing: -0.3,
              ).weight(FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
