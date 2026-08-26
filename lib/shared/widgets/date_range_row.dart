import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/app_theme.dart';
import 'app_chip.dart';
import 'date_time_picker.dart';

/// Custom date-range chip with a clear button.
///
/// Promoted from three private `_CustomDateRow` copies in the finance, task and
/// note filter sheets. They differed only in which filter object they wrote to,
/// so this takes plain dates and callbacks and lets each sheet keep its own
/// model.
class DateRangeRow extends StatelessWidget {
  const DateRangeRow({
    super.key,
    required this.from,
    required this.to,
    required this.selected,
    required this.color,
    required this.onPicked,
    required this.onCleared,
    this.emptyLabel = 'Custom range',
  });

  final DateTime? from;
  final DateTime? to;
  final bool selected;
  final Color color;

  /// Called with both ends once the user has picked them.
  final void Function(DateTime from, DateTime to) onPicked;

  final VoidCallback onCleared;
  final String emptyLabel;

  Future<void> _pick(BuildContext context) async {
    final start = await pickDate(context, initial: from ?? DateTime.now());
    if (start == null || !context.mounted) return;
    final end = await pickDate(
      context,
      initial: to ?? start,
      firstDate: start,
    );
    if (end == null) return;
    onPicked(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd();
    final surfaces = context.surfaces;
    final hasRange = selected && from != null;

    return Row(
      children: [
        AppChip(
          label: hasRange
              ? '${fmt.format(from!)} to ${fmt.format(to ?? from!)}'
              : emptyLabel,
          icon: Icons.date_range_rounded,
          color: color,
          selected: selected,
          onTap: () => _pick(context),
        ),
        if (selected) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Clear the date range',
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: surfaces.textSecondary,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onCleared,
          ),
        ],
      ],
    );
  }
}
