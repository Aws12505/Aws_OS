import 'share_item.dart';

enum TransferEventKind {
  queued,
  progress,
  done,
  failed,
  cancelled,
  declined,
  sessionDone,
}

/// A single progress signal emitted by both [TransferServer] and
/// [TransferClient]; the session controller folds these into `TransferTask`s.
class TransferEvent {
  const TransferEvent({
    required this.kind,
    this.id = '',
    this.name = '',
    this.itemKind = ShareItemKind.file,
    this.total = 0,
    this.transferred = 0,
    this.bps = 0,
    this.path,
    this.error,
  });

  final TransferEventKind kind;
  final String id;
  final String name;
  final ShareItemKind itemKind;
  final int total;
  final int transferred;
  final double bps;
  final String? path;
  final String? error;

  factory TransferEvent.queued(
    String id,
    String name,
    ShareItemKind kind,
    int total,
  ) => TransferEvent(
    kind: TransferEventKind.queued,
    id: id,
    name: name,
    itemKind: kind,
    total: total,
  );

  factory TransferEvent.progress(
    String id,
    int transferred,
    int total,
    double bps,
  ) => TransferEvent(
    kind: TransferEventKind.progress,
    id: id,
    transferred: transferred,
    total: total,
    bps: bps,
  );

  factory TransferEvent.done(String id, {String? path}) =>
      TransferEvent(kind: TransferEventKind.done, id: id, path: path);

  factory TransferEvent.failed(String id, String error) =>
      TransferEvent(kind: TransferEventKind.failed, id: id, error: error);

  factory TransferEvent.cancelled() =>
      const TransferEvent(kind: TransferEventKind.cancelled);

  factory TransferEvent.declined() =>
      const TransferEvent(kind: TransferEventKind.declined);

  factory TransferEvent.sessionDone() =>
      const TransferEvent(kind: TransferEventKind.sessionDone);
}
