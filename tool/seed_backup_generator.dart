import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  final rnd = Random(20260530);
  final dateMin = DateTime(2026, 5, 1);
  final dateMax = DateTime(2026, 5, 31, 23, 59, 59);

  DateTime randomDate() {
    final span =
        dateMax.millisecondsSinceEpoch - dateMin.millisecondsSinceEpoch;
    final offset = rnd.nextInt(span + 1);
    return DateTime.fromMillisecondsSinceEpoch(
      dateMin.millisecondsSinceEpoch + offset,
    );
  }

  int ts(DateTime d) => d.millisecondsSinceEpoch;

  Map<String, dynamic> syncable(
    Map<String, dynamic> fields, {
    DateTime? createdAt,
  }) {
    final created = createdAt ?? randomDate();
    final updated = created.add(Duration(minutes: rnd.nextInt(1440)));
    return {
      'id': _uuid.v4(),
      'created_at': ts(created),
      'updated_at': ts(updated),
      ...fields,
    };
  }

  final appSettings = <Map<String, dynamic>>[
    {'key': 'theme.primary', 'value': '4283123353'},
    {'key': 'theme.accent', 'value': '4278255386'},
    {'key': 'theme.mode', 'value': 'system'},
    {'key': 'theme.font', 'value': 'Inter'},
    {'key': 'theme.scale', 'value': '1.00'},
  ];

  final currencies = <Map<String, dynamic>>[];
  final currencyIds = <String>[];
  void addCurrency(String code, String symbol, int decimals, int sortOrder) {
    final row = syncable({
      'code': code,
      'symbol': symbol,
      'decimal_places': decimals,
      'is_active': 1,
      'sort_order': sortOrder,
    }, createdAt: DateTime(2026, 5, 1, 9));
    currencies.add(row);
    currencyIds.add(row['id'] as String);
  }

  addCurrency('USD', '\$', 2, 0);
  addCurrency('EUR', 'EUR', 2, 1);
  addCurrency('GBP', 'GBP', 2, 2);
  addCurrency('JPY', 'JPY', 0, 3);
  addCurrency('EGP', 'EGP', 2, 4);
  addCurrency('SAR', 'SAR', 2, 5);

  final accounts = <Map<String, dynamic>>[];
  final accountIds = <String>[];
  final accountNames = <String>[
    'Cash Wallet',
    'Main Checking',
    'Savings Vault',
    'Travel Card',
    'Side Hustle',
    'Emergency Fund',
  ];
  for (var i = 0; i < accountNames.length; i++) {
    final row = syncable({
      'name': accountNames[i],
      'currency_id': currencyIds[i % currencyIds.length],
      'kind': i == 3 ? 'card' : 'cash',
      'color': 0xFF000000 + rnd.nextInt(0x00FFFFFF),
      'icon': 'account_${i + 1}',
      'archived': 0,
      'sort_order': i,
      'note': i.isEven ? 'Primary money bucket.' : null,
    });
    accounts.add(row);
    accountIds.add(row['id'] as String);
  }

  final categories = <Map<String, dynamic>>[];
  final categoryIds = <String>[];
  final categorySeeds = <Map<String, String>>[
    {'name': 'Groceries', 'kind': 'expense'},
    {'name': 'Dining', 'kind': 'expense'},
    {'name': 'Transport', 'kind': 'expense'},
    {'name': 'Utilities', 'kind': 'expense'},
    {'name': 'Rent', 'kind': 'expense'},
    {'name': 'Salary', 'kind': 'income'},
    {'name': 'Investments', 'kind': 'income'},
    {'name': 'Gifts', 'kind': 'income'},
  ];
  for (var i = 0; i < categorySeeds.length; i++) {
    final seed = categorySeeds[i];
    final row = syncable({
      'name': seed['name'],
      'kind': seed['kind'],
      'color': 0xFF000000 + rnd.nextInt(0x00FFFFFF),
      'icon': 'cat_${i + 1}',
      'sort_order': i,
    });
    categories.add(row);
    categoryIds.add(row['id'] as String);
  }

  final categoryTypes = <Map<String, dynamic>>[];
  final categoryTypeIds = <String>[];
  for (var i = 0; i < categories.length; i++) {
    final catId = categories[i]['id'] as String;
    for (var j = 0; j < 3; j++) {
      final row = syncable({
        'category_id': catId,
        'name': '${categories[i]['name']} Type ${j + 1}',
        'sort_order': j,
      });
      categoryTypes.add(row);
      categoryTypeIds.add(row['id'] as String);
    }
  }

  final workspaces = <Map<String, dynamic>>[];
  final workspaceIds = <String>[];
  final workspaceNames = <String>['Personal', 'Work', 'Side Project', 'Family'];
  for (var i = 0; i < workspaceNames.length; i++) {
    final row = syncable({
      'name': workspaceNames[i],
      'color': 0xFF000000 + rnd.nextInt(0x00FFFFFF),
      'icon': 'ws_${i + 1}',
      'sort_order': i,
    });
    workspaces.add(row);
    workspaceIds.add(row['id'] as String);
  }

  String ruleJson(
    String freq, {
    int interval = 1,
    List<int>? byWeekday,
    DateTime? until,
  }) {
    final data = <String, dynamic>{
      'freq': freq,
      'interval': interval,
      if (byWeekday != null && byWeekday.isNotEmpty) 'byWeekday': byWeekday,
      if (until != null) 'until': until.toIso8601String(),
    };
    return jsonEncode(data);
  }

  final taskRecurrences = <Map<String, dynamic>>[];
  final taskRecurrenceIds = <String>[];
  for (var i = 0; i < 6; i++) {
    final row = syncable({
      'rule_json': ruleJson('weekly', byWeekday: [1, 3, 5]),
      'template_json': jsonEncode({
        'title': 'Recurring Task ${i + 1}',
        'bodyMd': 'Autogenerated template for task ${i + 1}.',
      }),
      'start_date': ts(DateTime(2026, 5, 1 + i)),
      'next_due_at': ts(DateTime(2026, 5, 5 + i)),
      'ended_at': null,
    });
    taskRecurrences.add(row);
    taskRecurrenceIds.add(row['id'] as String);
  }

  final tasks = <Map<String, dynamic>>[];
  final taskIds = <String>[];
  final taskHistory = <Map<String, dynamic>>[];
  var taskSort = 0;
  for (var w = 0; w < workspaceIds.length; w++) {
    for (var i = 0; i < 12; i++) {
      final due = DateTime(2026, 5, 2 + (i % 25), 9 + (i % 6));
      final completed = rnd.nextBool() && i % 3 == 0;
      final row = syncable({
        'workspace_id': workspaceIds[w],
        'parent_task_id': null,
        'title': 'Task ${w + 1}.${i + 1}',
        'body_md': i.isEven ? 'Details for task ${w + 1}.${i + 1}.' : null,
        'due_at': ts(due),
        'deadline_at': ts(due.add(const Duration(hours: 6))),
        'is_completed': completed ? 1 : 0,
        'completed_at': completed
            ? ts(due.add(const Duration(hours: 2)))
            : null,
        'recurrence_id': i % 5 == 0
            ? taskRecurrenceIds[i % taskRecurrenceIds.length]
            : null,
        'sort_order': taskSort++,
      });
      tasks.add(row);
      taskIds.add(row['id'] as String);

      final createdHist = syncable({
        'task_id': row['id'],
        'action': 'created',
        'at': ts(due.subtract(const Duration(hours: 2))),
        'snapshot_json': jsonEncode({'title': row['title']}),
      });
      taskHistory.add(createdHist);
      if (completed) {
        taskHistory.add(
          syncable({
            'task_id': row['id'],
            'action': 'completed',
            'at': ts(due.add(const Duration(hours: 2))),
            'snapshot_json': null,
          }),
        );
      }
    }
  }

  final measurementTypes = <Map<String, dynamic>>[];
  final measurementTypeIds = <String>[];
  final measurementSeeds = <Map<String, String?>>[
    {'name': 'Weight', 'unit': 'kg'},
    {'name': 'Body Fat', 'unit': '%'},
    {'name': 'Waist', 'unit': 'cm'},
    {'name': 'Sleep', 'unit': 'hrs'},
    {'name': 'Hydration', 'unit': 'L'},
  ];
  for (var i = 0; i < measurementSeeds.length; i++) {
    final row = syncable({
      'name': measurementSeeds[i]['name'],
      'unit': measurementSeeds[i]['unit'],
      'sort_order': i,
    });
    measurementTypes.add(row);
    measurementTypeIds.add(row['id'] as String);
  }

  final measurementEntries = <Map<String, dynamic>>[];
  final measurementEntryIds = <String>[];
  for (var i = 0; i < 32; i++) {
    final taken = DateTime(2026, 5, 1 + i, 7 + (i % 3));
    final row = syncable({
      'taken_at': ts(taken),
      'note': i % 5 == 0 ? 'Felt strong today.' : null,
    });
    measurementEntries.add(row);
    measurementEntryIds.add(row['id'] as String);
  }

  final measurementValues = <Map<String, dynamic>>[];
  for (var i = 0; i < measurementEntryIds.length; i++) {
    for (var t = 0; t < measurementTypeIds.length; t++) {
      final value = 50 + rnd.nextDouble() * 40 + t * 3;
      measurementValues.add(
        syncable({
          'entry_id': measurementEntryIds[i],
          'type_id': measurementTypeIds[t],
          'value': double.parse(value.toStringAsFixed(2)),
        }),
      );
    }
  }

  final programs = <Map<String, dynamic>>[];
  final programIds = <String>[];
  for (var i = 0; i < 3; i++) {
    final row = syncable({
      'name': 'Program ${i + 1}',
      'started_at': ts(DateTime(2026, 5, 1 + i * 3)),
      'ended_at': null,
      'note': 'Training block ${i + 1}.',
    });
    programs.add(row);
    programIds.add(row['id'] as String);
  }

  final programDays = <Map<String, dynamic>>[];
  final programDayIds = <String>[];
  for (var i = 0; i < programIds.length; i++) {
    for (var d = 0; d < 4; d++) {
      final row = syncable({
        'program_id': programIds[i],
        'name': 'Day ${d + 1}',
        'position': d,
      });
      programDays.add(row);
      programDayIds.add(row['id'] as String);
    }
  }

  final supersetGroups = <Map<String, dynamic>>[];
  final supersetGroupIds = <String>[];
  for (var i = 0; i < programDayIds.length; i++) {
    for (var g = 0; g < 2; g++) {
      final row = syncable({
        'day_id': programDayIds[i],
        'position': g,
        'target_sets': 3,
      });
      supersetGroups.add(row);
      supersetGroupIds.add(row['id'] as String);
    }
  }

  final dayExercises = <Map<String, dynamic>>[];
  final dayExerciseIds = <String>[];
  final exerciseNames = <String>[
    'Squat',
    'Bench Press',
    'Deadlift',
    'Overhead Press',
    'Row',
    'Pull Up',
    'Lunge',
    'Curl',
  ];
  for (var i = 0; i < programDayIds.length; i++) {
    for (var e = 0; e < 4; e++) {
      final row = syncable({
        'day_id': programDayIds[i],
        'superset_group_id': e < 2
            ? supersetGroupIds[(i * 2) % supersetGroupIds.length]
            : null,
        'position': e,
        'exercise_name': exerciseNames[(i + e) % exerciseNames.length],
        'target_sets': 3 + (e % 2),
      });
      dayExercises.add(row);
      dayExerciseIds.add(row['id'] as String);
    }
  }

  final setPrescriptions = <Map<String, dynamic>>[];
  for (var i = 0; i < dayExerciseIds.length; i++) {
    for (var s = 0; s < 3; s++) {
      final row = syncable({
        'day_exercise_id': dayExerciseIds[i],
        'set_index': s,
        'reps': 6 + s * 2,
        'weight': 20 + rnd.nextInt(80) + s * 5,
        'effective_from': ts(DateTime(2026, 5, 1 + (i % 20))),
      });
      setPrescriptions.add(row);
    }
  }

  final daySessions = <Map<String, dynamic>>[];
  for (var i = 0; i < programDayIds.length; i++) {
    for (var s = 0; s < 2; s++) {
      final played = DateTime(2026, 5, 3 + (i % 20), 17 + s, 30);
      daySessions.add(
        syncable({
          'program_day_id': programDayIds[i],
          'played_at': ts(played),
          'note': s == 1 ? 'Felt good. Increased weight.' : null,
        }),
      );
    }
  }

  String encodeLegs(List<Map<String, dynamic>> legs) => jsonEncode(legs);

  final recurrences = <Map<String, dynamic>>[];
  final recurrenceIds = <String>[];
  for (var i = 0; i < 8; i++) {
    final accId = accountIds[i % accountIds.length];
    final curId = currencyIds[i % currencyIds.length];
    final row = syncable({
      'kind': i.isEven ? 'expense' : 'income',
      'rule_json': ruleJson('weekly', byWeekday: [2, 4]),
      'template_legs_json': encodeLegs([
        {
          'accountId': accId,
          'currencyId': curId,
          'amount': i.isEven ? -45.0 - i : 120.0 + i,
        },
      ]),
      'category_id': categoryIds[i % categoryIds.length],
      'type_id': categoryTypeIds[i % categoryTypeIds.length],
      'note_template': i.isEven
          ? 'Recurring expense ${i + 1}'
          : 'Recurring income ${i + 1}',
      'start_date': ts(DateTime(2026, 5, 1 + i)),
      'next_due_at': ts(DateTime(2026, 5, 3 + i)),
      'ended_at': null,
    });
    recurrences.add(row);
    recurrenceIds.add(row['id'] as String);
  }

  final scheduledOccurrences = <Map<String, dynamic>>[];
  for (var i = 0; i < recurrenceIds.length; i++) {
    for (var o = 0; o < 4; o++) {
      scheduledOccurrences.add(
        syncable({
          'recurrence_id': recurrenceIds[i],
          'due_at': ts(DateTime(2026, 5, 5 + o * 3, 9)),
          'status': o == 0 ? 'confirmed' : 'pending',
          'materialized_transaction_id': null,
          'last_reminder_at': o == 0
              ? ts(DateTime(2026, 5, 5 + o * 3, 8, 30))
              : null,
        }),
      );
    }
  }

  final transactions = <Map<String, dynamic>>[];
  final transactionIds = <String>[];
  for (var i = 0; i < 60; i++) {
    final kind = i % 4 == 0 ? 'income' : 'expense';
    final occurred = DateTime(2026, 5, 1 + (i % 30), 10 + (i % 8));
    final row = syncable({
      'kind': kind,
      'occurred_at': ts(occurred),
      'note': kind == 'income' ? 'Income ${i + 1}' : 'Expense ${i + 1}',
      'category_id': categoryIds[i % categoryIds.length],
      'type_id': categoryTypeIds[i % categoryTypeIds.length],
      'recurrence_id': null,
      'scheduled_occurrence_id': null,
    });
    transactions.add(row);
    transactionIds.add(row['id'] as String);
  }

  final transactionLegs = <Map<String, dynamic>>[];
  for (var i = 0; i < transactionIds.length; i++) {
    final amountBase = 12.5 + rnd.nextDouble() * 180;
    final kind = (transactions[i]['kind'] as String);
    final amount = kind == 'income' ? amountBase : -amountBase;
    transactionLegs.add(
      syncable({
        'transaction_id': transactionIds[i],
        'account_id': accountIds[i % accountIds.length],
        'currency_id': currencyIds[i % currencyIds.length],
        'amount': double.parse(amount.toStringAsFixed(2)),
      }),
    );
  }

  final exchangeRates = <Map<String, dynamic>>[];
  for (var i = 0; i < 18; i++) {
    final fromId = currencyIds[i % currencyIds.length];
    final toId = currencyIds[(i + 1) % currencyIds.length];
    exchangeRates.add(
      syncable({
        'from_currency_id': fromId,
        'to_currency_id': toId,
        'rate': double.parse((0.7 + rnd.nextDouble() * 0.6).toStringAsFixed(4)),
        'occurred_at': ts(DateTime(2026, 5, 1 + (i % 30), 12)),
        'transaction_id': null,
      }),
    );
  }

  final notes = <Map<String, dynamic>>[];
  final noteIds = <String>[];
  for (var i = 0; i < 28; i++) {
    final occurred = DateTime(2026, 5, 1 + (i % 30), 8 + (i % 6));
    final row = syncable({
      'title': i % 3 == 0 ? 'Note ${i + 1}' : null,
      'content_md':
          '## Note ${i + 1}\n\nSeeded content for testing.\n\n- item A\n- item B',
      'occurred_at': ts(occurred),
      'sort_order': i,
    });
    notes.add(row);
    noteIds.add(row['id'] as String);
  }

  final tags = <Map<String, dynamic>>[];
  final tagIds = <String>[];
  final tagNames = <String>[
    'personal',
    'work',
    'urgent',
    'idea',
    'health',
    'finance',
    'travel',
    'family',
  ];
  for (var i = 0; i < tagNames.length; i++) {
    final row = syncable({
      'name': tagNames[i],
      'color': 0xFF000000 + rnd.nextInt(0x00FFFFFF),
    });
    tags.add(row);
    tagIds.add(row['id'] as String);
  }

  final noteTags = <Map<String, dynamic>>[];
  for (var i = 0; i < noteIds.length; i++) {
    final tagId = tagIds[i % tagIds.length];
    noteTags.add({'note_id': noteIds[i], 'tag_id': tagId});
  }

  final tables = <String, dynamic>{
    'app_settings': appSettings,
    'currencies': currencies,
    'accounts': accounts,
    'categories': categories,
    'category_types': categoryTypes,
    'workspaces': workspaces,
    'task_recurrences': taskRecurrences,
    'tasks': tasks,
    'task_history': taskHistory,
    'measurement_types': measurementTypes,
    'measurement_entries': measurementEntries,
    'measurement_values': measurementValues,
    'programs': programs,
    'program_days': programDays,
    'superset_groups': supersetGroups,
    'day_exercises': dayExercises,
    'exercise_set_prescriptions': setPrescriptions,
    'day_sessions': daySessions,
    'recurrences': recurrences,
    'transactions': transactions,
    'transaction_legs': transactionLegs,
    'exchange_rates': exchangeRates,
    'scheduled_occurrences': scheduledOccurrences,
    'notes': notes,
    'tags': tags,
    'note_tags': noteTags,
  };

  final doc = {
    'app': 'aws_os',
    'version': 1,
    'exported_at': DateTime(2026, 5, 30, 12).toIso8601String(),
    'tables': tables,
  };

  final outFile = File('tool/seed_backup_may_2026.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(doc));
  stdout.writeln('Wrote ${outFile.path}');
}
