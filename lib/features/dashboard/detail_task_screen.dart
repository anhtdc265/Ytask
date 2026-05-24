import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/services/task_service.dart';
import 'package:todo_app/services/comment_service.dart';
import 'package:todo_app/models/comment_model.dart';
import 'package:todo_app/services/auth_service.dart';
import 'package:todo_app/shared/widgets/ytask_avatar.dart';
import 'package:todo_app/features/dashboard/widgets/reminder_picker_sheet.dart';
import 'package:todo_app/features/dashboard/widgets/priority_selector_panel.dart';
import 'package:todo_app/features/dashboard/widgets/label_management_dialog.dart';
import 'package:todo_app/features/dashboard/widgets/manual_location_dialog.dart' as location_dialog;
import 'package:todo_app/features/dashboard/utils/task_time_formatter.dart';

String _taskPriorityLabel(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return 'Thấp';
    case TaskPriority.medium:
      return 'Trung bình';
    case TaskPriority.high:
      return 'Cao';
  }
}

class DetailTaskScreen extends StatefulWidget {
  final TaskModel task;
  final CategoryModel initialCategory;

  const DetailTaskScreen({
    super.key,
    required this.task,
    required this.initialCategory,
  });

  @override
  State<DetailTaskScreen> createState() => _DetailTaskScreenState();
}

class _DetailTaskScreenState extends State<DetailTaskScreen> {
  late TaskModel currentTask;
  late CategoryModel currentCategory;
  final TaskService _taskService = TaskService();
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentTask = widget.task;
    currentCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatCommentTime(DateTime dt) {
    final String time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    return "${dt.day} th${dt.month} $time";
  }

  double _detailTitleFontSize(String title) {
    final int length = title.trim().length;

    if (length <= 24) return 21;
    if (length <= 60) return 19;
    return 18;
  }

  String _priorityLabel(TaskPriority priority) => _taskPriorityLabel(priority);

