import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';

Future<void> showTransferFormSheet(BuildContext context) {
  return showModalBottomSheet<void>(
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
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _fromId;
  String? _toId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => _date = DateTime(d.year, d.month, d.day,
        _date.hour, _date.minute));
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
    if (from.currencyId != to.currencyId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Different currencies — use Exchange instead of Transfer.'),
      ));
      return;
    }
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;

    await ref.read(financeRepositoryProvider).recordTransfer(
          fromAccountId: from.id,
          toAccountId: to.id,
          currencyId: from.currencyId,
          amount: amount,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Transfer',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text('${_date.toLocal()}'.split('.').first),
                trailing: const Icon(Icons.event),
                onTap: _pickDate,
              ),
              DropdownButtonFormField<String>(
                initialValue: _fromId,
                decoration: const InputDecoration(labelText: 'From account'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.name} (${byCur[a.currencyId]?.code ?? '?'})',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _fromId = v),
                validator: (v) => v == null ? 'Required' : null,
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
                        '${a.name} (${byCur[a.currencyId]?.code ?? '?'})',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _toId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (n == null || n <= 0) ? 'Enter a positive number' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _save(accounts),
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
