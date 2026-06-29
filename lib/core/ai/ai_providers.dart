import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import 'ai_config.dart';
import 'ai_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref.watch(settingsServiceProvider));
});

/// Current AI config. UI watches this to show/hide AI affordances. Invalidate
/// it after saving config in settings.
final aiConfigProvider = FutureProvider<AiConfig>((ref) {
  return ref.watch(aiServiceProvider).loadConfig();
});
