import 'package:aws_os/features/sharing/data/wire/share_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareProtocol pairing URI', () {
    test('round-trips all fields', () {
      final uri = ShareProtocol.pairingUri(
        ip: '192.168.1.5',
        port: 53317,
        token: 'abc-_123',
        name: 'Pixel',
        mode: 'wifiDirect',
        ssid: 'DIRECT-xy',
        pass: r'p@ss',
      );
      final info = ShareProtocol.parsePairing(uri.toString());
      expect(info, isNotNull);
      expect(info!.ip, '192.168.1.5');
      expect(info.port, 53317);
      expect(info.token, 'abc-_123');
      expect(info.name, 'Pixel');
      expect(info.mode, 'wifiDirect');
      expect(info.ssid, 'DIRECT-xy');
      expect(info.pass, r'p@ss');
    });

    test('omits null bootstrap creds', () {
      final uri = ShareProtocol.pairingUri(
        ip: '10.0.0.2',
        port: 53317,
        token: 't',
        name: 'D',
      );
      final info = ShareProtocol.parsePairing(uri.toString())!;
      expect(info.ssid, isNull);
      expect(info.pass, isNull);
      expect(info.mode, 'lan');
    });

    test('rejects non-awsshare and incomplete URIs', () {
      expect(ShareProtocol.parsePairing('http://example.com'), isNull);
      expect(ShareProtocol.parsePairing('nonsense %%% not uri'), isNull);
      expect(
        ShareProtocol.parsePairing('awsshare://v1?ip=1.2.3.4'),
        isNull, // missing port + token
      );
    });
  });

  group('tokens & codes', () {
    test('token is url-safe and unpadded', () {
      final t = ShareProtocol.newToken();
      expect(t.length, greaterThan(16));
      expect(t.contains('='), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(t), isTrue);
    });

    test('code is 6 digits', () {
      final c = ShareProtocol.newCode();
      expect(c.length, 6);
      expect(int.tryParse(c), isNotNull);
    });
  });
}
