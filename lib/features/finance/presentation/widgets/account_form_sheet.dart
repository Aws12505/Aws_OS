import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/form_sheet.dart';
import '../providers.dart';

Future<void> showAccountFormSheet(BuildContext context, {Account? existing}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AccountForm(existing: existing),
    ),
  );
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.existing});
  final Account? existing;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _kind;
  late final TextEditingController _note;
  String? _currencyId;
  late bool _archived;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _kind = TextEditingController(text: e?.kind ?? 'cash');
    _note = TextEditingController(text: e?.note ?? '');
    _currencyId = e?.currencyId;
    _archived = e?.archived ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _kind.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currencyId == null) return;
    await ref.read(financeRepositoryProvider).saveAccount(
          id: widget.existing?.id,
          name: _name.text.trim(),
          currencyId: _currencyId!,
          kind: _kind.text.trim().isEmpty ? 'cash' : _kind.text.trim(),
          archived: _archived,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currencies = ref.watch(currenciesStreamProvider).value ?? const [];
    if (currencies.isNotEmpty && _currencyId == null) {
      _currencyId = currencies.first.id;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSheetHeader(
              icon: Icons.account_balance_wallet_rounded,
              color: DomainColors.tasks,
              title: widget.existing == null ? 'New account' : 'Edit account',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Cash USD, Bank SYP, Wallet…'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currencyId,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: [
                for (final c in currencies)
                  DropdownMenuItem(
                      value: c.id, child: Text('${c.code} (${c.symbol})')),
              ],
              onChanged: (v) => setState(() => _currencyId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kind,
              decoration: const InputDecoration(
                  labelText: 'Kind',
                  hintText: 'cash, bank, wallet…'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
            SwitchListTile(
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
              title: const Text('Archived'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Save',
              icon: Icons.save_rounded,
              expand: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
