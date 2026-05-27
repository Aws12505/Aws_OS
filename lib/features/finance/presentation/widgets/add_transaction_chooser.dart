import 'package:flutter/material.dart';

import 'exchange_form_sheet.dart';
import 'income_expense_form_sheet.dart';
import 'recurrence_form_sheet.dart';
import 'transfer_form_sheet.dart';

Future<void> showAddTransactionChooser(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChoiceTile(
            icon: Icons.trending_down,
            color: Colors.red,
            title: 'Expense',
            subtitle: 'Money out, possibly split across accounts.',
            onTap: () {
              Navigator.pop(sheetCtx);
              showIncomeExpenseFormSheet(context, kind: 'expense');
            },
          ),
          _ChoiceTile(
            icon: Icons.trending_up,
            color: Colors.green,
            title: 'Income',
            subtitle: 'Money in, possibly split across accounts.',
            onTap: () {
              Navigator.pop(sheetCtx);
              showIncomeExpenseFormSheet(context, kind: 'income');
            },
          ),
          _ChoiceTile(
            icon: Icons.compare_arrows,
            color: Colors.blue,
            title: 'Transfer',
            subtitle: 'Move between two same-currency accounts.',
            onTap: () {
              Navigator.pop(sheetCtx);
              showTransferFormSheet(context);
            },
          ),
          _ChoiceTile(
            icon: Icons.swap_horiz,
            color: Colors.purple,
            title: 'Exchange',
            subtitle: 'Convert between two currencies, records a rate.',
            onTap: () {
              Navigator.pop(sheetCtx);
              showExchangeFormSheet(context);
            },
          ),
          _ChoiceTile(
            icon: Icons.repeat,
            color: Colors.orange,
            title: 'Recurring',
            subtitle: 'Schedule an income/expense that reminds you to confirm each time.',
            onTap: () {
              Navigator.pop(sheetCtx);
              showRecurrenceFormSheet(context);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
