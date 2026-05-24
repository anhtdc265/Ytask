import 'package:flutter/material.dart';
import 'package:todo_app/features/dashboard/widgets/calendar_header.dart';
import 'package:todo_app/features/dashboard/widgets/schedule_panel.dart';
import 'package:todo_app/shared/widgets/custom_bottom_nav.dart';
import 'package:todo_app/features/dashboard/create_task_screen.dart';
import 'package:todo_app/services/auth_service.dart';
import 'package:todo_app/services/task_service.dart';
import 'package:todo_app/services/category_service.dart';
import 'package:todo_app/models/task_model.dart';
import 'package:todo_app/models/category_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final CategoryService _categoryService = CategoryService();

  late DateTime _today;
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  bool _isCalendarExpanded = false;
  String? _activeUid;
  Stream<List<CategoryModel>>? _categoriesStream;
  Stream<List<TaskModel>>? _tasksStream;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _today = _dateOnly(now);
    _selectedDate = _today;
    _displayedMonth = DateTime(_today.year, _today.month);

    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _ensureUserStreams(uid);
    }

    _initData();
  }

  void _ensureUserStreams(String uid) {
    if (_activeUid == uid &&
        _categoriesStream != null &&
        _tasksStream != null) {
      return;
    }

    _activeUid = uid;
    _categoriesStream = _categoryService.getCategoriesByUser(uid);
    _tasksStream = _taskService.getTasksByUser(uid);
  }

  Future<void> _initData() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await _categoryService.ensureDefaultCategories(uid);
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      _displayedMonth = DateTime(date.year, date.month);
    });
  }

  void _goToPreviousMonth() {
    final previousMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    _changeDisplayedMonth(previousMonth);
  }

  void _goToNextMonth() {
    final nextMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    _changeDisplayedMonth(nextMonth);
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _today = _dateOnly(now);
      _selectedDate = _today;
      _displayedMonth = DateTime(_today.year, _today.month);
    });
  }

  void _changeDisplayedMonth(DateTime newMonth) {
    setState(() {
      _displayedMonth = DateTime(newMonth.year, newMonth.month);

      final isCurrentRealMonth =
          _displayedMonth.year == _today.year && _displayedMonth.month == _today.month;

      _selectedDate = isCurrentRealMonth
          ? _today
          : DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    });
  }

  Future<void> _pickMonthYear() async {
    final pickedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242623)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        int tempMonth = _displayedMonth.month;
        int tempYear = _displayedMonth.year;

        final years = List.generate(16, (index) => 2020 + index);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn tháng và năm',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF2E2B3A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerBox(
                          label: 'Tháng',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: tempMonth,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(18),
                              items: List.generate(
                                12,
                                    (index) {
                                  final month = index + 1;
                                  return DropdownMenuItem<int>(
                                    value: month,
                                    child: Text('Tháng $month'),
                                  );
                                },
                              ),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() {
                                  tempMonth = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerBox(
                          label: 'Năm',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: years.contains(tempYear)
                                  ? tempYear
                                  : _today.year,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(18),
                              items: years
                                  .map(
                                    (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text('$year'),
                                ),
                              )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() {
                                  tempYear = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF64DA56),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          DateTime(tempYear, tempMonth),
                        );
                      },
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (pickedMonth == null) return;
    _changeDisplayedMonth(pickedMonth);
  }

  bool _isTaskVisibleOnDate(TaskModel task, DateTime selectedDate) {
    if (task.isDeleted) return false;
    if (task.status == TaskStatus.completed) return false;
    if (task.status == TaskStatus.cancelled) return false;

    final start = task.startDateTime;
    final end = task.endDateTime;
    final selected = _dateOnly(selectedDate);

    // Case 1: Không có start và không có end -> không đủ dữ liệu để đưa lên lịch ngày
    if (start == null && end == null) return false;

    // Case 2: Có start nhưng chưa có end
    // Ví dụ: start hôm nay 21:44, không set endDate
    // => vẫn phải hiện trong lịch trình của ngày start
    if (start != null && end == null) {
      return selected == _dateOnly(start);
    }

    // Case 3: Không có start nhưng có end
    // Ít gặp, nhưng nếu có thì cho hiện vào ngày deadline
    if (start == null && end != null) {
      return selected == _dateOnly(end);
    }

    // Case 4: Có cả start và end
    final startDate = _dateOnly(start!);
    final endDate = _dateOnly(end!);

    final rangeStart = startDate.isBefore(endDate) ? startDate : endDate;
    final rangeEnd = startDate.isBefore(endDate) ? endDate : startDate;

    return !selected.isBefore(rangeStart) && !selected.isAfter(rangeEnd);
  }

  List<TaskModel> _visibleTasksForSelectedDate(List<TaskModel> tasks) {
    final visibleTasks = tasks
        .where((task) => _isTaskVisibleOnDate(task, _selectedDate))
        .toList();

    visibleTasks.sort((a, b) {
      final aTime = a.startDateTime ?? DateTime(9999);
      final bTime = b.startDateTime ?? DateTime(9999);
      return aTime.compareTo(bTime);
    });

    return visibleTasks;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _handleCompleteTask(TaskModel task) async {
    if (task.id.isEmpty) return;

    try {
      await _taskService.markTaskCompleted(task.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Đã hoàn thành: ${task.title}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF64DA56),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Không thể hoàn thành task: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Future<void> _handleCancelTask(TaskModel task) async {
    if (task.id.isEmpty) return;

    try {
      await _taskService.markTaskCancelled(task.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Đã hủy: ${task.title}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Không thể hủy task: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final uid = _authService.currentUser?.uid;

    if (uid != null) {
      _ensureUserStreams(uid);
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 16),
                CalendarHeader(
                  today: _today,
                  selectedDate: _selectedDate,
                  displayedMonth: _displayedMonth,
                  isExpanded: _isCalendarExpanded,
                  onDateSelected: _selectDate,
                  onPreviousMonth: _goToPreviousMonth,
                  onNextMonth: _goToNextMonth,
                  onPickMonthYear: _pickMonthYear,
                  onGoToToday: _goToToday,
                ),
              ],
            ),
            if (uid == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 200),
                  child: Text('Vui lòng đăng nhập để xem lịch trình'),
                ),
              )
            else
              StreamBuilder<List<CategoryModel>>(
                stream: _categoriesStream,
                builder: (context, catSnapshot) {
                  final categories = catSnapshot.data ?? [];

                  return StreamBuilder<List<TaskModel>>(
                    stream: _tasksStream,
                    builder: (context, taskSnapshot) {
                      if (taskSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 200),
                            child: CircularProgressIndicator(
                              color: Color(0xFF64DA56),
                            ),
                          ),
                        );
                      }

                      if (taskSnapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 200),
                            child: Text('Đã xảy ra lỗi: ${taskSnapshot.error}'),
                          ),
                        );
                      }

                      final allTasks = taskSnapshot.data ?? [];
                      final visibleTasks = _visibleTasksForSelectedDate(allTasks);

                      return SchedulePanel(
                        tasks: visibleTasks,
                        categories: categories,
                        selectedDate: _selectedDate,
                        today: _today,
                        onCompleteTask: _handleCompleteTask,
                        onCancelTask: _handleCancelTask,
                        onExpandedChanged: (expanded) {
                          if (_isCalendarExpanded == expanded) return;

                          setState(() {
                            _isCalendarExpanded = expanded;
                          });
                        },
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateTaskScreen(),
              ),
            );

            if (!mounted || created != true) return;

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Đã tạo nhiệm vụ'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF64DA56),
                  duration: Duration(seconds: 2),
                ),
              );
          },
          backgroundColor: const Color(0xFF64DA56),
          shape: const CircleBorder(),
          elevation: 6,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
    );
  }
}

class _PickerBox extends StatelessWidget {
  final String label;
  final Widget child;

  const _PickerBox({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF5F1F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
