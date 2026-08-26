import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/insights_range.dart';
import '../../../../shared/widgets/segmented_control.dart';
import '../insights_providers.dart';

/// The range control every insights view shares.
///
/// It lives here rather than in `shared/` because it binds
/// [insightsRangeProvider], which is dashboard state. Two private copies used
/// to exist, one in the dashboard's insights view and one in finance's, both
/// driving the same provider, so switching range on one screen already changed
/// the other. Now that is one widget saying so out loud.
class InsightsRangeSelector extends ConsumerWidget {
  const InsightsRangeSelector({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    const ranges = InsightsRange.values;
    return Padding(
      padding: padding,
      child: SegmentedControl(
        labels: [for (final r in ranges) r.label],
        index: ranges.indexOf(range),
        onTap: (i) =>
            ref.read(insightsRangeProvider.notifier).state = ranges[i],
      ),
    );
  }
}
