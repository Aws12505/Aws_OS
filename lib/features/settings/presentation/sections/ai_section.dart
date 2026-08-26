part of '../settings_screen.dart';

// The optional LLM endpoint the mentors can use.

/// Bring-your-own AI: the user configures their own OpenAI-compatible endpoint,
/// model and key. Optional and off by default; the debrief falls back to an
/// offline summary when this isn't configured.
class _AiSection extends ConsumerStatefulWidget {
  const _AiSection();
  @override
  ConsumerState<_AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends ConsumerState<_AiSection> {
  AiConfig? _cfg;
  AiService get _ai => ref.read(aiServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _ai.loadConfig();
    if (!mounted) return;
    setState(() => _cfg = c);
  }

  Future<void> _save({
    bool? enabled,
    String? baseUrl,
    String? model,
    String? apiKey,
    bool keyProvided = false,
  }) async {
    final cur = _cfg ?? AiConfig.empty;
    await _ai.saveConfig(
      enabled: enabled ?? cur.enabled,
      baseUrl: baseUrl ?? cur.baseUrl,
      model: model ?? cur.model,
      apiKey: keyProvided ? apiKey : null,
    );
    ref.invalidate(aiConfigProvider);
    await _load();
  }

  Future<void> _editText(
    String title,
    String initial,
    String hint,
    ValueChanged<String> onSave,
  ) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showAppDialog<String>(
    context,
    builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) onSave(result);
  }

  Future<void> _pickProvider() async {
    final cfg = _cfg ?? AiConfig.empty;
    final current = presetForBaseUrl(cfg.baseUrl);
    final chosen = await showAppDialog<AiProviderPreset>(
    context,
    builder: (dCtx) => SimpleDialog(
        title: const Text('Provider'),
        children: [
          for (final p in kAiProviderPresets)
            ListTile(
              title: Text(p.label),
              subtitle: p.isCustom
                  ? const Text('Enter base URL and model manually')
                  : Text(p.baseUrl),
              trailing: p == current
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(dCtx, p),
            ),
        ],
      ),
    );
    if (chosen == null || chosen.isCustom) return;
    await _save(baseUrl: chosen.baseUrl, model: chosen.defaultModel);
  }

  Future<void> _test() async {
    final cfg = _cfg;
    final messenger = ScaffoldMessenger.of(context);
    if (cfg == null || !cfg.isConfigured) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Enable AI and set base URL + model first.')));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Testing connection…')));
    try {
      await _ai.completeWith(
        cfg,
        system: 'You are a connection tester.',
        prompt: 'Reply with the single word OK.',
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Connection OK ✓')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    if (cfg == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AppLoading(),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable AI summaries'),
          subtitle: const Text(
            'Use your own AI provider for a richer daily debrief.',
          ),
          value: cfg.enabled,
          onChanged: (v) => _save(enabled: v),
        ),
        ListTile(
          enabled: cfg.enabled,
          title: const Text('Provider'),
          subtitle: Text(presetForBaseUrl(cfg.baseUrl).label),
          trailing: const Icon(Icons.expand_more_rounded),
          onTap: _pickProvider,
        ),
        ListTile(
          enabled: cfg.enabled,
          title: const Text('Provider base URL'),
          subtitle: Text(cfg.baseUrl.isEmpty
              ? 'Not set. For example https://api.openai.com/v1'
              : cfg.baseUrl),
          onTap: () => _editText(
            'Provider base URL',
            cfg.baseUrl,
            'https://api.openai.com/v1',
            (v) => _save(baseUrl: v),
          ),
        ),
        ListTile(
          enabled: cfg.enabled,
          title: const Text('Model'),
          subtitle: Text(
              cfg.model.isEmpty ? 'Not set. For example gpt-4o-mini' : cfg.model),
          onTap: () => _editText(
            'Model',
            cfg.model,
            'gpt-4o-mini',
            (v) => _save(model: v),
          ),
        ),
        ListTile(
          enabled: cfg.enabled,
          title: const Text('API key'),
          subtitle: Text(cfg.apiKey.isEmpty
              ? 'Not set (required for Gemini/OpenAI, optional for local servers)'
              : '•••••••• set'),
          trailing: const Icon(Icons.key_rounded),
          onTap: () async {
            final k = await _askPassword(context,
                title: 'API key', confirmLabel: 'Save');
            if (k != null) await _save(apiKey: k, keyProvided: true);
          },
        ),
        ListTile(
          enabled: cfg.enabled,
          title: const Text('Test connection'),
          trailing: const Icon(Icons.bolt_rounded),
          onTap: _test,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Your day data is sent to this endpoint only when AI is enabled and you generate a summary. Everything else stays on-device.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
