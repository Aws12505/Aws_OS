import 'connection_mode.dart';

/// A discovered (mDNS) or scanned (QR) peer we can transfer with.
class ShareDevice {
  const ShareDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.mode = ConnectionMode.lan,
    this.token,
    this.lastSeen,
    this.joinSsid,
    this.joinPass,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final ConnectionMode mode;

  /// Pairing token — carried directly by a QR pairing, or filled in after the
  /// 6-digit code exchange for an mDNS-discovered device.
  final String? token;
  final DateTime? lastSeen;

  /// For Wi-Fi Direct / hotspot targets: the network the sender must join first.
  final String? joinSsid;
  final String? joinPass;

  String get baseUrl => 'http://$host:$port';

  ShareDevice copyWith({String? token, DateTime? lastSeen, ConnectionMode? mode}) =>
      ShareDevice(
        id: id,
        name: name,
        host: host,
        port: port,
        mode: mode ?? this.mode,
        token: token ?? this.token,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  @override
  bool operator ==(Object other) =>
      other is ShareDevice &&
      other.id == id &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(id, host, port);
}
