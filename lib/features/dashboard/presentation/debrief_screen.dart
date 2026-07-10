import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../../shared/design/tokens.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../tasks/presentation/providers.dart' as tasks;
import '../data/day_summary.dart';
import '../data/rule_based_summary.dart';
import 'debrief_providers.dart';

/// The end-of-day "debrief": rolled-up stats, a reflection journal, a weekly
/// trend, carry-over to tomorrow, and an optional AI/rule-based summary.
class DebriefScreen extends ConsumerStatefulWidget {
  const DebriefScreen({super.key, this.date});

  final DateTime? date;

  @override
  ConsumerState<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends ConsumerState<DebriefScreen> {
  late DateTime _day;
  int? _mood;
  int? _energy;
  final _wins = TextEditingController();
  final _improve = TextEditingController();
  final _gratitude = TextEditingController();
  final _reflection = TextEditingController();
  String? _loadedKey;
  bool _generating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _day = (widget.date ?? DateTime.now()).atStartOfDay;
  }

  @override
  void dispose() {
    _wins.dispose();
    _improve.dispose();
    _gratitude.dispose();
    _reflection.dispose();
    super.dispose();
  }

  void _applyEntry(DebriefEntry? e) {
    _mood = e?.mood;
    _energy = e?.energy;
    _wins.text = e?.wins ?? '';
    _improve.text = e?.improve ?? '';
    _gratitude.text = e?.gratitude ?? '';
    _reflection.text = e?.reflection ?? '';
  }

  void _changeDay(int delta) {
    setState(() {
      _day = _day.addDays(delta).atStartOfDay;
      _loadedKey = null; // force reload of that day's journal
      _applyEntry(null); // clear immediately to avoid showing stale text
      _loadedKey = _day.dayKey; // we'll repopulate from the stream below
    });
    // Repopulate from whatever is cached for the new day.
    final cached = ref.read(debriefForDayProvider(_day)).value;
    _applyEntry(cached);
  }

  String? _nn(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(debriefRepositoryProvider)
        .saveReflection(
          _day,
          mood: _mood,
          energy: _energy,
          wins: _nn(_wins.text),
          improve: _nn(_improve.text),
          gratitude: _nn(_gratitude.text),
          reflection: _nn(_reflection.text),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Debrief saved')));
  }

  Future<void> _generate(DaySummary summary) async {
    setState(() => _generating = true);
    await _save(); // persist the journal so the summary reflects it
    final ai = ref.read(aiServiceProvider);
    final prompt = _aiPrompt(summary);
    String text;
    var usedOffline = false;
    try {
      final cfg = await ai.loadConfig();
      if (cfg.isConfigured) {
        text = await ai.complete(system: _kSystem, prompt: prompt);
      } else {
        text = RuleBasedSummary.build(summary);
        usedOffline = true;
      }
    } on AiException {
      text = RuleBasedSummary.build(summary);
      usedOffline = true;
    }
    await ref.read(debriefRepositoryProvider).cacheAiSummary(_day, text);
    if (!mounted) return;
    setState(() => _generating = false);
    if (usedOffline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Used an offline summary')));
    }
  }

  String _aiPrompt(DaySummary s) {
    final df = DateFormat('EEEE, MMMM d');
    final b = StringBuffer()
      ..writeln('Date: ${df.format(s.date)}')
      ..writeln(
        'Tasks: ${s.tasksDone}/${s.tasksDue} done (${(s.taskCompletion * 100).round()}%).',
      );
    if (s.transactionCount > 0) {
      final net = s.netByCurrency.entries
          .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
          .join(', ');
      b.writeln('Money net: $net across ${s.transactionCount} transactions.');
      if (s.topExpenseCategories.isNotEmpty) {
        b.writeln('Top spend category: ${s.topExpenseCategories.first.name}.');
      }
    }
    b.writeln('Workout logged: ${s.workedOut ? 'yes' : 'no'}.');
    b.writeln('Notes written: ${s.notesCount}.');
    if (_mood != null) b.writeln('Self-rated mood: $_mood/5.');
    if (_energy != null) b.writeln('Self-rated energy: $_energy/5.');
    if (_nn(_wins.text) != null) b.writeln('Wins: ${_wins.text.trim()}');
    if (_nn(_improve.text) != null) {
      b.writeln('To improve: ${_improve.text.trim()}');
    }
    if (_nn(_gratitude.text) != null) {
      b.writeln('Gratitude: ${_gratitude.text.trim()}');
    }
    if (_nn(_reflection.text) != null) {
      b.writeln('Reflection: ${_reflection.text.trim()}');
    }
    if (s.taskStreak > 1) b.writeln('Task streak: ${s.taskStreak} days.');
    if (s.debriefStreak > 1) {
      b.writeln('Journaling streak: ${s.debriefStreak} days.');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Populate the journal once per day from the persisted entry.
    final entryAsync = ref.watch(debriefForDayProvider(_day));
    if (entryAsync.hasValue && _loadedKey != _day.dayKey) {
      _loadedKey = _day.dayKey;
      final e = entryAsync.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _applyEntry(e));
      });
    }

