import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../data/task_recurrence_service.dart';
import '../providers.dart';

Future<void> showTaskFormSheet(
  BuildContext context, {
  required String workspaceId,
  String? parentTaskId,
  Task? existing,
}) {
  return showAppModalBottomSheet<void>(
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
  late final TextEditingController _category;
  DateTime? _dueAt;
  DateTime? _deadlineAt;

  // Recurrence (top-level tasks only).
  RecurrenceFreq? _freq;
  int _interval = 1;
  final Set<int> _byWeekday = {};

  /// Anchor date of an existing recurrence — preserved across edits so editing
  /// a single occurrence never silently redefines the whole series.
  DateTime? _recStartDate;

  /// True while we load an existing recurrence to prefill the controls.
  bool _loadingRecurrence = false;

  bool get _isSubtask =>
      widget.parentTaskId != null || widget.existing?.parentTaskId != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.bodyMd ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _dueAt = e?.dueAt;
    _deadlineAt = e?.deadlineAt;
    if (e?.recurrenceId != null) _prefillRecurrence(e!.recurrenceId!);
  }

  Future<void> _prefillRecurrence(String recurrenceId) async {
    setState(() => _loadingRecurrence = true);
    final rec =
        await ref.read(tasksRepositoryProvider).getRecurrence(recurrenceId);
    if (!mounted) return;
    setState(() {
      _loadingRecurrence = false;
      if (rec == null || rec.endedAt != null) return;
      _recStartDate = rec.startDate;
      final rule = RecurrenceRule.parse(rec.ruleJson);
      _freq = rule.freq;
      _interval = rule.interval;
      _byWeekday
        ..clear()
        ..addAll(rule.byWeekday);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _category.dispose();
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
    final repo = ref.read(tasksRepositoryProvider);
    final category =
        _category.text.trim().isEmpty ? null : _category.text.trim();

    // Resolve recurrence intent for top-level tasks.
    final existingRecId = widget.existing?.recurrenceId;
    String? recurrenceId = existingRecId;
    var dueAt = _dueAt;
    if (!_isSubtask) {
      final wantsRecurrence = _freq != null;
      if (wantsRecurrence) {
        // A recurring task is itself an occurrence, so it needs a due date.
        dueAt ??= DateTime.now();
        final rule = RecurrenceRule(
          freq: _freq!,
          interval: _interval < 1 ? 1 : _interval,
          byWeekday: _freq == RecurrenceFreq.weekly
              ? (_byWeekday.toList()..sort())
              : const [],
        );
        final template = TaskRecurrenceService.encodeTemplate(
          workspaceId: widget.workspaceId,
          title: _title.text.trim(),
          bodyMd: _body.text.trim().isEmpty ? null : _body.text.trim(),
          category: category,
        );
        // Keep the series anchored to its original start on edit; for a new
        // recurrence, anchor it to this task's due date.
        final startDate = _recStartDate ?? dueAt;
        final rec = await repo.upsertRecurrence(
          id: existingRecId,
          ruleJson: rule.toJson(),
          templateJson: template,
          startDate: startDate,
        );
        recurrenceId = rec.id;
      } else if (existingRecId != null) {
        // User turned recurrence off — stop generating new occurrences.
        await repo.endRecurrence(existingRecId);
      }
    }

    final saved = await repo.saveTask(
      id: widget.existing?.id,
      workspaceId: widget.workspaceId,
      parentTaskId: widget.parentTaskId ?? widget.existing?.parentTaskId,
      title: _title.text.trim(),
      bodyMd: _body.text.trim().isEmpty ? null : _body.text.trim(),
      category: category,
      dueAt: dueAt,
      deadlineAt: _deadlineAt,
      recurrenceId: recurrenceId,
    );

    // Top up future occurrences for an active recurrence.
    if (!_isSubtask && _freq != null && recurrenceId != null) {
      await ref
          .read(taskRecurrenceServiceProvider)
          .materializeFor(recurrenceId);
    }

    if (!mounted) return;
    // Avoid an unused-variable lint when not needed downstream.
    assert(saved.id.isNotEmpty);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider);
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
                    ? (_isSubtask ? 'New subtask' : 'New task')
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
              _CategoryField(
                controller: _category,
                existing: categories,
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
              if (!_isSubtask) ...[
                const SizedBox(height: 16),
                _RecurrenceSection(
                  loading: _loadingRecurrence,
                  freq: _freq,
                  interval: _interval,
                  byWeekday: _byWeekday,
                  onFreqChanged: (f) => setState(() => _freq = f),
                  onIntervalChanged: (n) => _interval = n,
                  onWeekdayToggled: (d, sel) => setState(() {
                    if (sel) {
                      _byWeekday.add(d);
                    } else {
                      _byWeekday.remove(d);
                    }
                  }),
                ),
              ],
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

/// Category text field with one-tap chips for previously-used categories.
class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.controller, required this.existing});
  final TextEditingController controller;
  final List<String> existing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category (optional)',
            hintText: 'e.g. Work, Home, Errands',
            prefixIcon: Icon(Icons.label_outline_rounded),
          ),
        ),
        if (existing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in existing)
                ActionChip(
                  label: Text(c),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.text = c,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecurrenceSection extends StatelessWidget {
  const _RecurrenceSection({
    required this.loading,
    required this.freq,
    required this.interval,
    required this.byWeekday,
    required this.onFreqChanged,
    required this.onIntervalChanged,
    required this.onWeekdayToggled,
  });

  final bool loading;
  final RecurrenceFreq? freq;
  final int interval;
  final Set<int> byWeekday;
  final ValueChanged<RecurrenceFreq?> onFreqChanged;
  final ValueChanged<int> onIntervalChanged;
  final void Function(int weekday, bool selected) onWeekdayToggled;

  String _unitLabel(RecurrenceFreq f) {
    final plural = interval > 1;
    switch (f) {
      case RecurrenceFreq.daily:
        return plural ? 'days' : 'day';
      case RecurrenceFreq.weekly:
        return plural ? 'weeks' : 'week';
      case RecurrenceFreq.monthly:
        return plural ? 'months' : 'month';
      case RecurrenceFreq.yearly:
        return plural ? 'years' : 'year';
    }
  }

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Repeat', style: tt.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceFreq?>(
          initialValue: freq,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.repeat_rounded),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Does not repeat')),
            DropdownMenuItem(
                value: RecurrenceFreq.daily, child: Text('Daily')),
            DropdownMenuItem(
                value: RecurrenceFreq.weekly, child: Text('Weekly')),
            DropdownMenuItem(
                value: RecurrenceFreq.monthly, child: Text('Monthly')),
            DropdownMenuItem(
                value: RecurrenceFreq.yearly, child: Text('Yearly')),
          ],
          onChanged: loading ? null : onFreqChanged,
        ),
        if (freq != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Every'),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextFormField(
                  initialValue: interval.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onIntervalChanged(int.tryParse(v) ?? 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_unitLabel(freq!))),
            ],
          ),
          if (freq == RecurrenceFreq.weekly) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(_dayLabels[i - 1]),
                    selected: byWeekday.contains(i),
                    onSelected: (sel) => onWeekdayToggled(i, sel),
                  ),
              ],
            ),
          ],
        ],
      ],
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
