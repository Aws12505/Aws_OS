/// The local links a transfer can ride on, fastest-first. All three end with
/// both devices on one IP subnet; the same HTTP transport rides on top.
enum ConnectionMode { lan, wifiDirect, hotspot }

extension ConnectionModeX on ConnectionMode {
  String get label => switch (this) {
    ConnectionMode.lan => 'Wi-Fi / LAN',
    ConnectionMode.wifiDirect => 'Wi-Fi Direct',
    ConnectionMode.hotspot => 'Hotspot',
  };

  String get wire => name;

  static ConnectionMode fromWire(String? s) => switch (s) {
    'wifiDirect' => ConnectionMode.wifiDirect,
    'hotspot' => ConnectionMode.hotspot,
    _ => ConnectionMode.lan,
  };
}
