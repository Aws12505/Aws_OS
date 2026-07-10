import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/share_device.dart';
import '../models/share_item.dart';
import '../models/transfer_event.dart';
import '../wire/share_manifest.dart';
import '../wire/share_protocol.dart';

/// Sender side: streams each file from disk (or in-memory bytes) to the
/// receiver via PUT, emitting [TransferEvent]s. Backpressure-correct — never
/// buffers a whole file.
class TransferClient {
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  bool _cancelled = false;

  final _events = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get events => _events.stream;

  void cancel() => _cancelled = true;

  /// Liveness/reachability probe — the strategy layer's "can I reach this peer".
  Future<bool> ping(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    try {
      final req = await _http
          .getUrl(Uri.parse('http://$host:$port${ShareProtocol.ping}'))
          .timeout(timeout);
      final resp = await req.close().timeout(timeout);
      await resp.drain<void>();
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Handshake + send every item. Returns true when the whole batch is
  /// delivered; emits per-item progress throughout.
  Future<bool> sendBatch({
    required ShareDevice device,
    required String senderId,
    required String senderName,
    required List<ShareItem> items,
  }) async {
    _cancelled = false;
    final token = device.token;
    if (token == null) {
      _events.add(TransferEvent.failed('', 'No pairing token'));
      return false;
    }
    final manifest = ShareManifest(
      token: token,
      senderId: senderId,
      senderName: senderName,
      files: items.map(ManifestFile.fromItem).toList(),
    );

    String sid;
    try {
      final resp = await _postJson(device, ShareProtocol.session, manifest.toJson());
      if (resp['accept'] != true) {
        _events.add(TransferEvent.declined());
        return false;
      }
      sid = resp['sessionId'] as String;
    } catch (e) {
      _events.add(TransferEvent.failed('', 'Handshake failed: $e'));
      return false;
    }

    for (final it in items) {
      _events.add(TransferEvent.queued(it.id, it.name, it.kind, it.size));
    }

    for (final it in items) {
      if (_cancelled) {
        await _delete(device, sid, token);
        _events.add(TransferEvent.cancelled());
        return false;
      }
      final ok = await _putItem(device, sid, token, it);
      if (!ok) {
        await _delete(device, sid, token);
        return false;
      }
    }

    try {
      await _postJson(
        device,
        ShareProtocol.completePath(sid),
        const {},
        token: token,
      );
    } catch (_) {}
    _events.add(TransferEvent.sessionDone());
    return true;
  }

  Future<bool> _putItem(
    ShareDevice device,
    String sid,
    String token,
    ShareItem it,
  ) async {
    try {
      final uri = Uri.parse('${device.baseUrl}${ShareProtocol.filePath(sid, it.id)}');
      final req = await _http.putUrl(uri);
      req.headers.set(ShareProtocol.authHeader, ShareProtocol.bearer(token));
      if (it.size > 0) req.contentLength = it.size;
      var sent = 0;
      var lastEmit = 0;
      final sw = Stopwatch()..start();
      _events.add(TransferEvent.progress(it.id, 0, it.size, 0));
      final Stream<List<int>> source = it.bytes != null
          ? Stream<List<int>>.value(it.bytes!)
          : File(it.path!).openRead();
      await for (final chunk in source) {
        if (_cancelled) {
          req.abort();
          return false;
        }
        req.add(chunk);
        sent += chunk.length;
        if (sent - lastEmit > 262144 || sent >= it.size) {
          lastEmit = sent;
          final bps = sw.elapsedMilliseconds == 0
              ? 0.0
              : sent * 1000 / sw.elapsedMilliseconds;
          _events.add(TransferEvent.progress(it.id, sent, it.size, bps));
        }
      }
      final resp = await req.close();
      await resp.drain<void>();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _events.add(TransferEvent.done(it.id));
        return true;
      }
      _events.add(TransferEvent.failed(it.id, 'HTTP ${resp.statusCode}'));
      return false;
    } catch (e) {
      if (_cancelled) return false;
      _events.add(TransferEvent.failed(it.id, e.toString()));
      return false;
    }
  }

  Future<Map<String, dynamic>> _postJson(
    ShareDevice device,
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final req = await _http.postUrl(Uri.parse('${device.baseUrl}$path'));
    req.headers.contentType = ContentType.json;
    if (token != null) {
      req.headers.set(ShareProtocol.authHeader, ShareProtocol.bearer(token));
    }
    req.write(jsonEncode(body));
    final resp = await req.close();
    final text = await utf8.decoder.bind(resp).join();
    if (text.isEmpty) return const {};
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> _delete(ShareDevice device, String sid, String token) async {
    try {
      final req = await _http.deleteUrl(
        Uri.parse('${device.baseUrl}${ShareProtocol.cancelPath(sid)}'),
      );
      req.headers.set(ShareProtocol.authHeader, ShareProtocol.bearer(token));
      final resp = await req.close();
      await resp.drain<void>();
    } catch (_) {}
  }

  void dispose() {
    _http.close(force: true);
    _events.close();
  }
}
