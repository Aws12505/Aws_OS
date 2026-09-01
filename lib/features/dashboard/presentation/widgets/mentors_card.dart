part of '../dashboard_screen.dart';

// Entry points into the three mentors.

class _MentorsCard extends StatelessWidget {
  const _MentorsCard();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.psychology_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Text(
                'Mentors',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Analyze your data, forecast trends & get advice',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MentorChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Finance',
                  color: DomainColors.income,
                  onTap: () => context.push('/mentor?kind=finance'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MentorChip(
                  icon: Icons.fitness_center_rounded,
                  label: 'Gym',
                  color: DomainColors.gym,
                  onTap: () => context.push('/mentor?kind=gym'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MentorChip(
                  icon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  color: DomainColors.tasks,
                  onTap: () => context.push('/mentor?kind=productivity'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MentorChip extends StatelessWidget {
  const _MentorChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
