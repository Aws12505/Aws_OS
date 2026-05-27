import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/workspace_form_sheet.dart';
import 'task_history_screen.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspacesStreamProvider);
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(e.toString()))),
      data: (workspaces) {
        if (workspaces.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tasks')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspaces_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('No workspaces yet',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first workspace to start adding tasks.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('New workspace'),
                      onPressed: () => showWorkspaceFormSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _TasksTabs(workspaces: workspaces);
      },
    );
  }
}

class _TasksTabs extends ConsumerStatefulWidget {
  const _TasksTabs({required this.workspaces});
  final List<Workspace> workspaces;
  @override
  ConsumerState<_TasksTabs> createState() => _TasksTabsState();
}

class _TasksTabsState extends ConsumerState<_TasksTabs>
    with TickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.workspaces.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _TasksTabs old) {
    super.didUpdateWidget(old);
    if (old.workspaces.length != widget.workspaces.length) {
      _tabs.dispose();
      _tabs = TabController(length: widget.workspaces.length, vsync: this);
    }
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
        title: const Text('Tasks'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final w in widget.workspaces) Tab(text: w.name)],
        ),
        actions: [
          IconButton(
            tooltip: 'New workspace',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => showWorkspaceFormSheet(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final w in widget.workspaces) _WorkspaceTaskList(workspace: w),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Task'),
        onPressed: () {
          final w = widget.workspaces[_tabs.index];
          showTaskFormSheet(context, workspaceId: w.id);
        },
      ),
    );
  }
}

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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tasks yet. Tap + to add one.'),
            ),
          );
        }
        // Group: top-level + children.
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
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
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
    final subtitleParts = <String>[
      if (task.dueAt != null) 'Due ${DateFormat.MMMd().format(task.dueAt!)}',
      if (task.deadlineAt != null)
        'Deadline ${DateFormat.MMMd().format(task.deadlineAt!)}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            CheckboxListTile(
              value: task.isCompleted,
              onChanged: (v) => ref
                  .read(tasksRepositoryProvider)
                  .toggleCompletion(task.id, completed: v ?? false),
              title: Text(
                task.title,
                style: task.isCompleted
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      )
                    : null,
              ),
              subtitle: subtitleParts.isEmpty
                  ? null
                  : Text(subtitleParts.join(' · ')),
              secondary: PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'subtask':
                      showTaskFormSheet(
                        context,
                        workspaceId: workspaceId,
                        parentTaskId: task.id,
                      );
                    case 'edit':
                      showTaskFormSheet(
                        context,
                        workspaceId: workspaceId,
                        existing: task,
                      );
                    case 'history':
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TaskHistoryScreen(taskId: task.id)));
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
                  PopupMenuItem(
                      value: 'subtask', child: Text('Add subtask')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'history', child: Text('History')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
            if (subtasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  children: [
                    for (final s in subtasks)
                      CheckboxListTile(
                        dense: true,
                        value: s.isCompleted,
                        onChanged: (v) => ref
                            .read(tasksRepositoryProvider)
                            .toggleCompletion(s.id, completed: v ?? false),
                        title: Text(
                          s.title,
                          style: s.isCompleted
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
