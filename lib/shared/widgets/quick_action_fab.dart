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
      icon: const Icon(Icons.add_rounded),
      label: const Text('Quick add'),
      onPressed: () => _show(context, ref),
    );
  }

  void _show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetCtx) => _QuickActionSheet(ref: ref),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({required this.ref});
  final WidgetRef ref;

  static const _actions = <_Action>[
    _Action(
      icon: Icons.trending_down_rounded,
      label: 'Expense',
      sublabel: 'Money out',
      color: Color(0xFFEF4444),
      key: 'expense',
    ),
    _Action(
      icon: Icons.trending_up_rounded,
      label: 'Income',
      sublabel: 'Money in',
      color: Color(0xFF22C55E),
      key: 'income',
    ),
    _Action(
      icon: Icons.compare_arrows_rounded,
      label: 'Transfer',
      sublabel: 'Same currency',
      color: Color(0xFF3B82F6),
      key: 'transfer',
    ),
    _Action(
      icon: Icons.swap_horiz_rounded,
      label: 'Exchange',
      sublabel: 'Cross currency',
      color: Color(0xFF8B5CF6),
      key: 'exchange',
    ),
    _Action(
      icon: Icons.task_alt_rounded,
      label: 'Task',
      sublabel: 'Add to workspace',
      color: Color(0xFF14B8A6),
      key: 'task',
    ),
    _Action(
      icon: Icons.sticky_note_2_rounded,
      label: 'Note',
      sublabel: 'Markdown note',
      color: Color(0xFFF59E0B),
      key: 'note',
    ),
  ];

  void _handleTap(BuildContext context, String key) {
    Navigator.pop(context);
    switch (key) {
      case 'expense':
        showIncomeExpenseFormSheet(context, kind: 'expense');
      case 'income':
        showIncomeExpenseFormSheet(context, kind: 'income');
      case 'transfer':
        showTransferFormSheet(context);
      case 'exchange':
        showExchangeFormSheet(context);
      case 'task':
        final workspaces = ref.read(workspacesStreamProvider).value ?? const [];
        if (workspaces.isEmpty) {
          showWorkspaceFormSheet(context);
        } else {
          showTaskFormSheet(context, workspaceId: workspaces.first.id);
        }
      case 'note':
        showNoteFormSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Text(
                    'Quick add',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest,
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _actions.length,
              itemBuilder: (_, i) => _ActionCard(
                action: _actions[i],
                onTap: () => _handleTap(context, _actions[i].key),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});
  final _Action action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: action.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: action.color.withValues(alpha: 0.12),
        highlightColor: action.color.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: action.color.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                action.label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                action.sublabel,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.key,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String key;
}
