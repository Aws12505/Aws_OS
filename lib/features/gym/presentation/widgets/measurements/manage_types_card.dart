part of '../../screens/measurements_view.dart';

// Entry point into the measurement types.

class _ManageTypesCard extends StatelessWidget {
  const _ManageTypesCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final accent = context.sem.gym;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      semanticsLabel: 'Manage measurement types',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: accent.onContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Measurement types', style: tt.titleSmall),
                Text(
                  count == 1 ? '1 tracked' : '$count tracked',
                  style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: surfaces.textTertiary),
        ],
      ),
    );
  }
}
