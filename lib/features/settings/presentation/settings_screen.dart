import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/reminder_time_provider.dart';
import '../../../core/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final reminder = ref.watch(reminderTimeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Appearance'),
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
              final mode = await showDialog<ThemeMode>(
                context: context,
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
              final family = await showDialog<String>(
                context: context,
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
          _SectionHeader('Reminders'),
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
          _SectionHeader('Security'),
          const _SecuritySection(),
          const Divider(),
          _SectionHeader('Backup'),
          const _BackupSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

void _pickColor(
  BuildContext context, {
  required String title,
  required Color initial,
  required ValueChanged<Color> onPicked,
}) {
  Color current = initial;
  showDialog<void>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: initial,
          onColorChanged: (c) => current = c,
          enableAlpha: false,
          labelTypes: const [],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            onPicked(current);
            Navigator.pop(dCtx);
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('Export backup'),
          subtitle: const Text(
            'JSON file with everything; optional password encryption.',
          ),
          onTap: () => _exportBackup(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Import backup'),
          subtitle: const Text(
            'Pick a backup file. Replaces all current data.',
          ),
          onTap: () => _importBackup(context, ref),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final result = await _askOptionalPassword(
      context,
      title: 'Encrypt backup?',
      confirmLabel: 'Export',
    );
    if (!result.confirmed) return;
    final svc = ref.read(backupServiceProvider);
    try {
      final file = await svc.writeBackupFile(password: result.password);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Aws OS backup'),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    final file = File(path);
    final isEncrypted = path.toLowerCase().endsWith('.awsbak');

    if (!context.mounted) return;
    String? password;
    if (isEncrypted) {
      final result = await _askPassword(
        context,
        title: 'Password',
        confirmLabel: 'Import',
      );
      if (result == null) return;
      password = result;
    }

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Importing wipes every row in the database and replaces it with the backup. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(backupServiceProvider)
          .importFromFile(file, password: password);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup restored.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}

typedef _PasswordResult = ({bool confirmed, String? password});

Future<_PasswordResult> _askOptionalPassword(
  BuildContext context, {
  required String title,
  required String confirmLabel,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<_PasswordResult>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Leave blank for plain JSON, or set a password to AES-encrypt.',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Password (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dCtx, (confirmed: false, password: null)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text;
            Navigator.pop(dCtx, (
              confirmed: true,
              password: v.isEmpty ? null : v,
            ));
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? (confirmed: false, password: null);
}

Future<String?> _askPassword(
  BuildContext context, {
  required String title,
  required String confirmLabel,
}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.isEmpty) return;
            Navigator.pop(dCtx, controller.text);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();
  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  bool? _pinSet;
  bool? _bioEnabled;
  AuthService get _auth => ref.read(authServiceProvider);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final pinSet = await _auth.isPinSet;
    final bio = await _auth.isBiometricEnabled;
    if (!mounted) return;
    setState(() {
      _pinSet = pinSet;
      _bioEnabled = bio;
    });
    ref.read(lockProvider.notifier).refresh();
  }

  Future<void> _setPin() async {
    final pin = await _askPin('Set PIN');
    if (pin == null) return;
    await _auth.setPin(pin);
    await _refresh();
  }

  Future<void> _changePin() async {
    final current = await _askPin('Current PIN');
    if (current == null) return;
    if (!await _auth.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
      }
      return;
    }
    final next = await _askPin('New PIN');
    if (next == null) return;
    await _auth.setPin(next);
    await _refresh();
  }

  Future<void> _clearPin() async {
    final current = await _askPin('Confirm current PIN');
    if (current == null) return;
    if (!await _auth.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
      }
      return;
    }
    await _auth.clearPin();
    await _refresh();
  }

  Future<String?> _askPin(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN (4–8 digits)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.length < 4 || v.length > 8) return;
              Navigator.pop(dCtx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinSet = _pinSet;
    final bio = _bioEnabled;
    if (pinSet == null || bio == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          title: const Text('PIN unlock'),
          subtitle: Text(
            pinSet ? 'Enabled — tap below to change or clear' : 'Disabled',
          ),
          value: pinSet,
          onChanged: (v) async {
            if (v) {
              await _setPin();
            } else {
              await _clearPin();
            }
          },
        ),
        if (pinSet)
          ListTile(
            title: const Text('Change PIN'),
            trailing: const Icon(Icons.edit),
            onTap: _changePin,
          ),
        SwitchListTile(
          title: const Text('Biometric unlock'),
          subtitle: const Text(
            'Use fingerprint/face if available on this device.',
          ),
          value: bio,
          onChanged: (v) async {
            await _auth.setBiometric(v);
            await _refresh();
          },
        ),
      ],
    );
  }
}
