import 'share_item.dart';

enum TransferDirection { send, receive }

enum TransferStatus {
  queued,
  handshaking,
  transferring,
  verifying,
  done,
  failed,
  cancelled,
}

/// Live state for one file in a transfer. Progress/speed are derived from the
/// local stream counter (sender counts its upload, receiver its write).
class TransferTask {
  const TransferTask({
    required this.id,
    required this.name,
    required this.totalBytes,
    required this.direction,
    this.kind = ShareItemKind.file,
    this.transferredBytes = 0,
    this.status = TransferStatus.queued,
    this.speedBps = 0,
    this.error,
  });

  final String id;
  final String name;
  final int totalBytes;
  final TransferDirection direction;
  final ShareItemKind kind;
  final int transferredBytes;
  final TransferStatus status;
  final double speedBps;
  final String? error;

  double get progress =>
      totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0.0, 1.0);

  bool get isTerminal =>
      status == TransferStatus.done ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  TransferTask copyWith({
    int? totalBytes,
    int? transferredBytes,
    TransferStatus? status,
    double? speedBps,
    String? error,
  }) => TransferTask(
    id: id,
    name: name,
    totalBytes: totalBytes ?? this.totalBytes,
    direction: direction,
    kind: kind,
    transferredBytes: transferredBytes ?? this.transferredBytes,
    status: status ?? this.status,
    speedBps: speedBps ?? this.speedBps,
    error: error ?? this.error,
  );
}
