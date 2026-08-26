import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/design/app_theme.dart';
import '../../../shared/widgets/charts/activity_heatmap.dart';
import '../../../shared/widgets/charts/grouped_bar_chart.dart';
import '../../../shared/widgets/charts/trend_line_chart.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/insights_card.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/sparkline.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../mentor/data/forecast_service.dart';
import '../../mentor/presentation/mentor_providers.dart';
import '../data/day_summary.dart';
import '../data/insights_service.dart';
import 'insights_providers.dart';
import '../../../shared/widgets/app_loading.dart';
import 'widgets/insights_range_selector.dart';

part 'widgets/insights/kpi_strip.dart';
part 'widgets/insights/finance_section.dart';
part 'widgets/insights/budgets_section.dart';
part 'widgets/insights/productivity_section.dart';
part 'widgets/insights/gym_section.dart';
part 'widgets/insights/wellbeing_section.dart';
part 'widgets/insights/consistency_section.dart';

/// The "Insights" tab of the dashboard: a range selector followed by analytics
/// sections. Each section watches its own providers and self-hides when empty,
/// mirroring the Overview cards.
class InsightsView extends StatelessWidget {
  const InsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, AppInsets.listBottom),
      children: const [
        InsightsRangeSelector(padding: EdgeInsets.only(top: AppSpacing.xs)),
        _KpiStrip(),
        _FinanceSection(),
        _BudgetsCard(),
        _ProductivitySection(),
        _GymSection(),
        _WellbeingSection(),
        _ConsistencyCard(),
      ],
    );
  }
}

// ── range selector ───────────────────────────────────────────────────────────

// ── KPI strip ────────────────────────────────────────────────────────────────

// ── finance (per currency) ───────────────────────────────────────────────────

// ── budgets ──────────────────────────────────────────────────────────────────

// ── productivity ─────────────────────────────────────────────────────────────

// ── gym & body ───────────────────────────────────────────────────────────────

// ── wellbeing ────────────────────────────────────────────────────────────────

// ── consistency heatmap ──────────────────────────────────────────────────────

// ── shared bits ──────────────────────────────────────────────────────────────

List<String> _labels(RangeSummary rs) {
  final fmt = rs.days.length <= 8 ? DateFormat('E') : DateFormat('d/M');
  return [for (final d in rs.days) fmt.format(d.date)];
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

String _money(double v, Currency c) =>
    '${compactNumber(v)} ${c.symbol.isNotEmpty ? c.symbol : c.code}';

String _full(double v, Currency c) =>
    '${NumberFormat.decimalPatternDigits(decimalDigits: c.decimalPlaces).format(v)} ${c.symbol.isNotEmpty ? c.symbol : c.code}';
