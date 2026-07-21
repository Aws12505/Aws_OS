import 'dart:io';
import 'dart:typed_data';

import 'package:aws_os/features/sharing/data/models/share_device.dart';
import 'package:aws_os/features/sharing/data/models/share_item.dart';
import 'package:aws_os/features/sharing/data/services/received_files_store.dart';
import 'package:aws_os/features/sharing/data/services/share_settings_store.dart';
import 'package:aws_os/features/sharing/data/services/transfer_client.dart';
import 'package:aws_os/features/sharing/data/services/transfer_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Routes the received-files store to a temp dir (no path_provider plugin).
class _TempStore extends ReceivedFilesStore {
  _TempStore(this.dir) : super(ShareSettingsStore());
  final Directory dir;
  @override
  Future<Directory> receivedDir() async {
    await dir.create(recursive: true);
    return dir;
  }
}

void main() {
  test('server + client stream a file end-to-end over loopback', () async {
    final storeDir = await Directory.systemTemp.createTemp('awsshare_recv');
    final store = _TempStore(storeDir);
    final server = TransferServer(store);
    server.onAccept = (m) async => true;
    final port = await server.start(
      deviceId: 'srv',
      deviceName: 'Server',
      port: 0,
    );
    expect(port, greaterThan(0));

    // Source file (200 KB → exercises multi-chunk streaming).
    final srcDir = await Directory.systemTemp.createTemp('awsshare_src');
    final src = File(p.join(srcDir.path, 'hello.bin'));
    final bytes = Uint8List.fromList(
      List<int>.generate(200000, (i) => i % 256),
    );
    await src.writeAsBytes(bytes);

    final client = TransferClient();
    final device = ShareDevice(
      id: 'srv',
      name: 'Server',
      host: '127.0.0.1',
      port: port,
      token: server.token,
    );
    final item = ShareItem(
      id: 'f1',
      name: 'hello.bin',
      size: bytes.length,
      path: src.path,
    );

    final ok = await client.sendBatch(
      device: device,
      senderId: 'cli',
      senderName: 'Client',
      items: [item],
    );
    expect(ok, isTrue);

    final received = File(p.join(storeDir.path, 'hello.bin'));
    expect(await received.exists(), isTrue);
    expect(await received.length(), bytes.length);
    expect(await received.readAsBytes(), bytes);

    await server.stop();
    client.dispose();
  });

  test('ping probe answers on a running server, fails when stopped', () async {
    final store = _TempStore(
      await Directory.systemTemp.createTemp('awsshare_ping'),
    );
    final server = TransferServer(store);
    final port = await server.start(
      deviceId: 's',
      deviceName: 'S',
      port: 0,
    );
    final client = TransferClient();
    expect(await client.ping('127.0.0.1', port), isTrue);
    await server.stop();
    expect(await client.ping('127.0.0.1', port), isFalse);
    client.dispose();
  });
}
