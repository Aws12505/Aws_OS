import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ai/ai_providers.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../../shared/design/app_theme.dart';
import '../../../shared/design/color_ops.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../tasks/presentation/providers.dart' as tasks;
import '../data/day_summary.dart';
import '../data/rule_based_summary.dart';
import 'debrief_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/pills.dart';

part 'widgets/debrief/day_header.dart';
part 'widgets/debrief/glance_card.dart';
part 'widgets/debrief/journal_card.dart';
part 'widgets/debrief/week_trend_card.dart';
part 'widgets/debrief/carry_over_card.dart';
part 'widgets/debrief/summary_card.dart';

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

// ── glance (rolled-up stats) ─────────────────────────────────────────────────

// ── journal ──────────────────────────────────────────────────────────────────

// ── weekly trend (lightweight custom bars) ──────────────────────────────────

// ── carry over ───────────────────────────────────────────────────────────────

// ── summary (AI / rule-based) ────────────────────────────────────────────────

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
