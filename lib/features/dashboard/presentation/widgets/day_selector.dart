part of '../dashboard_screen.dart';

// The day strip that scopes the cards below it.

class _DaySelector extends ConsumerWidget {
  const _DaySelector({required this.selected, required this.isToday});
  final DateTime selected;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous day',
              icon: const Icon(Icons.chevron_left_rounded),
              color: cs.onSurfaceVariant,
              onPressed: () => ref.read(_selectedDayProvider.notifier).state =
                  selected.addDays(-1).atStartOfDay,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    ref.read(_selectedDayProvider.notifier).state =
                        d.atStartOfDay;
                  }
                },
                child: Column(
                  children: [
                    Text(
                      isToday ? 'Today' : DateFormat('EEEE').format(selected),
                      style: tt.labelMedium?.copyWith(
                        color: isToday ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, y').format(selected),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next day',
              icon: const Icon(Icons.chevron_right_rounded),
              color: cs.onSurfaceVariant,
              onPressed: () => ref.read(_selectedDayProvider.notifier).state =
                  selected.addDays(1).atStartOfDay,
            ),
          ],
        ),
      ),
    );
  }
}
