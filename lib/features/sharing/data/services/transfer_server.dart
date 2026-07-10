import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/transfer_event.dart';
import '../wire/share_manifest.dart';
import '../wire/share_protocol.dart';
import 'received_files_store.dart';

/// Receiver-hosted HTTP server. Streams each PUT body straight to disk (flat
/// memory on multi-GB files), verifies size, and emits [TransferEvent]s. The
/// same server binds whether the subnet came from LAN, hotspot or Wi-Fi Direct.
class TransferServer {
  TransferServer(this._store);
  final ReceivedFilesStore _store;

  HttpServer? _server;
  String _token = '';
  String _deviceName = 'Device';
  String _deviceId = '';

  final _events = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get events => _events.stream;

  /// Set by the controller to show an Accept prompt for an incoming batch.
  Future<bool> Function(ShareManifest manifest)? onAccept;

  /// Stage-3 hook: when set, special items (apk/obb/appData) are handed to this
  /// instead of the received-files dir (install / Shizuku restore). Returns the
  /// stored/installed path or null to fall back to the received dir.
  Future<String?> Function(ManifestFile file, File tempFile)? onSpecial;

  final _sessions = <String, _RecvSession>{};

  bool get running => _server != null;
  int get port => _server?.port ?? 0;
  String get token => _token;

  Future<int> start({
    required String deviceId,
    required String deviceName,
    int port = ShareProtocol.defaultPort,
  }) async {
    if (_server != null) return _server!.port;
    _deviceId = deviceId;
    _deviceName = deviceName;
    _token = ShareProtocol.newToken();
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } catch (_) {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    server.listen(_handle, onError: (_) {});
    return server.port;
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
    for (final sess in _sessions.values) {
      await sess.cleanup();
    }
    _sessions.clear();
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final segs = req.uri.pathSegments;
      if (req.method == 'GET' && req.uri.path == ShareProtocol.ping) {
        return _ping(req);
      }
      if (req.method == 'POST' && req.uri.path == ShareProtocol.session) {
        return await _session(req);
      }
      if (segs.isNotEmpty && segs[0] == 'session' && segs.length >= 2) {
        final sid = segs[1];
        if (req.method == 'PUT' && segs.length == 4 && segs[2] == 'files') {
          return await _putFile(req, sid, segs[3]);
        }
        if (req.method == 'POST' && segs.length == 3 && segs[2] == 'complete') {
          return await _complete(req, sid);
        }
        if (req.method == 'DELETE' && segs.length == 2) {
          return await _cancel(req, sid);
        }
      }
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  bool _auth(HttpRequest req) =>
      req.headers.value(ShareProtocol.authHeader) ==
      ShareProtocol.bearer(_token);

  void _ping(HttpRequest req) => _json(req, {
    'app': 'aws_os',
    'proto': ShareProtocol.proto,
    'name': _deviceName,
    'id': _deviceId,
  });

  Future<void> _session(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    late final ShareManifest manifest;
    try {
      manifest = ShareManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    if (manifest.token != _token) {
      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }
    final accept = onAccept == null ? true : await onAccept!(manifest);
    if (!accept) {
      _json(req, {'accept': false});
      return;
    }
    final sid = ShareProtocol.newToken();
    _sessions[sid] = _RecvSession(manifest);
    for (final f in manifest.files) {
      _events.add(TransferEvent.queued(f.id, f.name, f.itemKind, f.size));
    }
    _json(req, {'sessionId': sid, 'accept': true});
  }

  Future<void> _putFile(HttpRequest req, String sid, String fid) async {
    if (!_auth(req)) {
      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }
    final sess = _sessions[sid];
    final mf = sess?.file(fid);
    if (sess == null || mf == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final tmp = await _store.tempFor(fid);
    sess.temps.add(tmp);
    final sink = tmp.openWrite();
    var received = 0;
    var lastEmit = 0;
    final sw = Stopwatch()..start();
    try {
      _events.add(TransferEvent.progress(fid, 0, mf.size, 0));
      await for (final chunk in req) {
        sink.add(chunk);
        received += chunk.length;
        if (received - lastEmit > 262144 || received == mf.size) {
          lastEmit = received;
          final bps = sw.elapsedMilliseconds == 0
              ? 0.0
              : received * 1000 / sw.elapsedMilliseconds;
          _events.add(TransferEvent.progress(fid, received, mf.size, bps));
        }
      }
      await sink.close();
      if (mf.size > 0 && received != mf.size) {
        await tmp.delete().catchError((_) => tmp);
        _events.add(TransferEvent.failed(fid, 'Size mismatch'));
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }
      String finalPath;
      final special = onSpecial;
      if (special != null && mf.itemKind.name != 'file' &&
          mf.itemKind.name != 'photo' && mf.itemKind.name != 'video' &&
          mf.itemKind.name != 'audio') {
        finalPath = await special(mf, tmp) ?? (await _store.finalize(tmp, mf.name)).path;
      } else {
        finalPath = (await _store.finalize(tmp, mf.name)).path;
      }
      sess.donePaths[fid] = finalPath;
      _events.add(TransferEvent.done(fid, path: finalPath));
      _json(req, {'received': received});
    } catch (e) {
      await sink.close().catchError((_) {});
      await tmp.delete().catchError((_) => tmp);
      _events.add(TransferEvent.failed(fid, e.toString()));
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _complete(HttpRequest req, String sid) async {
    if (!_auth(req)) {
      req.response.statusCode = HttpStatus.unauthorized;
      await req.response.close();
      return;
    }
    final sess = _sessions.remove(sid);
    _events.add(TransferEvent.sessionDone());
    _json(req, {'ok': true, 'files': sess?.donePaths.length ?? 0});
  }

  Future<void> _cancel(HttpRequest req, String sid) async {
    final sess = _sessions.remove(sid);
    await sess?.cleanup();
    _events.add(TransferEvent.cancelled());
    _json(req, {'ok': true});
  }

  void _json(HttpRequest req, Map<String, dynamic> body) {
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    req.response.close();
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}

class _RecvSession {
  _RecvSession(this.manifest);
  final ShareManifest manifest;
  final Map<String, String> donePaths = {};
  final List<File> temps = [];

  ManifestFile? file(String fid) {
    for (final f in manifest.files) {
      if (f.id == fid) return f;
    }
    return null;
  }

  Future<void> cleanup() async {
    for (final t in temps) {
      try {
        if (await t.exists()) await t.delete();
      } catch (_) {}
    }
  }
}
