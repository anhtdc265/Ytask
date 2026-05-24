import 'package:todo_app/models/task_model.dart';

enum EffectiveTaskStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  overdue,
}

class EffectiveTaskStatusResolver {
  EffectiveTaskStatusResolver._();

  static EffectiveTaskStatus? resolve(
    TaskModel task, {
    DateTime? now,
  }) {
    if (task.isDeleted) return null;

    if (task.status == TaskStatus.completed) {
      return EffectiveTaskStatus.completed;
    }

    if (task.status == TaskStatus.cancelled) {
      return EffectiveTaskStatus.cancelled;
    }

    final current = now ?? DateTime.now();
    final start = task.startDateTime;
    final end = task.endDateTime;

    if (end != null && current.isAfter(end)) {
      return EffectiveTaskStatus.overdue;
    }

    if (task.status == TaskStatus.inProgress) {
      return EffectiveTaskStatus.inProgress;
    }

    if (start != null && !current.isBefore(start)) {
      return EffectiveTaskStatus.inProgress;
    }

    return EffectiveTaskStatus.pending;
  }

  static bool isOverdue(
    TaskModel task, {
    DateTime? now,
  }) {
    return resolve(task, now: now) == EffectiveTaskStatus.overdue;
  }

  static String label(EffectiveTaskStatus? status) {
    switch (status) {
      case EffectiveTaskStatus.pending:
        return 'Đang chờ';
      case EffectiveTaskStatus.inProgress:
        return 'Đang làm';
      case EffectiveTaskStatus.completed:
        return 'Hoàn thành';
      case EffectiveTaskStatus.cancelled:
        return 'Đã hủy';
      case EffectiveTaskStatus.overdue:
        return 'Quá hạn';
      case null:
        return '';
    }
  }

  static String searchText(EffectiveTaskStatus? status) {
    switch (status) {
      case EffectiveTaskStatus.pending:
        return 'dang cho đang chờ pending cho';
      case EffectiveTaskStatus.inProgress:
        return 'dang lam đang làm in progress doing';
      case EffectiveTaskStatus.completed:
        return 'hoan thanh hoàn thành completed done xong';
      case EffectiveTaskStatus.cancelled:
        return 'da huy đã hủy cancelled huy';
      case EffectiveTaskStatus.overdue:
        return 'qua han quá hạn tre trễ late overdue';
      case null:
        return '';
    }
  }
}

/// Centralized progress counter used by ProgressScreen and other progress UIs.
///
/// Counting rules:
/// - Deleted tasks are ignored.
/// - Completed and cancelled are final states and always win over overdue.
/// - Overdue only applies to non-final tasks whose deadline has passed.
/// - Pending/inProgress are resolved from saved status + start/end time.
class TaskProgressMetrics {
  final int pending;
  final int inProgress;
  final int completed;
  final int cancelled;
  final int overdue;

  const TaskProgressMetrics({
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
    required this.overdue,
  });

  factory TaskProgressMetrics.fromTasks(
    Iterable<TaskModel> tasks, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    int pending = 0;
    int inProgress = 0;
    int completed = 0;
    int cancelled = 0;
    int overdue = 0;

    for (final task in tasks) {
      final effectiveStatus = EffectiveTaskStatusResolver.resolve(
        task,
        now: current,
      );

      switch (effectiveStatus) {
        case EffectiveTaskStatus.pending:
          pending++;
          break;
        case EffectiveTaskStatus.inProgress:
          inProgress++;
          break;
        case EffectiveTaskStatus.completed:
          completed++;
          break;
        case EffectiveTaskStatus.cancelled:
          cancelled++;
          break;
        case EffectiveTaskStatus.overdue:
          overdue++;
          break;
        case null:
          break;
      }
    }

    return TaskProgressMetrics(
      pending: pending,
      inProgress: inProgress,
      completed: completed,
      cancelled: cancelled,
      overdue: overdue,
    );
  }

  int get total => pending + inProgress + completed + cancelled + overdue;

  double get completionRate {
    if (total == 0) return 0;
    return (completed / total) * 100;
  }
}
