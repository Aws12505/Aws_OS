import 'dart:typed_data';

/// What a queued item is — drives its icon and the receiver's routing.
enum ShareItemKind { file, photo, video, audio, apk, obb, appData, backup }

extension ShareItemKindX on ShareItemKind {
  static ShareItemKind fromWire(String? s) => ShareItemKind.values.firstWhere(
    (k) => k.name == s,
    orElse: () => ShareItemKind.file,
  );
}

/// One thing queued to send. Exactly one of [path] (streamed from disk) or
/// [bytes] (in-memory, e.g. the app backup) is set. [relPath] tells the
/// receiver where a special item (apk/obb/appData) lands on the far side.
class ShareItem {
  const ShareItem({
    required this.id,
    required this.name,
    required this.size,
    this.mime = 'application/octet-stream',
    this.kind = ShareItemKind.file,
    this.path,
    this.bytes,
    this.relPath,
    this.packageId,
  });

  final String id;
  final String name;
  final int size;
  final String mime;
  final ShareItemKind kind;
  final String? path;
  final Uint8List? bytes;
  final String? relPath;
  final String? packageId;
}
