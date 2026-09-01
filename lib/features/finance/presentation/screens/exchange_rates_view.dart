import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../providers.dart';
import '../../../../shared/widgets/app_card.dart';

class ExchangeRatesView extends ConsumerWidget {
  const ExchangeRatesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(exchangeRatesStreamProvider);
    final currenciesAsync = ref.watch(currenciesStreamProvider);

    return ratesAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(error: e),
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
          padding: const EdgeInsets.only(bottom: AppInsets.listBottomNoFab),
          itemCount: rates.length,
          separatorBuilder: (_, _) =>
              const AppRule(indent: AppSpacing.xl, endIndent: AppSpacing.xl),
          itemBuilder: (_, i) {
            final r = rates[i];
            final from = currencies[r.fromCurrencyId]?.code ?? '?';
            final to = currencies[r.toCurrencyId]?.code ?? '?';
            final dateStr = DateFormat.yMMMd().add_Hm().format(r.occurredAt);
            final formatted = NumberFormat.decimalPatternDigits(
              decimalDigits: 6,
            ).format(r.rate);
            return ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(
                '1 $from = $formatted $to',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(dateStr),
            );
          },
        );
      },
    );
  }
}
