import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/finance_dao.dart';
import '../providers.dart';
import 'accounts_screen.dart';
import 'budgets_screen.dart';
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
  static const _labels = ['Vault', 'Activity', 'Rates'];
  static const _icons = [
    Icons.account_balance_wallet_rounded,
    Icons.swap_vert_rounded,
    Icons.currency_exchange_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MONEY',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            )),
                        const SizedBox(height: 2),
                        Text('Finance',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            )),
                      ],
                    ),
                  ),
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
            _Segmented(
              labels: _labels,
              icons: _icons,
              index: _tabs.index,
              onTap: (i) => _tabs.animateTo(i),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  VaultView(),
                  TransactionsListView(),
                  ExchangeRatesView(),
                ],
              ),
            ),
          ],
        ),
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
        Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute(builder: (_) => routes[v]!));
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
    final txs = ref.watch(recentTransactionsStreamProvider).value ??
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
              color: const Color(0xFF22C55E),
              icon: Icons.south_west_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FlowChip(
              label: 'Out',
              value: fmt.format(expense),
              color: const Color(0xFFEF4444),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3,
                )),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.icons,
    required this.index,
    required this.onTap,
  });
  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icons[i],
                          size: 16,
                          color: i == index
                              ? cs.onPrimary
                              : cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(
                            color: i == index
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
