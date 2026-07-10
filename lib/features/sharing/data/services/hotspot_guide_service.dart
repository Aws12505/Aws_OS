import 'package:flutter/services.dart';

/// Guided hotspot: modern Android blocks apps from silently enabling a full
/// hotspot, so we deep-link the user to the system tethering/Wi-Fi settings and
/// hand out a standard Wi-Fi-join QR the peer can scan.
class HotspotGuideService {
  static const MethodChannel _ch = MethodChannel('com.aws.aws_os/system');

  Future<void> openHotspotSettings() async {
    try {
      await _ch.invokeMethod('openHotspotSettings');
    } catch (_) {}
  }

  Future<void> openWifiSettings() async {
    try {
      await _ch.invokeMethod('openWifiSettings');
    } catch (_) {}
  }

  /// `WIFI:` payload most phone cameras understand → one-scan hotspot join.
  String wifiJoinQr(String ssid, String password) =>
      'WIFI:T:WPA;S:$ssid;P:$password;;';
}
