import 'package:todo_app/models/ai_day_plan_result.dart';
import 'package:todo_app/models/ai_day_plan_task_summary.dart';

/// Local fallback planner for the AI day-plan feature.
///
/// This class is intentionally deterministic so the app can still demo a
/// reasonable day plan when Gemini/network is unavailable.
///
/// Sort priority:
/// 1. priority = high
/// 2. endAt nearest
/// 3. startAt earliest
/// 4. inProgress before pending
/// 5. tasks without time at the end
class LocalDayPlanSorter {
  const LocalDayPlanSorter();

  AiDayPlanResult buildPlan(List<AiDayPlanTaskSummary> sourceTasks) {
    final safeTasks = sourceTasks
        .where((task) => task.id.trim().isNotEmpty && task.title.trim().isNotEmpty)
        .toList(growable: true)
      ..sort(compareTasks);

    final items = <AiDayPlanItem>[];

    for (final task in safeTasks) {
      final lacksTime = _lacksTime(task);
      final order = items.length + 1;

      items.add(
        AiDayPlanItem(
          taskId: task.id,
          title: task.title,
          suggestedOrder: order,
          reason: _buildReason(task, order),
          suggestedTimeText: lacksTime
              ? 'Chưa có thời gian rõ ràng, có thể xếp vào cuối ngày.'
              : order == 1
              ? 'Nên làm đầu tiên.'
              : 'Làm sau các nhiệm vụ ưu tiên hơn.',
        ),
      );
    }

    if (items.isEmpty) {
      return AiDayPlanResult.empty(
        summary: 'Hôm nay chưa có nhiệm vụ đủ thông tin để lập kế hoạch.',
      );
    }

    return AiDayPlanResult(
      summary:
          'Mình đã sắp xếp tạm các nhiệm vụ hôm nay theo mức ưu tiên và thời hạn gần nhất.',
      items: List<AiDayPlanItem>.unmodifiable(items),
      tips: const <String>[
        'Hãy xử lý nhiệm vụ ưu tiên cao hoặc gần đến hạn trước.',
        'Các nhiệm vụ chưa có thời gian rõ ràng nên được xếp sau hoặc bổ sung thời gian cụ thể.',
      ],
    );
  }

  int compareTasks(AiDayPlanTaskSummary a, AiDayPlanTaskSummary b) {
    // 5. Task không có thời gian để cuối.
    final aLacksTime = _lacksTime(a);
    final bLacksTime = _lacksTime(b);
    if (aLacksTime != bLacksTime) {
      return aLacksTime ? 1 : -1;
    }

    // 1. Priority high trước.
    final priorityCompare = _priorityRank(a.priority).compareTo(
      _priorityRank(b.priority),
    );
    if (priorityCompare != 0) return priorityCompare;

    // 2. Deadline/endAt gần nhất trước.
    final endCompare = _compareNullableDateTime(a.endAt, b.endAt);
    if (endCompare != 0) return endCompare;

    // 3. StartAt sớm nhất trước.
    final startCompare = _compareNullableDateTime(a.startAt, b.startAt);
    if (startCompare != 0) return startCompare;

    // 4. inProgress trước pending.
    final statusCompare = _statusRank(a.status).compareTo(
      _statusRank(b.status),
    );
    if (statusCompare != 0) return statusCompare;

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  bool _lacksTime(AiDayPlanTaskSummary task) {
    return task.startAt == null && task.endAt == null;
  }

  int _compareNullableDateTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int _priorityRank(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }

  int _statusRank(String status) {
    switch (status.trim().toLowerCase()) {
      case 'inprogress':
        return 0;
      case 'pending':
        return 1;
      default:
        return 2;
    }
  }

  String _buildReason(AiDayPlanTaskSummary task, int order) {
    final reasons = <String>[];
    final priority = task.priority.trim().toLowerCase();
    final status = task.status.trim().toLowerCase();

    if (priority == 'high') {
      reasons.add('ưu tiên cao');
    } else if (priority == 'medium') {
      reasons.add('ưu tiên trung bình');
    } else if (priority == 'low') {
      reasons.add('mức ưu tiên thấp hơn');
    }

    if (task.endAt != null) {
      reasons.add('có thời hạn gần trong hôm nay');
    } else if (task.startAt != null) {
      reasons.add('có thời gian bắt đầu rõ ràng');
    } else {
      reasons.add('chưa có thời gian rõ ràng nên xếp sau');
    }

    if (status == 'inprogress') {
      reasons.add('đang thực hiện');
    } else if (status == 'pending') {
      reasons.add('đang chờ xử lý');
    }

    if (task.hasReminder) {
      reasons.add('có nhắc nhở');
    }

    if (reasons.isEmpty) {
      return order == 1
          ? 'Nhiệm vụ này phù hợp để làm trước trong hôm nay.'
          : 'Nhiệm vụ này có thể làm sau các việc quan trọng hơn.';
    }

    return 'Nên xếp ${order == 1 ? 'trước' : 'sau'} vì ${reasons.join(', ')}.';
  }
}
