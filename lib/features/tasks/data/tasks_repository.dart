import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
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
    String? category,
    DateTime? dueAt,
    DateTime? deadlineAt,
    String? recurrenceId,
    int sortOrder = 0,
  }) async {
    final saved = await dao.upsertTaskReturning(TasksCompanion(
      id: id == null ? const Value.absent() : Value(id),
      workspaceId: Value(workspaceId),
      parentTaskId: Value(parentTaskId),
      title: Value(title),
      bodyMd: Value(bodyMd),
      category: Value(category),
      dueAt: Value(dueAt),
      deadlineAt: Value(deadlineAt),
      recurrenceId: Value(recurrenceId),
      sortOrder: Value(sortOrder),
    ));
    await dao.appendHistory(
      taskId: saved.id,
      action: id == null ? 'created' : 'edited',
      snapshot: {
        'title': title,
        'workspaceId': workspaceId,
        'category': ?category,
        if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
        if (deadlineAt != null) 'deadlineAt': deadlineAt.toIso8601String(),
      },
    );
    return saved;
  }

  // -- Recurrences --------------------------------------------------------

  Stream<List<TaskRecurrence>> watchRecurrences() => dao.watchRecurrences();
  Future<TaskRecurrence?> getRecurrence(String id) => dao.getRecurrence(id);

  Future<TaskRecurrence> upsertRecurrence({
    String? id,
    required String ruleJson,
    required String templateJson,
    required DateTime startDate,
    DateTime? nextDueAt,
  }) {
    return dao.upsertRecurrenceReturning(TaskRecurrencesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      ruleJson: Value(ruleJson),
      templateJson: Value(templateJson),
      startDate: Value(startDate),
      nextDueAt: Value(nextDueAt),
    ));
  }

  Future<void> endRecurrence(String id) => dao.endRecurrence(id);

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

  /// Roll every unfinished task due (or with a deadline) on [from] forward to
  /// [to] (default: the next day), preserving each task's time-of-day. Records
  /// a 'carried_over' history entry per task and returns how many moved.
  Future<int> carryOverUnfinished({required DateTime from, DateTime? to}) async {
    final target = (to ?? from.addDays(1)).atStartOfDay;
    final all = await dao.watchAllTasks().first;
    final pending = all
        .where((t) =>
            !t.isCompleted &&
            ((t.dueAt != null && t.dueAt!.isSameDay(from)) ||
                (t.deadlineAt != null && t.deadlineAt!.isSameDay(from))))
        .toList();
    for (final t in pending) {
      final newDue = t.dueAt == null ? null : target.withTimeOf(t.dueAt!);
      final newDeadline =
          t.deadlineAt == null ? null : target.withTimeOf(t.deadlineAt!);
      await dao.upsertTaskReturning(t.toCompanion(true).copyWith(
            dueAt: Value(newDue),
            deadlineAt: Value(newDeadline),
          ));
      await dao.appendHistory(
        taskId: t.id,
        action: 'carried_over',
        snapshot: {
          'from': from.toIso8601String(),
          'to': target.toIso8601String(),
        },
      );
    }
    return pending.length;
  }

  /// Convenience: carry today's unfinished tasks to tomorrow.
  Future<int> planTomorrow() =>
      carryOverUnfinished(from: DateTime.now().atStartOfDay);
}
