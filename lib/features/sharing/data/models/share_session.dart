import 'connection_mode.dart';
import 'share_device.dart';
import 'transfer_task.dart';

enum ShareRole { idle, sending, receiving }

/// A pending incoming batch awaiting the user's Accept/Decline.
class IncomingRequest {
  const IncomingRequest({
    required this.senderName,
    required this.fileCount,
    required this.totalBytes,
  });
  final String senderName;
  final int fileCount;
  final int totalBytes;
}

/// Aggregate UI state for an in-progress share, folded from the per-file
/// [TransferTask] streams by the session controller.
class ShareSession {
  const ShareSession({
    this.role = ShareRole.idle,
    this.mode,
    this.peer,
    this.tasks = const [],
    this.serverRunning = false,
    this.incoming,
    this.status,
    this.error,
  });

  final ShareRole role;
  final ConnectionMode? mode;
  final ShareDevice? peer;
  final List<TransferTask> tasks;
  final bool serverRunning;
  final IncomingRequest? incoming;
  final String? status;
  final String? error;

  int get totalBytes => tasks.fold(0, (s, t) => s + t.totalBytes);
  int get transferredBytes => tasks.fold(0, (s, t) => s + t.transferredBytes);
  double get progress => totalBytes <= 0 ? 0 : transferredBytes / totalBytes;
  bool get active => tasks.any((t) => !t.isTerminal);
  bool get done => tasks.isNotEmpty && tasks.every((t) => t.isTerminal);
  double get speedBps => tasks
      .where((t) => t.status == TransferStatus.transferring)
      .fold(0.0, (s, t) => s + t.speedBps);

  ShareSession copyWith({
    ShareRole? role,
    ConnectionMode? mode,
    ShareDevice? peer,
    List<TransferTask>? tasks,
    bool? serverRunning,
    Object? incoming = _sentinel,
    String? status,
    String? error,
  }) => ShareSession(
    role: role ?? this.role,
    mode: mode ?? this.mode,
    peer: peer ?? this.peer,
    tasks: tasks ?? this.tasks,
    serverRunning: serverRunning ?? this.serverRunning,
    incoming: incoming == _sentinel ? this.incoming : incoming as IncomingRequest?,
    status: status,
    error: error,
  );
}

const _sentinel = Object();
