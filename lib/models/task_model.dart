import 'package:cloud_firestore/cloud_firestore.dart';

// Version: 1.4.0 - Added dual reminder fields for start + deadline
// Legacy reminder fields are kept to avoid breaking old Firestore data/UI.
enum TaskStatus { pending, inProgress, completed, cancelled }

enum TaskPriority { low, medium, high }

extension TaskPriorityDisplay on TaskPriority {
  String get vietnameseLabel {
    switch (this) {
      case TaskPriority.low:
        return 'Thấp';
      case TaskPriority.medium:
        return 'Trung bình';
      case TaskPriority.high:
        return 'Cao';
    }
  }
}

enum TaskReminderType { none, start, deadline }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final String userId;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final TaskStatus status;
  final TaskPriority priority;
  final String? location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Standardized lifecycle fields
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? reactivatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  // Legacy single-reminder fields. Do not remove yet.
  final bool isReminderOn;
  final TaskReminderType reminderType;
  final int? reminderOffsetMinutes;
  final DateTime? reminderScheduledAt;
  final int? localNotificationId;

  // New dual-reminder fields.
  final bool remindAtStart;
  final int startReminderOffsetMinutes;
  final bool remindAtDeadline;
  final int deadlineReminderOffsetMinutes;
  final DateTime? startReminderScheduledAt;
  final DateTime? deadlineReminderScheduledAt;
  final int? startLocalNotificationId;
  final int? deadlineLocalNotificationId;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.userId,
    this.startDateTime,
    this.endDateTime,
    this.status = TaskStatus.pending,
    required this.priority,
    this.isReminderOn = false,
    this.reminderType = TaskReminderType.none,
    this.location,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.cancelledAt,
    this.reactivatedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.reminderOffsetMinutes,
    this.reminderScheduledAt,
    this.localNotificationId,
    this.remindAtStart = false,
    this.startReminderOffsetMinutes = 0,
    this.remindAtDeadline = false,
    this.deadlineReminderOffsetMinutes = 0,
    this.startReminderScheduledAt,
    this.deadlineReminderScheduledAt,
    this.startLocalNotificationId,
    this.deadlineLocalNotificationId,
  });

  /// Parse DateTime safely from Timestamp, String, or DateTime.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    return _parseNullableInt(value) ?? fallback;
  }

  static bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return fallback;
  }

  static TaskReminderType _parseReminderType(
      dynamic value, {
        required bool isReminderOn,
      }) {
    if (value is String) {
      return TaskReminderType.values.firstWhere(
            (type) => type.name == value,
        orElse: () =>
        isReminderOn ? TaskReminderType.deadline : TaskReminderType.none,
      );
    }
    return isReminderOn ? TaskReminderType.deadline : TaskReminderType.none;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'userId': userId,
      'startDateTime':
      startDateTime != null ? Timestamp.fromDate(startDateTime!) : null,
      'endDateTime': endDateTime != null ? Timestamp.fromDate(endDateTime!) : null,
      'status': status.name,
      'priority': priority.name,
      'location': location,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt':
      completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt':
      cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'reactivatedAt':
      reactivatedAt != null ? Timestamp.fromDate(reactivatedAt!) : null,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'isDeleted': isDeleted,

      // Legacy fields.
      'isReminderOn': isReminderOn,
      'reminderType': reminderType.name,
      'reminderOffsetMinutes': reminderOffsetMinutes,
      'reminderScheduledAt':
      reminderScheduledAt != null ? Timestamp.fromDate(reminderScheduledAt!) : null,
      'localNotificationId': localNotificationId,

      // New dual-reminder fields.
      'remindAtStart': remindAtStart,
      'startReminderOffsetMinutes': startReminderOffsetMinutes,
      'remindAtDeadline': remindAtDeadline,
      'deadlineReminderOffsetMinutes': deadlineReminderOffsetMinutes,
      'startReminderScheduledAt': startReminderScheduledAt != null
          ? Timestamp.fromDate(startReminderScheduledAt!)
          : null,
      'deadlineReminderScheduledAt': deadlineReminderScheduledAt != null
          ? Timestamp.fromDate(deadlineReminderScheduledAt!)
          : null,
      'startLocalNotificationId': startLocalNotificationId,
      'deadlineLocalNotificationId': deadlineLocalNotificationId,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final isReminderOnValue = _parseBool(map['isReminderOn']);
    final legacyReminderType = _parseReminderType(
      map['reminderType'],
      isReminderOn: isReminderOnValue,
    );
    final legacyOffset = _parseNullableInt(map['reminderOffsetMinutes']);
    final legacyScheduledAt = _parseDateTime(map['reminderScheduledAt']);
    final legacyNotificationId = _parseNullableInt(map['localNotificationId']);

    final hasNewStartReminder = map.containsKey('remindAtStart');
    final hasNewDeadlineReminder = map.containsKey('remindAtDeadline');

    final remindAtStartValue = hasNewStartReminder
        ? _parseBool(map['remindAtStart'])
        : isReminderOnValue && legacyReminderType == TaskReminderType.start;

    final remindAtDeadlineValue = hasNewDeadlineReminder
        ? _parseBool(map['remindAtDeadline'])
        : isReminderOnValue && legacyReminderType == TaskReminderType.deadline;

    final startOffsetFallback = legacyReminderType == TaskReminderType.start
        ? (legacyOffset ?? 0)
        : 0;
    final deadlineOffsetFallback = legacyReminderType == TaskReminderType.deadline
        ? (legacyOffset ?? 0)
        : 0;

    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      categoryId: map['categoryId'] ?? '',
      userId: map['userId'] ?? '',
      startDateTime: _parseDateTime(map['startDateTime']),
      endDateTime: _parseDateTime(map['endDateTime']),
      status: TaskStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
            (e) => e.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      location: map['location'],
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      completedAt: _parseDateTime(map['completedAt']),
      cancelledAt: _parseDateTime(map['cancelledAt']),
      reactivatedAt: _parseDateTime(map['reactivatedAt']),
      deletedAt: _parseDateTime(map['deletedAt']),
      isDeleted: _parseBool(map['isDeleted']),

      // Legacy fields.
      isReminderOn: isReminderOnValue,
      reminderType: legacyReminderType,
      reminderOffsetMinutes: legacyOffset,
      reminderScheduledAt: legacyScheduledAt,
      localNotificationId: legacyNotificationId,

      // New fields, with migration from legacy single reminder.
      remindAtStart: remindAtStartValue,
      startReminderOffsetMinutes: _parseInt(
        map['startReminderOffsetMinutes'],
        fallback: startOffsetFallback,
      ),
      remindAtDeadline: remindAtDeadlineValue,
      deadlineReminderOffsetMinutes: _parseInt(
        map['deadlineReminderOffsetMinutes'],
        fallback: deadlineOffsetFallback,
      ),
      startReminderScheduledAt: _parseDateTime(map['startReminderScheduledAt']) ??
          (legacyReminderType == TaskReminderType.start ? legacyScheduledAt : null),
      deadlineReminderScheduledAt:
      _parseDateTime(map['deadlineReminderScheduledAt']) ??
          (legacyReminderType == TaskReminderType.deadline
              ? legacyScheduledAt
              : null),
      startLocalNotificationId: _parseNullableInt(map['startLocalNotificationId']) ??
          (legacyReminderType == TaskReminderType.start
              ? legacyNotificationId
              : null),
      deadlineLocalNotificationId:
      _parseNullableInt(map['deadlineLocalNotificationId']) ??
          (legacyReminderType == TaskReminderType.deadline
              ? legacyNotificationId
              : null),
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    String? userId,
    DateTime? startDateTime,
    DateTime? endDateTime,
    TaskStatus? status,
    TaskPriority? priority,
    bool? isReminderOn,
    TaskReminderType? reminderType,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? reactivatedAt,
    DateTime? deletedAt,
    bool? isDeleted,
    int? reminderOffsetMinutes,
    DateTime? reminderScheduledAt,
    int? localNotificationId,
    bool? remindAtStart,
    int? startReminderOffsetMinutes,
    bool? remindAtDeadline,
    int? deadlineReminderOffsetMinutes,
    DateTime? startReminderScheduledAt,
    DateTime? deadlineReminderScheduledAt,
    int? startLocalNotificationId,
    int? deadlineLocalNotificationId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isReminderOn: isReminderOn ?? this.isReminderOn,
      reminderType: reminderType ?? this.reminderType,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      reactivatedAt: reactivatedAt ?? this.reactivatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      reminderOffsetMinutes:
      reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      reminderScheduledAt: reminderScheduledAt ?? this.reminderScheduledAt,
      localNotificationId: localNotificationId ?? this.localNotificationId,
      remindAtStart: remindAtStart ?? this.remindAtStart,
      startReminderOffsetMinutes:
      startReminderOffsetMinutes ?? this.startReminderOffsetMinutes,
      remindAtDeadline: remindAtDeadline ?? this.remindAtDeadline,
      deadlineReminderOffsetMinutes:
      deadlineReminderOffsetMinutes ?? this.deadlineReminderOffsetMinutes,
      startReminderScheduledAt:
      startReminderScheduledAt ?? this.startReminderScheduledAt,
      deadlineReminderScheduledAt:
      deadlineReminderScheduledAt ?? this.deadlineReminderScheduledAt,
      startLocalNotificationId:
      startLocalNotificationId ?? this.startLocalNotificationId,
      deadlineLocalNotificationId:
      deadlineLocalNotificationId ?? this.deadlineLocalNotificationId,
    );
  }
}
