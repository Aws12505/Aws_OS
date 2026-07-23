import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../data/models/share_device.dart';
import '../data/models/share_session.dart';
import '../data/services/discovery_service.dart';
import '../data/services/foreground_task_service.dart';
import '../data/services/hotspot_guide_service.dart';
import '../data/services/installed_apps_service.dart';
import '../data/services/received_files_store.dart';
import '../data/services/share_settings_store.dart';
import '../data/services/shizuku_service.dart';
import '../data/services/strategy_service.dart';
import '../data/services/transfer_client.dart';
import '../data/services/wifi_connect_service.dart';
import '../data/services/wifi_direct_service.dart';
import '../data/services/transfer_server.dart';
import 'share_session_controller.dart';

/// This device's stable id + friendly name (persisted in secure storage).
class ShareIdentity {
  const ShareIdentity(this.id, this.name);
  final String id;
  final String name;
}

final shareSettingsStoreProvider = Provider((ref) => ShareSettingsStore());

final receivedFilesStoreProvider = Provider(
  (ref) => ReceivedFilesStore(ref.watch(shareSettingsStoreProvider)),
);

/// The directory received files currently land in — for display. Invalidate
/// this after changing the save location to refresh the UI.
final saveDirectoryProvider = FutureProvider<String>(
  (ref) => ref.watch(receivedFilesStoreProvider).currentSaveDirPath(),
);

/// The files already received into the save folder. Invalidate to refresh after
/// a transfer completes or the save location changes.
final receivedFilesListProvider = FutureProvider<List<File>>(
  (ref) => ref.watch(receivedFilesStoreProvider).list(),
);

final transferServerProvider = Provider<TransferServer>((ref) {
  final s = TransferServer(ref.watch(receivedFilesStoreProvider));
  ref.onDispose(s.dispose);
  return s;
});

final transferClientProvider = Provider<TransferClient>((ref) {
  final c = TransferClient();
  ref.onDispose(c.dispose);
  return c;
});

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final d = DiscoveryService();
  ref.onDispose(d.dispose);
  return d;
});

final strategyServiceProvider = Provider((ref) => StrategyService());
final hotspotGuideProvider = Provider((ref) => HotspotGuideService());
final foregroundServiceProvider =
    Provider((ref) => TransferForegroundService());
final wifiDirectServiceProvider = Provider((ref) => WifiDirectService());
final wifiConnectServiceProvider = Provider((ref) => WifiConnectService());
final installedAppsServiceProvider = Provider((ref) => InstalledAppsService());
final shizukuServiceProvider = Provider((ref) => ShizukuService());

final discoveredDevicesProvider = StreamProvider<List<ShareDevice>>((ref) {
  return ref.watch(discoveryServiceProvider).devices;
});

final shareIdentityProvider = FutureProvider<ShareIdentity>((ref) async {
  const storage = FlutterSecureStorage();
  var id = await storage.read(key: 'share.deviceId');
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await storage.write(key: 'share.deviceId', value: id);
  }
  var name = await storage.read(key: 'share.deviceName');
  if (name == null || name.isEmpty) {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      name = info.model;
    } catch (_) {
      name = 'My device';
    }
    if (name.isEmpty) name = 'My device';
    await storage.write(key: 'share.deviceName', value: name);
  }
  return ShareIdentity(id, name);
});

final shareSessionProvider =
    StateNotifierProvider<ShareSessionController, ShareSession>((ref) {
      return ShareSessionController(ref);
    });
