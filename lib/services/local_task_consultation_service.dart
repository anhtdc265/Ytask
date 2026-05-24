import 'package:todo_app/models/ai_day_plan_result.dart';
import 'package:todo_app/models/ai_day_plan_task_summary.dart';
import 'package:todo_app/services/local_day_plan_sorter.dart';
import 'package:todo_app/services/local_ytask_reply_service.dart';

/// Local rule-based advisor for YTask chatbot.
///
/// This service handles task-consultation questions without calling Gemini.
/// It is intentionally lightweight and demo-friendly: it answers based on
/// priority, deadline, status, time and category from the user's real tasks.
class LocalTaskConsultationService {
  const LocalTaskConsultationService({
    this.sorter = const LocalDayPlanSorter(),
  });

  final LocalDayPlanSorter sorter;

  AiDayPlanResult answer({
    required String userMessage,
    required List<AiDayPlanTaskSummary> tasks,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final normalized = _normalize(userMessage);
    final safeTasks = _safeTasks(tasks);

    if (safeTasks.isEmpty) {
      return AiDayPlanResult.empty(
        summary:
        'Mình chưa thấy nhiệm vụ nào trong hôm nay để tư vấn. Bạn có thể tạo task ở Dashboard bằng nút (+).',
      );
    }

    if (_isStatusQuery(normalized)) {
      return _answerStatus(safeTasks, normalized, currentTime);
    }

    if (_isOverdueQuery(normalized)) {
      return _answerOverdue(safeTasks, currentTime);
    }

    if (_isDeadlineQuery(normalized)) {
      return _answerDeadline(safeTasks, normalized, currentTime);
    }

    if (_isCategoryQuery(normalized)) {
      return _answerCategory(safeTasks, normalized, currentTime);
    }

    if (_isChecklistQuery(normalized)) {
      return _answerChecklist(safeTasks, normalized, currentTime);
    }

    if (_isEisenhowerQuery(normalized)) {
      return _answerEisenhower(safeTasks, currentTime);
    }

    if (_isLimitedTimeQuery(normalized)) {
      return _answerLimitedTime(safeTasks, normalized, currentTime);
    }

    if (_isTimeBlockingQuery(normalized)) {
      return _answerTimeBlocking(safeTasks, currentTime);
    }

    if (_isOverloadQuery(normalized)) {
      return _answerOverload(safeTasks, currentTime);
    }

    if (_isPriorityQuery(normalized)) {
      return _answerPriority(safeTasks, normalized, currentTime);
    }

    if (_isAdjustmentQuery(normalized)) {
      return _answerAdjustment(safeTasks, normalized, currentTime);
    }

    return _answerGeneralPlan(safeTasks, currentTime);
  }

  List<AiDayPlanTaskSummary> _safeTasks(List<AiDayPlanTaskSummary> tasks) {
    return tasks
        .where((task) => task.id.trim().isNotEmpty && task.title.trim().isNotEmpty)
        .toList(growable: true);
  }

  List<AiDayPlanTaskSummary> _activeTasks(List<AiDayPlanTaskSummary> tasks) {
    return tasks.where((task) => !_isClosed(task)).toList(growable: true)
      ..sort(sorter.compareTasks);
  }

  AiDayPlanResult _answerGeneralPlan(
      List<AiDayPlanTaskSummary> tasks,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) {
      return AiDayPlanResult.empty(
        summary: 'Các nhiệm vụ hôm nay đều đã hoàn thành hoặc đã hủy. Bạn có thể nghỉ hoặc chuẩn bị kế hoạch cho ngày mai.',
      );
    }

    final plan = sorter.buildPlan(active);
    final overdueCount = active.where((task) => _isOverdue(task, now)).length;
    final highCount = active.where((task) => _isHigh(task)).length;

    return plan.copyWith(
      summary: overdueCount > 0
          ? 'Bạn có $overdueCount nhiệm vụ quá hạn. Mình xếp các việc cần xử lý gấp lên trước.'
          : 'Mình đã sắp xếp nhiệm vụ hôm nay theo ưu tiên, deadline và trạng thái hiện tại.',
      tips: <String>[
        if (overdueCount > 0) 'Xử lý task quá hạn trước để giảm rủi ro trễ tiến độ.',
        if (highCount > 0) 'Task ưu tiên cao nên được làm khi bạn còn nhiều năng lượng.',
        'Task chưa có thời gian rõ ràng nên bổ sung start/end để YTask tư vấn chính xác hơn.',
      ],
    );
  }