    final summaryAsync = ref.watch(daySummaryProvider(_day));
    final isToday = _day.isSameDay(DateTime.now());

    return AppScaffold(
      appBar: AppBar(title: const Text('Debrief')),
      body: summaryAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorView(error: e),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 48),
          children: [
            _DayHeader(
              day: _day,
              isToday: isToday,
              onPrev: () => _changeDay(-1),
              onNext: isToday ? null : () => _changeDay(1),
            ),
            _GlanceCard(summary: summary),
            _JournalCard(
              mood: _mood,
              energy: _energy,
              wins: _wins,
              improve: _improve,
              gratitude: _gratitude,
              reflection: _reflection,
              saving: _saving,
              onMood: (v) => setState(() => _mood = v),
              onEnergy: (v) => setState(() => _energy = v),
              onSave: _save,
            ),
            _WeekTrendCard(day: _day),
            _CarryOverCard(day: _day, summary: summary),
            _SummaryCard(
              entry: entryAsync.value,
              generating: _generating,
              onGenerate: () => _generate(summary),
            ),
          ],
        ),
      ),
    );
  }
}

const _kSystem =
    'You are a thoughtful journaling companion. Given structured facts about a '
    "person's day, write a short (3–4 sentences), warm, specific reflection. "
    'Be encouraging but honest, and end with one small suggestion for tomorrow. '
    'Plain prose, no markdown headings.';

// ── day header ───────────────────────────────────────────────────────────────

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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('MMMM d, y').format(day),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── glance (rolled-up stats) ─────────────────────────────────────────────────