  String _getCurrentUserDisplayName() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Người dùng';
  }

  Future<void> _saveTaskUpdate(TaskModel updatedTask) async {
    setState(() {
      currentTask = updatedTask;
    });

    try {
      await _taskService.updateTask(updatedTask);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi cập nhật nhiệm vụ: $e")),
        );
      }
    }
  }

  void _showLabelDialog() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    showDialog(
      context: context,
      builder: (context) => LabelManagementDialog(
        uid: uid,
        initialCategoryId: currentTask.categoryId,
        onSelected: (category) {
          setState(() {
            currentCategory = category;
          });
          final updated = currentTask.copyWith(categoryId: category.id);
          _saveTaskUpdate(updated);
        },
      ),
    );
  }

  void _showPrioritySelector() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: PrioritySelectorPanel(
            currentPriority: currentTask.priority,
            onSelected: (priority) {
              Navigator.pop(context);
              final updated = currentTask.copyWith(priority: priority);
              _saveTaskUpdate(updated);
            },
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim1),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showTimeEditDialog() async {
    final result = await showDialog<List<DateTime?>>(
      context: context,
      builder: (context) => TimeEditDialog(
        initialStart: currentTask.startDateTime,
        initialEnd: currentTask.endDateTime,
      ),
    );

    if (result != null && result.length == 2) {
      _handleUpdateTime(result[0], result[1]);
    }
  }

  void _showLocationSelectionOptions() {
    _showManualLocationDialog();
  }

  Future<void> _showManualLocationDialog() async {
    final location = await location_dialog.showManualLocationDialog(
      context,
      initialValue: currentTask.location,
    );

    if (location == null || !mounted) return;

    final updated = currentTask.copyWith(location: location);
    _saveTaskUpdate(updated);
  }


  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng đăng nhập để bình luận!")),
        );
        return;
      }

      // TASK COMMENT AVATAR 2: Lấy profile để lấy avatarId
      final userProfile = await _authService.getUserProfile();
      final avatarId = userProfile?.avatarUrl ?? 'frog';

      final newComment = CommentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        taskId: currentTask.id,
        userId: uid,
        userDisplayName: _getCurrentUserDisplayName(),
        authorAvatarUrl: avatarId,
        content: text,
        createdAt: DateTime.now(),
      );

      try {
        await _commentService.addComment(newComment);
        _commentController.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi thêm bình luận: $e")),
          );
        }
      }
    }
  }

  void _showConfirmDeleteDialog(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text("Đánh dấu bình luận này là đã đọc và xóa khỏi danh sách?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _commentService.deleteComment(currentTask.id, commentId);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi xóa bình luận: $e")),
                  );
                }
              }
            },
            child: const Text("Xác nhận", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  Future<void> _showTitleEditSheet() async {
    final String originalTitle = currentTask.title.trim();

    final String? newTitle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _TitleEditSheet(initialTitle: originalTitle);
      },
    );

    if (!mounted || newTitle == null) return;

    final String trimmedTitle = newTitle.trim();
    if (trimmedTitle == originalTitle) return;

    final updated = currentTask.copyWith(
      title: trimmedTitle,
      updatedAt: DateTime.now(),
    );

    await _saveTaskUpdate(updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật tên nhiệm vụ')),
    );
  }

  void _showDescriptionEditDialog() {
    final TextEditingController descController = TextEditingController(text: currentTask.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chỉnh sửa mô tả"),
        content: TextField(
          controller: descController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Thêm chi tiết cho nhiệm vụ...",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final updated = currentTask.copyWith(description: descController.text.trim());
              _saveTaskUpdate(updated);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF64DA56)),
            child: const Text("LƯU", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Logic Action ---

  Future<void> _handleCancelTask() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hủy nhiệm vụ?"),
        content: const Text("Nhiệm vụ sẽ chuyển sang trạng thái Đã hủy. Bạn có thể kích hoạt lại sau."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Không")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hủy nhiệm vụ", style: TextStyle(color: Color(0xFFFF0000))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _taskService.markTaskCancelled(currentTask.id);
        if (!mounted) return;
        setState(() {
          currentTask = currentTask.copyWith(
            status: TaskStatus.cancelled,
            isReminderOn: false,
            reminderType: TaskReminderType.none,
            reminderOffsetMinutes: 0,
            remindAtStart: false,
            startReminderOffsetMinutes: 0,
            remindAtDeadline: false,
            deadlineReminderOffsetMinutes: 0,
            updatedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã hủy nhiệm vụ")));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
        }
      }
    }
  }

  bool _isTaskToday() {
    final now = DateTime.now();
    final dates = [currentTask.startDateTime, currentTask.endDateTime];
    return dates.any((dt) => dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day);
  }

  Future<void> _handleReactivateTask() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kích hoạt lại nhiệm vụ?"),
        content: const Text("Nhiệm vụ sẽ được chuyển lại sang trạng thái đang chờ hoặc đang làm tùy theo thời gian hiện tại."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Kích hoạt lại")),
        ],
      ),
    );

    if (confirm != true) return;

    final bool shouldStartNow = _isTaskToday();
    try {
      await _taskService.reactivateTask(currentTask.id, shouldStartNow: shouldStartNow);
      if (!mounted) return;
      setState(() {
        currentTask = currentTask.copyWith(
          status: shouldStartNow ? TaskStatus.inProgress : TaskStatus.pending,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã kích hoạt lại nhiệm vụ")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  Future<void> _handlePermanentlyDeleteTask() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xóa vĩnh viễn nhiệm vụ?"),
        content: const Text("Hành động này sẽ xóa nhiệm vụ khỏi hệ thống và không thể phục hồi."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Xác nhận xóa", style: TextStyle(color: Color(0xFFFF0000))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _taskService.permanentlyDeleteTask(currentTask.id);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa vĩnh viễn nhiệm vụ")));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
        }
      }
    }
  }

  bool _canMarkCurrentTaskCompleted() {
    final String displayStatus = _getDisplayStatusString();
    return displayStatus == "pending" ||
        displayStatus == "inProgress" ||
        displayStatus == "overdue";
  }

  Future<void> _showMarkCompletedConfirmationSheet() async {
    if (!_canMarkCurrentTaskCompleted()) return;

    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bool isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final Color textColor = isDark ? Colors.white : const Color(0xFF1D1B20);
        final Color mutedTextColor = isDark ? Colors.white70 : const Color(0xFF6C6C6C);

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(sheetContext).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mutedTextColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64DA56).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF64DA56),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hoàn thành nhiệm vụ?",
                            style: TextStyle(
                              fontSize: 19,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Nhiệm vụ sẽ được chuyển sang trạng thái hoàn thành.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: const Color(0xFF64DA56),
                          side: const BorderSide(color: Color(0xFF64DA56)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Hủy",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF64DA56),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Hoàn thành",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || confirm != true) return;
    await _handleMarkCompleted();
  }

  Future<void> _handleMarkCompleted() async {
    try {
      await _taskService.markTaskCompleted(currentTask.id);
      if (!mounted) return;
      setState(() {
        currentTask = currentTask.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isReminderOn: false,
          reminderType: TaskReminderType.none,
          reminderOffsetMinutes: 0,
          remindAtStart: false,
          startReminderOffsetMinutes: 0,
          remindAtDeadline: false,
          deadlineReminderOffsetMinutes: 0,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã hoàn thành nhiệm vụ")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  String _getDisplayStatusString() {
    if (currentTask.status == TaskStatus.completed) return "completed";
    if (currentTask.status == TaskStatus.cancelled) return "cancelled";

    final now = DateTime.now();

    if (currentTask.endDateTime != null && now.isAfter(currentTask.endDateTime!)) {
      return "overdue";
    }

    if (currentTask.startDateTime != null && now.isBefore(currentTask.startDateTime!)) {
      return "pending";
    }

    return "inProgress";
  }

  // --- TASK B.2 Logic: Update Time with Lifecycle handling ---

  Future<void> _handleUpdateTime(DateTime? start, DateTime? end) async {
    if (start == null || end == null) return;

    final now = DateTime.now();
    // shouldStartNow = (now >= start && now <= end)
    final bool shouldStartNow = (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
        (now.isAtSameMomentAs(end) || now.isBefore(end));

    if (currentTask.status == TaskStatus.completed) {
      final bool? reopen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Mở lại nhiệm vụ?"),
          content: const Text("Nhiệm vụ này đang ở trạng thái Hoàn thành. Bạn có muốn mở lại nhiệm vụ để tiếp tục theo dõi không?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Giữ hoàn thành")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Mở lại")),
          ],
        ),
      );

      if (!mounted || reopen == null) return;

      try {
        if (reopen) {
          await _taskService.reopenCompletedTaskWithDateTime(
            taskId: currentTask.id,
            startDateTime: start,
            endDateTime: end,
            shouldStartNow: shouldStartNow,
          );
          if (!mounted) return;
          setState(() {
            currentTask = currentTask.copyWith(
              startDateTime: start,
              endDateTime: end,
              status: shouldStartNow ? TaskStatus.inProgress : TaskStatus.pending,
              completedAt: null,
              reactivatedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã mở lại nhiệm vụ")));
        } else {
          await _taskService.updateTaskDateTime(taskId: currentTask.id, startDateTime: start, endDateTime: end);
          if (!mounted) return;
          setState(() {
            currentTask = currentTask.copyWith(
              startDateTime: start,
              endDateTime: end,
              updatedAt: DateTime.now(),
            );
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } else if (currentTask.status == TaskStatus.cancelled) {
      final bool? reactivate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Kích hoạt lại nhiệm vụ?"),
          content: const Text("Nhiệm vụ này đang ở trạng thái Đã hủy. Bạn có muốn kích hoạt lại nhiệm vụ sau khi đổi thời gian không?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Giữ đã hủy")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Kích hoạt lại")),
          ],
        ),
      );

      if (!mounted || reactivate == null) return;

      try {
        if (reactivate) {
          await _taskService.reactivateCancelledTaskWithDateTime(
            taskId: currentTask.id,
            startDateTime: start,
            endDateTime: end,
            shouldStartNow: shouldStartNow,
          );
          if (!mounted) return;
          setState(() {
            currentTask = currentTask.copyWith(
              startDateTime: start,
              endDateTime: end,
              status: shouldStartNow ? TaskStatus.inProgress : TaskStatus.pending,
              cancelledAt: null,
              reactivatedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã kích hoạt lại nhiệm vụ")));
        } else {
          await _taskService.updateTaskDateTime(taskId: currentTask.id, startDateTime: start, endDateTime: end);
          if (!mounted) return;
          setState(() {
            currentTask = currentTask.copyWith(
              startDateTime: start,
              endDateTime: end,
              updatedAt: DateTime.now(),
            );
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } else {
      // pending / inProgress
      try {
        await _taskService.updateTaskDateTime(taskId: currentTask.id, startDateTime: start, endDateTime: end);
        if (!mounted) return;
        setState(() {
          currentTask = currentTask.copyWith(
            startDateTime: start,
            endDateTime: end,
            updatedAt: DateTime.now(),
          );
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  // --- TASK 6B: Reminder UI Logic ---

  String _reminderLabel(TaskModel task) {
    if (!task.isReminderOn || task.reminderType == TaskReminderType.none) {
      return 'Không nhắc';
    }

    if (task.remindAtStart && task.remindAtDeadline) {
      return 'Bắt đầu + Deadline';
    }

    if (task.remindAtStart || task.reminderType == TaskReminderType.start) {
      return 'Bắt đầu';
    }

    if (task.remindAtDeadline || task.reminderType == TaskReminderType.deadline) {
      return 'Deadline';
    }

    return 'Không nhắc';
  }

  String _offsetLabel(int minutes) {
    return TaskTimeFormatter.reminderOffsetLabel(minutes);
  }

  DateTime? _scheduledReminderTime(DateTime? targetDateTime, int offsetMinutes) {
    if (targetDateTime == null) return null;
    return targetDateTime.subtract(Duration(minutes: offsetMinutes));
  }

  Future<void> _openReminderPicker(TaskModel task) async {
    final result = await showModalBottomSheet<ReminderPickerResult>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242623)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return ReminderPickerSheet(
          initialRemindAtStart: task.remindAtStart,
          initialStartOffsetMinutes: task.startReminderOffsetMinutes,
          initialRemindAtDeadline: task.remindAtDeadline,
          initialDeadlineOffsetMinutes: task.deadlineReminderOffsetMinutes,
          startDateTime: task.startDateTime,
          endDateTime: task.endDateTime,
          offsetLabelBuilder: _offsetLabel,
        );
      },
    );

    if (result == null || !mounted) return;

    if (result.remindAtStart && task.startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần chọn thời gian bắt đầu trước khi bật nhắc nhở.'),
        ),
      );
      return;
    }

    if (result.remindAtDeadline && task.endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần chọn thời gian kết thúc trước khi bật nhắc deadline.'),
        ),
      );
      return;
    }

    final startReminderTime = _scheduledReminderTime(
      task.startDateTime,
      result.startOffsetMinutes,
    );
    final deadlineReminderTime = _scheduledReminderTime(
      task.endDateTime,
      result.deadlineOffsetMinutes,
    );

    if (result.remindAtStart &&
        (startReminderTime == null || !startReminderTime.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời điểm nhắc bắt đầu đã qua. Vui lòng chọn thời gian khác.'),
        ),
      );
      return;
    }

    if (result.remindAtDeadline &&
        (deadlineReminderTime == null || !deadlineReminderTime.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời điểm nhắc deadline đã qua. Vui lòng chọn thời gian khác.'),
        ),
      );
      return;
    }

    final isReminderOn = result.remindAtStart || result.remindAtDeadline;
    final legacyReminderType = !isReminderOn
        ? TaskReminderType.none
        : result.remindAtDeadline
        ? TaskReminderType.deadline
        : TaskReminderType.start;
    final legacyReminderOffsetMinutes = result.remindAtDeadline
        ? result.deadlineOffsetMinutes
        : result.remindAtStart
        ? result.startOffsetMinutes
        : 0;

    final updatedTask = task.copyWith(
      isReminderOn: isReminderOn,
      reminderType: legacyReminderType,
      reminderOffsetMinutes: legacyReminderOffsetMinutes,
      reminderScheduledAt: null,
      localNotificationId: null,
      remindAtStart: result.remindAtStart,
      startReminderOffsetMinutes: result.startOffsetMinutes,
      remindAtDeadline: result.remindAtDeadline,
      deadlineReminderOffsetMinutes: result.deadlineOffsetMinutes,
      startReminderScheduledAt: null,
      deadlineReminderScheduledAt: null,
      startLocalNotificationId: null,
      deadlineLocalNotificationId: null,
      updatedAt: DateTime.now(),
    );

    setState(() {
      currentTask = updatedTask;
    });

    try {
      await _taskService.updateTaskAndRescheduleReminder(updatedTask);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReminderOn ? 'Đã cập nhật nhắc nhở.' : 'Đã tắt nhắc nhở.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật nhắc nhở: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF64DA56);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final panelColor = isDark ? const Color(0xFF242623) : const Color(0xFFF5F1F8);
    final textColor = isDark ? Colors.white : Colors.black;

    final bool canCancelTask = currentTask.status == TaskStatus.pending ||
        currentTask.status == TaskStatus.inProgress;
    final bool canDeleteTask = currentTask.status == TaskStatus.completed ||
        currentTask.status == TaskStatus.cancelled;
    final bool showTaskMenu = canCancelTask || canDeleteTask;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildPriorityBadge(currentTask.priority),
                      const Spacer(),
                      if (showTaskMenu)
                        _buildTaskMoreMenu(
                          canCancel: canCancelTask,
                          canDelete: canDeleteTask,
                          isDark: isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildEditableTitle(textColor, isDark),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusSection(textColor),
                      const SizedBox(height: 16),

                      _buildLabelSection(textColor),

                      const SizedBox(height: 18),
                      _buildCompactTimeSection(isDark, textColor),

                      const SizedBox(height: 12),
                      _buildCompactLocationSection(isDark, textColor),

                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _openReminderPicker(currentTask),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252725) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                color: Color(0xFF64DA56),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Nhắc nhở',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Text(
                                _reminderLabel(currentTask),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64DA56),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                      Text("Bình luận:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      const SizedBox(height: 12),

                      StreamBuilder<List<CommentModel>>(
                        stream: _commentService.getCommentsByTask(currentTask.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final comments = snapshot.data ?? [];
                          return Column(
                            children: comments.asMap().entries.map((entry) {
                              final isLast = entry.key == comments.length - 1;
                              return _buildCommentItem(entry.value, isDark, isLast);
                            }).toList(),
                          );
                        },
                      ),

                      _buildCommentInput(isDark),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Mô tả:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                            onPressed: _showDescriptionEditDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showDescriptionEditDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            currentTask.description.isEmpty ? "Thêm mô tả..." : currentTask.description,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(Color textColor) {
    final bool canReactivate = currentTask.status == TaskStatus.cancelled;

    return LayoutBuilder(
      builder: (context, constraints) {
        final statusLabel = Text(
          "Trạng thái:",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: textColor,
          ),
        );

        final actions = <Widget>[
          _buildDisplayStatusChip(),
          if (_canMarkCurrentTaskCompleted()) _buildMarkCompletedButton(),
          if (canReactivate) _buildReactivateTaskButton(),
        ];

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            statusLabel,
            ...actions,
          ],
        );
      },
    );
  }

  Widget _buildTaskMoreMenu({
    required bool canCancel,
    required bool canDelete,
    required bool isDark,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Tùy chọn nhiệm vụ',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: isDark ? Colors.white70 : const Color(0xFF4B4B4B),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'cancel') {
          _handleCancelTask();
        } else if (value == 'delete') {
          _handlePermanentlyDeleteTask();
        }
      },
      itemBuilder: (context) => [
        if (canCancel)
          const PopupMenuItem<String>(
            value: 'cancel',
            child: Row(
              children: [
                Icon(Icons.block_rounded, color: Color(0xFFFF0000), size: 20),
                SizedBox(width: 10),
                Text(
                  'Hủy nhiệm vụ',
                  style: TextStyle(
                    color: Color(0xFFFF0000),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (canDelete)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Color(0xFFFF0000), size: 20),
                SizedBox(width: 10),
                Text(
                  'Xóa vĩnh viễn',
                  style: TextStyle(
                    color: Color(0xFFFF0000),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }


  Widget _buildEditableTitle(Color textColor, bool isDark) {
    final String titleText = currentTask.title.trim().isEmpty
        ? 'Nhiệm vụ chưa có tên'
        : currentTask.title.trim();
    final Color hintColor = isDark ? Colors.grey.shade400 : Colors.black.withValues(alpha: 0.48);

    return Semantics(
      button: true,
      label: 'Sửa tên nhiệm vụ',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showTitleEditSheet,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: _detailTitleFontSize(currentTask.title),
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhấn vào tiêu đề để sửa',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelSection(Color textColor) {
    const Color primaryGreen = Color(0xFF64DA56);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Nhãn:",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: textColor,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: GestureDetector(
            onTap: _showLabelDialog,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 160, minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                currentCategory.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTimeSection(bool isDark, Color textColor) {
    final String timeText = TaskTimeFormatter.detailTimeRange(
      currentTask.startDateTime,
      currentTask.endDateTime,
    );
    final Color cardColor = isDark ? const Color(0xFF252725) : Colors.white;
    final Color secondaryTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Thời gian",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showTimeEditDialog,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64DA56).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: Color(0xFF64DA56),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      timeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLocationSection(bool isDark, Color textColor) {
    final String? trimmedLocation = currentTask.location?.trim();
    final bool hasLocation = trimmedLocation != null && trimmedLocation.isNotEmpty;
    final String locationText = hasLocation ? trimmedLocation : "Chưa thiết lập";
    final Color secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLocationSelectionOptions,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Vị trí: ",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: locationText,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    hasLocation ? Icons.edit_rounded : Icons.add_location_alt_rounded,
                    size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment, bool isDark, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _CommentUserAvatar(
                userId: comment.userId,
                fallbackAvatarId: comment.authorAvatarUrl ?? 'frog',
                size: 48,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFD8EFD6),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _CommentAuthorLine(
                          userId: comment.userId,
                          fallbackName: comment.userDisplayName,
                          timeText: _formatCommentTime(comment.createdAt),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showConfirmDeleteDialog(comment.id),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.check, size: 16, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCommentInput(bool isDark) {
    final Color inputBackground = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final Color borderColor = isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white;
    final Color hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;

    OutlineInputBorder inputBorder() {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor, width: 1),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CommentUserAvatar(
            userId: _authService.currentUser?.uid,
            fallbackAvatarId: 'frog',
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _commentController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: "Thêm một bình luận...",
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                filled: true,
                fillColor: inputBackground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: inputBorder(),
                enabledBorder: inputBorder(),
                focusedBorder: inputBorder(),
                disabledBorder: inputBorder(),
              ),
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Gửi bình luận',
            icon: const Icon(Icons.send, color: Color(0xFF6750A4)),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.high: color = const Color(0xFFFF3B30); break;
      case TaskPriority.medium: color = const Color(0xFFFFCC00); break;
      case TaskPriority.low: color = const Color(0xFF34C759); break;
    }
    return GestureDetector(
      onTap: _showPrioritySelector,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.24),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _priorityLabel(priority),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Color(0xFF1D1B20),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayStatusChip() {
    final String displayStatus = _getDisplayStatusString();
    return _buildStatusChip(displayStatus);
  }

  Widget _buildMarkCompletedButton() {
    return OutlinedButton.icon(
      onPressed: _showMarkCompletedConfirmationSheet,
      icon: const Icon(Icons.check_rounded, size: 15),
      label: const Text("Hoàn thành"),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        foregroundColor: const Color(0xFF1D8F2D),
        side: const BorderSide(color: Color(0xFF64DA56), width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }


  Widget _buildReactivateTaskButton() {
    return ElevatedButton.icon(
      onPressed: _handleReactivateTask,
      icon: const Icon(Icons.restart_alt_rounded, size: 15),
      label: const Text("Kích hoạt lại"),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: const Color(0xFF64DA56),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String displayStatus) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (displayStatus) {
      case "completed":
        bgColor = const Color(0xFF62E5FF);
        textColor = const Color(0xFF000000);
        text = "Hoàn thành";
        icon = Icons.check_circle_outline;
        break;
      case "inProgress":
        bgColor = const Color(0xFF64DA56);
        textColor = const Color(0xFFFFFFFF);
        text = "Đang làm";
        icon = Icons.sync;
        break;
      case "pending":
        bgColor = const Color(0xFFFFE562);
        textColor = const Color(0xFF000000);
        text = "Đang chờ";
        icon = Icons.schedule;
        break;
      case "cancelled":
        bgColor = const Color(0xFFABABAB);
        textColor = const Color(0xFF000000);
        text = "Đã hủy";
        icon = Icons.cancel_outlined;
        break;
      case "overdue":
        bgColor = const Color(0xFFFFE562);
        textColor = const Color(0xFF000000);
        text = "Quá hạn";
        icon = Icons.warning_amber_rounded;
        break;
      default:
        bgColor = Colors.grey;
        textColor = Colors.white;
        text = "Không xác định";
        icon = Icons.help_outline;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class TimeEditDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const TimeEditDialog({
    super.key,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<TimeEditDialog> createState() => _TimeEditDialogState();
}

class _TimeEditDialogState extends State<TimeEditDialog> {
  DateTime? tempStart;
  DateTime? tempEnd;
  bool isEditingStart = true;

  @override
  void initState() {
    super.initState();
    tempStart = widget.initialStart;
    tempEnd = widget.initialEnd;
  }

  String _formatDisplay(DateTime? dt) {
    return TaskTimeFormatter.detailDateTime(dt);
  }

  DateTime _safeInitialDate(DateTime initial, DateTime firstDate, DateTime lastDate) {
    if (initial.isBefore(firstDate)) return firstDate;
    if (initial.isAfter(lastDate)) return lastDate;
    return initial;
  }

  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 5, 1, 1);
    final DateTime lastDate = DateTime(now.year + 10, 12, 31);

    final DateTime initialDateTime = isEditingStart
        ? (tempStart ?? tempEnd ?? now)
        : (tempEnd ?? tempStart ?? now);

    final DateTime safeInitialDate = _safeInitialDate(
      initialDateTime,
      firstDate,
      lastDate,
    );

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isEditingStart ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (!mounted || pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      helpText: isEditingStart ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (!mounted || pickedTime == null) return;

    final DateTime pickedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isEditingStart) {
        tempStart = pickedDateTime;
      } else {
        tempEnd = pickedDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasError = tempStart != null && tempEnd != null && tempEnd!.isBefore(tempStart!);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Chỉnh sửa thời gian", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildTimeBox("Bắt đầu", tempStart, isEditingStart, () => setState(() => isEditingStart = true)),
            const SizedBox(height: 12),
            _buildTimeBox("Kết thúc", tempEnd, !isEditingStart, () => setState(() => isEditingStart = false)),

            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Thời gian kết thúc không được sớm hơn thời gian bắt đầu",
                  style: TextStyle(color: Colors.red.shade400, fontSize: 11),
                ),
              ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text("Chọn ngày & giờ ${isEditingStart ? 'Bắt đầu' : 'Kết thúc'}"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF64DA56).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF64DA56),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Hủy", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasError ? null : () {
                      Navigator.pop(context, [tempStart, tempEnd]);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF64DA56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, DateTime? value, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF64DA56).withValues(alpha: 0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF64DA56) : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(color: const Color(0xFF64DA56).withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_formatDisplay(value), style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            )),
          ],
        ),
      ),
    );
  }
}


class _CommentUserAvatar extends StatelessWidget {
  final String? userId;
  final String? fallbackAvatarId;
  final double size;

  const _CommentUserAvatar({
    required this.userId,
    required this.fallbackAvatarId,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final safeUserId = userId?.trim();

    if (safeUserId == null || safeUserId.isEmpty) {
      return YTaskAvatar(
        avatarId: fallbackAvatarId ?? 'frog',
        size: size,
        showBorder: false,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(safeUserId)
          .snapshots(),
      builder: (context, snapshot) {
        String? avatarId = fallbackAvatarId;

        final data = snapshot.data?.data();

        if (data != null) {
          final userAvatar = data['avatarUrl'] as String?;

          if (userAvatar != null && userAvatar.trim().isNotEmpty) {
            avatarId = userAvatar;
          }
        }

        return YTaskAvatar(
          avatarId: avatarId ?? 'frog',
          size: size,
          showBorder: false,
        );
      },
    );
  }
}

class _TitleEditSheet extends StatefulWidget {
  final String initialTitle;

  const _TitleEditSheet({required this.initialTitle});

  @override
  State<_TitleEditSheet> createState() => _TitleEditSheetState();
}

class _TitleEditSheetState extends State<_TitleEditSheet> {
  late final TextEditingController _titleController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _validateAndPop() {
    final String newTitle = _titleController.text.trim();

    if (newTitle.isEmpty) {
      setState(() {
        _titleError = 'Vui lòng nhập tên nhiệm vụ';
      });
      return;
    }

    if (newTitle.length > 100) {
      setState(() {
        _titleError = 'Tên nhiệm vụ tối đa 100 ký tự';
      });
      return;
    }

    Navigator.of(context).pop(newTitle);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F211F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  'Sửa tên nhiệm vụ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tên ngắn, rõ ý sẽ giúp bạn nhận diện nhiệm vụ nhanh hơn.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 100,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    setState(() {
                      _titleError = null;
                    });
                  },
                  onSubmitted: (_) => _validateAndPop(),
                  decoration: InputDecoration(
                    hintText: 'Nhập tên nhiệm vụ',
                    errorText: _titleError,
                    counterText: '${_titleController.text.length}/100',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2B2E2B) : const Color(0xFFF5F1F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFF64DA56),
                        width: 1.6,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _validateAndPop,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          elevation: 0,
                          backgroundColor: const Color(0xFF64DA56),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Lưu',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentAuthorLine extends StatelessWidget {
  final String? userId;
  final String fallbackName;
  final String timeText;

  const _CommentAuthorLine({
    required this.userId,
    required this.fallbackName,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final safeUserId = userId?.trim();

    if (safeUserId == null || safeUserId.isEmpty) {
      return _AuthorText(name: fallbackName, timeText: timeText);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(safeUserId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final liveName = (data?['name'] as String?)?.trim();

        return _AuthorText(
          name: liveName == null || liveName.isEmpty ? fallbackName : liveName,
          timeText: timeText,
        );
      },
    );
  }
}

class _AuthorText extends StatelessWidget {
  final String name;
  final String timeText;

  const _AuthorText({
    required this.name,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      '$name - $timeText',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}
