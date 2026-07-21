import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'share_settings_store.dart';

/// Decides where received bytes land (temp while streaming, then a de-duplicated
/// final name) and lists finished files. Files go to the user-chosen directory
/// when one is set (see [ShareSettingsStore]); otherwise the app-private
/// external dir, which needs no storage permission. Temp + app-clone staging sit
/// in hidden subfolders of that same dir, so a rename to the final path stays on
/// one volume, and [list] hides them.
class ReceivedFilesStore {
  ReceivedFilesStore(this._settings);

  final ShareSettingsStore _settings;

  Directory? _dir;

  Future<Directory> receivedDir() async {
    if (_dir != null) return _dir!;
    final custom = await _settings.saveDirectory();
    if (custom != null) {
      final d = await _tryCustom(custom);
      if (d != null) {
        _dir = d;
        return d;
      }
    }
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'AwsShare', 'received'));
    await d.create(recursive: true);
    _dir = d;
    return d;
  }

  /// Returns the custom dir only if it exists and is actually writable, so a
  /// stale/permission-less path silently falls back to the default.
  Future<Directory?> _tryCustom(String path) async {
    try {
      final d = Directory(path);
      await d.create(recursive: true);
      final probe = File(p.join(d.path, '.awsshare_write_test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete().catchError((_) => probe);
      return d;
    } catch (_) {
      return null;
    }
  }

  /// Drop the cached directory so the next access re-reads the chosen path.
  void invalidate() {
    _dir = null;
  }

  /// The save directory currently in effect (for display in the UI).
  Future<String> currentSaveDirPath() async => (await receivedDir()).path;

  Future<File> tempFor(String fid) async {
    final d = await receivedDir();
    final t = Directory(p.join(d.path, '.tmp'));
    await t.create(recursive: true);
    return File(p.join(t.path, '$fid.part'));
  }

  /// Final destination for a completed file, de-duplicating the name.
  Future<File> finalFor(String name) async {
    final d = await receivedDir();
    final safe = _sanitize(name);
    var candidate = File(p.join(d.path, safe));
    var i = 1;
    while (await candidate.exists()) {
      final base = p.basenameWithoutExtension(safe);
      final ext = p.extension(safe);
      candidate = File(p.join(d.path, '$base ($i)$ext'));
      i++;
    }
    return candidate;
  }

  /// Move a temp file to its final path, falling back to copy+delete across
  /// filesystems.
  Future<File> finalize(File temp, String name) async {
    final dest = await finalFor(name);
    try {
      return await temp.rename(dest.path);
    } on FileSystemException {
      final copied = await temp.copy(dest.path);
      await temp.delete().catchError((_) => temp);
      return copied;
    }
  }

  /// App-clone staging: where received apk/obb/appData files land before
  /// install / Shizuku restore, preserving their [relPath] tree.
  Future<File> placeSpecial(String relPath) async {
    final d = await receivedDir();
    final dest = File(p.join(d.path, '.appclone', relPath));
    await dest.parent.create(recursive: true);
    return dest;
  }

  Future<Directory> appCloneStagingDir() async {
    final d = await receivedDir();
    final s = Directory(p.join(d.path, '.appclone', 'send'));
    await s.create(recursive: true);
    return s;
  }

  Future<List<File>> list() async {
    final d = await receivedDir();
    final items = <File>[];
    await for (final e in d.list()) {
      if (e is File && !p.basename(e.path).startsWith('.')) items.add(e);
    }
    items.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return items;
  }

  String _sanitize(String name) {
    final base = p.basename(name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return base.isEmpty ? 'file' : base;
  }
}
