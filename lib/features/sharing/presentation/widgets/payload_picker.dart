import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/backup_provider.dart';
import '../../data/models/share_item.dart';

const _uuid = Uuid();

/// Pick arbitrary files (or media) to send — streamed from disk by path.
Future<List<ShareItem>> pickFilesToShare({FileType type = FileType.any}) async {
  final res = await FilePicker.pickFiles(
    allowMultiple: true,
    type: type,
    withData: false,
  );
  if (res == null) return const [];
  final items = <ShareItem>[];
  for (final f in res.files) {
    final path = f.path;
    if (path == null) continue;
    items.add(
      ShareItem(
        id: _uuid.v4(),
        name: f.name,
        size: f.size,
        mime: _guessMime(f.name),
        kind: _kindFor(f.name),
        path: path,
      ),
    );
  }
  return items;
}

/// The app's own encrypted/JSON backup as an in-memory [ShareItem].
Future<ShareItem> backupToShare(WidgetRef ref, {String? password}) async {
  final bytes = await ref
      .read(backupServiceProvider)
      .exportBytes(password: password);
  final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
  final ext = password == null ? 'json' : 'awsbak';
  return ShareItem(
    id: _uuid.v4(),
    name: 'aws_os_backup_$ts.$ext',
    size: bytes.length,
    mime: 'application/octet-stream',
    kind: ShareItemKind.backup,
    bytes: bytes,
  );
}

String _guessMime(String name) {
  final ext = name.contains('.') ? name.toLowerCase().split('.').last : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'mp4' => 'video/mp4',
    'mkv' => 'video/x-matroska',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'pdf' => 'application/pdf',
    'apk' => 'application/vnd.android.package-archive',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

ShareItemKind _kindFor(String name) {
  final m = _guessMime(name);
  if (m.startsWith('image/')) return ShareItemKind.photo;
  if (m.startsWith('video/')) return ShareItemKind.video;
  if (m.startsWith('audio/')) return ShareItemKind.audio;
  if (name.toLowerCase().endsWith('.apk')) return ShareItemKind.apk;
  return ShareItemKind.file;
}