  AiDayPlanResult _answerPriority(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final sorted = active
      ..sort((a, b) {
        final urgentCompare = _urgencyRank(a, now).compareTo(_urgencyRank(b, now));
        if (urgentCompare != 0) return urgentCompare;
        return sorter.compareTasks(a, b);
      });

    final top = sorted.take(5).toList(growable: false);
    return AiDayPlanResult(
      summary:
      'Nên ưu tiên ${top.first.title} trước. Mình dựa trên độ ưu tiên, deadline gần/quá hạn và trạng thái đang làm.',
      items: _toItems(
        top,
        now,
        reasonBuilder: (task, index) => _priorityReason(task, now, index),
      ),
      tips: const <String>[
        'Nếu task high và gần deadline cùng lúc, hãy làm task đó trước.',
        'Nếu không đủ thời gian, giữ lại các task high hoặc task có deadline gần nhất.',
      ],
    );
  }

  AiDayPlanResult _answerDeadline(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final activeWithDeadline = _activeTasks(tasks)
        .where((task) => task.endAt != null)
        .toList(growable: true)
      ..sort((a, b) => a.endAt!.compareTo(b.endAt!));

    if (activeWithDeadline.isEmpty) {
      return AiDayPlanResult.empty(
        summary: 'Hôm nay chưa có nhiệm vụ nào có deadline rõ ràng. Bạn nên bổ sung thời gian kết thúc cho các task quan trọng.',
      );
    }

    final beforeNoon = normalized.contains('12 gio') || normalized.contains('truoc 12');
    final beforeEvening = normalized.contains('buoi toi') || normalized.contains('toi nay') || normalized.contains('truoc toi');

    Iterable<AiDayPlanTaskSummary> filtered = activeWithDeadline;
    if (beforeNoon) {
      filtered = filtered.where((task) => task.endAt!.hour < 12);
    } else if (beforeEvening) {
      filtered = filtered.where((task) => task.endAt!.hour < 18);
    }

    final result = filtered.take(5).toList(growable: false);
    if (result.isEmpty) {
      return AiDayPlanResult.empty(
        summary: beforeNoon
            ? 'Không thấy nhiệm vụ nào cần hoàn thành trước 12 giờ.'
            : 'Không thấy nhiệm vụ nào cần hoàn thành trước buổi tối.',
      );
    }

    final nearest = result.first;
    return AiDayPlanResult(
      summary: _isOverdue(nearest, now)
          ? 'Có nhiệm vụ đã quá hạn. Bạn nên xử lý ${nearest.title} trước.'
          : 'Task gần deadline nhất là ${nearest.title}, hạn ${_formatDateTime(nearest.endAt)}.',
      items: _toItems(
        result,
        now,
        reasonBuilder: (task, index) => _deadlineReason(task, now),
      ),
      tips: const <String>[
        'Task có deadline gần nên được xử lý trước task chưa có thời gian rõ ràng.',
        'Nếu task đã quá hạn, hãy hoàn thành hoặc điều chỉnh lại thời gian để kế hoạch thực tế hơn.',
      ],
    );
  }

  AiDayPlanResult _answerOverdue(
      List<AiDayPlanTaskSummary> tasks,
      DateTime now,
      ) {
    final overdue = _activeTasks(tasks)
        .where((task) => _isOverdue(task, now))
        .toList(growable: true)
      ..sort((a, b) {
        final priorityCompare = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
        if (priorityCompare != 0) return priorityCompare;
        return (a.endAt ?? now).compareTo(b.endAt ?? now);
      });

    if (overdue.isEmpty) {
      return AiDayPlanResult.empty(
        summary: 'Hiện tại không thấy nhiệm vụ quá hạn trong danh sách hôm nay. Bạn có thể tập trung vào task gần deadline nhất.',
      );
    }

    return AiDayPlanResult(
      summary: 'Bạn có ${overdue.length} nhiệm vụ quá hạn. Nên xử lý task quá hạn có ưu tiên cao hoặc trễ lâu nhất trước.',
      items: _toItems(
        overdue.take(5).toList(growable: false),
        now,
        reasonBuilder: (task, index) => 'Quá hạn từ ${_formatDateTime(task.endAt)}${_isHigh(task) ? ', đồng thời là task ưu tiên cao' : ''}.',
      ),
      tips: const <String>[
        'Hoàn thành ngay nếu task còn cần làm.',
        'Nếu task không còn cần thiết, hãy hủy để kế hoạch hôm nay gọn hơn.',
      ],
    );
  }

