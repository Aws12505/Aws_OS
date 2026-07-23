import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../finance/presentation/providers.dart' show notificationServiceProvider;
import '../data/models/connection_mode.dart';
import '../data/models/share_device.dart';
import '../data/models/share_item.dart';
import '../data/models/share_session.dart';
import '../data/models/transfer_event.dart';
import '../data/models/transfer_task.dart';
import '../data/services/shizuku_service.dart';
import '../data/services/wifi_direct_service.dart';
import '../data/wire/share_manifest.dart';
import '../data/wire/share_protocol.dart';
import 'providers.dart';

/// Drives the whole share flow: starts/stops the receiver server, runs the
/// sender, and folds both sides' [TransferEvent] streams into a [ShareSession].
class ShareSessionController extends StateNotifier<ShareSession> {
  ShareSessionController(this._ref) : super(const ShareSession());
  final Ref _ref;

  StreamSubscription<TransferEvent>? _sub;
  Completer<bool>? _pendingAccept;

  /// Receiver pairing string (QR) — set while the server is running.
  String? qrData;

  /// Wi-Fi Direct group creds (SSID/pass) when receiving over Wi-Fi Direct.
  WifiDirectGroup? wdGroup;

  // ── Receive ────────────────────────────────────────────────────────────────

  Future<void> startReceiving({ConnectionMode mode = ConnectionMode.lan}) async {
    try {
      final id = await _ref.read(shareIdentityProvider.future);
      final server = _ref.read(transferServerProvider);
      server.onAccept = _handleAccept;
      server.onSpecial = _onSpecial;
      _specials.clear();
      await _sub?.cancel();
      _sub = server.events.listen(_onEvent);

      var activeMode = mode;
      var ip = '0.0.0.0';
      String? ssid;
      String? pass;

      if (mode == ConnectionMode.wifiDirect) {
        state = state.copyWith(status: 'Starting Wi-Fi Direct…');
        final g = await _ref.read(wifiDirectServiceProvider).createGroup();
        if (g != null) {
          wdGroup = g;
          ip = g.goAddress;
          ssid = g.ssid;
          pass = g.pass;
        } else {
          activeMode = ConnectionMode.lan;
          state = state.copyWith(
            error: 'Wi-Fi Direct unavailable — using Wi-Fi/LAN',
          );
        }
      }

      final port = await server.start(deviceId: id.id, deviceName: id.name);
      try {
        await _ref.read(discoveryServiceProvider).advertise(
          id: id.id,
          name: id.name,
          port: port,
          token: server.token,
        );
      } catch (_) {}

      if (activeMode == ConnectionMode.lan) {
        try {
          ip = (await _ref.read(strategyServiceProvider).current()).ip ?? ip;
        } catch (_) {}
      }
      qrData = ShareProtocol.pairingUri(
        ip: ip,
        port: port,
        token: server.token,
        name: id.name,
        mode: activeMode.wire,
        ssid: ssid,
        pass: pass,
        go: activeMode == ConnectionMode.wifiDirect ? ip : null,
      ).toString();
      state = state.copyWith(
        role: ShareRole.receiving,
        mode: activeMode,
        serverRunning: true,
        status: activeMode == ConnectionMode.wifiDirect
            ? 'Wi-Fi Direct ready — have them join & scan'
            : 'Ready — scan the code or pick this device',
        tasks: const [],
      );
      try {
        _ref.read(foregroundServiceProvider).start(
          'Ready to receive',
          'Nearby sharing is on',
        );
      } catch (_) {}
    } catch (e) {
      qrData = null;
      state = state.copyWith(
        serverRunning: false,
        error: 'Couldn\'t start receiving: $e',
      );
    }
  }

