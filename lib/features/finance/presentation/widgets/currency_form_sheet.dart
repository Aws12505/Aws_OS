import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../providers.dart';

Future<void> showCurrencyFormSheet(BuildContext context,
    {Currency? existing}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _CurrencyForm(existing: existing),
    ),
  );
}

class _CurrencyForm extends ConsumerStatefulWidget {
  const _CurrencyForm({this.existing});
  final Currency? existing;

  @override
  ConsumerState<_CurrencyForm> createState() => _CurrencyFormState();
}

class _CurrencyFormState extends ConsumerState<_CurrencyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _symbol;
  late int _decimals;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _symbol = TextEditingController(text: e?.symbol ?? '');
    _decimals = e?.decimalPlaces ?? 2;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _symbol.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(financeRepositoryProvider).saveCurrency(
          id: widget.existing?.id,
          code: _code.text.trim().toUpperCase(),
          symbol: _symbol.text.trim(),
          decimalPlaces: _decimals,
          isActive: _active,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New currency' : 'Edit currency',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Code', hintText: 'USD, SYP, EUR…'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _symbol,
              decoration: const InputDecoration(
                  labelText: 'Symbol', hintText: '\$, ل.س, €'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Decimals'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 6,
                    divisions: 6,
                    value: _decimals.toDouble(),
                    label: '$_decimals',
                    onChanged: (v) => setState(() => _decimals = v.round()),
                  ),
                ),
                Text('$_decimals'),
              ],
            ),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Active'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
