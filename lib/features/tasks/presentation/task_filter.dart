import 'package:aws_os/core/db/app_database.dart';
import 'package:aws_os/core/utils/date_ext.dart';

enum TaskStatusFilter { all, active, completed }

enum TaskDateFilter {
  all,
  today,
  tomorrow,
  thisWeek,
  thisMonth,
  overdue,
  noDate,
  custom,
}

extension TaskDateFilterLabel on TaskDateFilter {
  String get label => switch (this) {
        TaskDateFilter.all => 'All Dates',
        TaskDateFilter.today => 'Today',
        TaskDateFilter.tomorrow => 'Tomorrow',
        TaskDateFilter.thisWeek => 'This Week',
        TaskDateFilter.thisMonth => 'This Month',
        TaskDateFilter.overdue => 'Overdue',
        TaskDateFilter.noDate => 'No Date',
        TaskDateFilter.custom => 'Custom',
      };
}

class TaskFilter {
  const TaskFilter({
    this.status = TaskStatusFilter.active,
    this.dateFilter = TaskDateFilter.all,
    this.customRangeStart,
    this.customRangeEnd,
    this.category,
    this.recurringOnly = false,
    this.hasDeadlineOnly = false,
  });

  final TaskStatusFilter status;
  final TaskDateFilter dateFilter;
  final DateTime? customRangeStart;
  final DateTime? customRangeEnd;
  final String? category;
  final bool recurringOnly;
  final bool hasDeadlineOnly;

  bool get isDefault =>
      status == TaskStatusFilter.active &&
      dateFilter == TaskDateFilter.all &&
      category == null &&
      !recurringOnly &&
      !hasDeadlineOnly;

  /// Number of non-default filters active (status excluded — it's always visible).
  int get activeCount {
    int n = 0;
    if (dateFilter != TaskDateFilter.all) n++;
    if (category != null) n++;
    if (recurringOnly) n++;
    if (hasDeadlineOnly) n++;
    return n;
  }

  bool matches(Task task) {
    // Status
    switch (status) {
      case TaskStatusFilter.active:
        if (task.isCompleted) return false;
      case TaskStatusFilter.completed:
        if (!task.isCompleted) return false;
      case TaskStatusFilter.all:
        break;
    }

    // Date (applied to dueAt)
    final now = DateTime.now();
    switch (dateFilter) {
      case TaskDateFilter.today:
        if (task.dueAt == null || !task.dueAt!.isSameDay(now)) return false;
      case TaskDateFilter.tomorrow:
        final tomorrow = now.addDays(1);
        if (task.dueAt == null || !task.dueAt!.isSameDay(tomorrow)) return false;
      case TaskDateFilter.thisWeek:
        if (task.dueAt == null) return false;
        final weekStart = now.atStartOfDay.addDays(-(now.weekday - 1));
        final weekEnd = weekStart.addDays(7);
        if (task.dueAt!.isBefore(weekStart) || !task.dueAt!.isBefore(weekEnd)) {
          return false;
        }
      case TaskDateFilter.thisMonth:
        if (task.dueAt == null) return false;
        if (task.dueAt!.month != now.month || task.dueAt!.year != now.year) {
          return false;
        }
      case TaskDateFilter.overdue:
        if (task.dueAt == null || task.isCompleted) return false;
        if (!task.dueAt!.isBefore(now.atStartOfDay)) return false;
      case TaskDateFilter.noDate:
        if (task.dueAt != null) return false;
      case TaskDateFilter.custom:
        if (task.dueAt == null) return false;
        if (customRangeStart != null &&
            task.dueAt!.isBefore(customRangeStart!)) {
          return false;
        }
        if (customRangeEnd != null &&
            task.dueAt!.isAfter(customRangeEnd!.atEndOfDay)) {
          return false;
        }
      case TaskDateFilter.all:
        break;
    }

    // Category
    if (category != null) {
      if (task.category?.trim() != category) return false;
    }

    // Recurring only
    if (recurringOnly && task.recurrenceId == null) return false;

    // Has deadline only
    if (hasDeadlineOnly && task.deadlineAt == null) return false;

    return true;
  }

  TaskFilter copyWith({
    TaskStatusFilter? status,
    TaskDateFilter? dateFilter,
    Object? customRangeStart = _sentinel,
    Object? customRangeEnd = _sentinel,
    Object? category = _sentinel,
    bool? recurringOnly,
    bool? hasDeadlineOnly,
  }) {
    return TaskFilter(
      status: status ?? this.status,
      dateFilter: dateFilter ?? this.dateFilter,
      customRangeStart: customRangeStart == _sentinel
          ? this.customRangeStart
          : customRangeStart as DateTime?,
      customRangeEnd: customRangeEnd == _sentinel
          ? this.customRangeEnd
          : customRangeEnd as DateTime?,
      category: category == _sentinel ? this.category : category as String?,
      recurringOnly: recurringOnly ?? this.recurringOnly,
      hasDeadlineOnly: hasDeadlineOnly ?? this.hasDeadlineOnly,
    );
  }
}

const _sentinel = Object();
