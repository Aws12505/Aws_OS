part of '../settings_screen.dart';

// Encrypted export and restore.

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
    final ok = await showAppConfirmDialog(
      context,
      title: 'Replace all data?',
      message: 'Importing wipes every row in the database and replaces it with the backup. '
          'This cannot be undone.',
      confirmLabel: 'Replace',
      destructive: true,
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

/// Asks for a password, allowing an empty one to mean "do not encrypt".
Future<_PasswordResult> _askOptionalPassword(
  BuildContext context, {
  required String title,
  required String confirmLabel,
}) async {
  final controller = TextEditingController();
  final result = await showAppDialog<_PasswordResult>(
    context,
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

/// Asks for a password that is required rather than optional.
Future<String?> _askPassword(
  BuildContext context, {
  required String title,
  required String confirmLabel,
}) async {
  final controller = TextEditingController();
  return showAppDialog<String>(
    context,
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
