import 'package:aws_os/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('addition requires matching currencies', () {
      final a = const Money(10.5, 'USD');
      final b = const Money(2.25, 'USD');
      expect((a + b).amount, closeTo(12.75, 1e-9));
    });

    test('mixing currencies throws', () {
      expect(
        () => const Money(1, 'USD') + const Money(1, 'SYP'),
        throwsArgumentError,
      );
    });

    test('isZero respects epsilon', () {
      expect(const Money(1e-12, 'USD').isZero, isTrue);
      expect(const Money(0.01, 'USD').isZero, isFalse);
    });
  });
}
