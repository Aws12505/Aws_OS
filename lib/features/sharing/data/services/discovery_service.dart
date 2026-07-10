import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import '../models/share_device.dart';
import '../wire/share_protocol.dart';

/// mDNS advertise + browse via `nsd` (Android NsdManager — handles the
/// multicast lock internally). Emits the current peer list on the same LAN.
class DiscoveryService {
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  String _selfId = '';

  final _controller = StreamController<List<ShareDevice>>.broadcast();
  Stream<List<ShareDevice>> get devices => _controller.stream;

  Future<void> advertise({
    required String id,
    required String name,
    required int port,
    required String token,
  }) async {
    await stopAdvertise();
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: name,
          type: ShareProtocol.serviceType,
          port: port,
          txt: {
            'id': Uint8List.fromList(utf8.encode(id)),
            'tk': Uint8List.fromList(utf8.encode(token)),
            'v': Uint8List.fromList(utf8.encode('1')),
          },
        ),
      );
    } catch (_) {}
  }

  Future<void> stopAdvertise() async {
    final r = _registration;
    _registration = null;
    if (r != null) {
      try {
        await nsd.unregister(r);
      } catch (_) {}
    }
  }

  Future<void> startBrowse({required String selfId}) async {
    await stopBrowse();
    _selfId = selfId;
    try {
      final d = await nsd.startDiscovery(
        ShareProtocol.serviceType,
        autoResolve: true,
        ipLookupType: nsd.IpLookupType.v4,
      );
      _discovery = d;
      d.addListener(_emit);
      _emit();
    } catch (_) {}
  }

  void _emit() {
    final d = _discovery;
    if (d == null) return;
    final out = <ShareDevice>[];
    for (final s in d.services) {
      final port = s.port;
      if (port == null) continue;
      final addrs = s.addresses;
      final ip = (addrs != null && addrs.isNotEmpty) ? addrs.first.address : s.host;
      if (ip == null) continue;
      final idBytes = s.txt?['id'];
      final id = idBytes != null ? utf8.decode(idBytes) : (s.name ?? ip);
      if (id == _selfId) continue;
      final tkBytes = s.txt?['tk'];
      final token = tkBytes != null ? utf8.decode(tkBytes) : null;
      out.add(
        ShareDevice(
          id: id,
          name: s.name ?? 'Device',
          host: ip,
          port: port,
          token: token,
        ),
      );
    }
    _controller.add(out);
  }

  Future<void> stopBrowse() async {
    final d = _discovery;
    _discovery = null;
    if (d != null) {
      d.removeListener(_emit);
      try {
        await nsd.stopDiscovery(d);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stopAdvertise();
    await stopBrowse();
    await _controller.close();
  }
}
