part of '../../screens/tasks_screen.dart';

// One workspace in the rail, with its completion bar.

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.name,
    required this.color,
    required this.done,
    required this.total,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final Color color;
  final int done;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = total == 0 ? 0.0 : done / total;
    // The workspace colour comes from the categorical palette, so it can be a
    // pale amber as easily as a deep indigo. White is not readable on all of
    // them; ask which extreme actually passes.
    final onAccent = bestForegroundOn(color);
    return AnimatedContainer(
      duration: context.motion.medium,
      curve: context.motion.standardCurve,
            width: 158,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion.medium,
      curve: context.motion.standardCurve,
                        padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.22)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : cs.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? onAccent.withValues(alpha: 0.22)
                            : color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        size: 20,
                        color: selected ? onAccent : color,
                      ),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$total',
                        maxLines: 1,
                        style: tt.titleMedium?.copyWith(
                          color: selected ? onAccent : cs.onSurface,
                        ).weight(FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    color: selected ? onAccent : cs.onSurface,
                  ).weight(FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: selected
                        ? onAccent.withValues(alpha: 0.25)
                        : cs.surfaceContainerHighest,
                    color: selected ? onAccent : color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0 ? 'No tasks' : '$done of $total done',
                  style: tt.labelSmall?.copyWith(
                    color: selected
                        ? onAccent.withValues(alpha: 0.85)
                        : cs.onSurfaceVariant,
                  ).weight(FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
