import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/reminder_time_provider.dart';
import '../features/finance/presentation/providers.dart';
import 'router.dart';
import 'theme.dart';

class AwsOsApp extends ConsumerStatefulWidget {
  const AwsOsApp({super.key});

  @override
  ConsumerState<AwsOsApp> createState() => _AwsOsAppState();
}

class _AwsOsAppState extends ConsumerState<AwsOsApp> {
  @override
  void initState() {
    super.initState();
    // Refresh the recurring-entry queue every time the app boots so the
    // "Needs your attention" card and notifications stay accurate.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).init();
      final time = ref.read(reminderTimeProvider);
      ref
          .read(recurrenceServiceProvider)
          .setReminderTime(time.hour, time.minute);
      unawaited(ref.read(recurrenceServiceProvider).materializeAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Aws OS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(themeSettings, Brightness.light),
      darkTheme: buildTheme(themeSettings, Brightness.dark),
      themeMode: themeSettings.themeMode,
      routerConfig: router,
    );
  }
}
