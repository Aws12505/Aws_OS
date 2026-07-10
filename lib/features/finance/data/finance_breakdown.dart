import 'finance_dao.dart';

/// One slice of a category/type breakdown (a label + summed amount).
class BreakdownSlice {
  const BreakdownSlice(this.label, this.amount);
  final String label;
  final double amount;
}

/// Sum transactions by category — or by subcategory (type) — for one kind
/// (income/expense) and one currency, within an optional date range. Pure;
/// feeds the donut charts on the dashboard and finance Insights tab.
List<BreakdownSlice> categoryBreakdown({
  required List<TransactionWithLegs> txs,
  required String kind,
  required String currencyId,
  required bool byType,
  required Map<String, String> catNames,
  required Map<String, String> typeNames,
  DateTime? from,
  DateTime? to,
}) {
  final agg = <String, double>{};
  for (final t in txs) {
    if (t.transaction.kind != kind) continue;
    final at = t.transaction.occurredAt;
    if (from != null && at.isBefore(from)) continue;
    if (to != null && at.isAfter(to)) continue;
    final key = byType
        ? (typeNames[t.transaction.typeId] ?? 'Untyped')
        : (catNames[t.transaction.categoryId] ?? 'Uncategorized');
    for (final leg in t.legs) {
      if (leg.currencyId != currencyId) continue;
      agg.update(
        key,
        (v) => v + leg.amount.abs(),
        ifAbsent: () => leg.amount.abs(),
      );
    }
  }
  return agg.entries.map((e) => BreakdownSlice(e.key, e.value)).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

/// The currency id with the most volume for [kind] over the range — used to
/// pick which single currency a donut shows (never mixing currencies).
String? dominantCurrencyFor({
  required List<TransactionWithLegs> txs,
  required String kind,
  DateTime? from,
  DateTime? to,
}) {
  final vol = <String, double>{};
  for (final t in txs) {
    if (t.transaction.kind != kind) continue;
    final at = t.transaction.occurredAt;
    if (from != null && at.isBefore(from)) continue;
    if (to != null && at.isAfter(to)) continue;
    for (final leg in t.legs) {
      vol.update(
        leg.currencyId,
        (v) => v + leg.amount.abs(),
        ifAbsent: () => leg.amount.abs(),
      );
    }
  }
  if (vol.isEmpty) return null;
  return vol.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Currency ids that have any activity of [kind] in the range, busiest first.
List<String> currenciesWithActivity({
  required List<TransactionWithLegs> txs,
  required String kind,
  DateTime? from,
  DateTime? to,
}) {
  final vol = <String, double>{};
  for (final t in txs) {
    if (t.transaction.kind != kind) continue;
    final at = t.transaction.occurredAt;
    if (from != null && at.isBefore(from)) continue;
    if (to != null && at.isAfter(to)) continue;
    for (final leg in t.legs) {
      vol.update(
        leg.currencyId,
        (v) => v + leg.amount.abs(),
        ifAbsent: () => leg.amount.abs(),
      );
    }
  }
  final ids = vol.keys.toList()
    ..sort((a, b) => (vol[b] ?? 0).compareTo(vol[a] ?? 0));
  return ids;
}