  AiDayPlanResult _answerOverload(
      List<AiDayPlanTaskSummary> tasks,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final overdueCount = active.where((task) => _isOverdue(task, now)).length;
    final highCount = active.where(_isHigh).length;
    final noTimeCount = active.where((task) => task.startAt == null && task.endAt == null).length;
    final score = active.length + overdueCount * 2 + highCount + noTimeCount;

    final heavy = score >= 9 || active.length >= 7 || overdueCount >= 2;
    final keep = active.take(3).toList(growable: false);
    final canMove = active.skip(3).take(3).toList(growable: false);

    return AiDayPlanResult(
      summary: heavy
          ? 'Kế hoạch hôm nay hơi nặng: ${active.length} task, $highCount task ưu tiên cao và $overdueCount task quá hạn. Bạn nên giữ 2–3 việc quan trọng nhất trước.'
          : 'Kế hoạch hôm nay khá ổn nếu bạn tập trung theo thứ tự ưu tiên và không ôm thêm quá nhiều task mới.',
      items: _toItems(
        keep,
        now,
        reasonBuilder: (task, index) => index == 0
            ? 'Nên giữ lại vì đây là task quan trọng/gấp nhất trong hôm nay.'
            : 'Nên làm trong hôm nay nếu còn đủ thời gian.',
      ),
      tips: <String>[
        if (canMove.isNotEmpty) 'Có thể cân nhắc dời: ${canMove.map((task) => task.title).join(', ')}.',
        'Ưu tiên task high, task quá hạn và task gần deadline trước.',
        'Task chưa có deadline rõ ràng có thể để sau nếu bạn mệt.',
      ],
    );
  }

  AiDayPlanResult _answerLimitedTime(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final minutes = _extractAvailableMinutes(normalized);
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final count = minutes <= 15
        ? 1
        : minutes <= 30
        ? 2
        : minutes <= 60
        ? 3
        : 4;

    final selected = active.take(count).toList(growable: false);
    final label = minutes >= 120
        ? '${minutes ~/ 60} tiếng'
        : '$minutes phút';

    return AiDayPlanResult(
      summary:
      'Nếu bạn chỉ có $label, hãy làm bản rút gọn: chọn ${selected.length} task quan trọng/gấp nhất thay vì cố làm hết.',
      items: _toItems(
        selected,
        now,
        reasonBuilder: (task, index) => index == 0
            ? 'Nên làm trước vì có mức ưu tiên/deadline nổi bật nhất.'
            : 'Làm tiếp nếu còn thời gian sau task đầu tiên.',
      ),
      tips: <String>[
        if (minutes <= 30) 'Đừng mở task quá lớn; chỉ xử lý phần nhỏ nhất có thể hoàn thành.',
        'Nếu không xong, ghi lại phần còn lại và dời sang buổi sau.',
      ],
    );
  }

  AiDayPlanResult _answerTimeBlocking(
      List<AiDayPlanTaskSummary> tasks,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final top = active.take(6).toList(growable: false);
    final items = <AiDayPlanItem>[];
    for (var i = 0; i < top.length; i++) {
      final task = top[i];
      items.add(
        AiDayPlanItem(
          taskId: task.id,
          title: task.title,
          suggestedOrder: i + 1,
          reason: _priorityReason(task, now, i),
          suggestedTimeText: _timeBlockLabel(i, task),
        ),
      );
    }

    return AiDayPlanResult(
      summary: 'Mình chia lịch hôm nay theo kiểu time blocking: việc quan trọng/gấp làm trước, task nhẹ gom về cuối ngày.',
      items: List<AiDayPlanItem>.unmodifiable(items),
      tips: const <String>[
        'Sau mỗi 60–90 phút nên nghỉ 5–10 phút để tránh đuối sức.',
        'Các task nhỏ giống nhau có thể gom lại làm một lượt.',
      ],
    );
  }

