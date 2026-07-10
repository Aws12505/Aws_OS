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
}
