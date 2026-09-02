import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../../../../shared/widgets/form_sheet.dart';
import '../providers.dart';

Future<void> showExchangeFormSheet(BuildContext context) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _Form(),
    ),
  );
}

class _Form extends ConsumerStatefulWidget {
  const _Form();

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();

  /// What you're converting, in the source currency. This is the only amount
  /// typed by hand — what lands in the destination account is arithmetic, not
  /// a second guess.
  final _fromAmount = TextEditingController();

  /// How much of the destination currency one unit of the source is worth.
  final _rate = TextEditingController();
  final _note = TextEditingController();
  String? _fromId;
  String? _toId;

  /// True right after the pair changes and a past rate has been dropped in as
  /// a starting point, so the computed amount is styled as a suggestion until
  /// the user actually confirms or edits it.
  bool _rateIsSuggested = false;

  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _fromAmount.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() => _rateIsSuggested = false));
  }

  @override
  void dispose() {
    _fromAmount.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await pickDate(context, initial: _date);
    if (d == null) return;
    setState(
        () => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  /// Drops in the most recent rate recorded for this pair, if there is one —
  /// the same "last time" pattern as everywhere else a number gets typed in
  /// this app. Direction matters: a past A→B exchange does not by itself say
  /// what B→A is worth, so only an exact-direction match is offered.
  void _suggestRate(List<ExchangeRate> rates) {
    if (_fromId == null || _toId == null || _rate.text.isNotEmpty) return;
    final accounts = ref.read(accountsStreamProvider).value ?? const [];
    final from = accounts.where((a) => a.id == _fromId).firstOrNull;
    final to = accounts.where((a) => a.id == _toId).firstOrNull;
    if (from == null || to == null || from.currencyId == to.currencyId) {
      return;
    }
    final match = rates
        .where(
          (r) =>
              r.fromCurrencyId == from.currencyId &&
              r.toCurrencyId == to.currencyId,
        )
        .firstOrNull;
    if (match == null) return;
    _rate.text = _trimZeros(match.rate);
    setState(() => _rateIsSuggested = true);
  }

  static String _trimZeros(double v) {
    var s = v.toStringAsFixed(6);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  double? get _fromAmt =>
      double.tryParse(_fromAmount.text.trim().replaceAll(',', '.'));
  double? get _rateVal =>
      double.tryParse(_rate.text.trim().replaceAll(',', '.'));
  double? get _toAmt {
    final f = _fromAmt;
    final r = _rateVal;
    if (f == null || f <= 0 || r == null || r <= 0) return null;
    return f * r;
  }

  Future<void> _save(List<Account> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromId == null || _toId == null) return;
    if (_fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pick two different accounts.'),
      ));
      return;
    }
    final from = accounts.firstWhere((a) => a.id == _fromId);
    final to = accounts.firstWhere((a) => a.id == _toId);
    if (from.currencyId == to.currencyId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Same currency. Use Transfer instead.'),
      ));
      return;
    }
    final fromAmt = _fromAmt;
    final toAmt = _toAmt;
    if (fromAmt == null || fromAmt <= 0 || toAmt == null || toAmt <= 0) return;

    await ref.read(financeRepositoryProvider).recordExchange(
          fromAccountId: from.id,
          fromCurrencyId: from.currencyId,
          fromAmount: fromAmt,
          toAccountId: to.id,
          toCurrencyId: to.currencyId,
          toAmount: toAmt,
          occurredAt: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsStreamProvider).value ?? const <Account>[];
    final currencies =
        ref.watch(currenciesStreamProvider).value ?? const <Currency>[];
    final rates =
        ref.watch(exchangeRatesStreamProvider).value ?? const <ExchangeRate>[];
    final byCur = {for (final c in currencies) c.id: c};
    final fromCur = _fromId == null
        ? null
        : byCur[
            accounts.firstWhere((a) => a.id == _fromId).currencyId];
    final toCur = _toId == null
        ? null
        : byCur[accounts.firstWhere((a) => a.id == _toId).currencyId];

    final toAmt = _toAmt;
    final surfaces = context.surfaces;
    final accent = context.sem.exchange.base;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSheetHeader(
                icon: Icons.swap_horiz_rounded,
                color: accent,
                title: 'Exchange',
              ),
              const SizedBox(height: 16),
              SheetDateTile(
                label: 'Date',
                value: DateFormat.yMMMd().format(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _fromId,
                decoration: const InputDecoration(labelText: 'From account'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                          '${a.name} (${byCur[a.currencyId]?.code ?? '?'})'),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _fromId = v);
                  _suggestRate(rates);
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AmountField(
                controller: _fromAmount,
                label: 'Amount to convert',
                currencySymbol: fromCur?.symbol,
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (n == null || n <= 0) ? 'Required' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _toId,
                decoration: const InputDecoration(labelText: 'To account'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                          '${a.name} (${byCur[a.currencyId]?.code ?? '?'})'),
                    ),
                ],
                onChanged: (v) {
                  setState(() => _toId = v);
                  _suggestRate(rates);
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // The rate, not a second typed amount. Everything the
              // destination account receives falls out of this and the
              // amount above, which is the one thing the user asked to stop
              // computing by hand themselves.
              TextFormField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: Theme.of(context).textTheme.headlineSmall?.weight(
                      FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  labelText: 'Rate',
                  prefixText: fromCur == null || toCur == null
                      ? null
                      : '1 ${fromCur.code} = ',
                  suffixText: toCur?.code,
                  helperText: _rateIsSuggested
                      ? 'Last rate used for this pair — edit if it moved'
                      : null,
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (n == null || n <= 0) ? 'Required' : null;
                },
              ),
              const SizedBox(height: 12),
              AppCard(
                style: CardStyle.well,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(AppSpacing.md + 2),
                child: Row(
                  children: [
                    Icon(Icons.calculate_outlined, color: accent, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        "You'll receive",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: surfaces.textSecondary),
                      ),
                    ),
                    Text(
                      toAmt == null
                          ? '-'
                          : '${NumberFormat.decimalPatternDigits(decimalDigits: toCur?.decimalPlaces ?? 2).format(toAmt)} ${toCur?.symbol ?? toCur?.code ?? ''}',
                      style: context.type.numeric.copyWith(
                        color: toAmt == null
                            ? surfaces.textTertiary
                            : surfaces.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save',
                icon: Icons.save_rounded,
                expand: true,
                onPressed: () => _save(accounts),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
