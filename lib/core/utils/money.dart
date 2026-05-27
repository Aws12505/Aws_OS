import 'package:intl/intl.dart';

/// A monetary value tied to a currency.
///
/// Stored as a `double` per project preference; comparisons use an epsilon
/// to avoid float-equality pitfalls. Arithmetic only makes sense between
/// `Money` values that share the same `currencyId` — callers must ensure
/// that or convert via an `ExchangeRate` first.
class Money implements Comparable<Money> {
  const Money(this.amount, this.currencyId);

  factory Money.zero(String currencyId) => Money(0, currencyId);

  final double amount;
  final String currencyId;

  static const double _epsilon = 1e-9;

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(amount + other.amount, currencyId);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(amount - other.amount, currencyId);
  }

  Money operator -() => Money(-amount, currencyId);

  Money operator *(num factor) => Money(amount * factor, currencyId);

  Money operator /(num divisor) => Money(amount / divisor, currencyId);

  bool get isZero => amount.abs() < _epsilon;
  bool get isPositive => amount > _epsilon;
  bool get isNegative => amount < -_epsilon;

  @override
  int compareTo(Money other) {
    _checkSameCurrency(other);
    if ((amount - other.amount).abs() < _epsilon) return 0;
    return amount.compareTo(other.amount);
  }

  void _checkSameCurrency(Money other) {
    if (other.currencyId != currencyId) {
      throw ArgumentError(
        'Cannot mix currencies: $currencyId vs ${other.currencyId}',
      );
    }
  }

  /// Format using a given number of decimal places. Symbol/code is left to
  /// the caller — the `Currency` entity has the display metadata.
  String formatPlain(int decimalPlaces, {String? locale}) {
    final format = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimalPlaces,
    );
    return format.format(amount);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.currencyId == currencyId &&
      (other.amount - amount).abs() < _epsilon;

  @override
  int get hashCode => Object.hash(currencyId, (amount * 1e6).round());

  @override
  String toString() => 'Money($amount $currencyId)';
}
