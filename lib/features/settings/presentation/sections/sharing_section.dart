part of '../settings_screen.dart';

// Where received files land, and what is allowed in.

/// Local-sharing preferences: jump into the feature and set where received
/// files are saved (mirrors the prompt on the sharing screen).
class _SharingSection extends ConsumerWidget {
  const _SharingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(saveDirectoryProvider);
    final settings = ref.watch(shareSettingsStoreProvider);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.share_rounded),
          title: const Text('Open Local sharing'),
          subtitle: const Text('Send or receive files with nearby devices.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/sharing'),
        ),
        ListTile(
          leading: const Icon(Icons.folder_rounded),
          title: const Text('Save received files to'),
          subtitle: pathAsync.when(
            data: (path) => Text(path),
            loading: () => const Text('Loading…'),
            error: (_, _) => const Text('Default folder'),
          ),
          trailing: FutureBuilder<String?>(
            future: settings.saveDirectory(),
            builder: (_, snap) => snap.data == null
                ? const Icon(Icons.drive_folder_upload_rounded)
                : IconButton(
                    tooltip: 'Reset to default',
                    icon: const Icon(Icons.restore_rounded),
                    onPressed: () => resetShareSaveDirectory(ref),
                  ),
          ),
          onTap: () => pickShareSaveDirectory(context, ref),
        ),
      ],
    );
  }
}