  AiDayPlanResult _answerEisenhower(
      List<AiDayPlanTaskSummary> tasks,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final urgentImportant = active.where((task) => _isImportant(task) && _isUrgent(task, now)).toList();
    final importantNotUrgent = active.where((task) => _isImportant(task) && !_isUrgent(task, now)).toList();
    final urgentNotImportant = active.where((task) => !_isImportant(task) && _isUrgent(task, now)).toList();
    final later = active.where((task) => !_isImportant(task) && !_isUrgent(task, now)).toList();

    final focus = <AiDayPlanTaskSummary>[
      ...urgentImportant,
      ...importantNotUrgent,
      ...urgentNotImportant,
      ...later,
    ].take(5).toList(growable: false);

    return AiDayPlanResult(
      summary:
      'Phân loại nhanh theo quan trọng/khẩn cấp: làm ngay ${urgentImportant.length} task, lên lịch ${importantNotUrgent.length} task, xử lý sau ${urgentNotImportant.length + later.length} task.',
      items: _toItems(
        focus,
        now,
        reasonBuilder: (task, index) {
          if (_isImportant(task) && _isUrgent(task, now)) return 'Vừa quan trọng vừa gấp: nên làm ngay.';
          if (_isImportant(task)) return 'Quan trọng nhưng chưa quá gấp: nên lên lịch rõ ràng.';
          if (_isUrgent(task, now)) return 'Gấp nhưng không quá quan trọng: xử lý nhanh, tránh tốn quá nhiều thời gian.';
          return 'Chưa gấp và ít quan trọng hơn: có thể để cuối ngày.';
        },
      ),
      tips: const <String>[
        'Quan trọng = priority high hoặc ảnh hưởng lớn đến kế hoạch.',
        'Khẩn cấp = quá hạn hoặc deadline gần trong hôm nay.',
      ],
    );
  }

  AiDayPlanResult _answerCategory(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final target = _categoryTarget(normalized);
    if (target != null) {
      final matched = active.where((task) => _normalize(task.categoryName ?? '').contains(target)).toList(growable: true)
        ..sort(sorter.compareTasks);

      if (matched.isEmpty) {
        return AiDayPlanResult.empty(
          summary: 'Hôm nay chưa thấy task thuộc danh mục ${_displayCategoryTarget(target)} trong danh sách cần xử lý.',
        );
      }

      return AiDayPlanResult(
        summary:
        'Hôm nay có ${matched.length} task thuộc ${_displayCategoryTarget(target)}. Nên ưu tiên task gần deadline hoặc priority cao trước.',
        items: _toItems(
          matched.take(5).toList(growable: false),
          now,
          reasonBuilder: (task, index) => _priorityReason(task, now, index),
        ),
        tips: const <String>[
          'Nếu một danh mục có quá nhiều task, hãy giữ lại 2–3 việc quan trọng nhất.',
        ],
      );
    }

    final groups = <String, List<AiDayPlanTaskSummary>>{};
    for (final task in active) {
      final name = (task.categoryName?.trim().isNotEmpty ?? false) ? task.categoryName!.trim() : 'Chưa có danh mục';
      groups.putIfAbsent(name, () => <AiDayPlanTaskSummary>[]).add(task);
    }

    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final topGroup = sortedGroups.first;
    final topTasks = topGroup.value..sort(sorter.compareTasks);

    return AiDayPlanResult(
      summary:
      'Danh mục nhiều task nhất hôm nay là ${topGroup.key} (${topGroup.value.length} task). Bạn nên tập trung danh mục này trước nếu có task high hoặc gần deadline.',
      items: _toItems(
        topTasks.take(5).toList(growable: false),
        now,
        reasonBuilder: (task, index) => _priorityReason(task, now, index),
      ),
      tips: sortedGroups.take(3).map((entry) => '${entry.key}: ${entry.value.length} task').toList(growable: false),
    );
  }

