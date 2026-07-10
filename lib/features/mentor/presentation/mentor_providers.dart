import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_providers.dart';
import '../../../core/utils/date_ext.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../gym/presentation/providers.dart' as gym;
import '../../tasks/presentation/providers.dart' as tasks;
import '../data/forecast_service.dart';
import '../data/mentor_service.dart';

final forecastServiceProvider = Provider<ForecastService>(
  (_) => const ForecastService(),
);

final mentorServiceProvider = Provider<MentorService>((ref) {
  return MentorService(ref.watch(aiServiceProvider));
});

final financeForecastProvider = Provider<AsyncValue<FinanceForecast>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 6, 1);
  // Quantize `end` to the day so the family key is stable across rebuilds —
  // otherwise DateTime.now() makes a fresh key each build and it loads forever.
  final txA = ref.watch(
    fin.transactionsInRangeProvider((start: start, end: now.atEndOfDay)),
  );
  final accA = ref.watch(fin.accountsStreamProvider);
  final curA = ref.watch(fin.currenciesStreamProvider);
  final balA = ref.watch(fin.accountBalancesStreamProvider);
  final catA = ref.watch(fin.allCategoriesProvider);
  final budA = ref.watch(fin.budgetsStreamProvider);

  final xs = <AsyncValue<Object?>>[txA, accA, curA, balA, catA, budA];
  for (final a in xs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in xs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  return AsyncValue.data(
    ref
        .watch(forecastServiceProvider)
        .buildFinance(
          txs: txA.value ?? const [],
          accounts: accA.value ?? const [],
          currencies: curA.value ?? const [],
          balances: balA.value ?? const {},
          categories: catA.value ?? const [],
          now: now,
          budgets: budA.value ?? const [],
        ),
  );
});

final gymForecastProvider = Provider<AsyncValue<GymForecast>>((ref) {
  final now = DateTime.now();
  final sessA = ref.watch(gym.allSessionsStreamProvider);
  final entA = ref.watch(gym.measurementEntriesStreamProvider);
  final valA = ref.watch(gym.measurementValuesStreamProvider);
  final typA = ref.watch(gym.measurementTypesStreamProvider);
  final exA = ref.watch(gym.allDayExercisesProvider);
  final prA = ref.watch(gym.allPrescriptionsProvider);

  final xs = <AsyncValue<Object?>>[sessA, entA, valA, typA, exA, prA];
  for (final a in xs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in xs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  return AsyncValue.data(
    ref
        .watch(forecastServiceProvider)
        .buildGym(
          sessions: sessA.value ?? const [],
          entries: entA.value ?? const [],
          values: valA.value ?? const [],
          types: typA.value ?? const [],
          now: now,
          exercises: exA.value ?? const [],
          prescriptions: prA.value ?? const [],
        ),
  );
});

final productivityForecastProvider = Provider<AsyncValue<ProductivityForecast>>(
  (ref) {
    final now = DateTime.now();
    final tA = ref.watch(tasks.allTasksStreamProvider);
    if (tA.isLoading && !tA.hasValue) return const AsyncValue.loading();
    if (tA.hasError) {
      return AsyncValue.error(tA.error!, tA.stackTrace ?? StackTrace.current);
    }
    return AsyncValue.data(
      ref
          .watch(forecastServiceProvider)
          .buildProductivity(tasks: tA.value ?? const [], now: now),
    );
  },
);
