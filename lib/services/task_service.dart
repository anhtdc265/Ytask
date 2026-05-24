import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/services/notification_service.dart';

class TaskService {
  final CollectionReference<Map<String, dynamic>> _taskCollection =
  FirebaseFirestore.instance.collection('tasks');

  Map<String, dynamic> _clearReminderFields() {
    return {
      'isReminderOn': false,
      'reminderType': TaskReminderType.none.name,
      'reminderOffsetMinutes': null,
      'reminderScheduledAt': null,
      'localNotificationId': null,
    };
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? calculateReminderScheduledAt(TaskModel task) {
    if (!task.isReminderOn) return null;
    if (task.reminderType == TaskReminderType.none) return null;

    if (task.reminderType == TaskReminderType.start) {
      final startDateTime = task.startDateTime;
      if (startDateTime == null) return null;

      return startDateTime.subtract(
        Duration(minutes: task.reminderOffsetMinutes ?? 0),
      );
    }

    if (task.reminderType == TaskReminderType.deadline) {
      final endDateTime = task.endDateTime;
      if (endDateTime == null) return null;

      return endDateTime.subtract(
        Duration(minutes: task.reminderOffsetMinutes ?? 0),
      );
    }

    return null;
  }

  Future<void> _cancelReminderByTaskId(String taskId) async {
    if (taskId.isEmpty) return;

    final idsToCancel = <int>{};

    // Fallback id cũ/chuẩn được build từ taskId.
    idsToCancel.add(NotificationService.instance.buildNotificationId(taskId));

    try {
      final doc = await _taskCollection.doc(taskId).get();
      final data = doc.data();

      final savedNotificationId = _readInt(data?['localNotificationId']);
      if (savedNotificationId != null) {
        idsToCancel.add(savedNotificationId);
      }
    } catch (e) {
      debugPrint('YTask: Không đọc được localNotificationId của task $taskId: $e');
    }

    for (final id in idsToCancel) {
      try {
        await NotificationService.instance.cancelNotification(id);
        debugPrint('YTask: Đã cancel notification id=$id cho task=$taskId');
      } catch (e) {
        debugPrint('YTask: Lỗi cancel notification id=$id task=$taskId: $e');
      }
    }
  }

  Future<TaskModel?> _getTaskById(String taskId) async {
    if (taskId.isEmpty) return null;

    final doc = await _taskCollection.doc(taskId).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return TaskModel.fromMap({
      ...data,
      'id': data['id'] ?? doc.id,
    });
  }

  Future<void> updateTaskAndRescheduleReminder(TaskModel task) async {
    if (task.id.isEmpty) {
      throw Exception('Không thể cập nhật reminder nếu thiếu taskId');
    }

    // Hủy reminder cũ trước.
    await _cancelReminderByTaskId(task.id);

    final shouldClearReminder = task.isDeleted ||
        task.status == TaskStatus.completed ||
        task.status == TaskStatus.cancelled ||
        !task.isReminderOn ||
        task.reminderType == TaskReminderType.none;

    if (shouldClearReminder) {
      final updatedTask = task.copyWith(updatedAt: DateTime.now());

      await _taskCollection.doc(task.id).update({
        ...updatedTask.toMap(),
        ..._clearReminderFields(),
      });

      return;
    }

    final scheduledAt = calculateReminderScheduledAt(task);

    if (scheduledAt == null || !scheduledAt.isAfter(DateTime.now())) {
      final updatedTask = task.copyWith(updatedAt: DateTime.now());

      await _taskCollection.doc(task.id).update({
        ...updatedTask.toMap(),
        ..._clearReminderFields(),
      });

      return;
    }

    final granted = await NotificationService.instance.requestPermission();

    if (!granted) {
      final updatedTask = task.copyWith(updatedAt: DateTime.now());

      await _taskCollection.doc(task.id).update({
        ...updatedTask.toMap(),
        ..._clearReminderFields(),
      });

      return;
    }

    final notificationId = await NotificationService.instance.scheduleTaskReminder(
      task: task,
      offsetMinutes: task.reminderOffsetMinutes ?? 0,
    );

    final updatedTask = task.copyWith(
      updatedAt: DateTime.now(),
      reminderScheduledAt: notificationId == null ? null : scheduledAt,
      localNotificationId: notificationId,
    );

    await _taskCollection.doc(task.id).update(updatedTask.toMap());
  }

  Future<void> syncPendingRemindersForUser(String uid) async {
    if (uid.trim().isEmpty) return;

    try {
      final snapshot = await _taskCollection
          .where('userId', isEqualTo: uid)
          .where('isReminderOn', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final task = TaskModel.fromMap({
          ...data,
          'id': data['id'] ?? doc.id,
        });

        final shouldSkip = task.isDeleted ||
            task.status == TaskStatus.completed ||
            task.status == TaskStatus.cancelled ||
            !task.isReminderOn ||
            task.reminderType == TaskReminderType.none;

        if (shouldSkip) {
          await _taskCollection.doc(task.id).update({
            ..._clearReminderFields(),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          continue;
        }

        final scheduledAt = calculateReminderScheduledAt(task);

        if (scheduledAt == null || !scheduledAt.isAfter(DateTime.now())) {
          await _taskCollection.doc(task.id).update({
            ..._clearReminderFields(),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          continue;
        }

        await updateTaskAndRescheduleReminder(task);

        debugPrint(
          'YTask: sync reminder khi đăng nhập lại taskId=${task.id}, scheduledAt=$scheduledAt',
        );
      }
    } catch (e) {
      debugPrint('YTask: lỗi syncPendingRemindersForUser($uid): $e');
    }
  }

  Stream<List<TaskModel>> getTasksByUser(String uid) {
    return _taskCollection
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        // Bảo hiểm: nếu field id thiếu trong document thì dùng doc.id.
        return TaskModel.fromMap({
          ...data,
          'id': data['id'] ?? doc.id,
        });
      }).toList();
    });
  }

  bool _isSameLocalDay(DateTime value, DateTime day) {
    final localValue = value.toLocal();
    final localDay = day.toLocal();

    return localValue.year == localDay.year &&
        localValue.month == localDay.month &&
        localValue.day == localDay.day;
  }

  bool _overlapsLocalDay({
    required DateTime start,
    required DateTime end,
    required DateTime day,
  }) {
    final localDay = day.toLocal();
    final dayStart = DateTime(localDay.year, localDay.month, localDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return start.toLocal().isBefore(dayEnd) && end.toLocal().isAfter(dayStart);
  }

  bool _isTaskRelevantForAiToday(TaskModel task, DateTime today) {
    if (task.isDeleted) return false;
    if (task.status == TaskStatus.completed) return false;
    if (task.status == TaskStatus.cancelled) return false;

    final start = task.startDateTime;
    final end = task.endDateTime;

    // Task chưa có thời gian vẫn được giữ lại để AI có thể xếp vào nhóm
    // "chưa có thời gian rõ ràng" thay vì bỏ sót công việc của người dùng.
    if (start == null && end == null) return true;

    if (start != null && _isSameLocalDay(start, today)) return true;
    if (end != null && _isSameLocalDay(end, today)) return true;

    // Bao phủ thêm case task kéo dài qua hôm nay, ví dụ bắt đầu hôm qua
    // và kết thúc ngày mai. Case này vẫn là việc cần xét trong kế hoạch ngày.
    if (start != null && end != null) {
      return _overlapsLocalDay(start: start, end: end, day: today);
    }

    return false;
  }


  bool _isTaskScheduledOrClosedTodayForAi(TaskModel task, DateTime today) {
    if (task.isDeleted) return false;

    final start = task.startDateTime;
    final end = task.endDateTime;

    if (start != null && _isSameLocalDay(start, today)) return true;
    if (end != null && _isSameLocalDay(end, today)) return true;

    if (start != null && end != null) {
      return _overlapsLocalDay(start: start, end: end, day: today);
    }

    // Với task đã hoàn thành/hủy nhưng không có start/end, dùng thời điểm
    // hoàn thành/hủy để phân biệt “hôm nay không có task” với “task hôm nay
    // đã hoàn thành hoặc đã hủy”. Nếu field đó thiếu thì dùng createdAt như
    // một fallback nhẹ cho dữ liệu cũ.
    final closedAt = task.status == TaskStatus.completed
        ? task.completedAt
        : task.status == TaskStatus.cancelled
        ? task.cancelledAt
        : null;

    final referenceDate = closedAt ?? task.createdAt;
    return referenceDate != null && _isSameLocalDay(referenceDate, today);
  }

  Future<bool> hasOnlyCompletedOrCancelledTasksTodayForAi(String uid) async {
    if (uid.trim().isEmpty) return false;

    final today = DateTime.now();

    final snapshot = await _taskCollection
        .where('userId', isEqualTo: uid)
        .get();

    var hasCompletedOrCancelledToday = false;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final task = TaskModel.fromMap({
        ...data,
        'id': data['id'] ?? doc.id,
      });

      if (!_isTaskScheduledOrClosedTodayForAi(task, today)) {
        continue;
      }

      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        hasCompletedOrCancelledToday = true;
        continue;
      }

      // Nếu còn task active thuộc hôm nay thì không phải case “toàn bộ đã
      // hoàn thành/hủy”.
      return false;
    }

    return hasCompletedOrCancelledToday;
  }

