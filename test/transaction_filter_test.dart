import 'package:aws_os/core/db/app_database.dart';
import 'package:aws_os/features/finance/data/finance_dao.dart';
import 'package:aws_os/features/finance/presentation/providers.dart';
import 'package:aws_os/features/finance/presentation/screens/transactions_list_view.dart';
import 'package:aws_os/features/finance/presentation/transaction_filter.dart';
import 'package:aws_os/shared/utils/date_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 7, 1);

TransactionWithLegs _tx({
  String kind = 'expense',
  DateTime? at,
  String? categoryId,
  String? typeId,
  String? recurrenceId,
  String? note,
}) {
  return TransactionWithLegs(
    Transaction(
      id: 'tx-${note ?? kind}',
      createdAt: _base,
      updatedAt: _base,
      kind: kind,
      occurredAt: at ?? _base,
      note: note,
      categoryId: categoryId,
      typeId: typeId,
      recurrenceId: recurrenceId,
    ),
    const [],
  );
}

void main() {
  group('TransactionFilter.matches', () {
    test('default matches everything', () {
      const f = TransactionFilter();
      expect(f.matches(_tx(kind: 'income')), isTrue);
      expect(f.matches(_tx(kind: 'expense')), isTrue);
      expect(f.isDefault, isTrue);
      expect(f.activeCount, 0);
    });

    test('kind filter', () {
      const f = TransactionFilter(kind: 'income');
      expect(f.matches(_tx(kind: 'income')), isTrue);
      expect(f.matches(_tx(kind: 'expense')), isFalse);
    });

    test('category filter', () {
      const f = TransactionFilter(categoryId: 'food');
      expect(f.matches(_tx(categoryId: 'food')), isTrue);
      expect(f.matches(_tx(categoryId: 'rent')), isFalse);
      expect(f.matches(_tx(categoryId: null)), isFalse);
      expect(f.activeCount, 1);
    });

    test('subcategory (type) filter', () {
      const f = TransactionFilter(categoryId: 'food', typeId: 'groceries');
      expect(
        f.matches(_tx(categoryId: 'food', typeId: 'groceries')),
        isTrue,
      );
      expect(
        f.matches(_tx(categoryId: 'food', typeId: 'dining')),
        isFalse,
      );
      expect(f.activeCount, 2);
    });

    test('recurring filter — recurring vs one-off', () {
      const recurring = TransactionFilter(recurring: TxRecurring.recurring);
      const oneOff = TransactionFilter(recurring: TxRecurring.oneOff);
      final fromTemplate = _tx(recurrenceId: 'r1');
      final manual = _tx(recurrenceId: null);

      expect(recurring.matches(fromTemplate), isTrue);
      expect(recurring.matches(manual), isFalse);
      expect(oneOff.matches(manual), isTrue);
      expect(oneOff.matches(fromTemplate), isFalse);
      expect(recurring.activeCount, 1);
    });

    test('custom date range filter', () {
      final f = const TransactionFilter().copyWith(
        datePreset: DatePreset.custom,
        customFrom: DateTime(2026, 6, 1),
        customTo: DateTime(2026, 6, 30),
      );
      expect(f.matches(_tx(at: DateTime(2026, 6, 15))), isTrue);
      expect(f.matches(_tx(at: DateTime(2026, 7, 15))), isFalse);
      expect(f.matches(_tx(at: DateTime(2026, 5, 15))), isFalse);
    });

    test('dimensions combine (AND)', () {
      const f = TransactionFilter(kind: 'expense', categoryId: 'food');
      expect(f.matches(_tx(kind: 'expense', categoryId: 'food')), isTrue);
      expect(f.matches(_tx(kind: 'income', categoryId: 'food')), isFalse);
      expect(f.matches(_tx(kind: 'expense', categoryId: 'rent')), isFalse);
    });
  });

  group('copyWith', () {
    test('sentinel lets nullables be cleared', () {
      const f = TransactionFilter(categoryId: 'food', typeId: 'groceries');
      // Unrelated change keeps category/type.
      final kept = f.copyWith(kind: 'expense');
      expect(kept.categoryId, 'food');
      expect(kept.typeId, 'groceries');
      // Explicit null clears.
      final cleared = f.copyWith(categoryId: null, typeId: null);
      expect(cleared.categoryId, isNull);
      expect(cleared.typeId, isNull);
      expect(cleared.isDefault, isTrue);
    });
  });

  testWidgets('Activity view applies the kind filter to the list',
      (tester) async {
    final txs = [
      _tx(kind: 'income', note: 'salary'),
      _tx(kind: 'expense', categoryId: 'food', note: 'groceries'),
    ];
    final food = Category(
      id: 'food',
      createdAt: _base,
      updatedAt: _base,
      name: 'Food',
      kind: 'expense',
      sortOrder: 0,
    );

    final container = ProviderContainer(overrides: [
      recentTransactionsStreamProvider.overrideWith((ref) => Stream.value(txs)),
      currenciesStreamProvider.overrideWith((ref) => Stream.value(const [])),
      accountsStreamProvider.overrideWith((ref) => Stream.value(const [])),
      allCategoriesProvider.overrideWith((ref) => Stream.value([food])),
      allTypesProvider.overrideWith((ref) => Stream.value(const [])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TransactionsListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both transactions visible, and the compact filter bar rendered.
    expect(find.text('salary'), findsOneWidget);
    expect(find.text('groceries'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    // Apply an income-only filter → the expense row drops out.
    container.read(transactionFilterProvider.notifier).state =
        const TransactionFilter(kind: 'income');
    await tester.pumpAndSettle();

    expect(find.text('salary'), findsOneWidget);
    expect(find.text('groceries'), findsNothing);
  });
}
