import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/date_preset.dart';
import '../data/finance_dao.dart';

/// Recurrence dimension: show everything, only entries generated from a
/// recurring template, or only one-off entries.
enum TxRecurring { all, recurring, oneOff }

extension TxRecurringLabel on TxRecurring {
  String get label => switch (this) {
    TxRecurring.all => 'All',
    TxRecurring.recurring => 'Recurring',
    TxRecurring.oneOff => 'One-off',
  };
}

/// Structured filter for the transactions list. Mirrors `TaskFilter`: an
/// immutable value object with `copyWith` (sentinel-guarded nullables),
/// `isDefault`/`activeCount` for the UI, and a single `matches` predicate so
/// the view stays declarative. Free-text search stays in the view.
class TransactionFilter {
  const TransactionFilter({
    this.kind = 'all',
    this.datePreset = DatePreset.all,
    this.customFrom,
    this.customTo,
    this.categoryId,
    this.typeId,
    this.recurring = TxRecurring.all,
  });

  /// all | income | expense | transfer | exchange
  final String kind;
  final DatePreset datePreset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final String? categoryId;

  /// Subcategory (CategoryType) id. Only meaningful alongside [categoryId].
  final String? typeId;
  final TxRecurring recurring;

  bool get isDefault =>
      kind == 'all' &&
      datePreset == DatePreset.all &&
      categoryId == null &&
      typeId == null &&
      recurring == TxRecurring.all;

  /// Count of active filters beyond the always-visible kind row — drives the
  /// badge on the "Filters" button.
  int get activeCount {
    var n = 0;
    if (datePreset != DatePreset.all) n++;
    if (categoryId != null) n++;
    if (typeId != null) n++;
    if (recurring != TxRecurring.all) n++;
    return n;
  }

  bool matches(TransactionWithLegs e) {
    final tx = e.transaction;
    if (kind != 'all' && tx.kind != kind) return false;

    final range = datePresetRange(
      datePreset,
      customFrom: customFrom,
      customTo: customTo,
    );
    if (range != null &&
        (tx.occurredAt.isBefore(range.$1) || tx.occurredAt.isAfter(range.$2))) {
      return false;
    }

    if (categoryId != null && tx.categoryId != categoryId) return false;
    if (typeId != null && tx.typeId != typeId) return false;

    switch (recurring) {
      case TxRecurring.recurring:
        if (tx.recurrenceId == null) return false;
      case TxRecurring.oneOff:
        if (tx.recurrenceId != null) return false;
      case TxRecurring.all:
        break;
    }
    return true;
  }

  TransactionFilter copyWith({
    String? kind,
    DatePreset? datePreset,
    Object? customFrom = _sentinel,
    Object? customTo = _sentinel,
    Object? categoryId = _sentinel,
    Object? typeId = _sentinel,
    TxRecurring? recurring,
  }) {
    return TransactionFilter(
      kind: kind ?? this.kind,
      datePreset: datePreset ?? this.datePreset,
      customFrom: customFrom == _sentinel
          ? this.customFrom
          : customFrom as DateTime?,
      customTo: customTo == _sentinel ? this.customTo : customTo as DateTime?,
      categoryId: categoryId == _sentinel
          ? this.categoryId
          : categoryId as String?,
      typeId: typeId == _sentinel ? this.typeId : typeId as String?,
      recurring: recurring ?? this.recurring,
    );
  }
}

const _sentinel = Object();

/// Shared filter state for the Activity tab. Lives in a provider (not local
/// widget state) so it survives tab switches, like `taskFilterProvider`.
final transactionFilterProvider = StateProvider<TransactionFilter>(
  (_) => const TransactionFilter(),
);
