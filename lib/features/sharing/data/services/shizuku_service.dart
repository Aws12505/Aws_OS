import 'package:flutter/services.dart';

/// One file copied out of (or into) an app's obb/data sandbox via Shizuku.
class StagedFile {
  const StagedFile({required this.path, required this.relPath});
  final String path;
  final String relPath;

  Map<String, String> toMap() => {'path': path, 'relPath': relPath};
  factory StagedFile.fromMap(Map<String, dynamic> m) =>
      StagedFile(path: m['path'] as String, relPath: m['relPath'] as String);
}

/// Bridges the `com.aws.aws_os/shizuku` channel. Enables OBB / Android-data
/// access without root (Shizuku must be active). All methods degrade to
/// unavailable/false when Shizuku isn't running or authorized.
class ShizukuService {
  static const MethodChannel _ch = MethodChannel('com.aws.aws_os/shizuku');

  Future<bool> isAvailable() async {
    try {
      return (await _ch.invokeMethod<bool>('isAvailable')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return (await _ch.invokeMethod<bool>('hasPermission')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await _ch.invokeMethod<void>('requestPermission');
    } catch (_) {}
  }

  Future<int> dirSize(String path) async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('dirInfo', {
        'path': path,
      });
      return (m?['size'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Copy [package]'s obb/data into [stagingDir]; returns the staged files
  /// (app-readable) so the normal transport can stream them.
  Future<List<StagedFile>> stage({
    required String package,
    required bool obb,
    required bool data,
    required String stagingDir,
  }) async {
    try {
      final res = await _ch.invokeListMethod<Object?>('stage', {
        'package': package,
        'obb': obb,
        'data': data,
        'stagingDir': stagingDir,
      });
      return (res ?? [])
          .map((m) => StagedFile.fromMap((m as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Copy received files back into /sdcard/Android/obb|data.
  Future<bool> restore(List<StagedFile> files) async {
    try {
      return (await _ch.invokeMethod<bool>('restore', {
            'files': files.map((f) => f.toMap()).toList(),
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Silent split-aware install (requires Shizuku).
  Future<bool> installApks(List<String> paths) async {
    try {
      return (await _ch.invokeMethod<bool>('installApks', {'paths': paths})) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
