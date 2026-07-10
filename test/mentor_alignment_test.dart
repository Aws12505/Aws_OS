import 'package:aws_os/core/db/app_database.dart';
import 'package:aws_os/features/finance/data/finance_dao.dart';
import 'package:aws_os/features/mentor/data/forecast_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 7, 1);

Currency _cur(String id, String code) => Currency(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      code: code,
      symbol: code,
      decimalPlaces: 2,
      isActive: true,
      sortOrder: 0,
    );

Account _acc(String id, String currencyId) => Account(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      name: id,
      currencyId: currencyId,
      kind: 'cash',
      archived: false,
      sortOrder: 0,
    );

Category _cat(String id, String name) => Category(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      name: name,
      kind: 'expense',
      sortOrder: 0,
    );

Budget _bud(String id, String categoryId, double amount) => Budget(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      categoryId: categoryId,
      amount: amount,
      period: 'monthly',
    );

TransactionWithLegs _tx(
  double amount, {
  required String categoryId,
  required String currencyId,
}) {
  final id = 't-$categoryId';
  return TransactionWithLegs(
    Transaction(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      kind: 'expense',
      occurredAt: DateTime(2026, 7, 10),
      categoryId: categoryId,
    ),
    [
      TransactionLeg(
        id: 'l-$id',
        createdAt: _base,
        updatedAt: _base,
        transactionId: id,
        accountId: 'a1',
        currencyId: currencyId,
        amount: amount,
      ),
    ],
  );
}

void main() {
  const svc = ForecastService();
  final now = DateTime(2026, 7, 15);

  test('buildFinance feeds budgets + other-currency balances to the mentor', () {
    final f = svc.buildFinance(
      txs: [
        _tx(-120, categoryId: 'food', currencyId: 'usd'),
        _tx(-50, categoryId: 'rent', currencyId: 'usd'),
      ],
      accounts: [_acc('a1', 'usd'), _acc('a2', 'eur')],
      currencies: [_cur('usd', 'USD'), _cur('eur', 'EUR')],
      balances: {'a1': 1000, 'a2': 500},
      categories: [_cat('food', 'Food'), _cat('rent', 'Rent')],
      now: now,
      budgets: [_bud('b1', 'food', 100)],
    );

    expect(f.currencyCode, 'USD'); // dominant currency analyzed
    expect(f.budgets.length, 1);
    final food = f.budgets.single;
    expect(food.name, 'Food');
    expect(food.spent, 120);
    expect(food.limit, 100);
    expect(food.over, isTrue);
    expect(f.otherBalances, {'EUR': 500}); // primary excluded
  });

  test('buildGym feeds per-exercise strength progression to the mentor', () {
    final exercises = [
      DayExercise(
        id: 'e1',
        createdAt: _base,
        updatedAt: _base,
        dayId: 'd1',
        position: 0,
        exerciseName: 'Bench',
        targetSets: 3,
      ),
    ];
    ExerciseSetPrescription pres(String id, double weight, DateTime at) =>
        ExerciseSetPrescription(
          id: id,
          createdAt: _base,
          updatedAt: _base,
          dayExerciseId: 'e1',
          setIndex: 1,
          reps: 5,
          weight: weight,
          effectiveFrom: at,
        );

    final f = svc.buildGym(
      sessions: const [],
      entries: const [],
      values: const [],
      types: const [],
      now: now,
      exercises: exercises,
      prescriptions: [
        pres('p1', 80, DateTime(2026, 7, 1)),
        pres('p2', 85, DateTime(2026, 7, 8)),
      ],
    );

    expect(f.lifts.length, 1);
    final bench = f.lifts.single;
    expect(bench.name, 'Bench');
    expect(bench.latestWeight, 85);
    expect(bench.est1RM, closeTo(85 * (1 + 5 / 30), 1e-6));
    expect(bench.change, 5);
    expect(bench.entries, 2);
    expect(f.hasData, isTrue);
  });
}
