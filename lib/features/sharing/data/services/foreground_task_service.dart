import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Best-effort foreground service that keeps the process (and the transport
/// server / client running in the main isolate) prioritised with the screen
/// off, showing a progress notification. All calls are guarded so a device that
/// refuses the service never breaks a transfer.
class TransferForegroundService {
  bool _inited = false;

  void _ensureInit() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'transfers_fgs',
        channelName: 'Transfers',
        channelDescription: 'Keeps a nearby transfer running',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
  }

  Future<void> start(String title, String text) async {
    try {
      _ensureInit();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 4477,
          serviceTypes: const [
            ForegroundServiceTypes.connectedDevice,
            ForegroundServiceTypes.dataSync,
          ],
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
