import 'task_model.dart';

/// A compact task summary used only for the AI day-planning feature.
///
/// Do not send the full [TaskModel] to Gemini. This model keeps the prompt
/// small, predictable, and safer to control.
class AiDayPlanTaskSummary {
  final String id;
  final String title;
  final String priority;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool hasReminder;
  final String? categoryName;

  const AiDayPlanTaskSummary({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    this.startAt,
    this.endAt,
    this.hasReminder = false,
    this.categoryName,
  });

  /// Creates a safe AI-facing summary from the app's real task model.
  factory AiDayPlanTaskSummary.fromTaskModel(
    TaskModel task, {
    String? categoryName,
  }) {
    return AiDayPlanTaskSummary(
      id: task.id,
      title: task.title,
      priority: task.priority.name,
      status: task.status.name,
      startAt: task.startDateTime,
      endAt: task.endDateTime,
      hasReminder: task.isReminderOn ||
          task.remindAtStart ||
          task.remindAtDeadline ||
          task.reminderScheduledAt != null ||
          task.startReminderScheduledAt != null ||
          task.deadlineReminderScheduledAt != null,
      categoryName: _cleanNullableText(categoryName),
    );
  }

  /// Converts this summary into a single compact prompt line.
  ///
  /// Example:
  /// - id: abc123 | title: Làm báo cáo | priority: high | status: pending | start: 08:00 | end: 10:00
  String toPromptLine() {
    final parts = <String>[
      'id: ${_cleanPromptText(id)}',
      'title: ${_cleanPromptText(title)}',
      'priority: ${_cleanPromptText(priority)}',
      'status: ${_cleanPromptText(status)}',
      'start: ${_formatTime(startAt)}',
      'end: ${_formatTime(endAt)}',
      'reminder: ${hasReminder ? 'yes' : 'no'}',
    ];

    final cleanedCategoryName = _cleanNullableText(categoryName);
    if (cleanedCategoryName != null) {
      parts.add('category: ${_cleanPromptText(cleanedCategoryName)}');
    }

    return '- ${parts.join(' | ')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'priority': priority,
      'status': status,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'hasReminder': hasReminder,
      'categoryName': categoryName,
    };
  }

  AiDayPlanTaskSummary copyWith({
    String? id,
    String? title,
    String? priority,
    String? status,
    DateTime? startAt,
    DateTime? endAt,
    bool? hasReminder,
    String? categoryName,
    bool clearStartAt = false,
    bool clearEndAt = false,
    bool clearCategoryName = false,
  }) {
    return AiDayPlanTaskSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
      hasReminder: hasReminder ?? this.hasReminder,
      categoryName: clearCategoryName
          ? null
          : (_cleanNullableText(categoryName) ?? this.categoryName),
    );
  }

  static String _formatTime(DateTime? value) {
    if (value == null) return 'chưa rõ';

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Keeps each value on one prompt line and avoids breaking the separator format.
  static String _cleanPromptText(String value) {
    final cleaned = value
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('|', '/')
        .trim();

    return cleaned.isEmpty ? 'chưa rõ' : cleaned;
  }

  static String? _cleanNullableText(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }
}
