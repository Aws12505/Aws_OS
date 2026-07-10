import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Decides where received bytes land (temp while streaming, then a de-duplicated
/// final name) and lists finished files. App-private external dir → no storage
/// permission needed; exposed to the user via the share sheet.
class ReceivedFilesStore {
  Directory? _dir;

  Future<Directory> receivedDir() async {
    if (_dir != null) return _dir!;
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'AwsShare', 'received'));
    await d.create(recursive: true);
    _dir = d;
    return d;
  }

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
      if (e is File) items.add(e);
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
