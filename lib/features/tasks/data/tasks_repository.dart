import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import 'tasks_dao.dart';

class TasksRepository {
  TasksRepository(this.dao);
  final TasksDao dao;

  Stream<List<Workspace>> watchWorkspaces() => dao.watchWorkspaces();

  Future<void> saveWorkspace({
    String? id,
    required String name,
    int? color,
    String? icon,
    int sortOrder = 0,
  }) {
    return dao.upsertWorkspace(WorkspacesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name),
      color: Value(color),
      icon: Value(icon),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteWorkspace(String id) => dao.deleteWorkspace(id);

  Stream<List<Task>> watchTasksForWorkspace(String workspaceId) =>
      dao.watchTasksForWorkspace(workspaceId);
  Stream<List<Task>> watchAllTasks() => dao.watchAllTasks();
  Future<Task?> getTask(String id) => dao.getTask(id);

  Future<Task> saveTask({
    String? id,
    required String workspaceId,
    String? parentTaskId,
    required String title,
    String? bodyMd,
    DateTime? dueAt,
    DateTime? deadlineAt,
    int sortOrder = 0,
  }) async {
    final saved = await dao.upsertTaskReturning(TasksCompanion(
      id: id == null ? const Value.absent() : Value(id),
      workspaceId: Value(workspaceId),
      parentTaskId: Value(parentTaskId),
      title: Value(title),
      bodyMd: Value(bodyMd),
      dueAt: Value(dueAt),
      deadlineAt: Value(deadlineAt),
      sortOrder: Value(sortOrder),
    ));
    await dao.appendHistory(
      taskId: saved.id,
      action: id == null ? 'created' : 'edited',
      snapshot: {
        'title': title,
        'workspaceId': workspaceId,
        if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
        if (deadlineAt != null) 'deadlineAt': deadlineAt.toIso8601String(),
      },
    );
    return saved;
  }

  Future<void> toggleCompletion(String id, {required bool completed}) async {
    await dao.setCompletion(id, completed);
    await dao.appendHistory(
      taskId: id,
      action: completed ? 'completed' : 'uncompleted',
    );
  }

  Future<void> deleteTask(String id) async {
    await dao.appendHistory(taskId: id, action: 'deleted');
    await dao.deleteTask(id);
  }

  Stream<List<TaskHistoryData>> watchHistoryForTask(String id) =>
      dao.watchHistoryForTask(id);
}