  AiDayPlanResult _answerStatus(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final pending = tasks.where((task) => _status(task) == 'pending').toList(growable: true)..sort(sorter.compareTasks);
    final doing = tasks.where((task) => _status(task) == 'inprogress').toList(growable: true)..sort(sorter.compareTasks);
    final completed = tasks.where((task) => _status(task) == 'completed').toList(growable: true);
    final cancelled = tasks.where((task) => _status(task) == 'cancelled').toList(growable: true);

    if (normalized.contains('bao nhieu') || normalized.contains('trang thai')) {
      return AiDayPlanResult.empty(
        summary:
        'Trạng thái hôm nay: ${pending.length} đang chờ, ${doing.length} đang làm, ${completed.length} đã hoàn thành, ${cancelled.length} đã hủy.',
      );
    }

    if (normalized.contains('dang lam') || normalized.contains('lam do') || normalized.contains('inprogress')) {
      if (doing.isEmpty) return AiDayPlanResult.empty(summary: 'Hiện không thấy task nào đang làm dở trong hôm nay.');
      return AiDayPlanResult(
        summary: 'Bạn có ${doing.length} task đang làm. Nên tiếp tục task đang làm trước khi mở thêm task mới.',
        items: _toItems(doing.take(5).toList(growable: false), now, reasonBuilder: (task, index) => 'Task đang thực hiện, nên xử lý tiếp để tránh dở dang quá lâu.'),
        tips: const <String>['Hoàn thành task đang làm trước giúp giảm phân tán.'],
      );
    }

    if (normalized.contains('hoan thanh')) {
      if (completed.isEmpty) return AiDayPlanResult.empty(summary: 'Hôm nay chưa thấy task nào đã hoàn thành.');
      return AiDayPlanResult(
        summary: 'Hôm nay bạn đã hoàn thành ${completed.length} task.',
        items: _toItems(completed.take(5).toList(growable: false), now, reasonBuilder: (task, index) => 'Task đã hoàn thành trong hôm nay.'),
      );
    }

    if (normalized.contains('bi huy') || normalized.contains('da huy') || normalized.contains('cancelled')) {
      if (cancelled.isEmpty) return AiDayPlanResult.empty(summary: 'Hôm nay chưa thấy task nào đã bị hủy.');
      return AiDayPlanResult(
        summary: 'Hôm nay có ${cancelled.length} task đã hủy.',
        items: _toItems(cancelled.take(5).toList(growable: false), now, reasonBuilder: (task, index) => 'Task đã hủy, không cần ưu tiên xử lý nữa.'),
      );
    }

    if (pending.isEmpty) return AiDayPlanResult.empty(summary: 'Hiện không thấy task pending trong hôm nay.');
    return AiDayPlanResult(
      summary: 'Bạn còn ${pending.length} task đang chờ. Nên xử lý task pending gần deadline hoặc priority cao trước.',
      items: _toItems(pending.take(5).toList(growable: false), now, reasonBuilder: (task, index) => _priorityReason(task, now, index)),
    );
  }

  AiDayPlanResult _answerChecklist(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final target = _findBestMatchingTask(active, normalized) ?? active.first;
    return AiDayPlanResult(
      summary: 'Với task “${target.title}”, bạn có thể chia nhỏ thành checklist 5 bước để dễ bắt đầu hơn.',
      items: <AiDayPlanItem>[
        AiDayPlanItem(
          taskId: target.id,
          title: target.title,
          suggestedOrder: 1,
          reason: 'Bước 1: Xác định kết quả cần hoàn thành.\nBước 2: Chuẩn bị tài liệu/công cụ cần dùng.\nBước 3: Làm phần quan trọng nhất trước.\nBước 4: Kiểm tra lại lỗi hoặc thiếu sót.\nBước 5: Đánh dấu hoàn thành trong YTask.',
          suggestedTimeText: 'Có thể chia thành 25–45 phút mỗi lượt làm.',
        ),
      ],
      tips: const <String>[
        'Đừng cố làm toàn bộ task lớn một lần; hãy bắt đầu từ bước nhỏ nhất.',
        'Nếu task có deadline, làm phần khó nhất trước.',
      ],
    );
  }

