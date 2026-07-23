import 'package:flutter/services.dart';

/// Joins this phone to a specific Wi-Fi network (SSID+password) via Android's
/// WifiNetworkSpecifier, so scanning a Wi-Fi Direct / hotspot pairing QR can
/// connect automatically instead of sending the user to system Wi-Fi settings.
/// Android 10+ only, and best-effort — [connect] returning false means the
/// caller should fall back to the manual join flow.
class WifiConnectService {
  static const _ch = MethodChannel('com.aws.aws_os/wifi_connect');

  Future<bool> connect({required String ssid, String? password}) async {
    try {
      final ok = await _ch.invokeMethod<bool>('connect', {
        'ssid': ssid,
        'password': password,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Releases the bound network so this phone's normal internet routing
  /// (mobile data / its usual Wi-Fi) comes back after the transfer.
  Future<void> disconnect() async {
    try {
      await _ch.invokeMethod('disconnect');
    } catch (_) {}
  }
}
