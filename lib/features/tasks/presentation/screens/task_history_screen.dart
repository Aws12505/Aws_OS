import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';

class TaskHistoryScreen extends ConsumerWidget {
  const TaskHistoryScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskHistoryStreamProvider(taskId));
    return Scaffold(
      appBar: AppBar(title: const Text('Task history')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final h = items[i];
              return ListTile(
                leading: Icon(_iconFor(h.action)),
                title: Text(_labelFor(h.action)),
                subtitle: Text(DateFormat.yMMMd().add_Hm().format(h.at)),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String action) => switch (action) {
        'created' => Icons.add_circle_outline,
        'completed' => Icons.check_circle_outline,
        'uncompleted' => Icons.radio_button_unchecked,
        'edited' => Icons.edit,
        'deleted' => Icons.delete_outline,
        _ => Icons.history,
      };

  String _labelFor(String action) => switch (action) {
        'created' => 'Created',
        'completed' => 'Marked complete',
        'uncompleted' => 'Marked incomplete',
        'edited' => 'Edited',
        'deleted' => 'Deleted',
        _ => action,
      };
}
