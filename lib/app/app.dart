import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/reminder_time_provider.dart';
import '../features/finance/presentation/providers.dart';
import '../features/tasks/presentation/providers.dart' as tasks;
import '../shared/widgets/app_background.dart';
import 'router.dart';
import 'theme.dart';

class AwsOsApp extends ConsumerStatefulWidget {
  const AwsOsApp({super.key});

  @override
  ConsumerState<AwsOsApp> createState() => _AwsOsAppState();
}

class _AwsOsAppState extends ConsumerState<AwsOsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh the recurring-entry queue every time the app boots so the
    // "Needs your attention" card and notifications stay accurate.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).init();
      final time = ref.read(reminderTimeProvider);
      ref
          .read(recurrenceServiceProvider)
          .setReminderTime(time.hour, time.minute);
      unawaited(ref.read(recurrenceServiceProvider).materializeAll());
      // Generate upcoming recurring-task instances on boot.
      unawaited(ref.read(tasks.taskRecurrenceServiceProvider).materializeAll());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-lock: when the app is backgrounded, relock so the lock screen is
    // required on return (no-op unless lock is enabled).
    if (state == AppLifecycleState.paused) {
      ref.read(lockProvider.notifier).relock();
    }
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
      builder: (context, child) {
        // A single persistent aurora backdrop sits behind every route, so
        // content slides over a continuous, living background.
        return AuroraBackground(child: child);
      },
    );
  }
}
