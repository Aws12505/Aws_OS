import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists user preferences for the sharing feature. Currently just the
/// received-files save directory; kept tiny and in secure storage to match the
/// rest of the feature (see [share_identity] in providers).
class ShareSettingsStore {
  ShareSettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _saveDirKey = 'share.saveDir';

  /// The user-chosen directory received files are saved to, or null to use the
  /// app's default location.
  Future<String?> saveDirectory() async {
    final v = await _storage.read(key: _saveDirKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setSaveDirectory(String? path) async {
    if (path == null || path.isEmpty) {
      await _storage.delete(key: _saveDirKey);
    } else {
      await _storage.write(key: _saveDirKey, value: path);
    }
  }
}