  AiDayPlanResult _answerAdjustment(
      List<AiDayPlanTaskSummary> tasks,
      String normalized,
      DateTime now,
      ) {
    final active = _activeTasks(tasks);
    if (active.isEmpty) return _allClosedResult();

    final lightFirst = normalized.contains('nhe truoc') || normalized.contains('de truoc');
    final importantFirst = normalized.contains('quan trong truoc') || normalized.contains('uu tien truoc');

    final sorted = active.toList(growable: true);
    if (lightFirst) {
      sorted.sort((a, b) {
        final priorityCompare = _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
        if (priorityCompare != 0) return priorityCompare;
        return sorter.compareTasks(a, b);
      });
    } else if (importantFirst) {
      sorted.sort(sorter.compareTasks);
    }

    return AiDayPlanResult(
      summary: lightFirst
          ? 'Mình đã xếp việc nhẹ hơn lên trước để bạn dễ vào guồng, nhưng vẫn giữ task gấp không bị đẩy quá xa.'
          : 'Mình đã tối ưu lại kế hoạch theo hướng làm việc quan trọng/gần deadline trước.',
      items: _toItems(sorted.take(6).toList(growable: false), now, reasonBuilder: (task, index) => _priorityReason(task, now, index)),
      tips: const <String>[
        'Sau khi thêm/hủy/hoàn thành task, hãy hỏi lại để YTask sắp xếp lại kế hoạch.',
      ],
    );
  }

