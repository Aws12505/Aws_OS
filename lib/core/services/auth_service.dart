import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Optional app lock with PIN and/or biometric. Both are independently
/// toggleable in settings — the user can have one, the other, both, or
/// neither.
///
/// PIN is stored as a salted PBKDF2-SHA256 hash in `flutter_secure_storage`.
/// Biometric uses `local_auth` and only acts as an alternative unlock — never
/// as the *only* secret (the OS could fail to enrol biometrics).
class AuthService {
  AuthService();

  static const _kPinHash = 'auth.pinHash';
  static const _kPinSalt = 'auth.pinSalt';
  static const _kBiometric = 'auth.biometric';

  final _storage = const FlutterSecureStorage();
  final _local = LocalAuthentication();

  Future<bool> get isPinSet async =>
      (await _storage.read(key: _kPinHash)) != null;

  Future<bool> get isBiometricEnabled async =>
      (await _storage.read(key: _kBiometric)) == 'true';

  Future<bool> get isLockEnabled async {
    final pinSet = await isPinSet;
    final bio = await isBiometricEnabled;
    return pinSet || bio;
  }

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    final hash = await _pbkdf2(pin, salt);
    await _storage.write(key: _kPinSalt, value: base64Encode(salt));
    await _storage.write(key: _kPinHash, value: base64Encode(hash));
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
  }

  Future<void> setBiometric(bool enabled) async {
    await _storage.write(key: _kBiometric, value: enabled ? 'true' : 'false');
  }

  Future<bool> verifyPin(String pin) async {
    final saltB64 = await _storage.read(key: _kPinSalt);
    final hashB64 = await _storage.read(key: _kPinHash);
    if (saltB64 == null || hashB64 == null) return false;
    final salt = base64Decode(saltB64);
    final computed = await _pbkdf2(pin, salt);
    return _ctEq(computed, base64Decode(hashB64));
  }

  Future<bool> authenticateBiometric() async {
    try {
      final available = await _local.canCheckBiometrics;
      if (!available) return false;
      return _local.authenticate(
        localizedReason: 'Unlock Aws OS',
      );
    } catch (_) {
      return false;
    }
  }

  // -- internals ----------------------------------------------------------

  Uint8List _randomBytes(int len) {
    final r = Random.secure();
    final out = Uint8List(len);
    for (var i = 0; i < len; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }

  Future<Uint8List> _pbkdf2(String pin, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 30000,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(pin));
    final derived = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }

  bool _ctEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
