import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'providers.dart';

/// Shared logic for choosing / resetting where received files are saved, so the
/// sharing screen and the Settings tile behave identically.

/// Prompt for a folder and persist it as the received-files destination.
/// Returns the chosen path, or null if the user cancelled.
Future<String?> pickShareSaveDirectory(
  BuildContext context,
  WidgetRef ref,
) async {
  // Writing outside app-private storage needs All-files access on Android 11+.
  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }
  final dir = await FilePicker.getDirectoryPath(
    dialogTitle: 'Choose where to save received files',
  );
  if (dir == null || dir.isEmpty) return null;
  await ref.read(shareSettingsStoreProvider).setSaveDirectory(dir);
  ref.read(receivedFilesStoreProvider).invalidate();
  ref.invalidate(saveDirectoryProvider);
  ref.invalidate(receivedFilesListProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saving received files to $dir')),
    );
  }
  return dir;
}

/// Clear the custom folder and fall back to the app's default location.
Future<void> resetShareSaveDirectory(WidgetRef ref) async {
  await ref.read(shareSettingsStoreProvider).setSaveDirectory(null);
  ref.read(receivedFilesStoreProvider).invalidate();
  ref.invalidate(saveDirectoryProvider);
  ref.invalidate(receivedFilesListProvider);
}