  List<AiDayPlanItem> _toItems(
      List<AiDayPlanTaskSummary> tasks,
      DateTime now, {
        required String Function(AiDayPlanTaskSummary task, int index) reasonBuilder,
      }) {
    final items = <AiDayPlanItem>[];
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      items.add(
        AiDayPlanItem(
          taskId: task.id,
          title: task.title,
          suggestedOrder: i + 1,
          reason: reasonBuilder(task, i),
          suggestedTimeText: _suggestedTimeText(task, i, now),
        ),
      );
    }
    return List<AiDayPlanItem>.unmodifiable(items);
  }

  String _priorityReason(AiDayPlanTaskSummary task, DateTime now, int index) {
    final parts = <String>[];
    if (_isOverdue(task, now)) parts.add('đã quá hạn');
    if (_isHigh(task)) parts.add('ưu tiên cao');
    if (_isMedium(task)) parts.add('ưu tiên trung bình');
    if (_isUrgent(task, now) && !_isOverdue(task, now)) parts.add('deadline gần');
    if (_status(task) == 'inprogress') parts.add('đang làm dở');
    if (task.hasReminder) parts.add('có nhắc nhở');
    if (parts.isEmpty) parts.add(index == 0 ? 'phù hợp để bắt đầu trước' : 'có thể làm sau task quan trọng hơn');
    return 'Nên xếp ${index == 0 ? 'trước' : 'sau'} vì ${parts.join(', ')}.';
  }

  String _deadlineReason(AiDayPlanTaskSummary task, DateTime now) {
    if (task.endAt == null) return 'Task chưa có deadline rõ ràng.';
    if (_isOverdue(task, now)) return 'Task đã quá hạn từ ${_formatDateTime(task.endAt)}.';
    final diff = task.endAt!.difference(now);
    if (diff.inMinutes <= 60) return 'Deadline còn dưới 1 giờ, cần xử lý ngay.';
    if (diff.inHours <= 6) return 'Deadline còn khoảng ${diff.inHours} giờ, nên ưu tiên sớm.';
    return 'Deadline trong hôm nay lúc ${_formatTime(task.endAt)}.';
  }

  String _suggestedTimeText(AiDayPlanTaskSummary task, int index, DateTime now) {
    if (task.startAt != null && task.endAt != null) {
      return '${_formatTime(task.startAt)} – ${_formatTime(task.endAt)}';
    }
    if (task.endAt != null) return 'Nên làm trước ${_formatTime(task.endAt)}';
    if (task.startAt != null) return 'Bắt đầu khoảng ${_formatTime(task.startAt)}';
    if (index == 0) return 'Làm ngay khi bạn sẵn sàng.';
    return 'Xếp sau các task có deadline rõ ràng.';
  }

  String _timeBlockLabel(int index, AiDayPlanTaskSummary task) {
    if (task.startAt != null || task.endAt != null) {
      return _suggestedTimeText(task, index, DateTime.now());
    }
    switch (index) {
      case 0:
        return 'Khung đầu tiên: làm ngay hoặc đầu buổi sáng.';
      case 1:
        return 'Khung tiếp theo: cuối buổi sáng hoặc đầu buổi chiều.';
      case 2:
        return 'Khung chiều: xử lý sau khi hoàn thành task chính.';
      default:
        return 'Cuối ngày: làm nếu còn năng lượng.';
    }
  }

  AiDayPlanResult _allClosedResult() {
    return AiDayPlanResult.empty(
      summary: 'Các nhiệm vụ hôm nay đã hoàn thành hoặc đã hủy. Bạn không còn task active cần ưu tiên lúc này.',
    );
  }

  bool _isStatusQuery(String text) => _containsAny(text, <String>[
    'trang thai',
    'tinh trang',
    'dang cho',
    'pending',
    'dang lam',
    'lam do',
    'inprogress',
    'in progress',
    'chua bat dau',
    'hoan thanh',
    'da xong',
    'da huy',
    'bi huy',
    'cancelled',
    'con bao nhieu task',
    'bao nhieu task',
    'con bao nhieu nhiem vu',
    'bao nhieu viec',
  ]);

  bool _isOverdueQuery(String text) => _containsAny(text, <String>['qua han', 'bi tre', 'se bi tre', 'tre han']);

  bool _isDeadlineQuery(String text) => _containsAny(text, <String>[
    'deadline',
    'han chot',
    'thoi han',
    'den han',
    'het han',
    'gan han',
    'gan deadline',
    'sap den han',
    'sap het han',
    'truoc 12',
    '12 gio',
    'truoc buoi toi',
    'truoc toi',
    'can hoan thanh truoc',
  ]);

  bool _isPriorityQuery(String text) => _containsAny(text, <String>[
    'uu tien',
    'priority',
    'quan trong nhat',
    'quan trong',
    'can lam truoc',
    'nen lam truoc',
    'lam gi truoc',
    'xu ly gap',
    'gap nhat',
    'high truoc',
    'gan deadline truoc',
    'xep uu tien',
  ]);

  bool _isOverloadQuery(String text) => _containsAny(text, <String>[
    'qua tai',
    'qua nhieu viec',
    'nang qua',
    'om qua nhieu',
    'co thuc te khong',
    'hoan thanh het khong',
    'bo bot',
    'doi task nao',
    'de sang ngay mai',
    'neu toi met',
  ]);

  bool _isTimeBlockingQuery(String text) => _containsAny(text, <String>[
    'chia lich',
    'chia thoi gian',
    'khung gio',
    'time blocking',
    'buoi sang',
    'buoi chieu',
    'buoi toi',
    'tu gio den toi',
    'danh bao lau',
    'nghi giua',
    'gom cac task nho',
  ]);

  bool _isEisenhowerQuery(String text) => _containsAny(text, <String>[
    'quan trong vua gap',
    'vua quan trong vua gap',
    'quan trong nhung chua can',
    'gap nhung khong qua quan trong',
    'muc do quan trong',
    'viec lon',
    'viec nho',
    'dang lam nhat',
    'dang lam nhat hom nay',
    'dang lam nhat',
    'dang lam nhat',
    'eisenhower',
  ]) || (text.contains('quan trong') && text.contains('gap'));

  bool _isLimitedTimeQuery(String text) => _containsAny(text, <String>[
    'chi con',
    'chi ranh',
    'khong lam het',
    'ban ca ngay',
    '2 viec quan trong',
    '3 nhiem vu',
    'ban rut gon',
    'toi gian',
    '15 phut',
    '30 phut',
    '1 tieng',
    '2 tieng',
    'lam nhanh',
    'ton it thoi gian',
  ]);

  bool _isChecklistQuery(String text) => _containsAny(text, <String>[
    'chia nho',
    'checklist',
    'bat dau tu dau',
    'bat dau tu buoc nao',
    'cac buoc nho',
    'thu tu nao',
    'phan nao truoc',
    'task nay hoi lon',
  ]);

  bool _isAdjustmentQuery(String text) => _containsAny(text, <String>[
    'dieu chinh lai',
    'doi thu tu',
    'sap xep lai',
    'toi uu lai',
    'sau khi them',
    'neu toi huy',
    'neu toi hoan thanh',
    'lam viec nhe truoc',
    'viec nhe truoc',
    'quan trong truoc',
  ]);

  bool _isCategoryQuery(String text) {
    // Chỉ coi là hỏi theo danh mục khi người dùng nói rõ "danh mục/category/nhãn"
    // hoặc nhắc đến một nhóm cụ thể như học tập, cá nhân.
    // Không bắt cụm "công việc hôm nay" ở đây, vì trong tiếng Việt "công việc"
    // thường chỉ toàn bộ task, không phải danh mục tên "Công việc".
    if (_containsAny(text, <String>[
      'category',
      'danh muc',
      'nhan',
    ])) {
      return true;
    }

    return _categoryTarget(text) != null;
  }

  AiDayPlanTaskSummary? _findBestMatchingTask(List<AiDayPlanTaskSummary> tasks, String normalized) {
    for (final task in tasks) {
      final title = _normalize(task.title);
      if (title.split(' ').where((word) => word.length >= 3).any(normalized.contains)) {
        return task;
      }
    }
    return null;
  }

  int _extractAvailableMinutes(String text) {
    if (text.contains('15 phut')) return 15;
    if (text.contains('30 phut')) return 30;
    if (text.contains('2 tieng') || text.contains('hai tieng')) return 120;
    if (text.contains('1 tieng') || text.contains('mot tieng')) return 60;
    if (text.contains('buoi toi')) return 180;
    return 60;
  }

  String? _categoryTarget(String text) {
    final hasExplicitCategoryKeyword = _containsAny(text, <String>[
      'category',
      'danh muc',
      'nhan',
    ]);

    if (text.contains('hoc tap') ||
        text.contains('viec hoc') ||
        text.contains('task hoc') ||
        text.contains('hoc hom nay') ||
        text.contains('tap trung vao hoc')) {
      return 'hoc';
    }

    // Chỉ lọc danh mục "Công việc" khi câu hỏi thật sự đang nói về danh mục.
    // Ví dụ đúng: "danh mục Công việc hôm nay có gì?"
    // Ví dụ KHÔNG lọc: "Công việc hôm nay của tôi là gì?"
    if (hasExplicitCategoryKeyword &&
        (text.contains('cong viec') ||
            text.contains('di lam') ||
            text.contains('bao cao'))) {
      return 'cong viec';
    }

    if (text.contains('ca nhan') || text.contains('viec ca nhan')) return 'ca nhan';
    if (text.contains('van dong') || text.contains('tap luyen')) return 'van dong';
    if (text.contains('di choi')) return 'di choi';
    return null;
  }

  String _displayCategoryTarget(String target) {
    switch (target) {
      case 'hoc':
        return 'Học tập';
      case 'cong viec':
        return 'Công việc';
      case 'ca nhan':
        return 'Cá nhân';
      case 'van dong':
        return 'Vận động';
      case 'di choi':
        return 'Đi chơi';
      default:
        return target;
    }
  }

  bool _isClosed(AiDayPlanTaskSummary task) {
    final status = _status(task);
    return status == 'completed' || status == 'cancelled';
  }

  bool _isOverdue(AiDayPlanTaskSummary task, DateTime now) {
    return !_isClosed(task) && task.endAt != null && task.endAt!.isBefore(now);
  }

  bool _isUrgent(AiDayPlanTaskSummary task, DateTime now) {
    if (_isOverdue(task, now)) return true;
    final endAt = task.endAt;
    if (endAt == null) return false;
    final diff = endAt.difference(now);
    return !diff.isNegative && diff.inHours <= 4;
  }

  bool _isImportant(AiDayPlanTaskSummary task) => _isHigh(task) || task.hasReminder;
  bool _isHigh(AiDayPlanTaskSummary task) => task.priority.trim().toLowerCase() == 'high';
  bool _isMedium(AiDayPlanTaskSummary task) => task.priority.trim().toLowerCase() == 'medium';

  int _urgencyRank(AiDayPlanTaskSummary task, DateTime now) {
    if (_isOverdue(task, now)) return 0;
    if (_isUrgent(task, now)) return 1;
    if (task.endAt != null) return 2;
    return 3;
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

  String _status(AiDayPlanTaskSummary task) => task.status.trim().toLowerCase();

  String _formatTime(DateTime? value) {
    if (value == null) return 'chưa rõ';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'chưa rõ';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute, ${local.day}/${local.month}';
  }

  bool _containsAny(String text, List<String> values) {
    return values.any(text.contains);
  }

  String _normalize(String input) {
    return LocalYTaskReplyService.normalize(input);
  }
}
