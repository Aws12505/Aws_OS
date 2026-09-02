part of '../dashboard_screen.dart';

// Recurring entries waiting on a decision.

class _NeedsAttentionCard extends ConsumerWidget {
  const _NeedsAttentionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(fin.pendingOccurrencesProvider).value ??
        const <ScheduledOccurrence>[];
    if (pending.isEmpty) return const SizedBox.shrink();

    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final amber = context.sem.warning;

    final recurrences =
        ref.watch(fin.recurrencesStreamProvider).value ?? const <Recurrence>[];
    final currencies =
        ref.watch(fin.currenciesStreamProvider).value ?? const <Currency>[];
    final categories =
        ref.watch(fin.allCategoriesProvider).value ?? const <Category>[];
    final recsById = {for (final r in recurrences) r.id: r};
    final curById = {for (final c in currencies) c.id: c};
    final catNames = {for (final c in categories) c.id: c.name};

    return AppCard(
      borderColor: amber.base.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + 2,
        AppSpacing.lg + 2,
        AppSpacing.lg + 2,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.notifications_active_rounded,
                color: amber.base,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Needs attention', style: tt.titleMedium)),
              MiniPill(label: '${pending.length}', color: amber.base),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final o in pending)
            _PendingOccurrenceRow(
              occurrence: o,
              recurrence: recsById[o.recurrenceId],
              currencies: curById,
              categoryNames: catNames,
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'Reviewing one records it as a transaction.',
              style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry waiting to be confirmed.
///
/// This used to be a clock icon, a date and a button. A date on its own does
/// not tell you what is being asked: the question is *which* entry and *how
/// much*, and both were hidden behind the button. The row now leads with the
/// name and the amount and spends the small type on when it is due.
class _PendingOccurrenceRow extends StatelessWidget {
  const _PendingOccurrenceRow({
    required this.occurrence,
    required this.recurrence,
    required this.currencies,
    required this.categoryNames,
  });

  final ScheduledOccurrence occurrence;
  final Recurrence? recurrence;
  final Map<String, Currency> currencies;
  final Map<String, String> categoryNames;

  /// The entry's own name, falling through what is actually known about it
  /// rather than to a placeholder.
  String get _title {
    final rec = recurrence;
    if (rec == null) return 'Recurring entry';
    final note = rec.noteTemplate?.trim();
    if (note != null && note.isNotEmpty) return note;
    final category = categoryNames[rec.categoryId];
    if (category != null && category.isNotEmpty) return category;
    return DomainColors.labelForTxKind(rec.kind);
  }

  /// The template's total per currency: what gets recorded if the user
  /// confirms without editing.
  String? get _amount {
    final rec = recurrence;
    if (rec == null) return null;
    final List<TxLegDraft> legs;
    try {
      legs = RecurrenceService.decodeTemplateLegs(rec.templateLegsJson);
    } catch (_) {
      return null;
    }
    if (legs.isEmpty) return null;

    final totals = <String, double>{};
    for (final l in legs) {
      totals.update(
        l.currencyId,
        (v) => v + l.amount.abs(),
        ifAbsent: () => l.amount.abs(),
      );
    }
    return totals.entries
        .map((e) {
          final cur = currencies[e.key];
          final text = NumberFormat.decimalPatternDigits(
            decimalDigits: cur?.decimalPlaces ?? 2,
          ).format(e.value);
          final unit = cur?.symbol ?? cur?.code ?? '';
          return unit.isEmpty ? text : '$text $unit';
        })
        .join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final sem = context.sem;
    final kind = recurrence?.kind ?? 'expense';
    final role = sem.forTxKind(kind);

    final today = DateTime.now().atStartOfDay;
    final due = occurrence.dueAt.atStartOfDay;
    final days = due.difference(today).inDays;

    final (dueLabel, whenColor) = switch (days) {
      < 0 => (
        days == -1 ? '1 day overdue' : '${-days} days overdue',
        sem.expense.base,
      ),
      0 => ('Due today', sem.warning.base),
      1 => ('Due tomorrow', surfaces.textSecondary),
      _ => (
        'Due ${DateFormat.MMMd().format(occurrence.dueAt)}',
        surfaces.textSecondary,
      ),
    };

    final amount = _amount;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          IconBadge(
            icon: DomainColors.iconForTxKind(kind),
            color: role.base,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    if (amount != null) ...[
                      Text(
                        amount,
                        style: context.type.numericSmall.copyWith(
                          color: role.base,
                        ),
                      ),
                      Text(
                        '  ·  ',
                        style: tt.bodySmall?.copyWith(
                          color: surfaces.textQuaternary,
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        dueLabel,
                        style: tt.bodySmall?.copyWith(color: whenColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: () =>
                showConfirmOccurrenceSheet(context, occurrence: occurrence),
            style: FilledButton.styleFrom(
              backgroundColor: sem.warning.base,
              // Not `onContainer`: that is derived for contrast against the
              // pale container, and on the saturated base it vanished. The
              // button read as an amber blob with no visible label on it.
              foregroundColor: bestForegroundOn(sem.warning.base),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              textStyle: tt.labelLarge,
            ),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}
