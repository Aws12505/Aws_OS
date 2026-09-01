import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/ai/ai_config.dart';
import '../../../core/ai/ai_provider_presets.dart';
import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/reminder_time_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/design/app_theme.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../sharing/presentation/providers.dart';
import '../../sharing/presentation/save_location.dart';

part 'sections/appearance_section.dart';
part 'sections/sharing_section.dart';
part 'sections/backup_section.dart';
part 'sections/security_section.dart';
part 'sections/ai_section.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final reminder = ref.watch(reminderTimeProvider);

    return AppScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionLabel(
            'Appearance',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
          ),
          ListTile(
            title: const Text('Primary color'),
            trailing: _Swatch(color: theme.primaryColor),
            onTap: () => _pickColor(
              context,
              title: 'Primary color',
              initial: theme.primaryColor,
              onPicked: (c) => ref.read(themeProvider.notifier).setPrimary(c),
            ),
          ),
          ListTile(
            title: const Text('Accent color'),
            trailing: _Swatch(color: theme.accentColor),
            onTap: () => _pickColor(
              context,
              title: 'Accent color',
              initial: theme.accentColor,
              onPicked: (c) => ref.read(themeProvider.notifier).setAccent(c),
            ),
          ),
          ListTile(
            title: const Text('Theme mode'),
            subtitle: Text(switch (theme.themeMode) {
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
              ThemeMode.system => 'System',
            }),
            onTap: () async {
              final mode = await showAppDialog<ThemeMode>(
    context,
    builder: (dCtx) => SimpleDialog(
                  title: const Text('Theme mode'),
                  children: [
                    for (final m in ThemeMode.values)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(dCtx, m),
                        child: Text(m.name),
                      ),
                  ],
                ),
              );
              if (mode != null) {
                ref.read(themeProvider.notifier).setMode(mode);
              }
            },
          ),
          ListTile(
            title: const Text('Font family'),
            subtitle: Text(theme.fontFamily),
            onTap: () async {
              final family = await showAppDialog<String>(
    context,
    builder: (dCtx) => SimpleDialog(
                  title: const Text('Font family'),
                  children: [
                    for (final f in curatedFontFamilies)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(dCtx, f),
                        child: Text(f),
                      ),
                  ],
                ),
              );
              if (family != null) {
                ref.read(themeProvider.notifier).setFontFamily(family);
              }
            },
          ),
          ListTile(
            title: const Text('Text size'),
            subtitle: Slider(
              min: 0.85,
              max: 1.30,
              divisions: 9,
              value: theme.fontScale,
              label: theme.fontScale.toStringAsFixed(2),
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setFontScale(v),
            ),
          ),
          const Divider(),
          const SectionLabel(
            'Reminders',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
          ),
          ListTile(
            title: const Text('Daily reminder time'),
            subtitle: Text(reminder.format(context)),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: reminder,
              );
              if (picked != null) {
                await ref.read(reminderTimeProvider.notifier).setTime(picked);
              }
            },
          ),
          const Divider(),
          const SectionLabel(
            'AI',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
          ),
          const _AiSection(),
          const Divider(),
          const SectionLabel(
            'Security',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
          ),
          const _SecuritySection(),
          const Divider(),
          const SectionLabel(
            'Local sharing',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
          ),
          const _SharingSection(),
          const Divider(),
          const SectionLabel(
            'Backup',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
          ),
          const _BackupSection(),
        ],
      ),
    );
  }
}

typedef _PasswordResult = ({bool confirmed, String? password});

