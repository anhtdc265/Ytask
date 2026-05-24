import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_app/core/navigation/app_navigator.dart';
import 'package:todo_app/features/dashboard/task_detail_loader_screen.dart';

import '../models/task_model.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String reminderChannelId = 'ytask_reminders';
  static const String reminderChannelName = 'YTask Reminders';
  static const String reminderChannelDescription =
      'Thông báo nhắc nhở công việc trong YTask';

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await _initTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
      notificationTapBackgroundHandler,
    );

    await _handleLaunchFromNotification();
    await _createAndroidReminderChannel();

    _isInitialized = true;
  }

  Future<void> _handleLaunchFromNotification() async {
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final response = launchDetails?.notificationResponse;

      if (launchDetails?.didNotificationLaunchApp == true && response != null) {
        Future.delayed(const Duration(milliseconds: 700), () {
          _handleNotificationTap(response);
        });
      }
    } catch (e) {
      debugPrint('YTask: lỗi xử lý launch từ notification: $e');
    }
  }

  Future<void> _initTimeZone() async {
    tz_data.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timezoneName = timezoneInfo.identifier;

      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
    }
  }

  Future<void> _createAndroidReminderChannel() async {
    const channel = AndroidNotificationChannel(
      reminderChannelId,
      reminderChannelName,
      description: reminderChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> requestPermission() async {
    await init();

    bool androidGranted = true;
    bool iosGranted = true;

    final androidImplementation =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final iosImplementation =
    _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final androidResult =
    await androidImplementation?.requestNotificationsPermission();

    final iosResult = await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (androidResult != null) androidGranted = androidResult;
    if (iosResult != null) iosGranted = iosResult;

    return androidGranted && iosGranted;
  }

  Future<void> showTestNotification() async {
    await init();

    await _plugin.show(
      id: 999001,
      title: 'YTask Reminder',
      body: 'NotificationService đã hoạt động.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          reminderChannelName,
          channelDescription: reminderChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF64DA56),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'test'}),
    );
  }

  Future<int?> scheduleTaskStartReminder({
    required TaskModel task,
    required int offsetMinutes,
  }) async {
    final startDateTime = task.startDateTime;
    if (startDateTime == null) return null;

    return _scheduleTypedTaskReminder(
      task: task,
      reminderType: TaskReminderType.start,
      offsetMinutes: offsetMinutes,
      reminderTime: startDateTime.subtract(Duration(minutes: offsetMinutes)),
      notificationId: buildStartNotificationId(task.id),
    );
  }

  Future<int?> scheduleTaskDeadlineReminder({
    required TaskModel task,
    required int offsetMinutes,
  }) async {
    final endDateTime = task.endDateTime;
    if (endDateTime == null) return null;

    return _scheduleTypedTaskReminder(
      task: task,
      reminderType: TaskReminderType.deadline,
      offsetMinutes: offsetMinutes,
      reminderTime: endDateTime.subtract(Duration(minutes: offsetMinutes)),
      notificationId: buildDeadlineNotificationId(task.id),
    );
  }

  Future<int?> scheduleTaskReminder({
    required TaskModel task,
    required int offsetMinutes,
  }) async {
    if (task.reminderType == TaskReminderType.start) {
      return scheduleTaskStartReminder(
        task: task,
        offsetMinutes: offsetMinutes,
      );
    }

    if (task.reminderType == TaskReminderType.deadline) {
      return scheduleTaskDeadlineReminder(
        task: task,
        offsetMinutes: offsetMinutes,
      );
    }

    return null;
  }

  Future<int?> _scheduleTypedTaskReminder({
    required TaskModel task,
    required TaskReminderType reminderType,
    required int offsetMinutes,
    required DateTime reminderTime,
    required int notificationId,
  }) async {
    await init();

    if (task.id.isEmpty) return null;
    if (task.status == TaskStatus.completed) return null;
    if (task.status == TaskStatus.cancelled) return null;
    if (task.isDeleted) return null;
    if (!reminderTime.isAfter(DateTime.now())) return null;

    final title = _buildReminderTitle(
      task: task,
      reminderType: reminderType,
      offsetMinutes: offsetMinutes,
    );
    final body = _buildReminderBody(task);

    final payload = jsonEncode({
      'type': 'task_reminder',
      'taskId': task.id,
      'reminderType': reminderType.name,
    });

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          reminderChannelName,
          channelDescription: reminderChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF64DA56),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );

    return notificationId;
  }

  Future<void> cancelNotification(int notificationId) async {
    await init();
    await _plugin.cancel(id: notificationId);
  }

  Future<void> cancelTaskReminder(TaskModel task) async {
    if (task.id.isEmpty) return;

    await init();

    final idsToCancel = <int>{
      buildNotificationId(task.id),
      buildStartNotificationId(task.id),
      buildDeadlineNotificationId(task.id),
    };

    if (task.localNotificationId != null) {
      idsToCancel.add(task.localNotificationId!);
    }
    if (task.startLocalNotificationId != null) {
      idsToCancel.add(task.startLocalNotificationId!);
    }
    if (task.deadlineLocalNotificationId != null) {
      idsToCancel.add(task.deadlineLocalNotificationId!);
    }

    for (final id in idsToCancel) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  int buildNotificationId(String taskId) {
    return _buildNotificationIdWithSalt(taskId, 1);
  }

  int buildStartNotificationId(String taskId) {
    return _buildNotificationIdWithSalt(taskId, 101);
  }

  int buildDeadlineNotificationId(String taskId) {
    return _buildNotificationIdWithSalt(taskId, 202);
  }

  int _buildNotificationIdWithSalt(String taskId, int salt) {
    var hash = salt;

    for (final codeUnit in taskId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    if (hash == 0) return salt == 0 ? 1 : salt;
    return hash;
  }

  String _buildReminderTitle({
    required TaskModel task,
    required TaskReminderType reminderType,
    required int offsetMinutes,
  }) {
    if (reminderType == TaskReminderType.start) {
      if (offsetMinutes <= 0) {
        return 'Bắt đầu: ${task.title}';
      }

      if (offsetMinutes < 60) {
        return 'Còn $offsetMinutes phút bắt đầu: ${task.title}';
      }

      if (offsetMinutes == 60) {
        return 'Còn 1 giờ bắt đầu: ${task.title}';
      }

      return 'Sắp bắt đầu: ${task.title}';
    }

    if (offsetMinutes <= 0) {
      return 'Đến hạn: ${task.title}';
    }

    if (offsetMinutes < 60) {
      return 'Còn $offsetMinutes phút: ${task.title}';
    }

    if (offsetMinutes == 60) {
      return 'Còn 1 giờ: ${task.title}';
    }

    if (offsetMinutes == 1440) {
      return 'Còn 1 ngày: ${task.title}';
    }

    return 'Sắp đến hạn: ${task.title}';
  }

  String _buildReminderBody(TaskModel task) {
    final description = task.description.trim();

    if (description.isNotEmpty) {
      return description;
    }

    return 'Bạn có một nhiệm vụ cần chú ý trong YTask.';
  }

  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final type = data['type'] as String?;
      final taskId = data['taskId'] as String?;

      debugPrint('YTask notification tapped: $data');

      if (type != 'task_reminder') return;
      if (taskId == null || taskId.trim().isEmpty) return;

      final navigatorState = AppNavigator.navigatorKey.currentState;

      if (navigatorState == null) {
        debugPrint('YTask: navigatorState null, chưa thể mở task detail.');
        return;
      }

      navigatorState.push(
        MaterialPageRoute(
          builder: (_) => TaskDetailLoaderScreen(
            taskId: taskId.trim(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Không đọc được notification payload: $e');
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  final payload = response.payload;
  debugPrint('YTask background notification tapped: $payload');
}
