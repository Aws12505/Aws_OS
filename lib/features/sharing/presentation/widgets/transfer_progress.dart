import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/glass.dart';
import '../../data/models/share_item.dart';
import '../../data/models/transfer_task.dart';
import '../../data/share_format.dart';
import '../providers.dart';

IconData iconForKind(ShareItemKind k) => switch (k) {
  ShareItemKind.photo => Icons.image_rounded,
  ShareItemKind.video => Icons.movie_rounded,
  ShareItemKind.audio => Icons.audiotrack_rounded,
  ShareItemKind.apk => Icons.android_rounded,
  ShareItemKind.obb => Icons.videogame_asset_rounded,
  ShareItemKind.appData => Icons.folder_zip_rounded,
  ShareItemKind.backup => Icons.backup_rounded,
  ShareItemKind.file => Icons.insert_drive_file_rounded,
};

/// Shows the live per-file progress of the current session plus an aggregate
/// bar and a cancel action.
class TransferProgressCard extends ConsumerWidget {
  const TransferProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(shareSessionProvider);
    if (s.tasks.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final controller = ref.read(shareSessionProvider.notifier);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.status ?? 'Transfer',
                  style: tt.titleMedium,
                ),
              ),
              if (s.active)
                TextButton(
                  onPressed: controller.cancel,
                  child: const Text('Cancel'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: s.progress == 0 ? null : s.progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatBytes(s.transferredBytes)} / ${formatBytes(s.totalBytes)}'
            '${s.speedBps > 0 ? ' · ${formatSpeed(s.speedBps)}' : ''}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final t in s.tasks) _TaskRow(task: t),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = switch (task.status) {
      TransferStatus.done => context.sem.income.base,
      TransferStatus.failed || TransferStatus.cancelled => cs.error,
      _ => cs.primary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(iconForKind(task.kind), size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.weight(FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _trailing(context),
                  ],
                ),
                const SizedBox(height: 4),
                if (task.isTerminal)
                  Text(
                    _statusLabel(),
                    style: tt.labelSmall?.copyWith(color: color),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: task.progress == 0 ? null : task.progress,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return switch (task.status) {
      TransferStatus.done => Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: context.sem.income.base,
      ),
      TransferStatus.failed || TransferStatus.cancelled => Icon(
        Icons.error_outline_rounded,
        size: 18,
        color: cs.error,
      ),
      _ => Text(
        formatBytes(task.totalBytes),
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    };
  }

  String _statusLabel() => switch (task.status) {
    TransferStatus.done => '${formatBytes(task.totalBytes)} · done',
    TransferStatus.failed => task.error ?? 'Failed',
    TransferStatus.cancelled => 'Cancelled',
    _ => '',
  };
}