  Future<void> stopReceiving() async {
    await _ref.read(discoveryServiceProvider).stopAdvertise();
    await _ref.read(transferServerProvider).stop();
    await _ref.read(foregroundServiceProvider).stop();
    if (wdGroup != null) {
      await _ref.read(wifiDirectServiceProvider).removeGroup();
      wdGroup = null;
    }
    await _sub?.cancel();
    _sub = null;
    qrData = null;
    state = const ShareSession();
  }

  Future<bool> _handleAccept(ShareManifest m) async {
    final c = Completer<bool>();
    _pendingAccept = c;
    state = state.copyWith(
      incoming: IncomingRequest(
        senderName: m.senderName,
        fileCount: m.files.length,
        totalBytes: m.totalBytes,
      ),
    );
    try {
      _ref.read(notificationServiceProvider).showTransfer(
        title: 'Incoming files from ${m.senderName}',
        body: '${m.files.length} item(s) — open the app to accept',
      );
    } catch (_) {}
    return c.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _pendingAccept = null;
        return false;
      },
    );
  }

  void respondToIncoming(bool accept) {
    _pendingAccept?.complete(accept);
    _pendingAccept = null;
    state = state.copyWith(
      incoming: null,
      status: accept ? 'Receiving…' : 'Declined',
    );
  }

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> sendTo(ShareDevice device, List<ShareItem> items) async {
    if (items.isEmpty) return;
    final id = await _ref.read(shareIdentityProvider.future);
    final client = _ref.read(transferClientProvider);
    await _sub?.cancel();
    _sub = client.events.listen(_onEvent);
    state = const ShareSession().copyWith(
      role: ShareRole.sending,
      peer: device,
      mode: device.mode,
      status: 'Connecting…',
      tasks: const [],
    );
    final fgs = _ref.read(foregroundServiceProvider);
    await fgs.start('Sending to ${device.name}', '${items.length} item(s)');
    final ok = await client.sendBatch(
      device: device,
      senderId: id.id,
      senderName: id.name,
      items: items,
    );
    await fgs.stop();
    if (device.joinSsid != null) {
      await _ref.read(wifiConnectServiceProvider).disconnect();
    }
    state = state.copyWith(status: ok ? 'All sent' : state.status ?? 'Failed');
  }

  void cancel() {
    _ref.read(transferClientProvider).cancel();
    final tasks = [
      for (final t in state.tasks)
        t.isTerminal
            ? t
            : t.copyWith(status: TransferStatus.cancelled, speedBps: 0),
    ];
    state = state.copyWith(tasks: tasks, status: 'Cancelled');
  }

  void reset() {
    if (state.role == ShareRole.receiving) return; // keep the server up
    state = const ShareSession();
  }

  // ── Event folding ────────────────────────────────────────────────────────

  void _onEvent(TransferEvent e) {
    final dir = state.role == ShareRole.sending
        ? TransferDirection.send
        : TransferDirection.receive;
    final tasks = [...state.tasks];
    switch (e.kind) {
      case TransferEventKind.queued:
        if (tasks.every((t) => t.id != e.id)) {
          tasks.add(
            TransferTask(
              id: e.id,
              name: e.name,
              totalBytes: e.total,
              direction: dir,
              kind: e.itemKind,
              status: TransferStatus.queued,
            ),
          );
        }
        state = state.copyWith(tasks: tasks);
      case TransferEventKind.progress:
        _patch(tasks, e.id, (t) => t.copyWith(
          transferredBytes: e.transferred,
          totalBytes: e.total > 0 ? e.total : t.totalBytes,
          status: TransferStatus.transferring,
          speedBps: e.bps,
        ));
        state = state.copyWith(tasks: tasks, status: 'Transferring…');
      case TransferEventKind.done:
        _patch(tasks, e.id, (t) => t.copyWith(
          transferredBytes: t.totalBytes,
          status: TransferStatus.done,
          speedBps: 0,
        ));
        state = state.copyWith(tasks: tasks);
      case TransferEventKind.failed:
        _patch(tasks, e.id, (t) => t.copyWith(
          status: TransferStatus.failed,
          error: e.error,
        ));
        state = state.copyWith(tasks: tasks, error: e.error);
      case TransferEventKind.cancelled:
        state = state.copyWith(
          tasks: [
            for (final t in tasks)
              t.isTerminal
                  ? t
                  : t.copyWith(status: TransferStatus.cancelled, speedBps: 0),
          ],
          status: 'Cancelled',
        );
      case TransferEventKind.declined:
        state = state.copyWith(status: 'Declined by receiver');
      case TransferEventKind.sessionDone:
        state = state.copyWith(status: 'Done');
        unawaited(_finishAppClone());
    }
  }

  // ── App-clone receiving (install APKs + restore obb/data) ───────────────────

  final List<_ReceivedSpecial> _specials = [];

  Future<String?> _onSpecial(ManifestFile mf, File tmp) async {
    final store = _ref.read(receivedFilesStoreProvider);
    final rel = mf.relPath ?? mf.name;
    final String destPath;
    if (mf.itemKind == ShareItemKind.apk) {
      // APKs land in the *visible* received folder so they show up in the list
      // and can be installed manually — they're still tracked below for the
      // Shizuku group-install path when it's available.
      destPath = (await store.finalize(tmp, mf.name)).path;
    } else {
      // OBB / app-data are useless standalone (only a Shizuku restore consumes
      // them), so they stay in the hidden staging area.
      final dest = await store.placeSpecial(rel);
      try {
        await tmp.rename(dest.path);
      } on FileSystemException {
        await tmp.copy(dest.path);
        try {
          await tmp.delete();
        } catch (_) {}
      }
      destPath = dest.path;
    }
    _specials.add(
      _ReceivedSpecial(
        path: destPath,
        relPath: rel,
        packageId: mf.packageId,
        kind: mf.itemKind,
      ),
    );
    return destPath;
  }

  Future<void> _finishAppClone() async {
    if (_specials.isEmpty) return;
    final specials = [..._specials];
    _specials.clear();
    final byPkg = <String, List<_ReceivedSpecial>>{};
    for (final s in specials) {
      byPkg.putIfAbsent(s.packageId ?? 'unknown', () => []).add(s);
    }
    final shizuku = _ref.read(shizukuServiceProvider);
    final hasShizuku = await shizuku.hasPermission();
    for (final files in byPkg.values) {
      final apks = files
          .where((f) => f.kind == ShareItemKind.apk)
          .map((f) => f.path)
          .toList();
      final dataFiles = files
          .where(
            (f) =>
                f.kind == ShareItemKind.obb || f.kind == ShareItemKind.appData,
          )
          .map((f) => StagedFile(path: f.path, relPath: f.relPath))
          .toList();
      if (apks.isNotEmpty && hasShizuku) {
        // Shizuku can install silently (and handles splits as a group).
        await shizuku.installApks(apks);
      }
      // Without Shizuku, the APKs are already visible in the received folder;
      // the user installs them from the list (the old silent PackageInstaller
      // path never surfaced the confirm UI, so apps appeared to vanish).
      if (dataFiles.isNotEmpty && hasShizuku) {
        await shizuku.restore(dataFiles);
      }
    }
    final anyApk = specials.any((s) => s.kind == ShareItemKind.apk);
    state = state.copyWith(
      status: hasShizuku
          ? 'Installed / restored received apps'
          : anyApk
          ? 'Apps saved — open Received files to install them'
          : 'Received app data saved',
    );
    _ref.read(receivedFilesStoreProvider).invalidate();
  }

  void _patch(
    List<TransferTask> tasks,
    String id,
    TransferTask Function(TransferTask) f,
  ) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i >= 0) tasks[i] = f(tasks[i]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _ReceivedSpecial {
  _ReceivedSpecial({
    required this.path,
    required this.relPath,
    required this.kind,
    this.packageId,
  });
  final String path;
  final String relPath;
  final ShareItemKind kind;
  final String? packageId;
}
