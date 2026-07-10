import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Snapshot of the local network used to pick a connection strategy.
class NetworkStatus {
  const NetworkStatus({required this.onWifi, this.ip, this.gateway});
  final bool onWifi;
  final String? ip;
  final String? gateway;

  /// Same-/24 heuristic (a hint only — the authoritative test is a `/ping`).
  bool sameSubnetAs(String peerIp) {
    final a = ip;
    if (a == null) return false;
    int cut(String s) => s.lastIndexOf('.');
    if (cut(a) < 0 || cut(peerIp) < 0) return false;
    return a.substring(0, cut(a)) == peerIp.substring(0, cut(peerIp));
  }
}

/// Reads the current Wi-Fi/LAN state (the transport's `/ping` probe is the
/// authoritative reachability test, done in the controller).
class StrategyService {
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _info = NetworkInfo();

  Future<NetworkStatus> current() async {
    List<ConnectivityResult> results;
    try {
      results = await _connectivity.checkConnectivity();
    } catch (_) {
      results = const [];
    }
    final onWifi =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    String? ip;
    String? gw;
    try {
      ip = await _info.getWifiIP();
    } catch (_) {}
    try {
      gw = await _info.getWifiGatewayIP();
    } catch (_) {}
    return NetworkStatus(onWifi: onWifi, ip: ip, gateway: gw);
  }
}
