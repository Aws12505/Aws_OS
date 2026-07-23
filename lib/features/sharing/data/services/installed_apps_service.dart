import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({
    required this.package,
    required this.label,
    required this.system,
    required this.apkSize,
    this.versionName,
    this.hasSplits = false,
  });

  final String package;
  final String label;
  final bool system;
  final int apkSize;
  final String? versionName;
  final bool hasSplits;

  factory InstalledApp.fromMap(Map<String, dynamic> m) => InstalledApp(
    package: m['package'] as String,
    label: (m['label'] as String?) ?? (m['package'] as String),
    system: (m['system'] as bool?) ?? false,
    apkSize: (m['apkSize'] as num?)?.toInt() ?? 0,
    versionName: m['versionName'] as String?,
    hasSplits: (m['hasSplits'] as bool?) ?? false,
  );
}

/// Lists installed apps, resolves their (world-readable) APK paths, and installs
/// received APKs via the system PackageInstaller. Works on every device.
class InstalledAppsService {
  static const MethodChannel _ch = MethodChannel('com.aws.aws_os/apps');

  Future<List<InstalledApp>> list({bool includeSystem = false}) async {
    try {
      final res = await _ch.invokeListMethod<Object?>('listApps', {
        'includeSystem': includeSystem,
      });
      return (res ?? [])
          .map((m) => InstalledApp.fromMap((m as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  final _iconCache = <String, Uint8List?>{};

  /// Launcher icon for [package] as PNG bytes (cached). Returns null if the
  /// platform can't resolve one, so callers can fall back to a generic glyph.
  Future<Uint8List?> icon(String package, {int size = 128}) async {
    if (_iconCache.containsKey(package)) return _iconCache[package];
    try {
      final res = await _ch.invokeMethod<Uint8List>('getAppIcon', {
        'package': package,
        'size': size,
      });
      _iconCache[package] = res;
      return res;
    } catch (_) {
      _iconCache[package] = null;
      return null;
    }
  }

  Future<List<String>> apkPaths(String package) async {
    try {
      final res = await _ch.invokeListMethod<String>('getApkPaths', {
        'package': package,
      });
      return res ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> installApks(List<String> paths) async {
    try {
      return (await _ch.invokeMethod<bool>('installApks', {'paths': paths})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Launches the system installer for a single received APK (shows the confirm
  /// UI). Returns false if the file is gone or no installer handled it.
  Future<bool> installApk(String path) async {
    try {
      return (await _ch.invokeMethod<bool>('installApk', {'path': path})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Opens a received file with the system's default app (image viewer, video
  /// player, etc.). Pass [mime] to force a type; otherwise it's inferred from
  /// the extension. Returns false if nothing could open it.
  Future<bool> openFile(String path, {String? mime}) async {
    try {
      return (await _ch.invokeMethod<bool>('openFile', {
            'path': path,
            'mime': mime,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
