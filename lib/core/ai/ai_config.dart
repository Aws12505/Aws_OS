/// Immutable AI configuration. The user brings their own OpenAI-compatible
/// endpoint — OpenAI, Google Gemini (via its OpenAI-compatible endpoint),
/// OpenRouter, Groq, Together, a local Ollama/LM Studio server, etc. Nothing
/// here is tied to a specific vendor; one-tap presets live in
/// `ai_provider_presets.dart`.
class AiConfig {
  const AiConfig({
    required this.enabled,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final bool enabled;

  /// e.g. `https://api.openai.com/v1` — the service appends `/chat/completions`.
  final String baseUrl;

  /// e.g. `gpt-4o-mini`, `llama3.1`, `mistral-small`.
  final String model;

  /// May be empty for keyless local servers (Ollama / LM Studio).
  final String apiKey;

  /// Whether AI features should be offered and used.
  bool get isConfigured =>
      enabled && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  static const AiConfig empty =
      AiConfig(enabled: false, baseUrl: '', model: '', apiKey: '');

  AiConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) {
    return AiConfig(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
