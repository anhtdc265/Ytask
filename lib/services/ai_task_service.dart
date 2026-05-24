import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:todo_app/models/ai_task_draft.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/services/category_service.dart';
import 'package:todo_app/services/notification_service.dart';
import 'package:todo_app/services/task_service.dart';

/// Service trung gian cho luồng AI tạo nhiệm vụ.
///
/// Service này nhận AiTaskDraft, validate, map sang TaskModel rồi lưu Firestore.
/// Không gọi Gemini ở đây. Không xử lý UI ở đây.
class AiTaskService {
  AiTaskService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    TaskService? taskService,
    CategoryService? categoryService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _taskService = taskService ?? TaskService(),
        _categoryService = categoryService ?? CategoryService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final TaskService _taskService;
  final CategoryService _categoryService;

  /// Tạo task thật từ bản nháp AI.
  ///
  /// Đây là cổng lưu Firestore duy nhất cho luồng AI tạo nhiệm vụ.
  /// UI có thể đã validate ở bước preview, nhưng service vẫn validate lại lần cuối
  /// để không có bản nháp AI lỗi nào đi thẳng vào TaskService/Firestore.
  ///
  /// Trả về taskId sau khi lưu thành công.
  Future<String> createTaskFromDraft(AiTaskDraft draft) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      throw Exception('Bạn cần đăng nhập trước khi tạo nhiệm vụ.');
    }

    final safeUid = uid.trim();

    _validateDraftBeforeCreate(draft);

    await _categoryService.ensureDefaultCategories(safeUid);

    final category = await _resolveCategory(
      uid: safeUid,
      categoryName: draft.effectiveCategoryName,
    );

    final priority = _mapPriority(draft.priority);
    final now = DateTime.now();

    final hasReminder = draft.hasReminder;
    final reminderOffsetMinutes = hasReminder ? draft.reminderMinutes : null;

    final newTask = TaskModel(
      id: '',
      title: draft.title.trim(),
      description: draft.description.trim(),
      categoryId: category.id,
      userId: safeUid,
      startDateTime: draft.startAt,
      endDateTime: draft.endAt,
      status: TaskStatus.pending,
      priority: priority,
      location: _cleanNullableText(draft.location),
      createdAt: now,
      updatedAt: now,

      // Legacy reminder fields.
      isReminderOn: hasReminder,
      reminderType: hasReminder ? TaskReminderType.start : TaskReminderType.none,
      reminderOffsetMinutes: reminderOffsetMinutes,
      reminderScheduledAt: null,
      localNotificationId: null,

      // New dual-reminder fields for DetailScreen UI.
      remindAtStart: hasReminder,
      startReminderOffsetMinutes: reminderOffsetMinutes ?? 0,
      remindAtDeadline: false,
      deadlineReminderOffsetMinutes: 0,
      startReminderScheduledAt: null,
      deadlineReminderScheduledAt: null,
      startLocalNotificationId: null,
      deadlineLocalNotificationId: null,
    );

    final scheduledAt = _taskService.calculateReminderScheduledAt(newTask);

    _validateTaskBeforePersist(
      task: newTask,
      uid: safeUid,
      now: now,
      scheduledAt: scheduledAt,
    );

    final taskId = await _taskService.createTask(newTask);
    final createdTask = newTask.copyWith(id: taskId);

    if (!createdTask.isReminderOn) {
      return taskId;
    }

    try {
      final granted = await NotificationService.instance.requestPermission();

      if (!granted) {
        debugPrint(
          'YTask AI: Người dùng chưa cấp quyền thông báo, task đã lưu nhưng chưa schedule reminder.',
        );
        return taskId;
      }

      final notificationId = await NotificationService.instance.scheduleTaskReminder(
        task: createdTask,
        offsetMinutes: createdTask.reminderOffsetMinutes ?? 0,
      );

      if (notificationId != null && scheduledAt != null) {
        await _taskService.updateTask(
          createdTask.copyWith(
            reminderScheduledAt: scheduledAt,
            localNotificationId: notificationId,
            startReminderScheduledAt: scheduledAt,
            startLocalNotificationId: notificationId,
          ),
        );
      }
    } catch (e) {
      // Không làm fail toàn bộ việc tạo task nếu local notification gặp lỗi.
      // Task đã được lưu Firestore thành công, người dùng vẫn có thể thấy trên Dashboard.
      debugPrint('YTask AI: Lỗi schedule reminder cho task $taskId: $e');
    }

    return taskId;
  }

  void _validateDraftBeforeCreate(AiTaskDraft draft) {
    final validationErrors = draft.validateForPreview();

    if (validationErrors.isNotEmpty) {
      throw Exception(_buildDraftValidationErrorMessage(validationErrors));
    }

    if (!draft.hasTitle || draft.title.trim().isEmpty) {
      throw Exception('AI chưa xác định được tên nhiệm vụ.');
    }

    if (!_isAllowedPriority(draft.priority)) {
      throw Exception('Độ ưu tiên không hợp lệ.');
    }

    if (draft.needsStartTimeForReminder) {
      throw Exception(
        'AI chưa xác định được thời gian bắt đầu. Vì có nhắc nhở, bạn cần bổ sung thời gian trước khi tạo nhiệm vụ.',
      );
    }

    final startAt = draft.startAt;
    final endAt = draft.endAt;

    if (startAt != null && endAt != null && endAt.isBefore(startAt)) {
      throw Exception('Thời gian kết thúc không được sớm hơn thời gian bắt đầu.');
    }
  }

  /// Lớp kiểm tra cuối cùng ngay trước khi gọi TaskService.createTask().
  /// Hàm này không phụ thuộc vào UI, nên kể cả nếu UI bị bypass thì dữ liệu AI
  /// vẫn không thể được ghi vào Firestore khi thiếu uid, title, category, status
  /// hoặc reminder không hợp lệ.
  void _validateTaskBeforePersist({
    required TaskModel task,
    required String uid,
    required DateTime now,
    required DateTime? scheduledAt,
  }) {
    if (uid.trim().isEmpty) {
      throw Exception('Bạn cần đăng nhập trước khi tạo nhiệm vụ.');
    }

    if (task.userId.trim().isEmpty || task.userId != uid) {
      throw Exception('Nhiệm vụ AI phải được gắn với tài khoản hiện tại.');
    }

    if (task.title.trim().isEmpty) {
      throw Exception('Tên nhiệm vụ không được để trống.');
    }

    if (task.categoryId.trim().isEmpty) {
      throw Exception('Nhiệm vụ cần có nhãn hợp lệ trước khi lưu.');
    }

    if (task.status != TaskStatus.pending) {
      throw Exception('Nhiệm vụ tạo từ AI phải có trạng thái ban đầu là pending.');
    }

    if (task.createdAt == null || task.updatedAt == null) {
      throw Exception('Nhiệm vụ cần có createdAt và updatedAt trước khi lưu.');
    }

    final startAt = task.startDateTime;
    final endAt = task.endDateTime;

    if (startAt != null && endAt != null && endAt.isBefore(startAt)) {
      throw Exception('Thời gian kết thúc không được sớm hơn thời gian bắt đầu.');
    }

    if (!task.isReminderOn) {
      return;
    }

    if (task.reminderType == TaskReminderType.none) {
      throw Exception('Nhiệm vụ có nhắc nhở nhưng thiếu loại nhắc nhở.');
    }

    if ((task.reminderOffsetMinutes ?? 0) <= 0) {
      throw Exception('Thời gian nhắc trước phải lớn hơn 0 phút.');
    }

    if (task.reminderType == TaskReminderType.start && startAt == null) {
      throw Exception('Muốn nhắc trước giờ bắt đầu thì cần có thời gian bắt đầu.');
    }

    if (task.reminderType == TaskReminderType.deadline && endAt == null) {
      throw Exception('Muốn nhắc trước hạn chót thì cần có thời gian kết thúc.');
    }

    if (scheduledAt == null || !scheduledAt.isAfter(now)) {
      throw Exception(
        'Thời điểm nhắc nhở đã qua. Bạn hãy chọn thời gian bắt đầu muộn hơn.',
      );
    }
  }

  String _buildDraftValidationErrorMessage(List<String> fields) {
    final normalizedFields = fields.toSet();

    if (normalizedFields.contains('title')) {
      return 'AI chưa xác định được tên nhiệm vụ.';
    }

    if (normalizedFields.contains('priority')) {
      return 'Độ ưu tiên AI trả về không hợp lệ. Chỉ chấp nhận low, medium hoặc high.';
    }

    if (normalizedFields.contains('startAt')) {
      return 'Thời gian bắt đầu AI trả về chưa hợp lệ hoặc còn thiếu. Bạn cần bổ sung thời gian trước khi tạo nhiệm vụ.';
    }

    if (normalizedFields.contains('endAt')) {
      return 'Thời gian kết thúc AI trả về chưa hợp lệ hoặc sớm hơn thời gian bắt đầu.';
    }

    return 'Bản nháp AI còn thiếu thông tin: ${normalizedFields.join(', ')}.';
  }

  Future<CategoryModel> _resolveCategory({
    required String uid,
    required String categoryName,
  }) async {
    final requestedName = categoryName.trim().isEmpty
        ? AiTaskDraft.defaultCategoryName
        : categoryName.trim();

    final categories = await _loadCategories(uid);

    final matchedCategory = _findCategoryByName(categories, requestedName) ??
        _findCategoryByName(categories, AiTaskDraft.defaultCategoryName);

    if (matchedCategory != null) {
      return matchedCategory;
    }

    // Trường hợp user đã có category riêng nên ensureDefaultCategories không tạo thêm,
    // nhưng lại chưa có "Công việc". Tạo fallback để task luôn có categoryId hợp lệ.
    await _categoryService.createCategory(
      CategoryModel(
        id: '',
        userId: uid,
        name: AiTaskDraft.defaultCategoryName,
        colorHex: 'FF64DA56',
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final refreshedCategories = await _loadCategories(uid);
    final fallbackCategory =
    _findCategoryByName(refreshedCategories, AiTaskDraft.defaultCategoryName);

    if (fallbackCategory == null) {
      throw Exception('Không tìm thấy nhãn để gắn cho nhiệm vụ.');
    }

    return fallbackCategory;
  }

  Future<List<CategoryModel>> _loadCategories(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .get();

    return snapshot.docs
        .map((doc) => CategoryModel.fromMap({
      ...doc.data(),
      'id': doc.data()['id'] ?? doc.id,
    }))
        .toList(growable: false);
  }

  CategoryModel? _findCategoryByName(
      List<CategoryModel> categories,
      String categoryName,
      ) {
    final normalizedTarget = _normalizeVietnamese(categoryName);

    for (final category in categories) {
      if (_normalizeVietnamese(category.name) == normalizedTarget) {
        return category;
      }
    }

    return null;
  }

  TaskPriority _mapPriority(String priority) {
    switch (priority) {
      case AiTaskDraft.priorityHigh:
        return TaskPriority.high;
      case AiTaskDraft.priorityLow:
        return TaskPriority.low;
      case AiTaskDraft.priorityMedium:
      default:
        return TaskPriority.medium;
    }
  }

  bool _isAllowedPriority(String priority) {
    return priority == AiTaskDraft.priorityLow ||
        priority == AiTaskDraft.priorityMedium ||
        priority == AiTaskDraft.priorityHigh;
  }

  String? _cleanNullableText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String _normalizeVietnamese(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
