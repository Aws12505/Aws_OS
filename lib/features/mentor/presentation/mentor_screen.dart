import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_service.dart';
import '../../../shared/design/tokens.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/sparkline.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../data/forecast_service.dart';
import '../data/mentor_service.dart';
import 'mentor_providers.dart';

/// A domain mentor that analyzes the user's real data, forecasts trends and
/// gives advice — rule-based by default, AI-written when configured.
class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key, required this.kind});
  final MentorKind kind;

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  String? _advice;
  bool _loading = false;
  bool _usedOffline = false;

  Color get _accent => switch (widget.kind) {
        MentorKind.finance => DomainColors.income,
        MentorKind.gym => DomainColors.gym,
        MentorKind.productivity => DomainColors.tasks,
      };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(widget.kind.title)),
      body: switch (widget.kind) {
        MentorKind.finance => _finance(),
        MentorKind.gym => _gym(),
        MentorKind.productivity => _productivity(),
      },
    );
  }

  // ── Finance ────────────────────────────────────────────────────────────────

  Widget _finance() {
    final async = ref.watch(financeForecastProvider);
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(error: e),
      data: (f) {
        if (!f.hasData) {
          return _noData(
              'Add accounts and a few transactions, then your finance mentor '
              'can analyze cash flow and forecast your balance.');
        }
        final n = NumberFormat.decimalPatternDigits(decimalDigits: f.decimals);
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance (${f.currencyCode})',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '${n.format(f.currentBalance)} ${f.currencySymbol}',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Avg net / mo',
                          value: '${f.avgMonthlyNet >= 0 ? '+' : '−'}'
                              '${n.format(f.avgMonthlyNet.abs())}',
                          icon: Icons.trending_up_rounded,
                          accent: f.growing
                              ? DomainColors.income
                              : DomainColors.expense,
                          valueColor: f.growing
                              ? DomainColors.income
                              : DomainColors.expense,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MetricCard(
                          label: f.runwayMonths != null
                              ? 'Runway'
                              : 'In 3 months',
                          value: f.runwayMonths != null
                              ? '${f.runwayMonths!.toStringAsFixed(1)} mo'
                              : n.format(f.projected[3] ?? f.currentBalance),
                          icon: f.runwayMonths != null
                              ? Icons.timelapse_rounded
                              : Icons.savings_rounded,
                          accent: f.runwayMonths != null
                              ? DomainColors.warning
                              : DomainColors.income,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net trend (last ${f.months.length} months)',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Sparkline(
                    values: f.months.map((m) => m.net).toList(),
                    color: _accent,
                    height: 48,
                    fill: true,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final m in f.months)
                        Text(DateFormat('MMM').format(m.month),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            if (f.topCategories.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Where it goes',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    for (var i = 0; i < f.topCategories.length; i++)
                      _CatBar(
                        label: f.topCategories[i].name,
                        amount: f.topCategories[i].amount,
                        max: f.topCategories.first.amount,
                        color: ChartPalette.at(i),
                        format: (v) => n.format(v),
                      ),
                  ],
                ),
              ),
            _adviceCard(),
          ],
        );
      },
    );
  }

  // ── Gym ──────────────────────────────────────────────────────────────────

  Widget _gym() {
    final async = ref.watch(gymForecastProvider);
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(error: e),
      data: (g) {
        if (!g.hasData) {
          return _noData(
              'Log a few workouts and measurements, then your gym mentor can '
              'track frequency and project your trends.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.event_repeat_rounded,
                      color: DomainColors.gym,
                      label: 'Per week',
                      value: g.sessionsPerWeek.toStringAsFixed(1),
                      sub: '${g.totalSessions} in ${g.weeks} wks',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.local_fire_department_rounded,
                      color: DomainColors.warning,
                      label: 'Week streak',
                      value: '${g.currentWeekStreak}',
                      sub: g.lastSessionDaysAgo == null
                          ? '—'
                          : 'last ${g.lastSessionDaysAgo}d ago',
                    ),
                  ),
                ],
              ),
            ),
            for (final m in g.measurements)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.name,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text('${_t(m.latest)}${m.unit}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          m.slopePerWeek >= 0
                              ? Icons.north_east_rounded
                              : Icons.south_east_rounded,
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${m.slopePerWeek >= 0 ? '+' : ''}'
                          '${m.slopePerWeek.toStringAsFixed(2)}${m.unit}/wk · '
                          '~${_t(m.projected4w)}${m.unit} in 4 wks',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Sparkline(values: m.series, color: _accent, fill: true),
                  ],
                ),
              ),
            _adviceCard(),
          ],
        );
      },
    );
  }

  // ── Productivity ───────────────────────────────────────────────────────────

  Widget _productivity() {
    final async = ref.watch(productivityForecastProvider);
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(error: e),
      data: (p) {
        if (!p.hasData) {
          return _noData(
              'Add tasks with due dates, then your productivity mentor can '
              'track your follow-through.');
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.percent_rounded,
                      color: DomainColors.tasks,
                      label: 'Completion',
                      value: '${(p.completionRate * 100).round()}%',
                      sub: '${p.done}/${p.due} in ${p.windowDays}d',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.error_outline_rounded,
                      color: DomainColors.expense,
                      label: 'Overdue',
                      value: '${p.overdue}',
                      sub: p.overdue == 0 ? 'all clear' : 'to clear',
                    ),
                  ),
                ],
              ),
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily completion (last ${p.windowDays} days)',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Sparkline(
                      values: p.dailyCompletion, color: _accent, height: 48),
                ],
              ),
            ),
            _adviceCard(),
          ],
        );
      },
    );
  }

  // ── Advice (AI or rule-based) ────────────────────────────────────────────

  Widget _adviceCard() {
    final aiConfigured =
        ref.watch(aiConfigProvider).value?.isConfigured ?? false;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GlassCard(
      borderColor: _accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: _accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Mentor advice',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (aiConfigured)
                const MiniPill(label: 'AI', icon: Icons.bolt_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_advice != null)
            Text(_advice!, style: tt.bodyMedium?.copyWith(height: 1.5))
          else
            Text(
              aiConfigured
                  ? 'Ask your mentor to analyze the numbers above and suggest next steps.'
                  : 'Get instant suggestions from your data. Add your own AI provider in Settings for a deeper, personalized analysis.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          if (_usedOffline && _advice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Offline suggestions — configure AI in Settings for more.',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _advice == null ? 'Ask your mentor' : 'Refresh advice',
            icon: Icons.auto_awesome_rounded,
            expand: true,
            loading: _loading,
            onPressed: _ask,
          ),
        ],
      ),
    );
  }

  Future<void> _ask() async {
    final svc = ref.read(mentorServiceProvider);
    final ctx = _contextText(svc);
    if (ctx == null) return; // forecast not ready
    setState(() => _loading = true);
    String text;
    var offline = false;
    try {
      final cfg = await ref.read(aiServiceProvider).loadConfig();
      if (cfg.isConfigured) {
        text = await svc.advise(widget.kind, ctx);
      } else {
        text = _fallback(svc);
        offline = true;
      }
    } on AiException {
      text = _fallback(svc);
      offline = true;
    }
    if (!mounted) return;
    setState(() {
      _advice = text;
      _loading = false;
      _usedOffline = offline;
    });
  }

  String? _contextText(MentorService svc) {
    switch (widget.kind) {
      case MentorKind.finance:
        final f = ref.read(financeForecastProvider).value;
        return f == null ? null : svc.financeContext(f);
      case MentorKind.gym:
        final g = ref.read(gymForecastProvider).value;
        return g == null ? null : svc.gymContext(g);
      case MentorKind.productivity:
        final p = ref.read(productivityForecastProvider).value;
        return p == null ? null : svc.productivityContext(p);
    }
  }

  String _fallback(MentorService svc) {
    switch (widget.kind) {
      case MentorKind.finance:
        return svc.financeTips(ref.read(financeForecastProvider).value!);
      case MentorKind.gym:
        return svc.gymTips(ref.read(gymForecastProvider).value!);
      case MentorKind.productivity:
        return svc.productivityTips(
            ref.read(productivityForecastProvider).value!);
    }
  }

  Widget _noData(String message) {
    return AppEmptyState(
      icon: Icons.insights_rounded,
      title: 'Not enough data yet',
      message: message,
      accent: _accent,
    );
  }

  String _t(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _CatBar extends StatelessWidget {
  const _CatBar({
    required this.label,
    required this.amount,
    required this.max,
    required this.color,
    required this.format,
  });
  final String label;
  final double amount;
  final double max;
  final Color color;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final frac = max <= 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(format(amount),
                  style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
