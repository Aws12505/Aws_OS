import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';

Future<void> showNoteFormSheet(BuildContext context, {Note? existing}) async {
  List<String> initialTags = const [];
  if (existing != null) {
    initialTags = await ProviderScope.containerOf(context, listen: false)
        .read(notesRepositoryProvider)
        .getTagIdsForNote(existing.id);
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _Form(existing: existing, initialTagIds: initialTags),
    ),
  );
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.existing, required this.initialTagIds});
  final Note? existing;
  final List<String> initialTagIds;
  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late DateTime _occurredAt;
  late Set<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.contentMd ?? '');
    _occurredAt = e?.occurredAt ?? DateTime.now();
    _selectedTagIds = widget.initialTagIds.toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _occurredAt = DateTime(
          d.year, d.month, d.day, _occurredAt.hour, _occurredAt.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(notesRepositoryProvider).saveNote(
          id: widget.existing?.id,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          contentMd: _content.text,
          occurredAt: _occurredAt,
          tagIds: _selectedTagIds.toList(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addTagInline() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tag name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dCtx, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final tag = await ref.read(notesRepositoryProvider).saveTag(name: name);
    setState(() => _selectedTagIds.add(tag.id));
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? 'New note' : 'Edit note',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Content (Markdown)',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMd().format(_occurredAt)),
                trailing: const Icon(Icons.event),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Tags',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final t in tags)
                    FilterChip(
                      label: Text(t.name),
                      selected: _selectedTagIds.contains(t.id),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _selectedTagIds.add(t.id);
                        } else {
                          _selectedTagIds.remove(t.id);
                        }
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add tag'),
                    onPressed: _addTagInline,
                  ),
                ],
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
