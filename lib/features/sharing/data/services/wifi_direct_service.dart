import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

/// A formed Wi-Fi Direct group — an app-created access point (no manual
/// hotspot). The receiver is the group owner at [goAddress]; the sender joins
/// [ssid]/[pass] like any Wi-Fi, then the normal HTTP transport runs over it.
class WifiDirectGroup {
  const WifiDirectGroup({
    required this.goAddress,
    required this.ssid,
    required this.pass,
  });
  final String goAddress;
  final String ssid;
  final String pass;
}

/// Thin wrapper over `flutter_p2p_connection` for the group-owner (receiver)
/// side. Best-effort and fully guarded — Wi-Fi Direct reliability is
/// OEM-dependent, and the caller falls back to Wi-Fi/LAN or guided hotspot.
class WifiDirectService {
  final FlutterP2pConnection _p2p = FlutterP2pConnection();
  bool _registered = false;

  Future<bool> _ensure() async {
    try {
      await _p2p.initialize();
      if (!_registered) {
        await _p2p.register();
        _registered = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create a group and read its credentials. Returns null if unavailable.
  Future<WifiDirectGroup?> createGroup() async {
    if (!await _ensure()) return null;
    try {
      await _p2p.createGroup();
      WifiP2PGroupInfo? info;
      for (var i = 0; i < 12 && info == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        info = await _p2p.groupInfo();
      }
      if (info == null) return null;
      return WifiDirectGroup(
        goAddress: '192.168.49.1',
        ssid: info.groupNetworkName,
        pass: info.passPhrase,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> removeGroup() async {
    try {
      await _p2p.removeGroup();
    } catch (_) {}
    try {
      if (_registered) {
        await _p2p.unregister();
        _registered = false;
      }
    } catch (_) {}
  }
}
