import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_background.dart';
import '../providers.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/workspace_form_sheet.dart';
import 'task_detail_screen.dart';
import 'task_history_screen.dart';

const _wsPalette = <Color>[
  Color(0xFF6366F1),
  Color(0xFF06B6D4),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF14B8A6),
];

Color _wsColor(Workspace w, int i) =>
    w.color != null ? Color(w.color!) : _wsPalette[i % _wsPalette.length];

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspacesStreamProvider);
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (workspaces) {
        if (workspaces.isEmpty) return const _EmptyWorkspaces();
        return _TasksHome(workspaces: workspaces);
      },
    );
  }
}

// ── empty ────────────────────────────────────────────────────────────────────

class _EmptyWorkspaces extends StatelessWidget {
  const _EmptyWorkspaces();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspaces_rounded,
                      size: 48, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('Create a workspace',
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Workspaces organize your tasks into focused\nspaces — work, personal, projects.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New workspace'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => showWorkspaceFormSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── home ─────────────────────────────────────────────────────────────────────

class _TasksHome extends ConsumerStatefulWidget {
  const _TasksHome({required this.workspaces});
  final List<Workspace> workspaces;
  @override
  ConsumerState<_TasksHome> createState() => _TasksHomeState();
}

class _TasksHomeState extends ConsumerState<_TasksHome> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _TasksHome old) {
    super.didUpdateWidget(old);
    if (_index >= widget.workspaces.length) {
      _index = widget.workspaces.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final workspaces = widget.workspaces;
    final allTasks =
        ref.watch(allTasksStreamProvider).value ?? const <Task>[];
    final counts = <String, ({int done, int total})>{};
    for (final w in workspaces) {
      final ws = allTasks.where((t) => t.workspaceId == w.id);
      counts[w.id] = (
        done: ws.where((t) => t.isCompleted).length,
        total: ws.length,
      );
    }
    final active = workspaces[_index.clamp(0, workspaces.length - 1)];
    final accent = _wsColor(active, _index);

    return Scaffold(
      body: AuroraBackground(
        accent: accent,
        child: SafeArea(
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
                          Text(
                            'MY WORKSPACES',
                            style: tt.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tasks',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Carry unfinished tasks to tomorrow',
                      icon: const Icon(Icons.event_repeat_rounded),
                      onPressed: () async {
                        final moved = await ref
                            .read(tasksRepositoryProvider)
                            .carryOverUnfinished(from: DateTime.now());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(moved == 0
                                ? 'Nothing to carry over'
                                : 'Moved $moved task${moved == 1 ? '' : 's'} to tomorrow'),
                          ));
                        }
                      },
                    ),
                    IconButton.filledTonal(
                      tooltip: 'New workspace',
                      icon: const Icon(Icons.create_new_folder_rounded),
                      onPressed: () => showWorkspaceFormSheet(context),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 156,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: workspaces.length,
                  itemBuilder: (_, i) {
                    final w = workspaces[i];
                    final c = counts[w.id] ?? (done: 0, total: 0);
                    return _WorkspaceCard(
                      name: w.name,
                      color: _wsColor(w, i),
                      done: c.done,
                      total: c.total,
                      selected: i == _index,
                      onTap: () => _select(i),
                    );
                  },
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: workspaces.length,
                  itemBuilder: (_, i) =>
                      _WorkspaceTaskList(workspace: workspaces[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── workspace card ─────────────────────────────────────────────────────────

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.name,
    required this.color,
    required this.done,
    required this.total,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final Color color;
  final int done;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = total == 0 ? 0.0 : done / total;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: 158,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.22)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : cs.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.22)
                            : color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        size: 20,
                        color: selected ? Colors.white : color,
                      ),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$total',
                        maxLines: 1,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : cs.surfaceContainerHighest,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0 ? 'No tasks' : '$done of $total done',
                  style: tt.labelSmall?.copyWith(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── per-workspace list ───────────────────────────────────────────────────────

class _WorkspaceTaskList extends ConsumerWidget {
  const _WorkspaceTaskList({required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tasksForWorkspaceProvider(workspace.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (tasks) {
        if (tasks.isEmpty) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist_rtl_rounded,
                      size: 56,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('All clear',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Tap + to add a task here.',
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }
        final children = <String, List<Task>>{};
        final top = <Task>[];
        for (final t in tasks) {
          if (t.parentTaskId == null) {
            top.add(t);
          } else {
            children.putIfAbsent(t.parentTaskId!, () => []).add(t);
          }
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
          itemCount: top.length,
          itemBuilder: (_, i) => _TaskTile(
            task: top[i],
            subtasks: children[top[i].id] ?? const [],
            workspaceId: workspace.id,
          ),
        );
      },
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
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
                            fontWeight: FontWeight.w600,
                            color: task.isCompleted
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: cs.onSurfaceVariant,
                          ),
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
                                  color: const Color(0xFF8B5CF6),
                                ),
                              if (task.recurrenceId != null)
                                _DateChip(
                                  icon: Icons.repeat_rounded,
                                  label: 'Repeats',
                                  color: const Color(0xFF14B8A6),
                                ),
                              if (task.dueAt != null)
                                _DateChip(
                                  icon: Icons.schedule_rounded,
                                  label:
                                      'Due ${DateFormat.MMMd().format(task.dueAt!)}',
                                  color: const Color(0xFF3B82F6),
                                ),
                              if (task.deadlineAt != null)
                                _DateChip(
                                  icon: Icons.flag_rounded,
                                  label:
                                      'Deadline ${DateFormat.MMMd().format(task.deadlineAt!)}',
                                  color: const Color(0xFFEF4444),
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
                        Navigator.of(context, rootNavigator: true).push(
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
                        Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    TaskHistoryScreen(taskId: task.id)));
                      case 'delete':
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: Text('Delete "${task.title}"?'),
                            content: const Text(
                                'Subtasks under it will also be removed.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: cs.error),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
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
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < subtasks.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 12,
                            color: cs.outlineVariant.withValues(alpha: 0.3)),
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
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(top: 2),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? const Color(0xFF22C55E) : Colors.transparent,
          border: Border.all(
            color: checked
                ? const Color(0xFF22C55E)
                : cs.outline.withValues(alpha: 0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: checked
            ? Icon(Icons.check_rounded, size: size * 0.62, color: Colors.white)
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
        borderRadius: BorderRadius.circular(7),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
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
