import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:todo_app/models/ai_day_plan_result.dart';
import 'package:todo_app/models/ai_day_plan_task_summary.dart';
import 'package:todo_app/services/category_service.dart';
import 'package:todo_app/services/local_day_plan_sorter.dart';
import 'package:todo_app/services/local_task_consultation_service.dart';
import 'package:todo_app/services/task_service.dart';

/// Coordinates the day-planning / task-consultation flow.
///
/// This version is LOCAL-FIRST / LOCAL-ONLY for demo stability:
/// 1. Read the current Firebase user.
/// 2. Load today's real tasks from Firestore through TaskService.
/// 3. Convert TaskModel objects to safe summaries.
/// 4. Answer with local rule-based logic.
///
/// Important: this file intentionally does NOT call Gemini.
/// It prevents RESOURCE_EXHAUSTED when users ask day-plan questions such as
/// "Hôm nay tôi nên làm gì trước?" or "Task nào gần deadline nhất?".
class AiDayPlanService {
  AiDayPlanService({
    FirebaseAuth? firebaseAuth,
    TaskService? taskService,
    CategoryService? categoryService,
    LocalDayPlanSorter? localDayPlanSorter,
    LocalTaskConsultationService? localTaskConsultationService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _taskService = taskService ?? TaskService(),
        _categoryService = categoryService ?? CategoryService(),
        _localDayPlanSorter = localDayPlanSorter ?? const LocalDayPlanSorter(),
        _localTaskConsultationService = localTaskConsultationService ??
            const LocalTaskConsultationService();

  final FirebaseAuth _firebaseAuth;
  final TaskService _taskService;
  final CategoryService _categoryService;
  final LocalDayPlanSorter _localDayPlanSorter;
  final LocalTaskConsultationService _localTaskConsultationService;

  Future<AiDayPlanResult> generateTodayPlan({String userMessage = ''}) async {
    final uid = _firebaseAuth.currentUser?.uid.trim() ?? '';

    if (uid.isEmpty) {
      return AiDayPlanResult.empty(
        summary:
        'Bạn cần đăng nhập để mình lấy danh sách nhiệm vụ hôm nay và gợi ý thứ tự làm việc.',
      );
    }

    try {
      final todayTasks = await _taskService.getTodayTasksForConsultation(uid);

      if (todayTasks.isEmpty) {
        return AiDayPlanResult.empty(
          summary: 'Hôm nay bạn chưa có nhiệm vụ nào.',
        );
      }

      final categoryNameById = await _loadCategoryNameById(uid);

      final summaries = todayTasks
          .map(
            (task) => AiDayPlanTaskSummary.fromTaskModel(
          task,
          categoryName: categoryNameById[task.categoryId],
        ),
      )
          .where(
            (summary) =>
        summary.id.trim().isNotEmpty &&
            summary.title.trim().isNotEmpty,
      )
          .toList(growable: false);

      if (summaries.isEmpty) {
        return AiDayPlanResult.empty(
          summary: 'Hôm nay chưa có nhiệm vụ đủ thông tin để lập kế hoạch.',
        );
      }

      final cleanedUserMessage = userMessage.trim();
      if (cleanedUserMessage.isNotEmpty) {
        return _localTaskConsultationService.answer(
          userMessage: cleanedUserMessage,
          tasks: summaries,
        );
      }

      return _buildLocalPlan(summaries);
    } catch (e, stackTrace) {
      debugPrint('AiDayPlanService generateTodayPlan error: $e');
      debugPrintStack(stackTrace: stackTrace);

      return AiDayPlanResult.empty(
        summary: 'Mình chưa thể lập kế hoạch hôm nay. Bạn thử lại sau nhé.',
      );
    }
  }

  Future<Map<String, String>> _loadCategoryNameById(String uid) async {
    try {
      final categories = await _categoryService.getCategoriesForUser(uid);
      return <String, String>{
        for (final category in categories)
          if (category.id.trim().isNotEmpty && category.name.trim().isNotEmpty)
            category.id: category.name.trim(),
      };
    } catch (e) {
      debugPrint('AiDayPlanService load categories error: $e');
      return const <String, String>{};
    }
  }

  AiDayPlanResult _buildLocalPlan(List<AiDayPlanTaskSummary> summaries) {
    final localPlan = _localDayPlanSorter.buildPlan(summaries);

    if (!localPlan.hasItems) {
      return localPlan;
    }

    return localPlan.copyWith(
      summary:
      'YTask đã sắp xếp các nhiệm vụ hôm nay bằng thuật toán nội bộ, dựa trên độ ưu tiên, thời hạn, thời gian bắt đầu và trạng thái.',
    );
  }
}
