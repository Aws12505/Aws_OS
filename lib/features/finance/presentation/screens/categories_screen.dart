import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Expense'),
          Tab(text: 'Income'),
        ]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CategoryListView(kind: 'expense'),
          _CategoryListView(kind: 'income'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Category'),
        onPressed: () => _showCategoryForm(
          context,
          kind: _tabs.index == 0 ? 'expense' : 'income',
        ),
      ),
    );
  }
}

class _CategoryListView extends ConsumerWidget {
  const _CategoryListView({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesByKindProvider(kind));
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No $kind categories yet. Tap + to add one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          itemCount: items.length,
          itemBuilder: (_, i) => _CategoryCard(category: items[i]),
        );
      },
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(typesForCategoryProvider(category.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(category.kind == 'expense'
                    ? Icons.trending_down
                    : Icons.trending_up),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        _showCategoryForm(context,
                            kind: category.kind, existing: category);
                      case 'delete':
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: Text('Delete ${category.name}?'),
                            content: const Text(
                                'Types inside will also be removed.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(financeRepositoryProvider)
                              .deleteCategory(category.id);
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const Divider(),
            typesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text(e.toString()),
              data: (types) {
                return Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final t in types)
                      InputChip(
                        label: Text(t.name),
                        onDeleted: () => ref
                            .read(financeRepositoryProvider)
                            .deleteType(t.id),
                        onPressed: () => _showTypeForm(
                          context,
                          categoryId: category.id,
                          existing: t,
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add type'),
                      onPressed: () => _showTypeForm(
                        context,
                        categoryId: category.id,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCategoryForm(
  BuildContext context, {
  required String kind,
  Category? existing,
}) {
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
              existing == null
                  ? 'New ${kind == 'expense' ? 'expense' : 'income'} category'
                  : 'Edit category',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'Food, Rent, Salary, …'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(financeRepositoryProvider).saveCategory(
                      id: existing?.id,
                      kind: kind,
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

Future<void> _showTypeForm(
  BuildContext context, {
  required String categoryId,
  CategoryType? existing,
}) {
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
              existing == null ? 'New type' : 'Edit type',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Brother, Lunch, Bonus, …'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(financeRepositoryProvider).saveType(
                      id: existing?.id,
                      categoryId: categoryId,
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
