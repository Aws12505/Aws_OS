import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/tasks_dao.dart';
import '../data/tasks_repository.dart';

final tasksDaoProvider = Provider<TasksDao>((ref) {
  return TasksDao(ref.watch(databaseProvider));
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(tasksDaoProvider));
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
