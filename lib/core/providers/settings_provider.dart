import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';
import 'database_provider.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(databaseProvider));
});
