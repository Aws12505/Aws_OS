// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_dao.dart';

// ignore_for_file: type=lint
mixin _$TasksDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $TaskRecurrencesTable get taskRecurrences => attachedDatabase.taskRecurrences;
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskHistoryTable get taskHistory => attachedDatabase.taskHistory;
  TasksDaoManager get managers => TasksDaoManager(this);
}

class TasksDaoManager {
  final _$TasksDaoMixin _db;
  TasksDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$TaskRecurrencesTableTableManager get taskRecurrences =>
      $$TaskRecurrencesTableTableManager(
        _db.attachedDatabase,
        _db.taskRecurrences,
      );
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskHistoryTableTableManager get taskHistory =>
      $$TaskHistoryTableTableManager(_db.attachedDatabase, _db.taskHistory);
}
