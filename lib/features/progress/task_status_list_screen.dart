import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:todo_app/features/dashboard/create_task_screen.dart';
import 'package:todo_app/features/dashboard/detail_task_screen.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/services/category_service.dart';
import 'package:todo_app/services/task_service.dart';
import 'package:todo_app/shared/widgets/custom_bottom_nav.dart';
import 'package:todo_app/core/utils/effective_task_status.dart';

enum TaskStatusListType {
  pending,
  inProgress,
  completed,
  cancelled,
  overdue,
}

enum TimeFilter {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  all,
}

class TaskStatusListScreen extends StatefulWidget {
  final TaskStatusListType type;

  const TaskStatusListScreen({
    super.key,
    required this.type,
  });

  @override
  State<TaskStatusListScreen> createState() => _TaskStatusListScreenState();
}

class _TaskStatusListScreenState extends State<TaskStatusListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  late TimeFilter _timeFilter;

  static const Color yTaskGreen = Color(0xFF64DA56);
  static const Color yTaskBg = Color(0xFFD8F6D2);
  static const Color pendingYellow = Color(0xFFFFE562);
  static const Color completedCyan = Color(0xFF62E5FF);
  static const Color cancelledGrey = Color(0xFFABABAB);
  static const Color redTime = Color(0xFFFF3131);

  @override
  void initState() {
    super.initState();
    _timeFilter = _defaultTimeFilter(widget.type);

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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Vui lòng đăng nhập để xem danh sách task',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateTaskScreen(),
              ),
            );
          },
          backgroundColor: yTaskGreen,
          shape: const CircleBorder(),
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white, size: 34),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<TaskModel>>(
          stream: TaskService().getTasksByUser(uid),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: yTaskGreen),
              );
            }

            if (taskSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Đã xảy ra lỗi: ${taskSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            final allTasks = taskSnapshot.data ?? [];

            return StreamBuilder<List<CategoryModel>>(
              stream: CategoryService().getCategoriesByUser(uid),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? [];
                final categoryMap = {
                  for (final category in categories) category.id: category,
                };

                return ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, query, _) {
                    final visibleTasks = _applyAllFilters(
                      tasks: allTasks,
                      categoryMap: categoryMap,
                    );

                    return _buildContent(
                      context: context,
                      tasks: visibleTasks,
                      categoryMap: categoryMap,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required List<TaskModel> tasks,
    required Map<String, CategoryModel> categoryMap,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 120),
      children: [
        _buildTopBackBar(context),
        const SizedBox(height: 18),
        _buildSearchBox(context),
        const SizedBox(height: 20),
        _buildHeader(context),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          _buildEmptyState(context)
        else
          ...tasks.map((task) {
            final category = categoryMap[task.categoryId] ??
                CategoryModel(
                  id: task.categoryId,
                  userId: task.userId,
                  name: 'Khác',
                  colorHex: 'FF64DA56',
                  isDefault: true,
                );

            return _buildTaskItem(
              context: context,
              task: task,
              category: category,
            );
          }),
      ],
    );
  }

  Widget _buildTopBackBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Material(
          color: yTaskGreen,
          shape: const CircleBorder(),
          elevation: 5,
          shadowColor: yTaskGreen.withOpacity(0.28),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.maybePop(context),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Quay lại tiến độ",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _screenTitle(widget.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF151515),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252724) : const Color(0xFFB7F2B0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF3F6A43),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              cursorColor: yTaskGreen,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, query, _) {
              if (query.trim().isEmpty) return const SizedBox.shrink();

              return IconButton(
                onPressed: () {
                  _searchController.clear();
                  _searchFocusNode.requestFocus();
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF4F4F59),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Danh sách",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade200
                  : const Color(0xFF151515),
            ),
          ),
        ),
        _buildTimeFilterMenu(context),
      ],
    );
  }

  Widget _buildTimeFilterMenu(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: yTaskGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _timeFilterText(_timeFilter),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2F8E37),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      menuChildren: TimeFilter.values.map((filter) {
        final selected = filter == _timeFilter;

        return MenuItemButton(
          onPressed: () {
            setState(() {
              _timeFilter = filter;
            });
          },
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_rounded : Icons.circle_outlined,
                size: 18,
                color: selected ? yTaskGreen : Colors.grey,
              ),
              const SizedBox(width: 10),
              Text(_timeFilterText(filter)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskItem({
    required BuildContext context,
    required TaskModel task,
    required CategoryModel category,
  }) {
    final statusColor = _listStatusColor(widget.type, task);
    final icon = _listStatusIcon(widget.type, task);
    final priorityColor = _priorityColor(task.priority);
    final categoryColor = _categoryColor(category.colorHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openTaskDetail(context, task, category),
        child: Container(
          height: 76,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: double.infinity,
                color: statusColor,
                child: Icon(
                  icon,
                  size: 22,
                  color: const Color(0xFF202124),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
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
                          Flexible(
                            child: _buildMiniChip(
                              text: category.name,
                              backgroundColor: categoryColor,
                              textColor: _strongChipTextColor(categoryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        task.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
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
                  width: 86,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTaskDateTime(task.startDateTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF36D747),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTaskDateTime(task.endDateTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: redTime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        color: backgroundColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          height: 1.0,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final query = _searchController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          Icon(
            query.isEmpty ? Icons.inbox_rounded : Icons.search_off_rounded,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          Text(
            query.isEmpty
                ? 'Chưa có nhiệm vụ phù hợp'
                : 'Không tìm thấy task phù hợp',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query.isEmpty
                ? 'Thử đổi bộ lọc thời gian nhé.'
                : 'Thử nhập từ khóa khác nhé.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  List<TaskModel> _applyAllFilters({
    required List<TaskModel> tasks,
    required Map<String, CategoryModel> categoryMap,
  }) {
    final result = tasks.where((task) {
      if (task.isDeleted) return false;
      if (!_matchesListType(task)) return false;
      if (!_matchesTimeFilter(task)) return false;
      if (!_matchesSearch(task, categoryMap[task.categoryId])) return false;

      return true;
    }).toList();

    result.sort((a, b) {
      final aDate = a.startDateTime ?? a.endDateTime ?? a.createdAt ?? DateTime(2100);
      final bDate = b.startDateTime ?? b.endDateTime ?? b.createdAt ?? DateTime(2100);

      if (widget.type == TaskStatusListType.completed) {
        return bDate.compareTo(aDate);
      }

      return aDate.compareTo(bDate);
    });

    return result;
  }

  bool _matchesListType(TaskModel task) {
    final effectiveStatus = EffectiveTaskStatusResolver.resolve(task);

    switch (widget.type) {
      case TaskStatusListType.pending:
        return effectiveStatus == EffectiveTaskStatus.pending;
      case TaskStatusListType.inProgress:
        return effectiveStatus == EffectiveTaskStatus.inProgress;
      case TaskStatusListType.completed:
        return effectiveStatus == EffectiveTaskStatus.completed;
      case TaskStatusListType.cancelled:
        return effectiveStatus == EffectiveTaskStatus.cancelled;
      case TaskStatusListType.overdue:
        return effectiveStatus == EffectiveTaskStatus.overdue;
    }
  }

  bool _matchesTimeFilter(TaskModel task) {
    final range = _rangeForFilter(_timeFilter);

    if (range == null) return true;

    final start = task.startDateTime ?? task.endDateTime ?? task.createdAt;
    final end = task.endDateTime ?? task.startDateTime ?? task.updatedAt ?? task.createdAt;

    if (start == null && end == null) return false;

    final cleanStart = _dateOnly(start ?? end!);
    final cleanEnd = _dateOnly(end ?? start!).add(const Duration(days: 1));

    return cleanStart.isBefore(range.end) && cleanEnd.isAfter(range.start);
  }

  bool _matchesSearch(TaskModel task, CategoryModel? category) {
    final query = _normalizeSearchText(_searchController.text);

    if (query.isEmpty) return true;

    final terms = query
        .split(' ')
        .where((term) => term.trim().isNotEmpty)
        .toList();

    final searchableText = _taskSearchableText(task, category);
    return terms.every(searchableText.contains);
  }

  DateTimeRange? _rangeForFilter(TimeFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case TimeFilter.today:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case TimeFilter.thisWeek:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 7)),
        );
      case TimeFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return DateTimeRange(start: monthStart, end: nextMonth);
      case TimeFilter.thisYear:
        final yearStart = DateTime(now.year, 1, 1);
        final nextYear = DateTime(now.year + 1, 1, 1);
        return DateTimeRange(start: yearStart, end: nextYear);
      case TimeFilter.all:
        return null;
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isOverdue(TaskModel task) {
    return EffectiveTaskStatusResolver.isOverdue(task);
  }

  Future<void> _openTaskDetail(
    BuildContext context,
    TaskModel task,
    CategoryModel category,
  ) async {
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailTaskScreen(
          task: task,
          initialCategory: category,
        ),
      ),
    );
  }

  TimeFilter _defaultTimeFilter(TaskStatusListType type) {
    switch (type) {
      case TaskStatusListType.inProgress:
        return TimeFilter.today;
      case TaskStatusListType.pending:
        return TimeFilter.thisWeek;
      case TaskStatusListType.completed:
      case TaskStatusListType.cancelled:
      case TaskStatusListType.overdue:
        return TimeFilter.all;
    }
  }

  String _screenTitle(TaskStatusListType type) {
    switch (type) {
      case TaskStatusListType.pending:
        return 'Đang chờ';
      case TaskStatusListType.inProgress:
        return 'Đang làm';
      case TaskStatusListType.completed:
        return 'Hoàn thành';
      case TaskStatusListType.cancelled:
        return 'Đã hủy';
      case TaskStatusListType.overdue:
        return 'Quá hạn';
    }
  }

  Color _listStatusColor(TaskStatusListType type, TaskModel task) {
    final effectiveStatus = EffectiveTaskStatusResolver.resolve(task);

    switch (effectiveStatus) {
      case EffectiveTaskStatus.pending:
        return pendingYellow;
      case EffectiveTaskStatus.inProgress:
        return yTaskGreen;
      case EffectiveTaskStatus.completed:
        return completedCyan;
      case EffectiveTaskStatus.cancelled:
        return cancelledGrey;
      case EffectiveTaskStatus.overdue:
        return redTime;
      case null:
        return cancelledGrey;
    }
  }

  IconData _listStatusIcon(TaskStatusListType type, TaskModel task) {
    final effectiveStatus = EffectiveTaskStatusResolver.resolve(task);

    switch (effectiveStatus) {
      case EffectiveTaskStatus.pending:
        return Icons.hourglass_top_rounded;
      case EffectiveTaskStatus.inProgress:
        return Icons.autorenew_rounded;
      case EffectiveTaskStatus.completed:
        return Icons.check_circle_outline_rounded;
      case EffectiveTaskStatus.cancelled:
        return Icons.close_rounded;
      case EffectiveTaskStatus.overdue:
        return Icons.warning_amber_rounded;
      case null:
        return Icons.close_rounded;
    }
  }

  String _timeFilterText(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.today:
        return 'Hôm nay';
      case TimeFilter.thisWeek:
        return 'Tuần này';
      case TimeFilter.thisMonth:
        return 'Tháng này';
      case TimeFilter.thisYear:
        return 'Năm nay';
      case TimeFilter.all:
        return 'Tất cả';
    }
  }

  String _priorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String _prioritySearchText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'low thap thấp';
      case TaskPriority.medium:
        return 'medium trung binh trung bình';
      case TaskPriority.high:
        return 'high cao';
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return const Color(0xFF34C759);
      case TaskPriority.medium:
        return const Color(0xFFFF9800);
      case TaskPriority.high:
        return const Color(0xFFFF3131);
    }
  }

  Color _strongChipTextColor(Color color) {
    if (color == completedCyan) return const Color(0xFF00879A);
    if (color == pendingYellow) return const Color(0xFF9A7800);
    if (color == cancelledGrey) return const Color(0xFF555555);
    return const Color(0xFF1E8F2D);
  }

  Color _categoryColor(String colorHex) {
    try {
      var hex = colorHex.trim().replaceAll('#', '').replaceAll('0x', '');

      if (hex.length == 6) {
        hex = 'FF$hex';
      }

      if (hex.length != 8) {
        return yTaskGreen;
      }

      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return yTaskGreen;
    }
  }

  String _formatTaskDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    if (target == today) return '$hour:$minute';
    if (target == tomorrow) return 'Mai, $hour:$minute';
    if (target == yesterday) return 'Hôm qua, $hour:$minute';

    if (dateTime.year == now.year) {
      if (dateTime.month == now.month) {
        return 'Ngày ${dateTime.day}, $hour:$minute';
      }

      return '${dateTime.day} th${dateTime.month}, $hour:$minute';
    }

    return '${dateTime.day} th${dateTime.month}, ${dateTime.year}';
  }

  String _formatDateTimeForSearch(DateTime? dateTime) {
    if (dateTime == null) return '';

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final day = twoDigits(dateTime.day);
    final month = twoDigits(dateTime.month);
    final year = dateTime.year.toString();
    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    return [
      '$day/$month',
      '$day/$month/$year',
      '${dateTime.day} th${dateTime.month}',
      '${dateTime.day} th${dateTime.month} $year',
      '$hour:$minute',
      '$day/$month, $hour:$minute',
      '$day/$month/$year, $hour:$minute',
      year,
      month,
      day,
    ].join(' ');
  }

  String _statusSearchText(TaskModel task) {
    final effectiveStatus = EffectiveTaskStatusResolver.resolve(task);
    return EffectiveTaskStatusResolver.searchText(effectiveStatus);
  }

  String _taskSearchableText(TaskModel task, CategoryModel? category) {
    final rawText = [
      task.title,
      task.description,
      task.location ?? '',
      category?.name ?? '',
      _priorityText(task.priority),
      _prioritySearchText(task.priority),
      _screenTitle(widget.type),
      _statusSearchText(task),
      _formatDateTimeForSearch(task.startDateTime),
      _formatDateTimeForSearch(task.endDateTime),
      _formatDateTimeForSearch(task.createdAt),
      _formatDateTimeForSearch(task.updatedAt),
    ].join(' ');

    return _normalizeSearchText(rawText);
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
}
