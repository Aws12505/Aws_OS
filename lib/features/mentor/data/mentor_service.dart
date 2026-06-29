import 'package:intl/intl.dart';

import '../../../core/ai/ai_service.dart';
import 'forecast_service.dart';

/// Turns on-device forecasts into mentor advice. When the user has configured
/// an AI provider it asks the model (grounded in the real numbers); otherwise
/// it returns rule-based coaching so the feature always does something useful.
class MentorService {
  MentorService(this._ai);
  final AiService _ai;

  String systemFor(MentorKind kind) => switch (kind) {
        MentorKind.finance =>
          'You are a sharp, practical personal-finance mentor. You receive the '
              "user's real recent cash flow, balance, projections and top "
              'spending. Give a brief, concrete assessment and 3–5 prioritized, '
              'specific recommendations grounded in these exact numbers. '
              'Reference figures. No generic platitudes, no disclaimers.',
        MentorKind.gym =>
          'You are an experienced strength & conditioning coach. You receive the '
              "user's real training frequency, streak and body-measurement "
              'trends with 4-week projections. Give a brief assessment and 3–5 '
              'specific, actionable coaching cues grounded in these numbers '
              '(frequency, progression, plateaus). No generic advice, no medical '
              'disclaimers.',
        MentorKind.productivity =>
          'You are a pragmatic productivity coach. You receive the user\'s task '
              'completion stats and trend. Give a brief assessment and 3–5 '
              'specific, actionable suggestions grounded in the numbers. No '
              'platitudes.',
      };

  Future<String> advise(MentorKind kind, String context) {
    return _ai.complete(system: systemFor(kind), prompt: context);
  }

  // ── Context builders (fed to the model) ────────────────────────────────────

  String financeContext(FinanceForecast f) {
    final n = NumberFormat.decimalPatternDigits(decimalDigits: f.decimals);
    final b = StringBuffer()
      ..writeln('Currency: ${f.currencyCode}')
      ..writeln('Current balance: ${n.format(f.currentBalance)}')
      ..writeln('Average monthly net: ${n.format(f.avgMonthlyNet)}')
      ..writeln('Projected balance: +1mo ${n.format(f.projected[1] ?? 0)}, '
          '+3mo ${n.format(f.projected[3] ?? 0)}, '
          '+6mo ${n.format(f.projected[6] ?? 0)}');
    if (f.runwayMonths != null) {
      b.writeln('Runway at current burn: ${f.runwayMonths!.toStringAsFixed(1)} months');
    }
    b.writeln('Monthly history:');
    for (final m in f.months) {
      b.writeln('  ${DateFormat('MMM yyyy').format(m.month)}: '
          'in ${n.format(m.income)}, out ${n.format(m.expense)}, '
          'net ${n.format(m.net)}');
    }
    if (f.topCategories.isNotEmpty) {
      b.writeln('Top spending:');
      for (final c in f.topCategories) {
        b.writeln('  ${c.name}: ${n.format(c.amount)}');
      }
    }
    return b.toString();
  }

  String gymContext(GymForecast g) {
    final b = StringBuffer()
      ..writeln('Training: ${g.totalSessions} sessions in the last ${g.weeks} '
          'weeks (${g.sessionsPerWeek.toStringAsFixed(1)} per week).')
      ..writeln('Current weekly streak: ${g.currentWeekStreak} weeks.');
    if (g.lastSessionDaysAgo != null) {
      b.writeln('Last session: ${g.lastSessionDaysAgo} days ago.');
    }
    if (g.measurements.isNotEmpty) {
      b.writeln('Body measurements (latest, weekly trend, 4-week projection):');
      for (final m in g.measurements) {
        final s = m.slopePerWeek >= 0 ? '+' : '';
        b.writeln('  ${m.name}: ${_t(m.latest)}${m.unit}, '
            '$s${m.slopePerWeek.toStringAsFixed(2)}${m.unit}/wk → '
            '~${_t(m.projected4w)}${m.unit}');
      }
    }
    return b.toString();
  }

  String productivityContext(ProductivityForecast p) {
    return (StringBuffer()
          ..writeln('Last ${p.windowDays} days: ${p.done}/${p.due} tasks '
              'completed (${(p.completionRate * 100).round()}%).')
          ..writeln('Currently overdue: ${p.overdue}.')
          ..writeln('Daily completion trend slope: '
              '${p.slopePerDay.toStringAsFixed(3)} per day.'))
        .toString();
  }

  // ── Rule-based fallback advice (no AI configured / AI failed) ───────────────

  String financeTips(FinanceForecast f) {
    final n = NumberFormat.decimalPatternDigits(decimalDigits: f.decimals);
    final tips = <String>[];
    if (f.runwayMonths != null) {
      tips.add('You\'re spending more than you earn — about '
          '${f.runwayMonths!.toStringAsFixed(1)} months of runway at this rate. '
          'Trimming your top category would extend it.');
    } else {
      tips.add('You\'re net-positive (~${n.format(f.avgMonthlyNet)} '
          '${f.currencyCode}/mo). On this pace you\'d reach '
          '${n.format(f.projected[6] ?? f.currentBalance)} in ~6 months.');
    }
    if (f.topCategories.isNotEmpty) {
      tips.add('Biggest outflow: ${f.topCategories.first.name} '
          '(${n.format(f.topCategories.first.amount)}). Set a monthly cap here.');
    }
    tips.add('Automate a fixed transfer to savings right after income lands.');
    return _bullets(tips);
  }

  String gymTips(GymForecast g) {
    final tips = <String>[];
    if (g.sessionsPerWeek < 2) {
      tips.add('Frequency is low (${g.sessionsPerWeek.toStringAsFixed(1)}/week). '
          'Target 3 short sessions a week — consistency beats intensity.');
    } else {
      tips.add('Solid frequency (${g.sessionsPerWeek.toStringAsFixed(1)}/week). '
          'Keep the ${g.currentWeekStreak}-week streak alive.');
    }
    final moving = g.measurements.where((m) => m.slopePerWeek.abs() > 1e-6);
    if (moving.isNotEmpty) {
      final m = moving.first;
      final dir = m.slopePerWeek >= 0 ? 'rising' : 'falling';
      tips.add('${m.name} is $dir ~${m.slopePerWeek.abs().toStringAsFixed(2)}'
          '${m.unit}/wk → about ${_t(m.projected4w)}${m.unit} in a month.');
    }
    tips.add('Log each session\'s actual sets/reps to drive progressive overload.');
    return _bullets(tips);
  }

  String productivityTips(ProductivityForecast p) {
    final tips = <String>[];
    tips.add('You\'re completing ${(p.completionRate * 100).round()}% of due '
        'tasks. ${p.completionRate < 0.6 ? 'Schedule fewer, finish more.' : 'Great follow-through.'}');
    if (p.overdue > 0) {
      tips.add('${p.overdue} task(s) overdue — clear or reschedule them first to '
          'reset momentum.');
    }
    tips.add('Each evening, carry unfinished tasks to tomorrow and cap the list.');
    return _bullets(tips);
  }

  String _bullets(List<String> tips) => tips.map((t) => '• $t').join('\n\n');

  String _t(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
