import 'dart:convert';
import 'dart:math';

/// Wire constants, endpoint paths, the `awsshare://` pairing URI, and token /
/// code generation. Pure — unit-tested in `test/share_protocol_test.dart`.
class ShareProtocol {
  ShareProtocol._();

  static const int defaultPort = 53317;
  static const int proto = 1;
  static const String serviceType = '_awsshare._tcp';
  static const String authHeader = 'Authorization';
  static const String scheme = 'awsshare';

  static String bearer(String token) => 'Bearer $token';

  // Endpoints (receiver-hosted).
  static const String ping = '/ping';
  static const String session = '/session';
  static String filePath(String sid, String fid) => '/session/$sid/files/$fid';
  static String completePath(String sid) => '/session/$sid/complete';
  static String cancelPath(String sid) => '/session/$sid';

  /// 128-bit URL-safe session token.
  static String newToken([Random? rng]) {
    final r = rng ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// 6-digit pairing code for the mDNS path (kept off the multicast wire).
  static String newCode([Random? rng]) {
    final r = rng ?? Random.secure();
    return (r.nextInt(900000) + 100000).toString();
  }

  /// Build the QR pairing URI the receiver renders.
  static Uri pairingUri({
    required String ip,
    required int port,
    required String token,
    required String name,
    String mode = 'lan',
    String? ssid,
    String? pass,
    String? go,
  }) {
    return Uri(
      scheme: scheme,
      host: 'v1',
      queryParameters: {
        'ip': ip,
        'port': '$port',
        'token': token,
        'name': name,
        'mode': mode,
        'ssid': ?ssid,
        'pass': ?pass,
        'go': ?go,
      },
    );
  }

  /// Parse a scanned pairing string; returns null if it isn't a valid
  /// `awsshare://` URI with the required fields.
  static PairingInfo? parsePairing(String raw) {
    final Uri u;
    try {
      u = Uri.parse(raw.trim());
    } catch (_) {
      return null;
    }
    if (u.scheme != scheme) return null;
    final q = u.queryParameters;
    final ip = q['ip'];
    final port = int.tryParse(q['port'] ?? '');
    final token = q['token'];
    if (ip == null || ip.isEmpty || port == null || token == null) return null;
    return PairingInfo(
      ip: ip,
      port: port,
      token: token,
      name: q['name'] ?? 'Device',
      mode: q['mode'] ?? 'lan',
      ssid: q['ssid'],
      pass: q['pass'],
      go: q['go'],
    );
  }
}

/// Decoded QR pairing payload.
class PairingInfo {
  const PairingInfo({
    required this.ip,
    required this.port,
    required this.token,
    required this.name,
    this.mode = 'lan',
    this.ssid,
    this.pass,
    this.go,
  });

  final String ip;
  final int port;
  final String token;
  final String name;
  final String mode;
  final String? ssid;
  final String? pass;
  final String? go;
}
