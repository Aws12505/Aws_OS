part of '../../screens/tasks_screen.dart';

// The task list for one workspace page.

class _WorkspaceTaskList extends ConsumerWidget {
  const _WorkspaceTaskList({required this.workspace});
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredTasksForWorkspaceProvider(workspace.id));
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(error: e),
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
                          ),
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
        // separatorBuilder rather than a rule inside the tile: a rule belongs
        // between rows, and a tile that draws its own leaves a stray line under
        // the last one.
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppInsets.listBottom),
          itemCount: top.length,
          separatorBuilder: (_, _) => const AppRule(),
          itemBuilder: (_, i) => StaggeredEntry(
            index: i,
            child: _TaskTile(
              task: top[i],
              subtasks: children[top[i].id] ?? const [],
              workspaceId: workspace.id,
            ),
          ),
        );
      },
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final activeCount =
        filter.activeCount +
        (filter.status != TaskStatusFilter.active ? 1 : 0);

    return AppFilterBar(
      activeCount: activeCount,
      color: context.sem.tasks.base,
      onOpenFilters: () => showTaskFilterSheet(context),
      onClear: filter.isDefault
          ? null
          : () => ref.read(taskFilterProvider.notifier).state =
                const TaskFilter(),
    );
  }
}
