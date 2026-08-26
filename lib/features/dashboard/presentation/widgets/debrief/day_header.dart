part of '../../debrief_screen.dart';

// Date strip with the two arrows that move between days.

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.onPrev,
    this.onNext,
  });

  final DateTime day;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  isToday ? 'Today' : DateFormat('EEEE').format(day),
                  style: tt.labelLarge?.copyWith(
                    color: cs.primary,
                  ).weight(FontWeight.w700),
                ),
                Text(
                  DateFormat('MMMM d, y').format(day),
                  style: tt.titleMedium,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
