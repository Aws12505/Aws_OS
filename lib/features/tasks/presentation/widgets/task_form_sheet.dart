import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';

Future<void> showTaskFormSheet(
  BuildContext context, {
  required String workspaceId,
  String? parentTaskId,
  Task? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Form(
        workspaceId: workspaceId,
        parentTaskId: parentTaskId,
        existing: existing,
      ),
    ),
  );
}

class _Form extends ConsumerStatefulWidget {
  const _Form({
    required this.workspaceId,
    this.parentTaskId,
    this.existing,
  });
  final String workspaceId;
  final String? parentTaskId;
  final Task? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  DateTime? _dueAt;
  DateTime? _deadlineAt;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.bodyMd ?? '');
    _dueAt = e?.dueAt;
    _deadlineAt = e?.deadlineAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return d;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(tasksRepositoryProvider).saveTask(
          id: widget.existing?.id,
          workspaceId: widget.workspaceId,
          parentTaskId: widget.parentTaskId ?? widget.existing?.parentTaskId,
          title: _title.text.trim(),
          bodyMd: _body.text.trim().isEmpty ? null : _body.text.trim(),
          dueAt: _dueAt,
          deadlineAt: _deadlineAt,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? (widget.parentTaskId == null
                        ? 'New task'
                        : 'New subtask')
                    : 'Edit task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  hintText: 'Markdown supported',
                ),
              ),
              const SizedBox(height: 12),
              _DateRow(
                label: 'Due date',
                value: _dueAt,
                onChanged: (d) async {
                  final picked = await _pickDate(d);
                  setState(() => _dueAt = picked);
                },
                onClear: () => setState(() => _dueAt = null),
              ),
              const SizedBox(height: 8),
              _DateRow(
                label: 'Deadline',
                value: _deadlineAt,
                onChanged: (d) async {
                  final picked = await _pickDate(d);
                  setState(() => _deadlineAt = picked);
                },
                onClear: () => setState(() => _deadlineAt = null),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
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

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onChanged(value),
            icon: const Icon(Icons.event),
            label: Text(value == null
                ? '$label: not set'
                : '$label: ${DateFormat.yMMMd().format(value!)}'),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: 'Clear',
          ),
      ],
    );
  }
}
