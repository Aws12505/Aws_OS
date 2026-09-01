import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../data/models/share_item.dart';
import '../../data/share_format.dart';
import '../providers.dart';
import 'transfer_progress.dart';
import '../../../../shared/widgets/app_card.dart';

/// A browser of files already received into the save folder. Images render as
/// real thumbnails; everything else gets a type icon. Tapping a row opens the
/// share sheet so the file can be opened or forwarded.
class ReceivedFilesCard extends ConsumerWidget {
  const ReceivedFilesCard({super.key});

  static const _previewCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filesAsync = ref.watch(receivedFilesListProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inbox_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Received files',
                  style: tt.titleSmall?.weight(FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => ref.invalidate(receivedFilesListProvider),
              ),
            ],
          ),
          filesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: AppLoading(),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Couldn\'t read the save folder.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            data: (files) {
              if (files.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nothing received yet. Files you receive land here.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }
              final preview = files.take(_previewCount).toList();
              final extra = files.length - preview.length;
              return Column(
                children: [
                  for (final f in preview) _ReceivedRow(file: f),
                  if (extra > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: () => _showAllReceivedFiles(context, files),
                        child: Text('View all ${files.length} files'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAllReceivedFiles(BuildContext context, List<File> files) {
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: files.length,
          itemBuilder: (_, i) => _ReceivedRow(file: files[i]),
        ),
      ),
    );
  }
}

enum _RowAction { open, share }

class _ReceivedRow extends ConsumerWidget {
  const _ReceivedRow({required this.file});
  final File file;

  static const _imageExts = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif',
  };

  ShareItemKind _kindForName(String name) {
    final ext = p.extension(name).toLowerCase();
    if (_imageExts.contains(ext)) return ShareItemKind.photo;
    return switch (ext) {
      '.mp4' || '.mkv' || '.mov' || '.webm' || '.avi' => ShareItemKind.video,
      '.mp3' || '.wav' || '.m4a' || '.aac' || '.flac' || '.ogg' =>
        ShareItemKind.audio,
      '.apk' => ShareItemKind.apk,
      '.obb' => ShareItemKind.obb,
      _ => ShareItemKind.file,
    };
  }

  bool get _isApk => p.extension(file.path).toLowerCase() == '.apk';

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final service = ref.read(installedAppsServiceProvider);
    final ok = _isApk
        ? await service.installApk(file.path)
        : await service.openFile(file.path);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isApk
                ? "Couldn't open the installer for this app."
                : "No app can open this file.",
          ),
        ),
      );
    }
  }

  void _share() =>
      SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = p.basename(file.path);
    final kind = _kindForName(name);
    final size = () {
      try {
        return file.lengthSync();
      } catch (_) {
        return 0;
      }
    }();

    final leading = kind == ShareItemKind.photo
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.file(
              file,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              cacheWidth: 96,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _GlyphTile(kind: kind),
            ),
          )
        : _GlyphTile(kind: kind);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.bodyMedium?.weight(FontWeight.w600),
      ),
      subtitle: Text(
        formatBytes(size),
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<_RowAction>(
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onSelected: (a) => switch (a) {
          _RowAction.open => _open(context, ref),
          _RowAction.share => _share(),
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _RowAction.open,
            child: Row(
              children: [
                Icon(
                  _isApk
                      ? Icons.install_mobile_rounded
                      : Icons.open_in_new_rounded,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(_isApk ? 'Install' : 'Open'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: _RowAction.share,
            child: Row(
              children: [
                Icon(Icons.ios_share_rounded, size: 20),
                SizedBox(width: 12),
                Text('Share'),
              ],
            ),
          ),
        ],
      ),
      // Primary tap: install (APK) or open with the default app.
      onTap: () => _open(context, ref),
    );
  }
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.kind});
  final ShareItemKind kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.surfaces.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(iconForKind(kind), size: 22, color: cs.onSurfaceVariant),
    );
  }
}
