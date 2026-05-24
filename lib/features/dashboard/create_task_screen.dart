import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:todo_app/models/category_model.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/features/dashboard/widgets/label_management_dialog.dart';
import 'package:todo_app/features/dashboard/widgets/reminder_picker_sheet.dart';
import 'package:todo_app/features/dashboard/widgets/manual_location_dialog.dart' as location_dialog;
import 'package:todo_app/features/dashboard/utils/task_time_formatter.dart';
import 'package:todo_app/services/auth_service.dart';
import 'package:todo_app/services/task_service.dart';
import 'package:todo_app/services/category_service.dart';
import 'package:todo_app/services/notification_service.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _titleError;

  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final CategoryService _categoryService = CategoryService();

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  bool _endDateTimeManuallyEdited = false;

  TaskPriority _selectedPriority = TaskPriority.medium;
  CategoryModel? _selectedCategory;

  // Reminder State
  bool _remindAtStart = false;
  int _startReminderOffsetMinutes = 0;
  bool _remindAtDeadline = false;
  int _deadlineReminderOffsetMinutes = 0;

  bool _isSaving = false;
  bool _isSnackMessageVisible = false;

  static const Duration _snackMessageDuration = Duration(seconds: 2);

  bool get _isReminderOn => _remindAtStart || _remindAtDeadline;

  TaskReminderType get _legacyReminderType {
    if (_remindAtStart && !_remindAtDeadline) return TaskReminderType.start;
    if (!_remindAtStart && _remindAtDeadline) return TaskReminderType.deadline;
    if (_remindAtStart && _remindAtDeadline) return TaskReminderType.deadline;
    return TaskReminderType.none;
  }

  int? get _legacyReminderOffsetMinutes {
    if (!_isReminderOn) return null;
    if (_remindAtDeadline) return _deadlineReminderOffsetMinutes;
    if (_remindAtStart) return _startReminderOffsetMinutes;
    return null;
  }

  String get _reminderLabel {
    if (!_isReminderOn) return 'Không nhắc';
    if (_remindAtStart && _remindAtDeadline) return 'Bắt đầu + Deadline';
    if (_remindAtStart) return 'Bắt đầu';
    return 'Deadline';
  }

  void _clearTitleErrorIfNeeded() {
    if (_titleError == null) return;

    setState(() {
      _titleError = null;
    });
  }

  bool _validateTitle() {
    if (_titleController.text.trim().isNotEmpty) {
      return true;
    }

    setState(() {
      _titleError = 'Vui lòng nhập tên nhiệm vụ';
    });

    return false;
  }


  String _priorityLabel(TaskPriority priority) => priority.vietnameseLabel;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await _categoryService.ensureDefaultCategories(uid);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _formatDateTimeDisplay(DateTime? dt) {
    return TaskTimeFormatter.inputDateTime(dt);
  }

  Future<void> _selectDateTime(bool isStart) async {
    final DateTime now = DateTime.now();
    final DateTime initialDateTime = isStart
        ? (_startDateTime ?? now)
        : (_endDateTime ?? _startDateTime?.add(const Duration(hours: 2)) ?? now);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (pickedTime == null) return;
    if (!mounted) return;

    final DateTime newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startDateTime = newDateTime;

        final bool shouldAutoSetEndDateTime =
            _endDateTime == null ||
                !_endDateTimeManuallyEdited ||
                !_endDateTime!.isAfter(newDateTime);

        if (shouldAutoSetEndDateTime) {
          _endDateTime = newDateTime.add(const Duration(hours: 2));
        }
      } else {
        _endDateTime = newDateTime;
        _endDateTimeManuallyEdited = true;
      }
    });
  }

  DateTime? _calculateStartReminderScheduledAt() {
    if (!_remindAtStart) return null;
    if (_startDateTime == null) return null;

    return _startDateTime!.subtract(
      Duration(minutes: _startReminderOffsetMinutes),
    );
  }

  DateTime? _calculateDeadlineReminderScheduledAt() {
    if (!_remindAtDeadline) return null;
    if (_endDateTime == null) return null;

    return _endDateTime!.subtract(
      Duration(minutes: _deadlineReminderOffsetMinutes),
    );
  }

  String _offsetLabel(int minutes) {
    return TaskTimeFormatter.reminderOffsetLabel(minutes);
  }

  void _showSnackMessage(String message) {
    if (!mounted || _isSnackMessageVisible) return;

    _isSnackMessageVisible = true;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger
        .showSnackBar(
      SnackBar(
        content: Text(message),
        duration: _snackMessageDuration,
      ),
    )
        .closed
        .whenComplete(() {
      _isSnackMessageVisible = false;
    });
  }

  bool _isScheduledReminderInFuture({
    required DateTime? targetDateTime,
    required int offsetMinutes,
  }) {
    if (targetDateTime == null) return false;

    final scheduledAt = targetDateTime.subtract(Duration(minutes: offsetMinutes));
    return scheduledAt.isAfter(DateTime.now());
  }

  Future<void> _openReminderPicker() async {
    final result = await showModalBottomSheet<ReminderPickerResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242623)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return ReminderPickerSheet(
          initialRemindAtStart: _remindAtStart,
          initialStartOffsetMinutes: _startReminderOffsetMinutes,
          initialRemindAtDeadline: _remindAtDeadline,
          initialDeadlineOffsetMinutes: _deadlineReminderOffsetMinutes,
          startDateTime: _startDateTime,
          endDateTime: _endDateTime,
          offsetLabelBuilder: _offsetLabel,
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _remindAtStart = result.remindAtStart;
      _startReminderOffsetMinutes = result.startOffsetMinutes;
      _remindAtDeadline = result.remindAtDeadline;
      _deadlineReminderOffsetMinutes = result.deadlineOffsetMinutes;
    });
  }

  void _showLabelDialog() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _showSnackMessage("Bạn cần đăng nhập trước");
      return;
    }

    showDialog(
      context: context,
      builder: (context) => LabelManagementDialog(
        uid: uid,
        initialCategoryId: _selectedCategory?.id ?? '',
        onSelected: (category) {
          setState(() {
            _selectedCategory = category;
          });
        },
      ),
    );
  }

  Future<void> _onCreateTask() async {
    final title = _titleController.text.trim();

    if (!_validateTitle()) {
      return;
    }

    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _showSnackMessage("Bạn cần đăng nhập trước để tạo nhiệm vụ!");
      return;
    }

    if (_selectedCategory == null) {
      _showSnackMessage("Vui lòng chọn một nhãn!");
      return;
    }

    if (_startDateTime != null && _endDateTime != null) {
      if (!_endDateTime!.isAfter(_startDateTime!)) {
        _showSnackMessage("Thời gian kết thúc phải sau thời gian bắt đầu.");
        return;
      }
    }

    final startReminderScheduledAt = _calculateStartReminderScheduledAt();
    final deadlineReminderScheduledAt = _calculateDeadlineReminderScheduledAt();

    if (_remindAtStart) {
      if (_startDateTime == null) {
        _showSnackMessage(
          'Bạn cần chọn thời gian bắt đầu trước khi bật nhắc nhở.',
        );
        return;
      }

      if (startReminderScheduledAt == null ||
          !startReminderScheduledAt.isAfter(DateTime.now())) {
        _showSnackMessage(
          'Thời điểm nhắc bắt đầu đã qua. Vui lòng chọn thời gian khác.',
        );
        return;
      }
    }

    if (_remindAtDeadline) {
      if (_endDateTime == null) {
        _showSnackMessage(
          'Bạn cần chọn thời gian kết thúc trước khi bật nhắc deadline.',
        );
        return;
      }

      if (deadlineReminderScheduledAt == null ||
          !deadlineReminderScheduledAt.isAfter(DateTime.now())) {
        _showSnackMessage(
          'Thời điểm nhắc deadline đã qua. Vui lòng chọn thời gian khác.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newTask = TaskModel(
        id: '',
        title: title,
        description: _descriptionController.text,
        categoryId: _selectedCategory!.id,
        userId: uid,
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
        status: TaskStatus.pending,
        priority: _selectedPriority,
        isReminderOn: _isReminderOn,
        reminderType: _legacyReminderType,
        reminderOffsetMinutes: _legacyReminderOffsetMinutes,
        reminderScheduledAt: null,
        localNotificationId: null,
        remindAtStart: _remindAtStart,
        startReminderOffsetMinutes: _startReminderOffsetMinutes,
        remindAtDeadline: _remindAtDeadline,
        deadlineReminderOffsetMinutes: _deadlineReminderOffsetMinutes,
        startReminderScheduledAt: null,
        deadlineReminderScheduledAt: null,
        startLocalNotificationId: null,
        deadlineLocalNotificationId: null,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final taskId = await _taskService.createTask(newTask);
      final createdTask = newTask.copyWith(id: taskId);

      if (createdTask.isReminderOn) {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) {
          _showSnackMessage(
            'Bạn chưa cấp quyền thông báo nên YTask chưa thể nhắc nhở.',
          );
        } else {
          int? startNotificationId;
          int? deadlineNotificationId;

          if (createdTask.remindAtStart) {
            startNotificationId =
            await NotificationService.instance.scheduleTaskStartReminder(
              task: createdTask,
              offsetMinutes: createdTask.startReminderOffsetMinutes,
            );
          }

          if (createdTask.remindAtDeadline) {
            deadlineNotificationId =
            await NotificationService.instance.scheduleTaskDeadlineReminder(
              task: createdTask,
              offsetMinutes: createdTask.deadlineReminderOffsetMinutes,
            );
          }

          if (startNotificationId != null || deadlineNotificationId != null) {
            await _taskService.updateTask(
              createdTask.copyWith(
                startLocalNotificationId: startNotificationId,
                deadlineLocalNotificationId: deadlineNotificationId,
                startReminderScheduledAt:
                startNotificationId == null ? null : startReminderScheduledAt,
                deadlineReminderScheduledAt: deadlineNotificationId == null
                    ? null
                    : deadlineReminderScheduledAt,
                localNotificationId: deadlineNotificationId ?? startNotificationId,
                reminderScheduledAt: deadlineReminderScheduledAt ?? startReminderScheduledAt,
              ),
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackMessage("Lỗi tạo nhiệm vụ: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showManualLocationDialog() async {
    final location = await location_dialog.showManualLocationDialog(
      context,
      initialValue: _locationController.text,
    );

    if (location == null || !mounted) return;

    setState(() {
      _locationController.text = location;
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    const Color primaryGreen = Color(0xFF64DA56);
    final uid = _authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tạo lịch trình mới',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 32),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSoftInputBox(
                    minHeight: 72,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: TextField(
                      controller: _titleController,
                      cursorColor: const Color(0xFF64DA56),
                      style: const TextStyle(
                        color: Color(0xFF1F1F1F),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _softInputDecoration('Tên nhiệm vụ *'),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearTitleErrorIfNeeded(),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: _titleError == null
                        ? const SizedBox.shrink()
                        : Padding(
                      padding: const EdgeInsets.only(top: 8, left: 18),
                      child: Text(
                        _titleError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildSoftInputBox(
                minHeight: 72,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: TextField(
                  controller: _descriptionController,
                  cursorColor: const Color(0xFF64DA56),
                  minLines: 1,
                  maxLines: null,
                  style: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                  decoration: _softInputDecoration('Thêm mô tả'),
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDateTime(true),
                      child: _buildDateTimeSelector(
                        label: "Bắt đầu",
                        dateTime: _startDateTime,
                        isDark: isDark,
                        textColor: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDateTime(false),
                      child: _buildDateTimeSelector(
                        label: "Kết thúc",
                        dateTime: _endDateTime,
                        isDark: isDark,
                        textColor: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text("Nhãn", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              if (uid != null)
                StreamBuilder<List<CategoryModel>>(
                  stream: _categoryService.getCategoriesByUser(uid),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];

                    // Cập nhật selectedCategory nếu chưa có hoặc không còn tồn tại
                    if (_selectedCategory == null && categories.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedCategory = categories.first;
                        });
                      });
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showLabelDialog,
                            child: _buildAddLabelButton(isDark),
                          ),
                          const SizedBox(width: 12),
                          ...categories.map((cat) {
                            final isSelected = _selectedCategory?.id == cat.id;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = cat),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildLabelChip(cat, isSelected, isDark),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              Text("Khẩn cấp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPriorityOption(TaskPriority.low, const Color(0xFFA7FFEB), isDark),
                  const SizedBox(width: 12),
                  _buildPriorityOption(TaskPriority.medium, const Color(0xFFFFF59D), isDark),
                  const SizedBox(width: 12),
                  _buildPriorityOption(TaskPriority.high, const Color(0xFFFFCDD2), isDark),
                ],
              ),
              const SizedBox(height: 24),

              Text("Vị trí", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showManualLocationDialog,
                child: _buildInputContainer(
                  isDark: isDark,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _locationController.text.isEmpty ? "Nhập địa điểm..." : _locationController.text,
                            style: TextStyle(color: _locationController.text.isEmpty ? Colors.grey : textColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              InkWell(
                onTap: _openReminderPicker,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252725) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nhắc nhở',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF2E2B3A),
                          ),
                        ),
                      ),
                      Text(
                        _reminderLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onCreateTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text(
                    "TẠO NHIỆM VỤ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoftInputBox({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 2,
    ),
    double minHeight = 58,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A3029) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A4438)
              : Colors.white.withValues(alpha: 0.95),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.055),
            blurRadius: 14,
            spreadRadius: -3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _softInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9A9A9A),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),

      // Quan trọng: chặn toàn bộ border từ ThemeData.inputDecorationTheme
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,

      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildInputContainer({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildDateTimeSelector({required String label, required DateTime? dateTime, required bool isDark, required Color textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF64DA56),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDateTimeDisplay(dateTime),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: dateTime == null ? 12 : 13,
                    fontWeight: dateTime == null ? FontWeight.w600 : FontWeight.w800,
                    color: dateTime == null
                        ? (isDark ? Colors.white54 : Colors.black45)
                        : textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelChip(CategoryModel cat, bool isSelected, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF64DA56) : (isDark ? Colors.grey[800] : const Color(0xFFD8EFD6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cat.name,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : const Color(0xFF898C89)),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAddLabelButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
      ),
      child: const Icon(Icons.add, size: 20, color: Colors.grey),
    );
  }

  Widget _buildPriorityOption(TaskPriority priority, Color color, bool isDark) {
    bool isSelected = _selectedPriority == priority;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = priority),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.3) : color,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: const Color(0xFF64DA56), width: 2) : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _priorityLabel(priority),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF2E2B3A))
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
