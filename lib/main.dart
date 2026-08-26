import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'app/app.dart';
import 'app/theme.dart';
import 'core/db/app_database.dart';
import 'core/providers/database_provider.dart';
import 'core/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  // Open the database here rather than letting the provider do it lazily, so
  // the persisted theme can be read before the first frame. Without this the
  // app painted one frame of default indigo in the default font and then
  // swapped, which is very visible on every cold start.
  final db = AppDatabase();
  final initialTheme = await loadThemeSettings(SettingsService(db));

  // Resolving the theme kicks off the font loads for the chosen family. Give
  // them a moment to land so the first frame is not typeset in the platform
  // fallback, but never block startup on the network.
  buildTheme(initialTheme, Brightness.light);
  await GoogleFonts.pendingFonts().timeout(
    const Duration(milliseconds: 400),
    onTimeout: () => const [],
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialThemeSettingsProvider.overrideWithValue(initialTheme),
      ],
      child: const AwsOsApp(),
    ),
  );
}
