import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/settings_service.dart';
import 'ai_config.dart';

/// Thrown for every AI failure (unconfigured, network, non-200, malformed) so
/// callers can degrade gracefully to offline output.
class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Calls a user-configured AI endpoint.
///
/// Supports Google Gemini's native API (detected by hostname) and any
/// OpenAI-compatible `/chat/completions` endpoint. Entirely optional and off
/// by default. The non-secret config lives in the `app_settings` table; the
/// API key lives in secure storage.
class AiService {
  AiService(this._settings);

  final SettingsService _settings;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kEnabled = 'ai.enabled';
  static const _kBaseUrl = 'ai.baseUrl';
  static const _kModel = 'ai.model';
  static const _kApiKey = 'ai.apiKey';

  Future<AiConfig> loadConfig() async {
    return AiConfig(
      enabled: await _settings.getBool(_kEnabled) ?? false,
      baseUrl: await _settings.getRaw(_kBaseUrl) ?? '',
      model: await _settings.getRaw(_kModel) ?? '',
      apiKey: await _storage.read(key: _kApiKey) ?? '',
    );
  }

  Future<void> saveConfig({
    required bool enabled,
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    await _settings.setBool(_kEnabled, enabled);
    await _settings.setRaw(_kBaseUrl, baseUrl.trim());
    await _settings.setRaw(_kModel, model.trim());
    if (apiKey != null) {
      if (apiKey.isEmpty) {
        await _storage.delete(key: _kApiKey);
      } else {
        await _storage.write(key: _kApiKey, value: apiKey);
      }
    }
  }

  /// Single entry point. Throws [AiException] on any failure.
  Future<String> complete({
    required String system,
    required String prompt,
    double temperature = 0.7,
  }) async {
    final cfg = await loadConfig();
    return completeWith(
      cfg,
      system: system,
      prompt: prompt,
      temperature: temperature,
    );
  }

  /// Like [complete] but against an explicit config — used by the settings
  /// "Test connection" action before the config is saved.
  Future<String> completeWith(
    AiConfig cfg, {
    required String system,
    required String prompt,
    double temperature = 0.7,
  }) async {
    if (!cfg.isConfigured) throw AiException('AI is not configured');

    final isGemini = cfg.baseUrl
        .contains('generativelanguage.googleapis.com');

    return isGemini
        ? _completeGemini(cfg,
            system: system, prompt: prompt, temperature: temperature)
        : _completeOpenAi(cfg,
            system: system, prompt: prompt, temperature: temperature);
  }

  Future<String> _completeGemini(
    AiConfig cfg, {
    required String system,
    required String prompt,
    required double temperature,
  }) async {
    final model = cfg.model.trim();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (cfg.apiKey.isNotEmpty) 'x-goog-api-key': cfg.apiKey,
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': system},
                ],
              },
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {'temperature': temperature},
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiException('Could not reach the AI endpoint: $e');
    }

    if (res.statusCode != 200) {
      throw AiException('AI error ${res.statusCode}: ${_short(res.body)}');
    }

    try {
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final candidates = body['candidates'];
      String? content;
      if (candidates is List && candidates.isNotEmpty) {
        final parts = candidates.first?['content']?['parts'];
        if (parts is List && parts.isNotEmpty) {
          content = parts.first?['text'] as String?;
        }
      }
      if (content == null || content.trim().isEmpty) {
        throw AiException('Empty AI response');
      }
      return content.trim();
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException('Malformed AI response');
    }
  }

  Future<String> _completeOpenAi(
    AiConfig cfg, {
    required String system,
    required String prompt,
    required double temperature,
  }) async {
    final base = cfg.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (cfg.apiKey.isNotEmpty)
                'Authorization': 'Bearer ${cfg.apiKey}',
            },
            body: jsonEncode({
              'model': cfg.model,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': prompt},
              ],
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiException('Could not reach the AI endpoint: $e');
    }

    if (res.statusCode != 200) {
      throw AiException('AI error ${res.statusCode}: ${_short(res.body)}');
    }

    try {
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final choices = body['choices'];
      String? content;
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map && message['content'] is String) {
            content = message['content'] as String;
          }
        }
      }
      if (content == null || content.trim().isEmpty) {
        throw AiException('Empty AI response');
      }
      return content.trim();
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException('Malformed AI response');
    }
  }

  String _short(String s) => s.length > 140 ? '${s.substring(0, 140)}…' : s;
}
