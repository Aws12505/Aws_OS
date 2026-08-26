part of '../../screens/day_detail_screen.dart';

/// Sets done over sets planned, with a bar.
///
/// The count was already being computed to drive auto-completion, so showing it
/// costs nothing and turns "am I nearly done" from counting rows into a glance.
class _SessionProgress extends StatelessWidget implements PreferredSizeWidget {
  const _SessionProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Size get preferredSize => const Size.fromHeight(30);

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final surfaces = context.surfaces;
    final accent = context.sem.gym;
    final motion = context.motion;
    final progress = (done / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Semantics(
        label: '$done of $total sets done',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$done / $total sets',
              style: context.type.numericSmall.copyWith(
                color: done == total ? accent.fg : surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: motion.medium,
                curve: motion.standardCurve,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: surfaces.sunken,
                  color: accent.base,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
