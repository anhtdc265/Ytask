import 'package:flutter/material.dart';
import 'package:todo_app/core/theme/app_theme.dart';
import 'package:todo_app/features/dashboard/widgets/task_schedule_card.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/models/task_model.dart';

class SchedulePanel extends StatefulWidget {
  final List<TaskModel> tasks;
  final List<CategoryModel> categories;
  final DateTime selectedDate;
  final DateTime today;
  final Future<void> Function(TaskModel task)? onCompleteTask;
  final Future<void> Function(TaskModel task)? onCancelTask;
  final ValueChanged<bool>? onExpandedChanged;

  const SchedulePanel({
    super.key,
    required this.tasks,
    required this.categories,
    required this.selectedDate,
    required this.today,
    this.onCompleteTask,
    this.onCancelTask,
    this.onExpandedChanged,
  });

  @override
  State<SchedulePanel> createState() => _SchedulePanelState();
}

enum _ScheduleSortMode {
  smart,
  newest,
  priorityHighToLow,
  priorityLowToHigh,
  startTimeAsc,
  startTimeDesc,
  deadlineAsc,
}

class _SchedulePanelState extends State<SchedulePanel> {
  static const double _peekSize = 0.32;
  static const double _normalSize = 0.64;
  static const double _expandedSize = 0.92;
  static const double _calendarExpandedThreshold = 0.42;

  static const double _panelRadius = 34;
  static const double _scheduleHorizontalPadding = 24;
  static const double _scheduleCardGap = 14;
  static const double _scheduleListBottomBasePadding = 126;

  double _sheetSize = _normalSize;
  bool _isDragging = false;
  bool? _lastCalendarExpanded;

  _ScheduleSortMode _sortMode = _ScheduleSortMode.smart;

