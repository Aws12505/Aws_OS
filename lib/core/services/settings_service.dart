import '../db/app_database.dart';

/// Typed wrapper around the `app_settings` key/value table.
class SettingsService {
  SettingsService(this._db);

  final AppDatabase _db;

  Future<String?> getRaw(String key) async {
    final row = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchRaw(String key) {
    return (_db.select(_db.appSettingsTable)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> setRaw(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.appSettingsTable)
            ..where((t) => t.key.equals(key)))
          .go();
      return;
    }
    await _db.into(_db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: key, value: value),
        );
  }

  Future<int?> getInt(String key) async {
    final raw = await getRaw(key);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<bool?> getBool(String key) async {
    final raw = await getRaw(key);
    if (raw == null) return null;
    return raw == 'true';
  }

  Future<void> setInt(String key, int? value) =>
      setRaw(key, value?.toString());

  Future<void> setBool(String key, bool? value) =>
      setRaw(key, value == null ? null : (value ? 'true' : 'false'));
}
