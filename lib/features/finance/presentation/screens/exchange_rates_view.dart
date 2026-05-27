import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';

class ExchangeRatesView extends ConsumerWidget {
  const ExchangeRatesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(exchangeRatesStreamProvider);
    final currenciesAsync = ref.watch(currenciesStreamProvider);

    return ratesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (rates) {
        if (rates.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No exchange rates yet.\nEvery exchange you record adds a row here.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final currencies = {
          for (final c in (currenciesAsync.value ?? const <Currency>[]))
            c.id: c,
        };
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: rates.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            final r = rates[i];
            final from = currencies[r.fromCurrencyId]?.code ?? '?';
            final to = currencies[r.toCurrencyId]?.code ?? '?';
            final dateStr = DateFormat.yMMMd().add_Hm().format(r.occurredAt);
            final formatted = NumberFormat.decimalPatternDigits(
              decimalDigits: 6,
            ).format(r.rate);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text('1 $from = $formatted $to'),
                subtitle: Text(dateStr),
              ),
            );
          },
        );
      },
    );
  }
}