  int _priorityRank(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 0;
      case TaskPriority.medium:
        return 1;
      case TaskPriority.low:
        return 2;
    }
  }

  int _compareTasksForAiToday(TaskModel a, TaskModel b) {
    final priorityCompare =
    _priorityRank(a.priority).compareTo(_priorityRank(b.priority));

    if (priorityCompare != 0) return priorityCompare;

    final aTime = a.endDateTime ?? a.startDateTime;
    final bTime = b.endDateTime ?? b.startDateTime;

    if (aTime == null && bTime == null) return a.title.compareTo(b.title);
    if (aTime == null) return 1;
    if (bTime == null) return -1;

    return aTime.compareTo(bTime);
  }

  Future<List<TaskModel>> getTodayTasksForAi(String uid) async {
    if (uid.trim().isEmpty) return [];

    final today = DateTime.now();

    final snapshot = await _taskCollection
        .where('userId', isEqualTo: uid)
        .get();

    final tasks = snapshot.docs.map((doc) {
      final data = doc.data();

      // Bảo hiểm: nếu field id thiếu trong document thì dùng doc.id.
      return TaskModel.fromMap({
        ...data,
        'id': data['id'] ?? doc.id,
      });
    }).where((task) {
      return _isTaskRelevantForAiToday(task, today);
    }).toList();

    tasks.sort(_compareTasksForAiToday);

    return tasks;
  }


  /// Lấy toàn bộ task liên quan đến hôm nay cho chatbot tư vấn local.
  ///
  /// Khác với getTodayTasksForAi, method này giữ cả completed/cancelled để
  /// chatbot trả lời được các câu hỏi về trạng thái task trong testcase.
  Future<List<TaskModel>> getTodayTasksForConsultation(String uid) async {
    if (uid.trim().isEmpty) return <TaskModel>[];

    final today = DateTime.now();

    final snapshot = await _taskCollection
        .where('userId', isEqualTo: uid)
        .get();

    final tasks = snapshot.docs.map((doc) {
      final data = doc.data();
      return TaskModel.fromMap({
        ...data,
        'id': data['id'] ?? doc.id,
      });
    }).where((task) {
      return !task.isDeleted && _isTaskScheduledOrClosedTodayForAi(task, today);
    }).toList();

    tasks.sort(_compareTasksForAiToday);

    return tasks;
  }

  Future<String> createTask(TaskModel task) async {
    if (task.userId.isEmpty) {
      throw Exception('Không thể tạo task nếu thiếu userId');
    }

    final now = DateTime.now();

    final docRef = task.id.isNotEmpty
        ? _taskCollection.doc(task.id)
        : _taskCollection.doc();

    final newTask = task.copyWith(
      id: docRef.id,
      createdAt: task.createdAt ?? now,
      updatedAt: now,
    );

    await docRef.set(newTask.toMap());
    return docRef.id;
  }

  Future<void> updateTask(TaskModel task) async {
    if (task.id.isEmpty) {
      throw Exception('Không thể cập nhật task nếu thiếu taskId');
    }

    final updatedTask = task.copyWith(updatedAt: DateTime.now());
    await _taskCollection.doc(task.id).update(updatedTask.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    if (taskId.isEmpty) return;

    await _cancelReminderByTaskId(taskId);
    await _taskCollection.doc(taskId).delete();
  }

  Future<void> markTaskPending(String taskId) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _taskCollection.doc(taskId).update({
      'status': TaskStatus.pending.name,
      'completedAt': null,
      'cancelledAt': null,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Future<void> markTaskInProgress(String taskId) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _taskCollection.doc(taskId).update({
      'status': TaskStatus.inProgress.name,
      'cancelledAt': null,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Future<void> markTaskCompleted(String taskId) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _cancelReminderByTaskId(taskId);

    await _taskCollection.doc(taskId).update({
      'status': TaskStatus.completed.name,
      'completedAt': Timestamp.fromDate(now),
      'cancelledAt': null,
      'updatedAt': Timestamp.fromDate(now),
      ..._clearReminderFields(),
    });
  }

  Future<void> markTaskCancelled(String taskId) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _cancelReminderByTaskId(taskId);

    await _taskCollection.doc(taskId).update({
      'status': TaskStatus.cancelled.name,
      'cancelledAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      ..._clearReminderFields(),
    });
  }

  Future<void> reactivateTask(
      String taskId, {
        required bool shouldStartNow,
      }) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _taskCollection.doc(taskId).update({
      'status': shouldStartNow
          ? TaskStatus.inProgress.name
          : TaskStatus.pending.name,
      'cancelledAt': null,
      'reactivatedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Future<void> softDeleteTask(String taskId) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _cancelReminderByTaskId(taskId);

    await _taskCollection.doc(taskId).update({
      'isDeleted': true,
      'deletedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      ..._clearReminderFields(),
    });
  }

  Future<void> restoreTask(String taskId) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _taskCollection.doc(taskId).update({
      'isDeleted': false,
      'deletedAt': null,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Future<void> permanentlyDeleteTask(String taskId) async {
    if (taskId.isEmpty) return;

    await _cancelReminderByTaskId(taskId);
    await _taskCollection.doc(taskId).delete();
  }

  Future<void> updateTaskDateTime({
    required String taskId,
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) async {
    if (taskId.isEmpty) return;

    final currentTask = await _getTaskById(taskId);

    if (currentTask == null) {
      await _taskCollection.doc(taskId).update({
        'startDateTime': Timestamp.fromDate(startDateTime),
        'endDateTime': Timestamp.fromDate(endDateTime),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return;
    }

    final updatedTask = currentTask.copyWith(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      updatedAt: DateTime.now(),
    );

    final shouldReschedule = updatedTask.isReminderOn &&
        updatedTask.status != TaskStatus.completed &&
        updatedTask.status != TaskStatus.cancelled &&
        !updatedTask.isDeleted;

    if (shouldReschedule) {
      debugPrint(
        'YTask: reschedule reminder after updateTaskDateTime taskId=$taskId',
      );
      await updateTaskAndRescheduleReminder(updatedTask);
      return;
    }

    await _taskCollection.doc(taskId).update({
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> reopenCompletedTaskWithDateTime({
    required String taskId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required bool shouldStartNow,
  }) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _taskCollection.doc(taskId).update({
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'status': shouldStartNow
          ? TaskStatus.inProgress.name
          : TaskStatus.pending.name,
      'completedAt': null,
      'reactivatedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Future<void> reactivateCancelledTaskWithDateTime({
    required String taskId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required bool shouldStartNow,
  }) async {
    if (taskId.isEmpty) return;

    final now = DateTime.now();

    await _taskCollection.doc(taskId).update({
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'status': shouldStartNow
          ? TaskStatus.inProgress.name
          : TaskStatus.pending.name,
      'cancelledAt': null,
      'reactivatedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }
}
