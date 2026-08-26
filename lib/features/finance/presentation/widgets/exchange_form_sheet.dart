import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
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
  final _fromAmount = TextEditingController();
  final _toAmount = TextEditingController();
  final _note = TextEditingController();
  String? _fromId;
  String? _toId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _fromAmount.addListener(() => setState(() {}));
    _toAmount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fromAmount.dispose();
    _toAmount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await pickDate(context, initial: _date);
    if (d == null) return;
    setState(
        () => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
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
    final fromAmt = double.tryParse(_fromAmount.text.replaceAll(',', '.'));
    final toAmt = double.tryParse(_toAmount.text.replaceAll(',', '.'));
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
    final byCur = {for (final c in currencies) c.id: c};
    final fromCur = _fromId == null
        ? null
        : byCur[
            accounts.firstWhere((a) => a.id == _fromId).currencyId];
    final toCur = _toId == null
        ? null
        : byCur[accounts.firstWhere((a) => a.id == _toId).currencyId];

    final fromAmt = double.tryParse(_fromAmount.text.replaceAll(',', '.'));
    final toAmt = double.tryParse(_toAmount.text.replaceAll(',', '.'));
    final rateText = (fromAmt != null && fromAmt > 0 && toAmt != null)
        ? '1 ${fromCur?.code ?? '?'} = ${NumberFormat.decimalPatternDigits(decimalDigits: 6).format(toAmt / fromAmt)} ${toCur?.code ?? '?'}'
        : '-';

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
                color: context.sem.exchange.base,
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
                onChanged: (v) => setState(() => _fromId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AmountField(
                controller: _fromAmount,
                label: 'From amount',
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
                onChanged: (v) => setState(() => _toId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AmountField(
                controller: _toAmount,
                label: 'To amount',
                currencySymbol: toCur?.symbol,
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (n == null || n <= 0) ? 'Required' : null;
                },
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rate: $rateText',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
