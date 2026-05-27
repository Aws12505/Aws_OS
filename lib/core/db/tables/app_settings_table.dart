import 'package:drift/drift.dart';

/// Simple key/value store for app-level settings (reminder time, theme,
/// idle-lock timeout, etc.). Values are encoded as strings and parsed by
/// the settings service.
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
