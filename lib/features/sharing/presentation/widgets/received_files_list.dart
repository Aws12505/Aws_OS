import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../shared/widgets/glass.dart';
import '../../data/models/share_item.dart';
import '../../data/share_format.dart';
import '../providers.dart';
import 'transfer_progress.dart';

/// A browser of files already received into the save folder. Images render as
/// real thumbnails; everything else gets a type icon. Tapping a row opens the
/// share sheet so the file can be opened or forwarded.
class ReceivedFilesCard extends ConsumerWidget {
  const ReceivedFilesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filesAsync = ref.watch(receivedFilesListProvider);

    return GlassCard(
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
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
              child: Center(child: CircularProgressIndicator()),
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
              return Column(
                children: [
                  for (final f in files) _ReceivedRow(file: f),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReceivedRow extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
            borderRadius: BorderRadius.circular(8),
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
        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        formatBytes(size),
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.ios_share_rounded, size: 18),
      onTap: () => SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      ),
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
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconForKind(kind), size: 22, color: cs.onSurfaceVariant),
    );
  }
}
