import 'package:drift/drift.dart';

import '_syncable.dart';

class Workspaces extends Table with SyncableColumns {
  @override
  String get tableName => 'workspaces';

  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskRecurrences extends Table with SyncableColumns {
  @override
  String get tableName => 'task_recurrences';

  TextColumn get ruleJson => text()();
  TextColumn get templateJson => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDueAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table with SyncableColumns {
  @override
  String get tableName => 'tasks';

  TextColumn get workspaceId =>
      text().customConstraint('NOT NULL REFERENCES workspaces(id)')();
  TextColumn get parentTaskId => text().nullable().customConstraint(
      'NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  TextColumn get title => text()();
  TextColumn get bodyMd => text().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get deadlineAt => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get recurrenceId => text().nullable().customConstraint(
      'NULL REFERENCES task_recurrences(id) ON DELETE SET NULL')();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskHistory extends Table with SyncableColumns {
  @override
  String get tableName => 'task_history';

  TextColumn get taskId => text().customConstraint(
      'NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  // 'created' | 'completed' | 'uncompleted' | 'edited' | 'deleted'
  TextColumn get action => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get snapshotJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
