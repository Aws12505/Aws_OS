import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../data/finance_repository.dart';
import '../../data/recurrence_service.dart';
import '../providers.dart';

Future<void> showConfirmOccurrenceSheet(
  BuildContext context, {
  required ScheduledOccurrence occurrence,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Sheet(occurrence: occurrence),
    ),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.occurrence});
  final ScheduledOccurrence occurrence;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late Future<Recurrence?> _recFuture;
  Recurrence? _rec;
  late DateTime _date;
  final _note = TextEditingController();
  final List<_LineDraft> _lines = [];

  @override
  void initState() {
    super.initState();
    _date = widget.occurrence.dueAt;
    _recFuture = ref
        .read(financeRepositoryProvider)
        .getRecurrence(widget.occurrence.recurrenceId);
    _recFuture.then((r) {
      if (!mounted || r == null) return;
      setState(() {
        _rec = r;
        _note.text = r.noteTemplate ?? '';
        final tpl = RecurrenceService.decodeTemplateLegs(r.templateLegsJson);
        _lines
          ..clear()
          ..addAll(tpl.map((l) => _LineDraft(
                accountId: l.accountId,
                currencyId: l.currencyId,
                amount: l.amount.abs(),
              )));
      });
    });
  }

  @override
  void dispose() {
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm(List<Account> accounts) async {
    final rec = _rec;
    if (rec == null) return;
    final overrideLegs = <TxLegDraft>[];
    final isExpense = rec.kind == 'expense';
    for (final line in _lines) {
      final accId = line.accountId;
      final currencyId = line.currencyId;
      if (accId == null || currencyId == null) continue;
      final raw = line.controller.text.trim();
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (value == null || value <= 0) continue;
      overrideLegs.add(TxLegDraft(
        accountId: accId,
        currencyId: currencyId,
        amount: isExpense ? -value : value,
      ));
    }
    if (overrideLegs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount for at least one account.'),
        ),
      );
      return;
    }
    try {
      await ref.read(recurrenceServiceProvider).confirmOccurrence(
            widget.occurrence.id,
            overrideLegs: overrideLegs,
            overrideNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
            overrideDate: _date,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: $e')),
      );
    }
  }

  Future<void> _skip() async {
    try {
      await ref
          .read(recurrenceServiceProvider)
          .skipOccurrence(widget.occurrence.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not skip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsIncludingArchivedStreamProvider).value ??
        const <Account>[];
    final currencies =
        ref.watch(currenciesStreamProvider).value ?? const <Currency>[];
    final byCur = {for (final c in currencies) c.id: c};
    final rec = _rec;
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Confirm occurrence',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              rec == null
                  ? 'Loading…'
                  : '${rec.kind == 'expense' ? 'Expense' : 'Income'} due ${DateFormat.yMMMd().format(widget.occurrence.dueAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Effective date'),
                      subtitle:
                          Text(DateFormat.yMMMd().add_Hm().format(_date)),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setState(() => _date = DateTime(
                              d.year, d.month, d.day, _date.hour, _date.minute));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _lines.length; i++)
                      _LineRow(
                        line: _lines[i],
                        accounts: accounts,
                        currencies: byCur,
                        onChanged: () => setState(() {}),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Leave the amount as-is to confirm the usual amount, '
                      'or edit it to record a different amount this month.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _note,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Note (optional)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _skip,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip this month'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirm(accounts),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineDraft {
  _LineDraft({this.accountId, this.currencyId, double? amount})
      : controller = TextEditingController(
          text: amount == null ? '' : amount.toString(),
        );
  String? accountId;
  String? currencyId;
  final TextEditingController controller;
  void dispose() => controller.dispose();
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.accounts,
    required this.currencies,
    required this.onChanged,
  });
  final _LineDraft line;
  final List<Account> accounts;
  final Map<String, Currency> currencies;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final account = accounts.where((a) => a.id == line.accountId).firstOrNull;
    final currency = account == null ? null : currencies[account.currencyId];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: line.accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(
                        '${a.name} (${currencies[a.currencyId]?.code ?? '?'})'
                        '${a.archived ? ' — archived' : ''}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                line.accountId = v;
                line.currencyId = accounts.where((a) => a.id == v).firstOrNull?.currencyId;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: line.controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: currency?.symbol ?? '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _Iter<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
