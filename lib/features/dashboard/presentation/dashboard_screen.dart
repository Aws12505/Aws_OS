import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../../shared/widgets/charts/category_donut.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../finance/data/finance_breakdown.dart';
import '../../finance/data/finance_dao.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../finance/presentation/widgets/confirm_occurrence_sheet.dart';
import '../../gym/presentation/providers.dart' as gym;
import '../../notes/presentation/providers.dart' as notes;
import '../../tasks/presentation/providers.dart' as tasks;
import '../../tasks/presentation/screens/task_detail_screen.dart';
import 'debrief_providers.dart';
import 'insights_view.dart';
import '../../../shared/design/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/pills.dart';

part 'widgets/hero_balance.dart';
part 'widgets/day_selector.dart';
part 'widgets/needs_attention_card.dart';
part 'widgets/day_cards.dart';
part 'widgets/spending_breakdown_card.dart';
part 'widgets/projected_balance_card.dart';
part 'widgets/debrief_cta.dart';
part 'widgets/mentors_card.dart';
part 'widgets/icon_badge.dart';

final _selectedDayProvider = StateProvider<DateTime>(
  (_) => DateTime.now().atStartOfDay,
);

/// 0 = Overview (today's cards), 1 = Insights (analytics).
final _dashboardTabProvider = StateProvider<int>((_) => 0);

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ambient: the aurora is part of what makes this screen feel like the
    // front door rather than a list.
    return const AppScaffold(
      body: _DashboardBody(),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_dashboardTabProvider);
    return Column(
      children: [
        const _TopBar(),
        const SizedBox(height: AppSpacing.xs),
        SegmentedControl(
          labels: const ['Overview', 'Insights'],
          icons: const [Icons.dashboard_rounded, Icons.insights_rounded],
          index: tab,
          onTap: (i) => ref.read(_dashboardTabProvider.notifier).state = i,
        ),
        Expanded(
          child: tab == 0 ? const _OverviewView() : const InsightsView(),
        ),
      ],
    );
  }
}

/// The original "today"-focused dashboard: hero balance, stat tiles, the day
/// selector and its per-day cards. Extracted verbatim so the Insights tab can
/// sit beside it under the segmented toggle.
class _OverviewView extends ConsumerWidget {
  const _OverviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDayProvider);
    final isToday = selected.isSameDay(DateTime.now());
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.read(fin.recurrenceServiceProvider).materializeAll(),
        ref.read(tasks.taskRecurrenceServiceProvider).materializeAll(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, AppInsets.listBottom),
        children: [
          const _HeroBalance(),
          const _StatRow(),
          const _NeedsAttentionCard(),
          _DaySelector(selected: selected, isToday: isToday),
          _DebriefCta(date: selected),
          _TransactionsForDayCard(date: selected),
          _TasksForDayCard(date: selected),
          _NotesForDayCard(date: selected),
          const _SpendingBreakdownCard(),
          const _ProjectedBalanceCard(),
          const _MentorsCard(),
        ],
      ),
    );
  }
}

// ── top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(fin.pendingOccurrencesProvider).value?.length ?? 0;
    return SectionHeader(
      title: 'Aws OS',
      // The greeting is the friendly half; the rest of the line is the useful
      // half. If something needs a decision today, say so here rather than
      // making the reader scroll to find out.
      status: pending == 0
          ? '${_greeting()}, ${DateFormat.MMMEd().format(DateTime.now())}'
          : pending == 1
          ? '1 entry needs confirming'
          : '$pending entries need confirming',
      statusIcon: pending == 0 ? null : Icons.pending_actions_rounded,
      statusColor: pending == 0 ? null : context.sem.warning.fg,
      trailing: IconButton.filledTonal(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_rounded),
        onPressed: () => context.push('/settings'),
      ),
    );
  }
}

// ── hero balance ─────────────────────────────────────────────────────────────

// ── stat row (bento) ─────────────────────────────────────────────────────────

// ── day selector ─────────────────────────────────────────────────────────────

// ── needs attention ──────────────────────────────────────────────────────────

// ── transactions for day ─────────────────────────────────────────────────────

// ── tasks for day ────────────────────────────────────────────────────────────

// ── notes for day ────────────────────────────────────────────────────────────

// ── expense pie ──────────────────────────────────────────────────────────────

// ── projected ────────────────────────────────────────────────────────────────

// ── debrief CTA ──────────────────────────────────────────────────────────────

// ── mentors ──────────────────────────────────────────────────────────────────

// ── shared bits ──────────────────────────────────────────────────────────────