  @override
  void didUpdateWidget(covariant SchedulePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final didDateChange = !_isSameDay(
      oldWidget.selectedDate,
      widget.selectedDate,
    );

    if (!didDateChange) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _snapTo(_normalSize);
      _notifyCalendarExpanded(false);
    });
  }

  void _notifyCalendarExpanded(bool expanded) {
    if (_lastCalendarExpanded == expanded) return;

    _lastCalendarExpanded = expanded;
    widget.onExpandedChanged?.call(expanded);
  }

  void _snapTo(double size) {
    setState(() {
      _sheetSize = size;
      _isDragging = false;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxHeight) {
    final delta = details.primaryDelta ?? 0;

    final nextSize = (_sheetSize - delta / maxHeight).clamp(
      _peekSize,
      _expandedSize,
    );

    setState(() {
      _sheetSize = nextSize;
    });

    _notifyCalendarExpanded(nextSize <= _calendarExpandedThreshold);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    double targetSize;

    if (velocity > 650) {
      targetSize = _peekSize;
    } else if (velocity < -650) {
      targetSize = _sheetSize < _normalSize ? _normalSize : _expandedSize;
    } else {
      targetSize = _nearestSnapSize(_sheetSize);
    }

    _snapTo(targetSize);

    final shouldShowFullCalendar = targetSize <= _calendarExpandedThreshold;
    _notifyCalendarExpanded(shouldShowFullCalendar);
  }

  double _nearestSnapSize(double value) {
    const snapSizes = [_peekSize, _normalSize, _expandedSize];

    double nearest = snapSizes.first;
    double minDistance = (value - nearest).abs();

    for (final size in snapSizes) {
      final distance = (value - size).abs();

      if (distance < minDistance) {
        nearest = size;
        minDistance = distance;
      }
    }

    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yColors = AppTheme.colors(context);
    final panelColor = yColors.schedulePanel;
    final sortedTasks = _sortedTasks(widget.tasks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final panelHeight = maxHeight * _sheetSize;
        final isPeekMode = _sheetSize <= _calendarExpandedThreshold;

        return SizedBox(
          width: constraints.maxWidth,
          height: maxHeight,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: 0,
                height: panelHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_panelRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.24 : 0.08,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_panelRadius),
                    ),
                    child: Column(
                      children: [
                        _PanelHeader(
                          title: _scheduleTitle,
                          taskCount: widget.tasks.length,
                          isDark: isDark,
                          isPeekMode: isPeekMode,
                          sortControl: _buildCompactSortMenu(),
                          onVerticalDragStart: _handleDragStart,
                          onVerticalDragUpdate: (details) {
                            _handleDragUpdate(details, maxHeight);
                          },
                          onVerticalDragEnd: _handleDragEnd,
                        ),
                        if (!isPeekMode)
                          Expanded(
                            child: sortedTasks.isEmpty
                                ? const _EmptyScheduleState()
                                : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                _scheduleHorizontalPadding,
                                0,
                                _scheduleHorizontalPadding,
                                _scheduleBottomPadding(context),
                              ),
                              itemCount: sortedTasks.length,
                              separatorBuilder: (context, index) {
                                return const SizedBox(
                                  height: _scheduleCardGap,
                                );
                              },
                              itemBuilder: (context, index) {
                                final task = sortedTasks[index];

                                final category = widget.categories.firstWhere(
                                      (c) => c.id == task.categoryId,
                                  orElse: () => CategoryModel(
                                    id: '0',
                                    userId: '',
                                    name: 'Khác',
                                    colorHex: 'FF64DA56',
                                    isDefault: true,
                                  ),
                                );

                                return TaskScheduleCard(
                                  task: task,
                                  category: category,
                                  onComplete: widget.onCompleteTask,
                                  onCancel: widget.onCancelTask,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _scheduleBottomPadding(BuildContext context) {
    return _scheduleListBottomBasePadding + MediaQuery.paddingOf(context).bottom;
  }

  Widget _buildCompactSortMenu() {
    final yColors = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<_ScheduleSortMode>(
      tooltip: 'Sắp xếp lịch trình',
      initialValue: _sortMode,
      position: PopupMenuPosition.under,
      elevation: 8,
      color: isDark ? yColors.scheduleCard : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      constraints: const BoxConstraints(
        minWidth: 190,
        maxWidth: 230,
      ),
      onSelected: (value) {
        setState(() {
          _sortMode = value;
        });
      },
      itemBuilder: (context) {
        return _ScheduleSortMode.values.map((mode) {
          final selected = mode == _sortMode;

          return PopupMenuItem<_ScheduleSortMode>(
            value: mode,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: selected
                      ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: yColors.brand,
                  )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sortModeLabel(mode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? yColors.brandDark : yColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 190),
        decoration: BoxDecoration(
          color: isDark
              ? yColors.brand.withValues(alpha: 0.16)
              : yColors.brand.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: yColors.brand.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 17,
              color: yColors.brandDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _sortModeLabel(_sortMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: yColors.brandDark,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: yColors.brandDark,
            ),
          ],
        ),
      ),
    );
  }

  List<TaskModel> _sortedTasks(List<TaskModel> tasks) {
    final sorted = List<TaskModel>.from(tasks);

    sorted.sort((a, b) {
      switch (_sortMode) {
        case _ScheduleSortMode.smart:
          return _compareSmart(a, b);
        case _ScheduleSortMode.newest:
          return _compareNewest(a, b);
        case _ScheduleSortMode.priorityHighToLow:
          return _comparePriority(a, b, highFirst: true);
        case _ScheduleSortMode.priorityLowToHigh:
          return _comparePriority(a, b, highFirst: false);
        case _ScheduleSortMode.startTimeAsc:
          return _compareDateTime(
            a.startDateTime,
            b.startDateTime,
            nullLast: true,
          );
        case _ScheduleSortMode.startTimeDesc:
          return _compareDateTime(
            b.startDateTime,
            a.startDateTime,
            nullLast: true,
          );
        case _ScheduleSortMode.deadlineAsc:
          return _compareDateTime(
            a.endDateTime,
            b.endDateTime,
            nullLast: true,
          );
      }
    });

    return sorted;
  }

  int _compareSmart(TaskModel a, TaskModel b) {
    final now = DateTime.now();

    final aOverdue = _isOverdue(a, now);
    final bOverdue = _isOverdue(b, now);

    if (aOverdue != bOverdue) return aOverdue ? -1 : 1;

    final aSoon = _isDueSoon(a, now);
    final bSoon = _isDueSoon(b, now);

    if (aSoon != bSoon) return aSoon ? -1 : 1;

    final aHasStart = a.startDateTime != null;
    final bHasStart = b.startDateTime != null;

    if (aHasStart != bHasStart) return aHasStart ? -1 : 1;

    if (aHasStart && bHasStart) {
      final startCompare = a.startDateTime!.compareTo(b.startDateTime!);
      if (startCompare != 0) return startCompare;
    }

    final aHasDeadline = a.endDateTime != null;
    final bHasDeadline = b.endDateTime != null;

    if (aHasDeadline != bHasDeadline) return aHasDeadline ? -1 : 1;

    if (aHasDeadline && bHasDeadline) {
      final deadlineCompare = a.endDateTime!.compareTo(b.endDateTime!);
      if (deadlineCompare != 0) return deadlineCompare;
    }

    return _compareNewest(a, b);
  }

  int _compareNewest(TaskModel a, TaskModel b) {
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;

    if (aCreated == null && bCreated == null) return 0;
    if (aCreated == null) return 1;
    if (bCreated == null) return -1;

    return bCreated.compareTo(aCreated);
  }

  int _comparePriority(
      TaskModel a,
      TaskModel b, {
        required bool highFirst,
      }) {
    final aRank = _priorityRank(a.priority);
    final bRank = _priorityRank(b.priority);

    final result = highFirst ? bRank.compareTo(aRank) : aRank.compareTo(bRank);
    if (result != 0) return result;

    return _compareNewest(a, b);
  }

  int _compareDateTime(
      DateTime? a,
      DateTime? b, {
        required bool nullLast,
      }) {
    if (a == null && b == null) return 0;

    if (a == null) return nullLast ? 1 : -1;
    if (b == null) return nullLast ? -1 : 1;

    return a.compareTo(b);
  }

  int _priorityRank(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
    }
  }

  bool _isOverdue(TaskModel task, DateTime now) {
    if (_isTaskDoneOrCancelled(task)) return false;

    final end = task.endDateTime;
    if (end == null) return false;

    return end.isBefore(now);
  }

  bool _isDueSoon(TaskModel task, DateTime now) {
    if (_isTaskDoneOrCancelled(task)) return false;

    final end = task.endDateTime;
    if (end == null) return false;
    if (end.isBefore(now)) return false;

    final diff = end.difference(now);
    return diff.inMinutes <= 15;
  }

  bool _isTaskDoneOrCancelled(TaskModel task) {
    return task.status == TaskStatus.completed ||
        task.status == TaskStatus.cancelled;
  }

  String _sortModeLabel(_ScheduleSortMode mode) {
    switch (mode) {
      case _ScheduleSortMode.smart:
        return 'Thông minh';
      case _ScheduleSortMode.newest:
        return 'Mới tạo';
      case _ScheduleSortMode.priorityHighToLow:
        return 'Cao → Thấp';
      case _ScheduleSortMode.priorityLowToHigh:
        return 'Thấp → Cao';
      case _ScheduleSortMode.startTimeAsc:
        return 'Giờ sớm';
      case _ScheduleSortMode.startTimeDesc:
        return 'Giờ muộn';
      case _ScheduleSortMode.deadlineAsc:
        return 'Deadline gần';
    }
  }

  String get _scheduleTitle {
    if (_isSameDay(widget.selectedDate, widget.today)) {
      return 'Lịch trình hôm nay';
    }

    return 'Lịch trình ${widget.selectedDate.day}/${widget.selectedDate.month}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final int taskCount;
  final bool isDark;
  final bool isPeekMode;
  final Widget sortControl;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  const _PanelHeader({
    required this.title,
    required this.taskCount,
    required this.isDark,
    required this.isPeekMode,
    required this.sortControl,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          isPeekMode ? 14 : 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.26)
                    : Colors.black.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: isPeekMode ? 18 : 19),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isPeekMode ? 26 : 28,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                      color: yColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: yColors.brand.withValues(
                      alpha: isDark ? 0.18 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$taskCount việc',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: isDark ? yColors.textPrimary : yColors.brandDark,
                    ),
                  ),
                ),
              ],
            ),
            if (!isPeekMode) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: sortControl,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState();

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        126 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          decoration: BoxDecoration(
            color: isDark
                ? yColors.scheduleCard.withValues(alpha: 0.82)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? yColors.scheduleCardBorder
                  : Colors.white.withValues(alpha: 0.85),
            ),
            boxShadow: [
              BoxShadow(
                color: yColors.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: yColors.brand.withValues(
                    alpha: isDark ? 0.18 : 0.14,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 34,
                  color: isDark ? Colors.white : yColors.brand,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Không có nhiệm vụ trong ngày này',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: yColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy chọn ngày khác hoặc tạo nhiệm vụ mới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: yColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
