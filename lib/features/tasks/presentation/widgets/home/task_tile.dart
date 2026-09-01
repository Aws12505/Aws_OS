part of '../../screens/tasks_screen.dart';

// One task row and the small controls that live in it.

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    required this.subtasks,
    required this.workspaceId,
  });
  final Task task;
  final List<Task> subtasks;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasCategory =
        task.category != null && task.category!.trim().isNotEmpty;
    final hasMeta =
        task.dueAt != null || task.deadlineAt != null || hasCategory;
    // No box. Tasks are rows in a list, and the list separates them with a
    // rule; boxing each one cost a border, a radius, a shadow and a gap per
    // item and made a screenful of tasks read as a screenful of widgets.
    return Padding(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          14,
          AppSpacing.sm,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Check(
                  checked: task.isCompleted,
                  size: 22,
                  onTap: () => ref
                      .read(tasksRepositoryProvider)
                      .toggleCompletion(task.id,
                          completed: !task.isCompleted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: tt.bodyLarge?.copyWith(
                            color: task.isCompleted
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: cs.onSurfaceVariant,
                          ).weight(FontWeight.w600),
                        ),
                        if (hasMeta) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (hasCategory)
                                _DateChip(
                                  icon: Icons.label_rounded,
                                  label: task.category!,
                                  color: context.sem.exchange.base,
                                ),
                              if (task.recurrenceId != null)
                                _DateChip(
                                  icon: Icons.repeat_rounded,
                                  label: 'Repeats',
                                  color: context.sem.tasks.base,
                                ),
                              if (task.dueAt != null)
                                _DateChip(
                                  icon: Icons.schedule_rounded,
                                  label:
                                      'Due ${DateFormat.MMMd().format(task.dueAt!)}',
                                  color: context.sem.transfer.base,
                                ),
                              if (task.deadlineAt != null)
                                _DateChip(
                                  icon: Icons.flag_rounded,
                                  label:
                                      'Deadline ${DateFormat.MMMd().format(task.deadlineAt!)}',
                                  color: context.sem.expense.base,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  onSelected: (v) async {
                    switch (v) {
                      case 'details':
                        Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailScreen(taskId: task.id)));
                      case 'subtask':
                        showTaskFormSheet(context,
                            workspaceId: workspaceId, parentTaskId: task.id);
                      case 'edit':
                        showTaskFormSheet(context,
                            workspaceId: workspaceId, existing: task);
                      case 'history':
                        Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    TaskHistoryScreen(taskId: task.id)));
                      case 'delete':
                        final ok = await showAppConfirmDialog(
                          context,
                          title: 'Delete "${task.title}"?',
                          message: 'Subtasks under it will also be removed.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (ok) {
                          await ref
                              .read(tasksRepositoryProvider)
                              .deleteTask(task.id);
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'details', child: Text('Details')),
                    PopupMenuItem(value: 'subtask', child: Text('Add subtask')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'history', child: Text('History')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (subtasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(left: 34),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surfaces.sunken,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: context.surfaces.hairline),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < subtasks.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 12,
                            color: context.surfaces.hairline),
                      _SubtaskRow(task: subtasks[i], ref: ref),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.checked,
    required this.onTap,
    this.size = 22,
  });
  final bool checked;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: context.motion.short,
                      curve: context.motion.standardCurve,
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

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 11,
              ).weight(FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({required this.task, required this.ref});
  final Task task;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => ref
          .read(tasksRepositoryProvider)
          .toggleCompletion(task.id, completed: !task.isCompleted),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          _Check(
            checked: task.isCompleted,
            size: 18,
            onTap: () => ref.read(tasksRepositoryProvider).toggleCompletion(
                task.id,
                completed: !task.isCompleted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              style: tt.bodyMedium?.copyWith(
                color: task.isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
