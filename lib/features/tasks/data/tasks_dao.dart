import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/_syncable.dart';
import '../../../core/db/tables/tasks_tables.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Workspaces, Tasks, TaskRecurrences, TaskHistory])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  // -- Workspaces ---------------------------------------------------------

  Stream<List<Workspace>> watchWorkspaces() {
    return (select(workspaces)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<void> upsertWorkspace(WorkspacesCompanion w) {
    final now = DateTime.now();
    return into(workspaces)
        .insertOnConflictUpdate(w.copyWith(updatedAt: Value(now)));
  }

  Future<void> deleteWorkspace(String id) =>
      (delete(workspaces)..where((t) => t.id.equals(id))).go();

  // -- Tasks --------------------------------------------------------------

  Stream<List<Task>> watchTasksForWorkspace(String workspaceId) {
    return (select(tasks)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.dueAt),
          ]))
        .watch();
  }

  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.asc(t.dueAt),
          ]))
        .watch();
  }

  Future<Task?> getTask(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Task> upsertTaskReturning(TasksCompanion t) async {
    final now = DateTime.now();
    return into(tasks).insertReturning(
      t.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<void> setCompletion(String id, bool completed) {
    final now = DateTime.now();
    return (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completed ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  // -- Recurrences --------------------------------------------------------

  Stream<List<TaskRecurrence>> watchRecurrences() =>
      select(taskRecurrences).watch();

  Future<TaskRecurrence?> getRecurrence(String id) =>
      (select(taskRecurrences)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<TaskRecurrence> upsertRecurrenceReturning(
      TaskRecurrencesCompanion r) async {
    final now = DateTime.now();
    return into(taskRecurrences).insertReturning(
      r.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateRecurrenceNextDue(String id, DateTime? next) {
    return (update(taskRecurrences)..where((t) => t.id.equals(id))).write(
      TaskRecurrencesCompanion(
        nextDueAt: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> endRecurrence(String id) {
    final now = DateTime.now();
    return (update(taskRecurrences)..where((t) => t.id.equals(id))).write(
      TaskRecurrencesCompanion(endedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// All tasks generated from (or anchoring) a given recurrence — used to
  /// avoid materializing duplicate occurrences.
  Future<List<Task>> getTasksForRecurrence(String recurrenceId) =>
      (select(tasks)..where((t) => t.recurrenceId.equals(recurrenceId))).get();

  // -- History ------------------------------------------------------------

  Future<void> appendHistory({
    required String taskId,
    required String action,
    Map<String, dynamic>? snapshot,
  }) {
    return into(taskHistory).insert(
      TaskHistoryCompanion(
        id: Value(newUuid()),
        taskId: Value(taskId),
        action: Value(action),
        at: Value(DateTime.now()),
        snapshotJson: Value(snapshot == null ? null : jsonEncode(snapshot)),
      ),
    );
  }

  Stream<List<TaskHistoryData>> watchHistoryForTask(String taskId) {
    return (select(taskHistory)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.desc(t.at)]))
        .watch();
  }
}
