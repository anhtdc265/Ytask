import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/services/task_service.dart';
import 'package:todo_app/shared/widgets/custom_bottom_nav.dart';
import 'package:todo_app/features/dashboard/create_task_screen.dart';
import 'package:todo_app/features/dashboard/detail_task_screen.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/services/category_service.dart';
import 'package:todo_app/features/progress/task_status_list_screen.dart';
import 'package:todo_app/core/utils/effective_task_status.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  static const double _searchOverlayTop = 176;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQueryNotifier.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252724) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 30,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              cursorColor: const Color(0xFF64DA56),
              decoration: const InputDecoration(
                hintText: "Tìm kiếm task...",
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, query, _) {
              if (query.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: "Xóa tìm kiếm",
                onPressed: () {
                  _searchController.clear();
                  _searchFocusNode.requestFocus();
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 30,
                  color: Color(0xFF4F4F59),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBanner(BuildContext context, int overdueCount) {
    const Color yTaskGreen = Color(0xFF64DA56);
    const Color yTaskRed = Color(0xFFFF5252);

    final bool hasOverdue = overdueCount > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color mainColor = hasOverdue ? yTaskRed : yTaskGreen;

    final Color backgroundColor = hasOverdue
        ? yTaskRed.withOpacity(isDark ? 0.18 : 0.12)
        : yTaskGreen.withOpacity(isDark ? 0.16 : 0.14);

    final Color borderColor = hasOverdue
        ? yTaskRed.withOpacity(0.32)
        : yTaskGreen.withOpacity(0.32);

    return InkWell(
      onTap: hasOverdue
          ? () => _openTaskStatusList(
        context,
        TaskStatusListType.overdue,
      )
          : null,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                color: mainColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasOverdue
                        ? "Cảnh báo nhiệm vụ quá hạn"
                        : "Tiến độ đang ổn định",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: mainColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasOverdue
                        ? "Bạn có $overdueCount nhiệm vụ quá hạn cần xử lý"
                        : "Không có nhiệm vụ quá hạn",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasOverdue
                  ? Icons.chevron_right_rounded
                  : Icons.check_circle_outline_rounded,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const Color yTaskGreen = Color(0xFF63D64E);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "Vui lòng đăng nhập để xem tiến độ",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: bgColor,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
      body: SafeArea(
        child: StreamBuilder<List<TaskModel>>(
          stream: TaskService().getTasksByUser(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: yTaskGreen),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    "Đã xảy ra lỗi: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            final tasks = snapshot.data ?? [];
            if (tasks.isEmpty) {
              return _buildEmptyState();
            }

            return _buildMainContent(context, tasks);
          },
        ),
      ),
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTaskScreen()),
            );
          },
          backgroundColor: const Color(0xFF64DA56),
          shape: const CircleBorder(),
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Chưa có dữ liệu tiến độ",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            "Hãy hoàn thành nhiệm vụ để thấy kết quả!",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<TaskModel> _filterTasks(List<TaskModel> tasks) {
    final query = _normalizeSearchText(_searchController.text);

    if (query.isEmpty) return tasks;

    final queryTerms = query
        .split(' ')
        .where((term) => term.trim().isNotEmpty)
        .toList();

    return tasks.where((task) {
      final searchableText = _taskSearchableText(task);
      return queryTerms.every(searchableText.contains);
    }).toList();
  }

  Widget _buildSearchResultsOverlay(
      BuildContext context,
      List<TaskModel> allTasks,
      ) {
    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (context, query, _) {
        if (query.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        final results = _filterTasks(allTasks);
        return Positioned(
          top: _searchOverlayTop,
          left: 32,
          right: 32,
          child: Material(
            color: Colors.transparent,
            child: _buildSearchResultsPanel(context, results),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsPanel(
      BuildContext context,
      List<TaskModel> results,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF64DA56).withOpacity(0.43),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252724) : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Không tìm thấy task phù hợp",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    final displayResults = results.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF64DA56).withOpacity(0.43),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < displayResults.length; i++) ...[
            _buildSearchTaskCard(context, displayResults[i]),
            if (i != displayResults.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _openTaskDetail(BuildContext context, TaskModel task) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? task.userId;

    try {
      final categories = await CategoryService().getCategoriesByUser(uid).first;

      CategoryModel? matchedCategory;
      for (final category in categories) {
        if (category.id == task.categoryId) {
          matchedCategory = category;
          break;
        }
      }

      final fallbackCategory = CategoryModel(
        id: task.categoryId,
        userId: uid,
        name: "Khác",
        colorHex: "FF64DA56",
        isDefault: true,
      );

      final initialCategory = matchedCategory ?? fallbackCategory;

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailTaskScreen(
            task: task,
            initialCategory: initialCategory,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Không thể mở chi tiết task: $e"),
        ),
      );
    }
  }

  Widget _buildSearchTaskCard(BuildContext context, TaskModel task) {
    final effectiveStatus = EffectiveTaskStatusResolver.resolve(task);
    final statusColor = _effectiveSearchStatusColor(effectiveStatus);
    final priorityColor = _priorityColor(task.priority);
    final statusIcon = _effectiveSearchStatusIcon(effectiveStatus);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openTaskDetail(context, task),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 42,
              height: double.infinity,
              color: statusColor,
              child: Icon(
                statusIcon,
                size: 22,
                color: const Color(0xFF202124),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildMiniChip(
                          text: _priorityText(task.priority),
                          backgroundColor: priorityColor,
                          textColor: priorityColor,
                        ),
                        const SizedBox(width: 6),
                        _buildMiniChip(
                          text: EffectiveTaskStatusResolver.label(effectiveStatus),
                          backgroundColor: const Color(0xFF64DA56),
                          textColor: const Color(0xFF1E8F2D),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 82,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatShortDateTime(task.startDateTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF36D747),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatShortDateTime(task.endDateTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF3131),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip({
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          height: 1.0,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Color _effectiveSearchStatusColor(EffectiveTaskStatus? status) {
    switch (status) {
      case EffectiveTaskStatus.inProgress:
        return const Color(0xFF64DA56);
      case EffectiveTaskStatus.pending:
        return const Color(0xFFFFE562);
      case EffectiveTaskStatus.cancelled:
        return const Color(0xFFABABAB);
      case EffectiveTaskStatus.completed:
        return const Color(0xFF62E5FF);
      case EffectiveTaskStatus.overdue:
        return const Color(0xFFFF5252);
      case null:
        return const Color(0xFFABABAB);
    }
  }

  IconData _effectiveSearchStatusIcon(EffectiveTaskStatus? status) {
    switch (status) {
      case EffectiveTaskStatus.inProgress:
        return Icons.play_arrow_rounded;
      case EffectiveTaskStatus.pending:
        return Icons.hourglass_top_rounded;
      case EffectiveTaskStatus.cancelled:
        return Icons.notifications_off_rounded;
      case EffectiveTaskStatus.completed:
        return Icons.check_circle_rounded;
      case EffectiveTaskStatus.overdue:
        return Icons.warning_amber_rounded;
      case null:
        return Icons.close_rounded;
    }
  }

  String _formatShortDateTime(DateTime? dateTime) {
    if (dateTime == null) return "--:--";

    String twoDigits(int value) => value.toString().padLeft(2, "0");

    final now = DateTime.now();
    final day = twoDigits(dateTime.day);
    final month = twoDigits(dateTime.month);
    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    if (dateTime.year == now.year) {
      return "$day/$month, $hour:$minute";
    }

    return "$day/$month/${dateTime.year}, $hour:$minute";
  }

  String _normalizeSearchText(String input) {
    var value = input.toLowerCase().trim();

    const vietnameseMap = {
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',

      'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',

      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',

      'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',

      'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',

      'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',

      'đ': 'd',
    };

    vietnameseMap.forEach((key, replacement) {
      value = value.replaceAll(key, replacement);
    });

    value = value.replaceAll(RegExp(r'\s+'), ' ');
    return value;
  }

  String _priorityText(TaskPriority priority) => priority.vietnameseLabel;

  String _prioritySearchText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return "low thap thấp";
      case TaskPriority.medium:
        return "medium trung binh trung bình";
      case TaskPriority.high:
        return "high cao";
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return const Color(0xFF63D64E);
      case TaskPriority.medium:
        return const Color(0xFFFF9800);
      case TaskPriority.high:
        return const Color(0xFFFF5252);
    }
  }

  bool _isOverdue(TaskModel task) {
    return EffectiveTaskStatusResolver.isOverdue(task);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfCurrentWeek() {
    final today = _dateOnly(DateTime.now());
    return today.subtract(Duration(days: today.weekday - 1));
  }

  bool _isTaskRelatedToWeek(
      TaskModel task,
      DateTime weekStart,
      DateTime weekEnd,
      ) {
    final start = task.startDateTime ?? task.endDateTime ?? task.createdAt;
    final end = task.endDateTime ?? task.startDateTime ?? task.updatedAt ?? task.createdAt;

    if (start == null && end == null) return false;

    final cleanStart = _dateOnly(start ?? end!);
    final cleanEnd = _dateOnly(end ?? start!).add(const Duration(days: 1));

    return cleanStart.isBefore(weekEnd) && cleanEnd.isAfter(weekStart);
  }

  _OverviewMetrics _calculateWeeklyOverview(List<TaskModel> tasks) {
    final now = DateTime.now();
    final weekStart = _startOfCurrentWeek();
    final weekEnd = weekStart.add(const Duration(days: 7));

    final dailyCompleted = List<int>.filled(7, 0);
    int totalThisWeek = 0;

    for (final task in tasks) {
      if (task.isDeleted) continue;

      var shouldCountInWeek = _isTaskRelatedToWeek(task, weekStart, weekEnd);

      final effectiveStatus = EffectiveTaskStatusResolver.resolve(task, now: now);
      final completedDate = effectiveStatus == EffectiveTaskStatus.completed
          ? task.completedAt ?? task.updatedAt ?? task.endDateTime ?? task.createdAt
          : null;

      if (completedDate != null) {
        final cleanCompletedDate = _dateOnly(completedDate);
        final dayIndex = cleanCompletedDate.difference(weekStart).inDays;

        if (dayIndex >= 0 && dayIndex < 7) {
          dailyCompleted[dayIndex]++;
          shouldCountInWeek = true;
        }
      }

      if (shouldCountInWeek) {
        totalThisWeek++;
      }
    }

    final completedThisWeek = dailyCompleted.fold<int>(
      0,
          (total, value) => total + value,
    );

    double completionRate = 0;
    if (totalThisWeek > 0) {
      completionRate = (completedThisWeek / totalThisWeek) * 100;
      if (completionRate > 100) completionRate = 100;
    }

    int bestDayIndex = 0;
    int bestDayCount = 0;

    for (int i = 0; i < dailyCompleted.length; i++) {
      if (dailyCompleted[i] > bestDayCount) {
        bestDayCount = dailyCompleted[i];
        bestDayIndex = i;
      }
    }

    return _OverviewMetrics(
      completedThisWeek: completedThisWeek,
      totalThisWeek: totalThisWeek,
      completionRate: completionRate,
      dailyCompleted: dailyCompleted,
      bestDayIndex: bestDayIndex,
      bestDayCount: bestDayCount,
    );
  }

  String _weekdayLabel(int index) {
    const labels = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
    return labels[index.clamp(0, 6)];
  }

  String _formatDateTimeForSearch(DateTime? dateTime) {
    if (dateTime == null) return "";

    String twoDigits(int value) => value.toString().padLeft(2, "0");

    final day = twoDigits(dateTime.day);
    final month = twoDigits(dateTime.month);
    final year = dateTime.year.toString();    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    return [
      "$day/$month",
      "$day/$month/$year",
      "${dateTime.day} th${dateTime.month}",
      "${dateTime.day} th${dateTime.month} $year",
      "$hour:$minute",
      "$day/$month, $hour:$minute",
      "$day/$month/$year, $hour:$minute",
      year,
      month,
      day,
    ].join(" ");
  }

  String _taskSearchableText(TaskModel task) {
    final effectiveStatus = EffectiveTaskStatusResolver.resolve(task);
    final rawText = [
      task.title,
      task.description,
      task.location ?? "",
      _priorityText(task.priority),
      _prioritySearchText(task.priority),
      EffectiveTaskStatusResolver.label(effectiveStatus),
      EffectiveTaskStatusResolver.searchText(effectiveStatus),
      _formatDateTimeForSearch(task.startDateTime),
      _formatDateTimeForSearch(task.endDateTime),
      _formatDateTimeForSearch(task.createdAt),
      _formatDateTimeForSearch(task.updatedAt),
    ].join(" ");

    return _normalizeSearchText(rawText);
  }

  Widget _buildMainContent(BuildContext context, List<TaskModel> tasks) {
    final metrics = TaskProgressMetrics.fromTasks(tasks);

    final pending = metrics.pending;
    final inProgress = metrics.inProgress;
    final completed = metrics.completed;
    final cancelled = metrics.cancelled;
    final overdue = metrics.overdue;
    final overdueCount = metrics.overdue;
    final total = metrics.total;
    final completionRate = metrics.completionRate;
    const Color yTaskGreen = Color(0xFF63D64E);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tiến độ công việc",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Theo dõi tổng quan nhiệm vụ của bạn",
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildSearchBar(context),
              const SizedBox(height: 14),
              _buildOverdueBanner(context, overdueCount),
              const SizedBox(height: 28),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
                children: [
                  _buildStatCard(
                    context,
                    "Đang chờ",
                    pending,
                    Icons.hourglass_top_rounded,
                    Colors.orange,
                    onTap: () => _openTaskStatusList(context, TaskStatusListType.pending),
                  ),
                  _buildStatCard(
                    context,
                    "Đang làm",
                    inProgress,
                    Icons.play_arrow_rounded,
                    Colors.blue,
                    onTap: () => _openTaskStatusList(context, TaskStatusListType.inProgress),
                  ),
                  _buildStatCard(
                    context,
                    "Hoàn thành",
                    completed,
                    Icons.check_circle_rounded,
                    yTaskGreen,
                    onTap: () => _openTaskStatusList(context, TaskStatusListType.completed),
                  ),
                  _buildStatCard(
                    context,
                    "Đã hủy",
                    cancelled,
                    Icons.notifications_off_rounded,
                    Colors.redAccent,
                    onTap: () => _openTaskStatusList(context, TaskStatusListType.cancelled),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              _buildOverviewCard(context, tasks),

              const SizedBox(height: 32),

              const Text(
                "Phân bổ trạng thái",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252724) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildBarRow("Hoàn thành", completed, total, yTaskGreen),
                    const SizedBox(height: 14),
                    _buildBarRow("Đang làm", inProgress, total, Colors.blue),
                    const SizedBox(height: 14),
                    _buildBarRow("Đang chờ", pending, total, Colors.orange),
                    const SizedBox(height: 14),
                    _buildBarRow("Đã hủy", cancelled, total, Colors.redAccent),
                    const SizedBox(height: 14),
                    _buildBarRow("Quá hạn", overdue, total, const Color(0xFFFF5252)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: yTaskGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: yTaskGreen.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem("Tổng task", "$total"),
                    _buildSummaryItem("Đã xong", "$completed"),
                    _buildSummaryItem("Tỷ lệ", "${completionRate.toStringAsFixed(1)}%"),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildSearchResultsOverlay(context, tasks),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, List<TaskModel> tasks) {
    const Color yTaskGreen = Color(0xFF64DA56);
    const Color yTaskBlue = Color(0xFF62E5FF);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metrics = _calculateWeeklyOverview(tasks);

    final maxDailyValue = metrics.dailyCompleted.fold<int>(
      0,
          (maxValue, value) => value > maxValue ? value : maxValue,
    );

    final todayIndex = DateTime.now().weekday - 1;
    final progressFactor = metrics.completionRate / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252724) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : yTaskGreen.withOpacity(0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: yTaskGreen.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: yTaskGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Overview",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: yTaskGreen.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "Tuần này",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: yTaskGreen,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildOverviewMetricTile(
                  context: context,
                  icon: Icons.check_circle_rounded,
                  iconColor: yTaskGreen,
                  value: "${metrics.completedThisWeek}",
                  label: "Hoàn thành",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewMetricTile(
                  context: context,
                  icon: Icons.trending_up_rounded,
                  iconColor: yTaskBlue,
                  value: "${metrics.completionRate.toStringAsFixed(0)}%",
                  label: "Tỷ lệ",
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _buildOverviewProgressLine(
            context: context,
            progressFactor: progressFactor,
            completed: metrics.completedThisWeek,
            total: metrics.totalThisWeek,
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 138,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = metrics.dailyCompleted[index];
                final isToday = index == todayIndex;
                return Expanded(
                  child: _buildWeeklyBar(
                    context: context,
                    label: _weekdayLabel(index),
                    value: value,
                    maxValue: maxDailyValue,
                    isToday: isToday,
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 18),

          _buildBestDayFooter(context, metrics),
        ],
      ),
    );
  }

  Widget _buildOverviewMetricTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF30332F) : const Color(0xFFF7FAF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.035),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewProgressLine({
    required BuildContext context,
    required double progressFactor,
    required int completed,
    required int total,
  }) {
    const Color yTaskGreen = Color(0xFF64DA56);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final safeFactor = progressFactor < 0
        ? 0.0
        : progressFactor > 1
        ? 1.0
        : progressFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Hiệu suất tuần này",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey.shade200 : const Color(0xFF252525),
              ),
            ),
            const Spacer(),
            Text(
              "$completed/$total task",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
              FractionallySizedBox(
                widthFactor: safeFactor == 0 ? 0.012 : safeFactor,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  height: 12,
                  decoration: BoxDecoration(
                    color: yTaskGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyBar({
    required BuildContext context,
    required String label,
    required int value,
    required int maxValue,
    required bool isToday,
  }) {
    const Color yTaskGreen = Color(0xFF64DA56);
    const Color yTaskBlue = Color(0xFF62E5FF);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final barColor = isToday ? yTaskBlue : yTaskGreen;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double valueTextHeight = 16;
        const double valueToBarGap = 4;
        const double barToLabelGap = 6;
        const double labelHeight = 24;

        final availableBarHeight = constraints.maxHeight -
            valueTextHeight -
            valueToBarGap -
            barToLabelGap -
            labelHeight;

        final safeAvailableBarHeight = availableBarHeight < 36
            ? 36.0
            : availableBarHeight;

        final barHeight = value == 0
            ? 10.0
            : 18.0 + ((safeAvailableBarHeight - 18.0) * value / safeMax);

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: valueTextHeight,
              child: Center(
                child: Text(
                  value == 0 ? "" : "$value",
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: valueToBarGap),

            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  width: 18,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: value == 0
                        ? (isDark
                        ? Colors.white.withOpacity(0.10)
                        : Colors.black.withOpacity(0.06))
                        : barColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: value == 0
                        ? []
                        : [
                      BoxShadow(
                        color: barColor.withOpacity(0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: barToLabelGap),

            SizedBox(
              height: labelHeight,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isToday ? 7 : 0,
                    vertical: isToday ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isToday ? yTaskBlue.withOpacity(0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: isToday
                          ? yTaskBlue
                          : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBestDayFooter(BuildContext context, _OverviewMetrics metrics) {
    const Color yTaskGreen = Color(0xFF64DA56);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasBestDay = metrics.bestDayCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasBestDay
            ? yTaskGreen.withOpacity(isDark ? 0.13 : 0.10)
            : Colors.grey.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            hasBestDay ? Icons.local_fire_department_rounded : Icons.auto_awesome_rounded,
            color: hasBestDay ? yTaskGreen : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasBestDay
                  ? "Ngày tốt nhất: ${_weekdayLabel(metrics.bestDayIndex)} - ${metrics.bestDayCount} task hoàn thành"
                  : "Tuần này chưa có task hoàn thành. Hãy hoàn thành nhiệm vụ đầu tiên nhé.",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: hasBestDay
                    ? yTaskGreen
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTaskStatusList(BuildContext context, TaskStatusListType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskStatusListScreen(type: type),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context,
      String title,
      int count,
      IconData icon,
      Color color, {
        VoidCallback? onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252724) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$count",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarRow(String label, int count, int total, Color color) {
    final double factor = total == 0 ? 0 : (count / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text("$count", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: factor > 0 ? factor : 0.001,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF63D64E),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _OverviewMetrics {
  final int completedThisWeek;
  final int totalThisWeek;
  final double completionRate;
  final List<int> dailyCompleted;
  final int bestDayIndex;
  final int bestDayCount;

  const _OverviewMetrics({
    required this.completedThisWeek,
    required this.totalThisWeek,
    required this.completionRate,
    required this.dailyCompleted,
    required this.bestDayIndex,
    required this.bestDayCount,
  });
}
