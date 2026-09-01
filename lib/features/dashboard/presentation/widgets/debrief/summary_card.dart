part of '../../debrief_screen.dart';

// The written or generated wrap-up.

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.entry,
    required this.generating,
    required this.onGenerate,
  });

  final DebriefEntry? entry;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final aiConfigured =
        ref.watch(aiConfigProvider).value?.isConfigured ?? false;
    final summary = entry?.aiSummary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Summary',
                style: tt.titleMedium,
              ),
              const Spacer(),
              if (aiConfigured)
                const MiniPill(label: 'AI', icon: Icons.bolt_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary != null && summary.isNotEmpty)
            Text(summary, style: tt.bodyMedium?.copyWith(height: 1.4))
          else
            Text(
              aiConfigured
                  ? 'Generate a short AI reflection of your day.'
                  : 'Generate a quick summary of your day. Add your own AI provider in Settings for a richer narrative.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: summary == null ? 'Generate summary' : 'Regenerate',
            icon: Icons.auto_awesome_rounded,
            expand: true,
            onPressed: generating ? null : onGenerate,
          ),
          if (generating)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
