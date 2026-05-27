import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/finance/presentation/widgets/exchange_form_sheet.dart';
import '../../features/finance/presentation/widgets/income_expense_form_sheet.dart';
import '../../features/finance/presentation/widgets/transfer_form_sheet.dart';
import '../../features/notes/presentation/widgets/note_form_sheet.dart';
import '../../features/tasks/presentation/providers.dart';
import '../../features/tasks/presentation/widgets/task_form_sheet.dart';
import '../../features/tasks/presentation/widgets/workspace_form_sheet.dart';

class QuickActionFab extends ConsumerWidget {
  const QuickActionFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.bolt),
      label: const Text('Quick add'),
      onPressed: () => _show(context, ref),
    );
  }

  void _show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tile(
              icon: Icons.trending_down,
              color: Colors.red,
              title: 'Expense',
              subtitle: 'Money out',
              onTap: () {
                Navigator.pop(sheetCtx);
                showIncomeExpenseFormSheet(context, kind: 'expense');
              },
            ),
            _Tile(
              icon: Icons.trending_up,
              color: Colors.green,
              title: 'Income',
              subtitle: 'Money in',
              onTap: () {
                Navigator.pop(sheetCtx);
                showIncomeExpenseFormSheet(context, kind: 'income');
              },
            ),
            _Tile(
              icon: Icons.compare_arrows,
              color: Colors.blue,
              title: 'Transfer',
              subtitle: 'Between accounts, same currency',
              onTap: () {
                Navigator.pop(sheetCtx);
                showTransferFormSheet(context);
              },
            ),
            _Tile(
              icon: Icons.swap_horiz,
              color: Colors.purple,
              title: 'Exchange',
              subtitle: 'Across currencies',
              onTap: () {
                Navigator.pop(sheetCtx);
                showExchangeFormSheet(context);
              },
            ),
            const Divider(),
            _Tile(
              icon: Icons.task_alt,
              color: Colors.teal,
              title: 'Task',
              subtitle: 'Add to a workspace',
              onTap: () async {
                Navigator.pop(sheetCtx);
                final workspaces =
                    ref.read(workspacesStreamProvider).value ?? const [];
                if (workspaces.isEmpty) {
                  showWorkspaceFormSheet(context);
                } else {
                  showTaskFormSheet(context, workspaceId: workspaces.first.id);
                }
              },
            ),
            _Tile(
              icon: Icons.notes,
              color: Colors.indigo,
              title: 'Note',
              subtitle: 'Quick markdown note',
              onTap: () {
                Navigator.pop(sheetCtx);
                showNoteFormSheet(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
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
