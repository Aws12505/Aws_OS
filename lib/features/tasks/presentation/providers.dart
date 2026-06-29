import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/task_recurrence_service.dart';
import '../data/tasks_dao.dart';
import '../data/tasks_repository.dart';

final tasksDaoProvider = Provider<TasksDao>((ref) {
  return TasksDao(ref.watch(databaseProvider));
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(tasksDaoProvider));
});

final taskRecurrenceServiceProvider = Provider<TaskRecurrenceService>((ref) {
  return TaskRecurrenceService(ref.watch(tasksDaoProvider));
});

/// Distinct, non-empty task category labels seen across all tasks — powers the
/// category autocomplete in the task form.
final taskCategoriesProvider = Provider<List<String>>((ref) {
  final tasks = ref.watch(allTasksStreamProvider).value ?? const <Task>[];
  final set = <String>{
    for (final t in tasks)
      if (t.category != null && t.category!.trim().isNotEmpty) t.category!.trim(),
  };
  final list = set.toList()..sort();
  return list;
});

final workspacesStreamProvider = StreamProvider<List<Workspace>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchWorkspaces();
});

final tasksForWorkspaceProvider =
    StreamProvider.family<List<Task>, String>((ref, workspaceId) {
  return ref
      .watch(tasksRepositoryProvider)
      .watchTasksForWorkspace(workspaceId);
});

final allTasksStreamProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchAllTasks();
});

final taskHistoryStreamProvider =
    StreamProvider.family<List<TaskHistoryData>, String>((ref, taskId) {
  return ref.watch(tasksRepositoryProvider).watchHistoryForTask(taskId);
});