class _GlanceCard extends ConsumerWidget {
  const _GlanceCard({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies =
        ref.watch(fin.currenciesStreamProvider).value ?? const <Currency>[];
    final byId = {for (final c in currencies) c.id: c};
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final net = summary.netByCurrency.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final netLabel = net.isEmpty
        ? '—'
        : _fmtMoney(net.first.value, byId[net.first.key], signed: true);
    final netColor = net.isEmpty
        ? null
        : (net.first.value >= 0 ? DomainColors.income : DomainColors.expense);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'The day at a glance',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (summary.taskStreak > 0)
                MiniPill(
                  label: '${summary.taskStreak}d',
                  icon: Icons.local_fire_department_rounded,
                  color: DomainColors.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Tasks',
                  value: summary.tasksDue == 0
                      ? '—'
                      : '${summary.tasksDone}/${summary.tasksDue}',
                  icon: Icons.task_alt_rounded,
                  accent: DomainColors.tasks,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Net',
                  value: netLabel,
                  icon: Icons.account_balance_wallet_rounded,
                  accent: cs.tertiary,
                  valueColor: netColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Workout',
                  value: summary.workedOut
                      ? (summary.sessionCount > 1
                            ? '${summary.sessionCount}×'
                            : 'Done')
                      : '—',
                  icon: Icons.fitness_center_rounded,
                  accent: DomainColors.gym,
                  valueColor: summary.workedOut ? DomainColors.income : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Notes',
                  value: '${summary.notesCount}',
                  icon: Icons.sticky_note_2_rounded,
                  accent: DomainColors.notes,
                ),
              ),
            ],
          ),
          if (summary.tasksDue > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: summary.taskCompletion,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                color: summary.taskCompletion >= 1
                    ? DomainColors.income
                    : DomainColors.tasks,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(summary.taskCompletion * 100).round()}% of today\'s tasks done',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (summary.topExpenseCategories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (
                  var i = 0;
                  i < summary.topExpenseCategories.length && i < 3;
                  i++
                )
                  MiniPill(
                    label: summary.topExpenseCategories[i].name,
                    color: ChartPalette.at(i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── journal ──────────────────────────────────────────────────────────────────

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.mood,
    required this.energy,
    required this.wins,
    required this.improve,
    required this.gratitude,
    required this.reflection,
    required this.saving,
    required this.onMood,
    required this.onEnergy,
    required this.onSave,
  });

  final int? mood;
  final int? energy;
  final TextEditingController wins;
  final TextEditingController improve;
  final TextEditingController gratitude;
  final TextEditingController reflection;
  final bool saving;
  final ValueChanged<int> onMood;
  final ValueChanged<int> onEnergy;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was your day?',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          _ScalePicker(
            label: 'Mood',
            value: mood,
            onChanged: onMood,
            colorFor: MoodColors.forScore,
          ),
          const SizedBox(height: AppSpacing.md),
          _ScalePicker(
            label: 'Energy',
            value: energy,
            onChanged: onEnergy,
            colorFor: (s) => Color.lerp(cs.primary, cs.tertiary, (s - 1) / 4)!,
          ),
          const SizedBox(height: AppSpacing.lg),
          _JournalField(
            controller: wins,
            label: 'Wins',
            hint: 'What went well?',
          ),
          _JournalField(
            controller: improve,
            label: 'To improve',
            hint: 'What could be better?',
          ),
          _JournalField(
            controller: gratitude,
            label: 'Gratitude',
            hint: "What you're thankful for",
          ),
          _JournalField(
            controller: reflection,
            label: 'Reflection',
            hint: 'Anything else on your mind',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Save debrief',
            icon: Icons.check_rounded,
            expand: true,
            loading: saving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _ScalePicker extends StatelessWidget {
  const _ScalePicker({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.colorFor,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 36,
                      decoration: BoxDecoration(
                        color: value != null && i <= value!
                            ? colorFor(value!).withValues(alpha: 0.9)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: value == i
                              ? colorFor(i)
                              : cs.outlineVariant.withValues(alpha: 0.4),
                          width: value == i ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: value != null && i <= value!
                                ? Colors.white
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JournalField extends StatelessWidget {
  const _JournalField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 2,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: maxLines,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }
}

// ── weekly trend (lightweight custom bars) ──────────────────────────────────

class _WeekTrendCard extends ConsumerWidget {
  const _WeekTrendCard({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeAsync = ref.watch(
      rangeSummaryProvider((start: day.addDays(-6), end: day)),
    );
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          rangeAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                Text('$e', style: tt.bodySmall?.copyWith(color: cs.error)),
            data: (range) {
              final maxNet = range.days
                  .map(
                    (d) => d.netByCurrency.values
                        .fold<double>(0, (s, v) => s + v)
                        .abs(),
                  )
                  .fold<double>(1, (a, b) => a > b ? a : b);
              return Column(
                children: [
                  SizedBox(
                    height: 132,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in range.days)
                          Expanded(
                            child: _DayBar(
                              completion: d.taskCompletion,
                              hasTasks: d.tasksDue > 0,
                              workedOut: d.workedOut,
                              mood: d.debrief?.mood,
                              label: DateFormat('E').format(d.date)[0],
                              isToday: d.date.isSameDay(DateTime.now()),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(
                        label: 'Workouts',
                        value: '${range.totalWorkouts}',
                      ),
                      _MiniStat(
                        label: 'Tasks done',
                        value: '${range.totalTasksDone}',
                      ),
                      _MiniStat(
                        label: 'Avg mood',
                        value: range.avgMood == 0
                            ? '—'
                            : range.avgMood.toStringAsFixed(1),
                      ),
                    ],
                  ),
                  if (maxNet < 0) const SizedBox.shrink(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.completion,
    required this.hasTasks,
    required this.workedOut,
    required this.mood,
    required this.label,
    required this.isToday,
  });

  final double completion;
  final bool hasTasks;
  final bool workedOut;
  final int? mood;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Fully dynamic: the bar lives in an Expanded area and is sized as a
    // fraction of whatever height is available, so it can never overflow.
    return Column(
      children: [
        SizedBox(
          height: 14,
          child: workedOut
              ? const Icon(
                  Icons.fitness_center_rounded,
                  size: 12,
                  color: DomainColors.gym,
                )
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: hasTasks ? (0.06 + completion * 0.94) : 0.06,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: hasTasks
                        ? (completion >= 1
                                  ? DomainColors.income
                                  : DomainColors.tasks)
                              .withValues(alpha: 0.85)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mood != null
                ? MoodColors.forScore(mood!)
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: isToday ? cs.primary : cs.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── carry over ───────────────────────────────────────────────────────────────

class _CarryOverCard extends ConsumerWidget {
  const _CarryOverCard({required this.day, required this.summary});
  final DateTime day;
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unfinished = summary.tasksDue - summary.tasksDone;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (unfinished <= 0) return const SizedBox.shrink();
    final target = day.addDays(1);
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: DomainColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.arrow_circle_right_rounded,
              color: DomainColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan tomorrow',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$unfinished unfinished task${unfinished == 1 ? '' : 's'} can move to ${DateFormat('MMM d').format(target)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: () async {
              final moved = await ref
                  .read(tasks.tasksRepositoryProvider)
                  .carryOverUnfinished(from: day);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved $moved to tomorrow')),
              );
            },
            child: const Text('Carry over'),
          ),
        ],
      ),
    );
  }
}

// ── summary (AI / rule-based) ────────────────────────────────────────────────

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.entry,
    required this.generating,
    required this.onGenerate,
  });

  final DebriefEntry? entry;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final aiConfigured =
        ref.watch(aiConfigProvider).value?.isConfigured ?? false;
    final summary = entry?.aiSummary;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Summary',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (aiConfigured)
                const MiniPill(label: 'AI', icon: Icons.bolt_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary != null && summary.isNotEmpty)
            Text(summary, style: tt.bodyMedium?.copyWith(height: 1.4))
          else
            Text(
              aiConfigured
                  ? 'Generate a short AI reflection of your day.'
                  : 'Generate a quick summary of your day. Add your own AI provider in Settings for a richer narrative.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: summary == null ? 'Generate summary' : 'Regenerate',
            icon: Icons.auto_awesome_rounded,
            expand: true,
            onPressed: generating ? null : onGenerate,
          ),
          if (generating)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

String _fmtMoney(double amount, Currency? cur, {bool signed = false}) {
  final digits = cur?.decimalPlaces ?? 2;
  final n = NumberFormat.decimalPatternDigits(
    decimalDigits: digits,
  ).format(amount.abs());
  final sym = cur?.symbol ?? cur?.code ?? '';
  final sign = signed && amount < 0 ? '−' : (signed && amount > 0 ? '+' : '');
  return sym.isEmpty ? '$sign$n' : '$sign$n $sym';
}
