import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/recurrence.dart';
import '../../data/finance_repository.dart';
import '../../data/recurrence_service.dart';
import '../providers.dart';

Future<void> showRecurrenceFormSheet(
  BuildContext context, {
  Recurrence? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Form(existing: existing),
    ),
  );
}

class _LineDraft {
  _LineDraft({this.accountId, double? amount})
      : controller = TextEditingController(
          text: amount == null ? '' : amount.toString(),
        );
  String? accountId;
  final TextEditingController controller;
  void dispose() => controller.dispose();
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.existing});
  final Recurrence? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  String _kind = 'expense';
  final _note = TextEditingController();
  late DateTime _startDate;
  RecurrenceFreq _freq = RecurrenceFreq.monthly;
  int _interval = 1;
  String? _categoryId;
  String? _typeId;
  final List<_LineDraft> _lines = [];
  late final List<int> _byWeekday;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _kind = e.kind;
      _note.text = e.noteTemplate ?? '';
      _startDate = e.startDate;
      _categoryId = e.categoryId;
      _typeId = e.typeId;
      final rule = RecurrenceRule.parse(e.ruleJson);
      _freq = rule.freq;
      _interval = rule.interval;
      _byWeekday = [...rule.byWeekday];
      final legs = RecurrenceService.decodeTemplateLegs(e.templateLegsJson);
      _lines.addAll(legs.map((l) => _LineDraft(
            accountId: l.accountId,
            amount: l.amount.abs(),
          )));
    } else {
      _startDate = DateTime.now();
      _byWeekday = [];
      _lines.add(_LineDraft());
    }
  }

  @override
  void dispose() {
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _save(List<Account> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    final legs = <TxLegDraft>[];
    final isExpense = _kind == 'expense';
    for (final line in _lines) {
      final accId = line.accountId;
      if (accId == null) continue;
      final raw = line.controller.text.trim();
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (value == null || value <= 0) continue;
      final account = accounts.firstWhere((a) => a.id == accId);
      legs.add(TxLegDraft(
        accountId: accId,
        currencyId: account.currencyId,
        amount: isExpense ? -value : value,
      ));
    }
    if (legs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one line with an amount.'),
      ));
      return;
    }
    final rule = RecurrenceRule(
      freq: _freq,
      interval: _interval,
      byWeekday: _freq == RecurrenceFreq.weekly ? _byWeekday : const [],
    );
    final repo = ref.read(financeRepositoryProvider);
    final saved = await repo.saveRecurrence(
      id: widget.existing?.id,
      kind: _kind,
      ruleJson: rule.toJson(),
      templateLegsJson: RecurrenceService.encodeTemplateLegs(legs),
      categoryId: _categoryId,
      typeId: _typeId,
      noteTemplate: _note.text.trim().isEmpty ? null : _note.text.trim(),
      startDate: _startDate,
    );
    await ref.read(recurrenceServiceProvider).materializeFor(saved.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsStreamProvider).value ?? const <Account>[];
    final currencies =
        ref.watch(currenciesStreamProvider).value ?? const <Currency>[];
    final byCur = {for (final c in currencies) c.id: c};
    final cats = ref.watch(categoriesByKindProvider(_kind)).value ?? const [];
    final types = _categoryId == null
        ? const <CategoryType>[]
        : (ref.watch(typesForCategoryProvider(_categoryId!)).value ?? const []);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? 'New recurring entry' : 'Edit recurring',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _categoryId = null;
                  _typeId = null;
                }),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.event),
                onTap: _pickStartDate,
              ),
              const SizedBox(height: 8),
              Text('Repeat',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Every'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      initialValue: _interval.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (v) => _interval = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<RecurrenceFreq>(
                    isExpanded: true,
                    value: _freq,
                    onChanged: (v) {
                      if (v != null) setState(() => _freq = v);
                    },
                    items: const [
                      DropdownMenuItem(
                          value: RecurrenceFreq.daily, child: Text('days')),
                      DropdownMenuItem(
                          value: RecurrenceFreq.weekly, child: Text('weeks')),
                      DropdownMenuItem(
                          value: RecurrenceFreq.monthly, child: Text('months')),
                      DropdownMenuItem(
                          value: RecurrenceFreq.yearly, child: Text('years')),
                    ],
                    ),
                  ),
                ],
              ),
              if (_freq == RecurrenceFreq.weekly) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                        label: Text(_dayLabel(i)),
                        selected: _byWeekday.contains(i),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _byWeekday.add(i);
                          } else {
                            _byWeekday.remove(i);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Text('Default amount(s)',
                  style: Theme.of(context).textTheme.titleSmall),
              for (var i = 0; i < _lines.length; i++)
                _LineRow(
                  line: _lines[i],
                  accounts: accounts,
                  currencies: byCur,
                  canRemove: _lines.length > 1,
                  onRemove: () => setState(() {
                    _lines.removeAt(i).dispose();
                  }),
                  onChanged: () => setState(() {}),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add line'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— none —')),
                  for (final c in cats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() {
                  _categoryId = v;
                  _typeId = null;
                }),
              ),
              if (_categoryId != null) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _typeId,
                  decoration: const InputDecoration(labelText: 'Type (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— none —')),
                    for (final t in types)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _typeId = v),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note template (optional)',
                    hintText: 'Applied to each generated occurrence'),
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

  String _dayLabel(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.accounts,
    required this.currencies,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });
  final _LineDraft line;
  final List<Account> accounts;
  final Map<String, Currency> currencies;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final account =
        accounts.where((a) => a.id == line.accountId).firstOrNull;
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
                        '${a.name} (${currencies[a.currencyId]?.code ?? '?'})',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                line.accountId = v;
                onChanged();
              },
              validator: (v) => v == null ? 'Required' : null,
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
                labelText: 'Default amount',
                suffixText: currency?.symbol ?? '',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return '> 0';
                return null;
              },
            ),
          ),
          IconButton(
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

extension _Iter<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
