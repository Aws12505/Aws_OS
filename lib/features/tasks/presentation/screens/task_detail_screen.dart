import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../providers.dart';
import '../widgets/task_form_sheet.dart';
import 'task_history_screen.dart';

/// Read-only view of a single task — opened by tapping a task (no edit mode).
/// Edits/history/delete are reachable from the app-bar actions.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allTasksStreamProvider).value ?? const <Task>[];
    Task? task;
    for (final t in all) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }

    if (task == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Task')),
        body: const Center(child: Text('This task no longer exists.')),
      );
    }

    final t = task;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final repo = ref.read(tasksRepositoryProvider);
    final subtasks = all.where((s) => s.parentTaskId == t.id).toList();

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showTaskFormSheet(context,
                workspaceId: t.workspaceId, existing: t),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'subtask':
                  showTaskFormSheet(context,
                      workspaceId: t.workspaceId, parentTaskId: t.id);
                case 'history':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TaskHistoryScreen(taskId: t.id)));
                case 'delete':
                  final ok = await showAppConfirmDialog(
                    context,
                    title: 'Delete "${t.title}"?',
                    message: 'Subtasks under it will also be removed.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok) {
                    await repo.deleteTask(t.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'subtask', child: Text('Add subtask')),
              PopupMenuItem(value: 'history', child: Text('History')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Check(
                checked: t.isCompleted,
                onTap: () =>
                    repo.toggleCompletion(t.id, completed: !t.isCompleted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.title,
                  style: tt.headlineSmall?.copyWith(
                    decoration:
                        t.isCompleted ? TextDecoration.lineThrough : null,
                    color: t.isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                  ).weight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: t.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                label: t.isCompleted ? 'Completed' : 'Active',
                color: t.isCompleted
                    ? context.sem.income.base
                    : context.sem.tasks.base,
              ),
              if (t.category != null && t.category!.trim().isNotEmpty)
                _Chip(
                  icon: Icons.label_rounded,
                  label: t.category!,
                  color: context.sem.exchange.base,
                ),
              if (t.dueAt != null)
                _Chip(
                  icon: Icons.schedule_rounded,
                  label: 'Due ${DateFormat.yMMMd().format(t.dueAt!)}',
                  color: context.sem.transfer.base,
                ),
              if (t.deadlineAt != null)
                _Chip(
                  icon: Icons.flag_rounded,
                  label: 'Deadline ${DateFormat.yMMMd().format(t.deadlineAt!)}',
                  color: context.sem.expense.base,
                ),
            ],
          ),
          if (t.recurrenceId != null)
            _RecurrenceLine(recurrenceId: t.recurrenceId!),
          if (t.completedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Completed ${DateFormat.yMMMd().add_jm().format(t.completedAt!)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (t.bodyMd != null && t.bodyMd!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Details',
                style: tt.titleSmall?.weight(FontWeight.w700)),
            const SizedBox(height: 8),
            MarkdownBody(data: t.bodyMd!, selectable: true),
          ],
          if (subtasks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Subtasks (${subtasks.where((s) => s.isCompleted).length}/${subtasks.length})',
                style: tt.titleSmall?.weight(FontWeight.w700)),
            const SizedBox(height: 8),
            for (final s in subtasks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _Check(
                      checked: s.isCompleted,
                      size: 20,
                      onTap: () => repo.toggleCompletion(s.id,
                          completed: !s.isCompleted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        style: tt.bodyMedium?.copyWith(
                          decoration: s.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: s.isCompleted
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Loads the recurrence and renders a human-readable summary line.
class _RecurrenceLine extends ConsumerWidget {
  const _RecurrenceLine({required this.recurrenceId});
  final String recurrenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<TaskRecurrence?>(
      future: ref.read(tasksRepositoryProvider).getRecurrence(recurrenceId),
      builder: (context, snap) {
        final rec = snap.data;
        if (rec == null) return const SizedBox.shrink();
        final summary = recurrenceSummary(RecurrenceRule.parse(rec.ruleJson));
        final label =
            rec.endedAt != null ? '$summary (ended)' : summary;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Icon(Icons.repeat_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Repeats every 2 weeks on Mon, Wed" style summary.
String recurrenceSummary(RecurrenceRule rule) {
  final n = rule.interval;
  final unit = switch (rule.freq) {
    RecurrenceFreq.daily => n == 1 ? 'day' : 'days',
    RecurrenceFreq.weekly => n == 1 ? 'week' : 'weeks',
    RecurrenceFreq.monthly => n == 1 ? 'month' : 'months',
    RecurrenceFreq.yearly => n == 1 ? 'year' : 'years',
  };
  final base = n == 1 ? 'Repeats every $unit' : 'Repeats every $n $unit';
  if (rule.freq == RecurrenceFreq.weekly && rule.byWeekday.isNotEmpty) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days =
        (rule.byWeekday.toList()..sort()).map((d) => names[d - 1]).join(', ');
    return '$base on $days';
  }
  return base;
}

class _Check extends StatelessWidget {
  const _Check({required this.checked, required this.onTap, this.size = 24});
  final bool checked;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? context.sem.income.base : Colors.transparent,
          border: Border.all(
            color: checked
                ? context.sem.income.base
                : cs.outline.withValues(alpha: 0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: checked
            ? Icon(
                Icons.check_rounded,
                size: size * 0.62,
                color: context.sem.income.onContainer,
              )
            : null,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
            ).weight(FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
