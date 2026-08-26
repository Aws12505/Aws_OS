import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';

/// Order matters for import: parents (tables referenced by FK) must come
/// before their children. Same list reversed is used for cascade-friendly
/// deletes during a "replace" import.
const _orderedTables = <String>[
  'app_settings',
  'currencies',
  'accounts',
  'categories',
  'category_types',
  'workspaces',
  'task_recurrences',
  'tasks',
  'task_history',
  'measurement_types',
  'measurement_entries',
  'measurement_values',
  'programs',
  'program_days',
  'superset_groups',
  'day_exercises',
  'exercise_set_prescriptions',
  'day_sessions',
  'recurrences',
  'transactions',
  'transaction_legs',
  'exchange_rates',
  'scheduled_occurrences',
  'budgets',
  'notes',
  'tags',
  'note_tags',
  'debrief_entries',
];

class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  static const int _formatVersion = 1;

  /// Build a JSON document representing every domain row in the database.
  /// Numbers stay raw (SQLite integer/real); DateTimes are stored as the
  /// epoch-millis ints Drift writes — round-trips cleanly.
  Future<String> exportToJson() async {
    final tablesOut = <String, dynamic>{};
    for (final t in _orderedTables) {
      final rows = await db.customSelect('SELECT * FROM $t').get();
      tablesOut[t] = rows.map((r) => r.data).toList();
    }
    final doc = {
      'app': 'aws_os',
      'version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tablesOut,
    };
    return jsonEncode(doc);
  }

  /// Write the backup payload to a file under the app's documents dir and
  /// return its absolute path. Optionally encrypts with AES-GCM-256 + a
  /// PBKDF2(SHA256, 100k) key derived from [password].
  Future<File> writeBackupFile({String? password}) async {
    final docs = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final ext = password == null ? 'json' : 'awsbak';
    final file = File(p.join(docs.path, 'aws_os_backup_$timestamp.$ext'));
    final json = await exportToJson();
    if (password == null) {
      await file.writeAsString(json);
    } else {
      final encrypted = await _encrypt(json, password);
      await file.writeAsBytes(encrypted);
    }
    return file;
  }

  /// In-memory backup bytes for streaming (e.g. local sharing) without a temp
  /// file. Plain UTF-8 JSON when [password] is null, else the AES-GCM `.awsbak`
  /// byte layout. Mirrors [writeBackupFile].
  Future<Uint8List> exportBytes({String? password}) async {
    final json = await exportToJson();
    if (password == null) return Uint8List.fromList(utf8.encode(json));
    return _encrypt(json, password);
  }

  /// Parse a backup file (JSON or encrypted .awsbak) and apply it.
  /// [replace] = true wipes existing rows in-table before insertion (full
  /// restore). [replace] = false performs INSERT OR REPLACE on each row so
  /// the newer `updated_at` wins where there's a UUID collision.
  Future<void> importFromFile(File file,
      {String? password, bool replace = true}) async {
    final bytes = await file.readAsBytes();
    String jsonText;
    if (password != null) {
      jsonText = await _decrypt(bytes, password);
    } else {
      try {
        jsonText = utf8.decode(bytes);
      } catch (_) {
        throw const FormatException(
            'Could not read file as text. Did you forget the password?');
      }
    }
    await importFromJson(jsonText, replace: replace);
  }

  Future<void> importFromJson(String jsonText, {bool replace = true}) async {
    final doc = jsonDecode(jsonText) as Map<String, dynamic>;
    if (doc['app'] != 'aws_os') {
      throw const FormatException('Not an Aws OS backup file.');
    }
    final tables = (doc['tables'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    await db.transaction(() async {
      // Temporarily relax FK enforcement during bulk swap.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      try {
        if (replace) {
          for (final t in _orderedTables.reversed) {
            await db.customStatement('DELETE FROM $t');
          }
        }
        for (final t in _orderedTables) {
          final rows = (tables[t] as List?)?.cast<dynamic>() ?? const [];
          for (final row in rows) {
            final map = (row as Map).cast<String, dynamic>();
            final cols = map.keys.toList();
            final placeholders = List.filled(cols.length, '?').join(', ');
            final values = cols.map((c) => map[c]).toList();
            await db.customStatement(
              'INSERT OR REPLACE INTO $t (${cols.join(', ')}) '
              'VALUES ($placeholders)',
              values,
            );
          }
        }
      } finally {
        await db.customStatement('PRAGMA foreign_keys = ON');
      }
    });
  }

  // -- AES-GCM-256 with PBKDF2 from password ------------------------------

  Future<Uint8List> _encrypt(String plaintext, String password) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt);
    final algo = AesGcm.with256bits();
    final nonce = algo.newNonce();
    final secretBox = await algo.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    // Layout: magic(4) | salt(16) | nonce(12) | mac(16) | ciphertext
    final magic = utf8.encode('AWSB');
    return Uint8List.fromList([
      ...magic,
      ...salt,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);
  }

  Future<String> _decrypt(Uint8List bytes, String password) async {
    if (bytes.length < 4 + 16 + 12 + 16) {
      throw const FormatException('Backup file is too small / corrupt.');
    }
    final magic = utf8.decode(bytes.sublist(0, 4));
    if (magic != 'AWSB') {
      throw const FormatException('Not an Aws OS encrypted backup.');
    }
    final salt = bytes.sublist(4, 20);
    final nonce = bytes.sublist(20, 32);
    final mac = bytes.sublist(32, 48);
    final cipherText = bytes.sublist(48);
    final key = await _deriveKey(password, salt);
    final algo = AesGcm.with256bits();
    try {
      final clear = await algo.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(clear);
    } catch (_) {
      throw const FormatException(
          'Could not decrypt that. The password is wrong, or the file is corrupt.');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }
}
