import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../../../../shared/widgets/form_sheet.dart';
import '../../data/finance_dao.dart';
import '../../data/finance_repository.dart';
import '../providers.dart';
import 'link_transaction_sheet.dart';

Future<void> showIncomeExpenseFormSheet(
  BuildContext context, {
  required String kind, // 'income' | 'expense'
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Form(kind: kind),
    ),
  );
}

class _LineDraft {
  _LineDraft() : controller = TextEditingController();
  String? accountId;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.kind});
  final String kind;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  final _note = TextEditingController();
  final List<_LineDraft> _lines = [_LineDraft()];
  String? _categoryId;
  String? _typeId;
  final List<TransactionWithLegs> _linkedEntries = [];

  bool get _isExpense => widget.kind == 'expense';

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickDateTime(context, initial: _date);
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _addLink() async {
    final excludeIds = _linkedEntries.map((e) => e.transaction.id).toList();
    final pickedId =
        await showLinkTransactionPicker(context, excludeIds: excludeIds);
    if (pickedId == null || !mounted) return;
    final entry =
        await ref.read(financeRepositoryProvider).getTransactionWithLegs(pickedId);
    if (entry == null || !mounted) return;
    setState(() => _linkedEntries.add(entry));
  }

  Future<void> _save(List<Account> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    final legs = <TxLegDraft>[];
    for (final line in _lines) {
      final accId = line.accountId;
      if (accId == null) continue;
      final raw = line.controller.text.trim();
      final value = double.tryParse(raw);
      if (value == null || value <= 0) continue;
      final account = accounts.firstWhere((a) => a.id == accId);
      legs.add(TxLegDraft(
        accountId: accId,
        currencyId: account.currencyId,
        amount: _isExpense ? -value : value,
      ));
    }
    if (legs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one line with an amount.'),
      ));
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    final newId = await repo.recordIncomeOrExpense(
      kind: widget.kind,
      occurredAt: _date,
      legs: legs,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      categoryId: _categoryId,
      typeId: _typeId,
    );
    for (final entry in _linkedEntries) {
      await repo.linkTransactions(newId, entry.transaction.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final currencies =
        ref.watch(currenciesStreamProvider).value ?? const <Currency>[];
    final accounts = accountsAsync.value ?? const <Account>[];
    final byCurrency = {for (final c in currencies) c.id: c};

    final title = _isExpense ? 'New expense' : 'New income';
    final color = DomainColors.forTxKind(widget.kind);
    final icon = DomainColors.iconForTxKind(widget.kind);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSheetHeader(icon: icon, color: color, title: title),
              const SizedBox(height: 16),
              SheetDateTile(
                label: 'Date',
                value: DateFormat.yMMMd().add_Hm().format(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              const FormSectionLabel('Lines'),
              const SizedBox(height: 8),
              for (var i = 0; i < _lines.length; i++)
                _LineEditor(
                  line: _lines[i],
                  accounts: accounts,
                  currencies: byCurrency,
                  canRemove: _lines.length > 1,
                  onRemove: () => setState(() {
                    _lines.removeAt(i).dispose();
                  }),
                  onChanged: () => setState(() {}),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add line'),
                ),
              ),
              const SizedBox(height: 12),
              _CategoryTypePicker(
                kind: widget.kind,
                categoryId: _categoryId,
                typeId: _typeId,
                onCategoryChanged: (id) {
                  setState(() {
                    _categoryId = id;
                    _typeId = null;
                  });
                },
                onTypeChanged: (id) => setState(() => _typeId = id),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'What was this for?'),
              ),
              const SizedBox(height: 16),
              const FormSectionLabel('Linked transactions'),
              const SizedBox(height: 8),
              if (_linkedEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _linkedEntries)
                        _LinkedChip(
                          entry: entry,
                          onRemove: () =>
                              setState(() => _linkedEntries.remove(entry)),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Link to another transaction'),
                ),
              ),
              const SizedBox(height: 8),
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

class _LinkedChip extends StatelessWidget {
  const _LinkedChip({required this.entry, required this.onRemove});
  final TransactionWithLegs entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tx = entry.transaction;
    final color = DomainColors.forTxKind(tx.kind);
    return Chip(
      avatar: Icon(DomainColors.iconForTxKind(tx.kind), size: 16, color: color),
      label: Text(
        '${DomainColors.labelForTxKind(tx.kind)} · ${DateFormat.MMMd().format(tx.occurredAt)}',
      ),
      onDeleted: onRemove,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
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
    final currency =
        account == null ? null : currencies[account.currencyId];
    final dp = currency?.decimalPlaces ?? 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      overflow: TextOverflow.ellipsis,
                    ),
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
            child: AmountField(
              controller: line.controller,
              currencySymbol: currency?.symbol,
              helperText: dp == 0 ? null : '${dp}dp',
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

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _CategoryTypePicker extends ConsumerWidget {
  const _CategoryTypePicker({
    required this.kind,
    required this.categoryId,
    required this.typeId,
    required this.onCategoryChanged,
    required this.onTypeChanged,
  });

  final String kind;
  final String? categoryId;
  final String? typeId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesByKindProvider(kind)).value ?? const [];
    final types = categoryId == null
        ? const <CategoryType>[]
        : (ref.watch(typesForCategoryProvider(categoryId!)).value ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: categoryId,
          decoration: const InputDecoration(labelText: 'Category (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('— none —')),
            for (final c in cats)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: onCategoryChanged,
        ),
        if (categoryId != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: typeId,
            decoration: const InputDecoration(labelText: 'Type (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— none —')),
              for (final t in types)
                DropdownMenuItem(value: t.id, child: Text(t.name)),
            ],
            onChanged: onTypeChanged,
          ),
        ],
      ],
    );
  }
}
