import '../models/share_item.dart';

/// One file in the batch manifest (JSON round-trippable).
class ManifestFile {
  const ManifestFile({
    required this.id,
    required this.name,
    required this.size,
    required this.mime,
    required this.kind,
    this.relPath,
    this.sha256,
    this.packageId,
  });

  final String id;
  final String name;
  final int size;
  final String mime;
  final String kind; // ShareItemKind.name
  final String? relPath;
  final String? sha256;
  final String? packageId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'mime': mime,
    'kind': kind,
    if (relPath != null) 'relPath': relPath,
    if (sha256 != null) 'sha256': sha256,
    if (packageId != null) 'packageId': packageId,
  };

  factory ManifestFile.fromJson(Map<String, dynamic> j) => ManifestFile(
    id: j['id'] as String,
    name: j['name'] as String,
    size: (j['size'] as num).toInt(),
    mime: (j['mime'] as String?) ?? 'application/octet-stream',
    kind: (j['kind'] as String?) ?? 'file',
    relPath: j['relPath'] as String?,
    sha256: j['sha256'] as String?,
    packageId: j['packageId'] as String?,
  );

  factory ManifestFile.fromItem(ShareItem it) => ManifestFile(
    id: it.id,
    name: it.name,
    size: it.size,
    mime: it.mime,
    kind: it.kind.name,
    relPath: it.relPath,
    packageId: it.packageId,
  );

  ShareItemKind get itemKind => ShareItemKindX.fromWire(kind);
}

/// The batch handshake body (`POST /session`).
class ShareManifest {
  const ShareManifest({
    required this.token,
    required this.senderId,
    required this.senderName,
    required this.files,
  });

  final String token;
  final String senderId;
  final String senderName;
  final List<ManifestFile> files;

  int get totalBytes => files.fold(0, (s, f) => s + f.size);

  Map<String, dynamic> toJson() => {
    'token': token,
    'sender': {'id': senderId, 'name': senderName},
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory ShareManifest.fromJson(Map<String, dynamic> j) {
    final s = (j['sender'] as Map).cast<String, dynamic>();
    final files = (j['files'] as List)
        .map((m) => ManifestFile.fromJson((m as Map).cast<String, dynamic>()))
        .toList();
    return ShareManifest(
      token: j['token'] as String,
      senderId: (s['id'] as String?) ?? '',
      senderName: (s['name'] as String?) ?? 'Device',
      files: files,
    );
  }
}
