/// One-tap provider presets for the AI settings section. Each preset just
/// pre-fills the existing base URL + model fields; the user can still edit them
/// afterwards. "Custom" leaves the fields untouched for manual entry (e.g. a
/// local Ollama / LM Studio server or any other OpenAI-compatible endpoint).
class AiProviderPreset {
  const AiProviderPreset({
    required this.label,
    required this.baseUrl,
    required this.defaultModel,
  });

  final String label;

  /// Empty for "Custom" — the user types their own.
  final String baseUrl;

  /// Pre-filled when the preset is chosen, fully editable afterwards.
  final String defaultModel;

  bool get isCustom => baseUrl.isEmpty;
}

/// Normalizes a base URL for comparison: trims and strips trailing slashes,
/// matching how [AiService.completeWith] treats it.
String normalizeBaseUrl(String url) =>
    url.trim().replaceAll(RegExp(r'/+$'), '');

const kAiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    label: 'Google Gemini',
    // Gemini's OpenAI-compatible endpoint. The service appends
    // `/chat/completions`, yielding `.../v1beta/openai/chat/completions`.
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    // Editable; the user can switch to gemini-2.5-flash, gemini-2.0-flash, etc.
    defaultModel: 'gemini-3.5-flash',
  ),
  AiProviderPreset(
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
  ),
  AiProviderPreset(
    label: 'Custom',
    baseUrl: '',
    defaultModel: '',
  ),
];

/// The preset whose base URL matches [baseUrl], or the "Custom" preset when
/// nothing matches (including an empty URL).
AiProviderPreset presetForBaseUrl(String baseUrl) {
  final normalized = normalizeBaseUrl(baseUrl);
  if (normalized.isNotEmpty) {
    for (final p in kAiProviderPresets) {
      if (!p.isCustom && normalizeBaseUrl(p.baseUrl) == normalized) return p;
    }
  }
  return kAiProviderPresets.firstWhere((p) => p.isCustom);
}
