import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../providers.dart';

Future<void> showWorkspaceFormSheet(BuildContext context,
    {Workspace? existing}) {
  final controller = TextEditingController(text: existing?.name ?? '');
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Consumer(builder: (ctx2, ref, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'New workspace' : 'Edit workspace',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Work, Family, Personal, …',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(tasksRepositoryProvider).saveWorkspace(
                      id: existing?.id,
                      name: name,
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    ),
  );
}
