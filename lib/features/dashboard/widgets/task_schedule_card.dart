import 'package:flutter/material.dart';
import 'package:todo_app/core/theme/app_theme.dart';
import 'package:todo_app/features/dashboard/detail_task_screen.dart';
import 'package:todo_app/features/dashboard/utils/task_time_formatter.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/models/task_model.dart';

class TaskScheduleCard extends StatefulWidget {
  final TaskModel task;
  final CategoryModel category;
  final Future<void> Function(TaskModel task)? onComplete;
  final Future<void> Function(TaskModel task)? onCancel;

  const TaskScheduleCard({
    super.key,
    required this.task,
    required this.category,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<TaskScheduleCard> createState() => _TaskScheduleCardState();
}

class _TaskScheduleCardState extends State<TaskScheduleCard> {
  static const Color yTaskGreen = Color(0xFF64DA56);
  static const Color completeCyan = Color(0xFF62E5FF);
  static const Color completeText = Color(0xFF007D8F);
  static const Color cancelGrey = Color(0xFFB8B8B8);
  static const Color cancelText = Color(0xFF3A3A3A);

  static const double _actionWidth = 104.0;
  static const double _actionGap = 10.0;
  static const int _warningThresholdMinutes = 15;

  double _dragOffset = 0;
  bool _isActionLoading = false;

  TaskModel get task => widget.task;
  CategoryModel get category => widget.category;

  bool get _canSwipe {
    if (task.status == TaskStatus.completed) return false;
    if (task.status == TaskStatus.cancelled) return false;

    return widget.onComplete != null || widget.onCancel != null;
  }

  bool get _isOpen => _dragOffset > 0;

  void _openActions() {
    if (!_canSwipe) return;
    setState(() => _dragOffset = _actionWidth);
  }

  void _closeActions() {
    if (!mounted) return;
    setState(() => _dragOffset = 0);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_canSwipe || _isActionLoading) return;

    final nextOffset = _dragOffset - details.delta.dx;

    setState(() {
      _dragOffset = nextOffset.clamp(0.0, _actionWidth);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_canSwipe || _isActionLoading) return;

    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -250) {
      _openActions();
      return;
    }

    if (velocity > 250) {
      _closeActions();
      return;
    }

    if (_dragOffset > _actionWidth * 0.42) {
      _openActions();
    } else {
      _closeActions();
    }
  }

  Future<void> _handleComplete() async {
    if (_isActionLoading || widget.onComplete == null) return;

    setState(() => _isActionLoading = true);

    try {
      _closeActions();
      await widget.onComplete?.call(task);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _handleCancel() async {
    if (_isActionLoading || widget.onCancel == null) return;

    setState(() => _isActionLoading = true);

    try {
      _closeActions();
      await widget.onCancel?.call(task);
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _handleCardTap() {
    if (_isOpen) {
      _closeActions();
      return;
    }

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

  String _shortCategoryName(String name) {
    final value = name.trim();
    if (value.length <= 16) return value;
    return '${value.substring(0, 16).trimRight()}...';
  }

  _TaskTimeAlert? _getTimeAlert() {
    if (_isTaskDoneOrCancelled) return null;

    final now = DateTime.now();

    final end = task.endDateTime;
    if (end != null && end.isBefore(now)) {
      return const _TaskTimeAlert(
        type: _TaskTimeAlertType.overdue,
        label: 'Quá hạn',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFFF3B30),
        backgroundColor: Color(0xFFFFECEA),
      );
    }

    if (end != null) {
      final diff = end.difference(now);

      if (!diff.isNegative && diff.inMinutes <= _warningThresholdMinutes) {
        final minutes = diff.inMinutes <= 0 ? 1 : diff.inMinutes;

        return _TaskTimeAlert(
          type: _TaskTimeAlertType.deadlineSoon,
          label: 'Còn $minutes phút',
          icon: Icons.access_time_rounded,
          color: const Color(0xFFFF9500),
          backgroundColor: const Color(0xFFFFF3DF),
        );
      }
    }

    final start = task.startDateTime;
    if (start != null) {
      final diff = start.difference(now);

      if (!diff.isNegative && diff.inMinutes <= _warningThresholdMinutes) {
        return const _TaskTimeAlert(
          type: _TaskTimeAlertType.startSoon,
          label: 'Sắp bắt đầu',
          icon: Icons.play_circle_outline_rounded,
          color: Color(0xFF2D9E39),
          backgroundColor: Color(0xFFEAF8E8),
        );
      }
    }

    return null;
  }

  bool get _isTaskDoneOrCancelled {
    return task.status == TaskStatus.completed ||
        task.status == TaskStatus.cancelled;
  }

  Color _alertBorderColor(_TaskTimeAlert? alert, Color fallbackColor) {
    if (alert == null) return fallbackColor;

    switch (alert.type) {
      case _TaskTimeAlertType.overdue:
        return alert.color.withValues(alpha: 0.62);
      case _TaskTimeAlertType.deadlineSoon:
        return alert.color.withValues(alpha: 0.48);
      case _TaskTimeAlertType.startSoon:
        return alert.color.withValues(alpha: 0.36);
    }
  }

  List<BoxShadow> _cardShadows({
    required _TaskTimeAlert? alert,
    required bool isDark,
    required Color normalShadowColor,
  }) {
    if (alert == null) {
      return [
        BoxShadow(
          color: normalShadowColor.withValues(alpha: isDark ? 0.35 : 0.12),
          blurRadius: isDark ? 16 : 18,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];
    }

    return [
      BoxShadow(
        color: normalShadowColor.withValues(alpha: isDark ? 0.30 : 0.10),
        blurRadius: 16,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: alert.color.withValues(
          alpha: alert.type == _TaskTimeAlertType.overdue ? 0.16 : 0.10,
        ),
        blurRadius: 18,
        spreadRadius: 0,
        offset: const Offset(0, 6),
      ),
    ];
  }

  Widget _buildTimeAlertChip(_TaskTimeAlert alert) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: alert.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            alert.icon,
            size: 14,
            color: alert.color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              alert.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: alert.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return const Color(0xFFFF3B30);
      case TaskPriority.medium:
        return const Color(0xFFFFCC00);
      case TaskPriority.low:
        return const Color(0xFF34C759);
    }
  }

  Color _parseCategoryColor(String colorHex) {
    try {
      var hex = colorHex.trim().replaceAll('#', '').replaceAll('0x', '');

      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length != 8) return yTaskGreen;

      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return yTaskGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(task.priority);
    final categoryColor = _parseCategoryColor(category.colorHex);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_canSwipe) _buildActionPanel(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(-_dragOffset, 0, 0),
            child: GestureDetector(
              onTap: _handleCardTap,
              child: _buildCardBody(
                priorityColor: priorityColor,
                categoryColor: categoryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    return Positioned.fill(
      right: 0,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(left: _actionGap),
          child: SizedBox(
            width: _actionWidth - _actionGap,
            child: Column(
              children: [
                Expanded(
                  child: _buildActionButton(
                    color: completeCyan,
                    textColor: completeText,
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Hoàn thành',
                    onTap: _handleComplete,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildActionButton(
                    color: cancelGrey,
                    textColor: cancelText,
                    icon: Icons.close_rounded,
                    label: 'Hủy',
                    onTap: _handleCancel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Color color,
    required Color textColor,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _isActionLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isActionLoading
                  ? const SizedBox(
                key: ValueKey('loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : Column(
                key: ValueKey(label),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.34),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: textColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody({
    required Color priorityColor,
    required Color categoryColor,
  }) {
    final yColors = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAlert = _getTimeAlert();
    final normalBorderColor = isDark
        ? yColors.scheduleCardBorder
        : Colors.white.withValues(alpha: 0.82);
    final timeLines = TaskTimeFormatter.scheduleRange(
      start: task.startDateTime,
      end: task.endDateTime,
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: yColors.scheduleCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          width: timeAlert == null ? 1 : 1.35,
          color: _alertBorderColor(timeAlert, normalBorderColor),
        ),
        boxShadow: _cardShadows(
          alert: timeAlert,
          isDark: isDark,
          normalShadowColor: yColors.shadow,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -1,
            left: -1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTag(
                  task.priority.vietnameseLabel,
                  priorityColor,
                  isFirst: true,
                ),
                Transform.translate(
                  offset: const Offset(-15, 0),
                  child: _buildTag(
                    _shortCategoryName(category.name),
                    categoryColor.withValues(alpha: 0.84),
                    isFirst: false,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 43, 16, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          color: yColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      if (task.description.trim().isNotEmpty)
                        Text(
                          task.description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.12,
                            color: yColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (timeAlert != null) _buildTimeAlertChip(timeAlert),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildScheduleTimeText(
                        timeLines.start,
                        color: yColors.success,
                      ),
                      const SizedBox(height: 4),
                      _buildScheduleTimeText(
                        timeLines.end,
                        color: yColors.danger,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTimeText(String value, {required Color color}) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }

  double _measureTagTextWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.width;
  }

  double _tagWidth(String text, {required bool isFirst}) {
    final textWidth = _measureTagTextWidth(text);

    // Tag có cạnh chéo nên vùng nhìn thấy bị ăn bớt ở mép trái/phải.
    // Bản này cố tình cộng dư hơn một chút để chữ ngắn như High/AI không bị
    // ellipsis oan, còn nhãn dài vẫn được giới hạn bằng maxWidth.
    final leftPadding = isFirst ? 18.0 : 32.0;
    final rightPadding = isFirst ? 40.0 : 44.0;
    const slantSafeSpace = 14.0;

    final minWidth = isFirst ? 94.0 : 96.0;
    final maxWidth = isFirst ? 132.0 : 188.0;

    return (textWidth + leftPadding + rightPadding + slantSafeSpace)
        .clamp(minWidth, maxWidth)
        .toDouble();
  }

  Widget _buildTag(String text, Color color, {required bool isFirst}) {
    final tagWidth = _tagWidth(text, isFirst: isFirst);

    return ClipPath(
      clipper: TagClipper(isFirst: isFirst),
      child: Container(
        width: tagWidth,
        height: 33,
        padding: EdgeInsets.only(
          left: isFirst ? 18 : 32,
          right: isFirst ? 40 : 44,
        ),
        alignment: Alignment.center,
        color: color,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textAlign: TextAlign.center,
          strutStyle: const StrutStyle(
            fontSize: 11,
            height: 1,
            forceStrutHeight: true,
          ),
          style: const TextStyle(
            color: Color(0xFF2E2B3A),
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

enum _TaskTimeAlertType {
  startSoon,
  deadlineSoon,
  overdue,
}

class _TaskTimeAlert {
  final _TaskTimeAlertType type;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _TaskTimeAlert({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

class TagClipper extends CustomClipper<Path> {
  final bool isFirst;

  TagClipper({required this.isFirst});

  @override
  Path getClip(Size size) {
    final path = Path();

    if (isFirst) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width - 15, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(15, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width - 15, size.height);
      path.lineTo(0, size.height);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
