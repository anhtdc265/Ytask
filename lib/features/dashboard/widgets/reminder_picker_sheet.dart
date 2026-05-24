import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReminderPickerSheet extends StatefulWidget {
  final bool initialRemindAtStart;
  final int initialStartOffsetMinutes;
  final bool initialRemindAtDeadline;
  final int initialDeadlineOffsetMinutes;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String Function(int minutes) offsetLabelBuilder;

  const ReminderPickerSheet({
    required this.initialRemindAtStart,
    required this.initialStartOffsetMinutes,
    required this.initialRemindAtDeadline,
    required this.initialDeadlineOffsetMinutes,
    required this.startDateTime,
    required this.endDateTime,
    required this.offsetLabelBuilder,
  });

  @override
  State<ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<ReminderPickerSheet> {
  late bool _tempRemindAtStart;
  late int _tempStartOffset;
  late bool _tempRemindAtDeadline;
  late int _tempDeadlineOffset;

  final TextEditingController _customOffsetController = TextEditingController();
  bool? _customForStart;
  String? _customOffsetError;
  String? _sheetMessage;
  bool _isSheetMessageVisible = false;
  Timer? _sheetMessageTimer;

  static const Duration _sheetMessageDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _tempRemindAtStart = widget.initialRemindAtStart;
    _tempStartOffset = widget.initialStartOffsetMinutes;
    _tempRemindAtDeadline = widget.initialRemindAtDeadline;
    _tempDeadlineOffset = widget.initialDeadlineOffsetMinutes;
  }

  @override
  void dispose() {
    _sheetMessageTimer?.cancel();
    _customOffsetController.dispose();
    super.dispose();
  }

  void _showSheetMessage(String message) {
    if (_isSheetMessageVisible) return;

    setState(() {
      _sheetMessage = message;
      _isSheetMessageVisible = true;
    });

    _sheetMessageTimer?.cancel();
    _sheetMessageTimer = Timer(_sheetMessageDuration, () {
      if (!mounted) return;

      setState(() {
        _sheetMessage = null;
        _isSheetMessageVisible = false;
      });
    });
  }

  Widget _buildSheetMessage({required bool isDark}) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: _sheetMessage == null
          ? const SizedBox.shrink()
          : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sheetMessage!,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : const Color(0xFF3A2F35),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isScheduledReminderInFuture({
    required DateTime? targetDateTime,
    required int offsetMinutes,
  }) {
    if (targetDateTime == null) return false;

    final scheduledAt = targetDateTime.subtract(Duration(minutes: offsetMinutes));
    return scheduledAt.isAfter(DateTime.now());
  }

  String _compactCustomOffsetLabel(int minutes) {
    return widget.offsetLabelBuilder(minutes).replaceFirst('Trước ', '');
  }

  void _openInlineCustomOffset({required bool forStart}) {
    final currentOffset = forStart ? _tempStartOffset : _tempDeadlineOffset;

    setState(() {
      _customForStart = forStart;
      _customOffsetError = null;
      _customOffsetController.text = currentOffset > 0 ? '$currentOffset' : '0';
      _customOffsetController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _customOffsetController.text.length,
      );
    });
  }

  void _closeInlineCustomOffset() {
    setState(() {
      _customForStart = null;
      _customOffsetError = null;
      _customOffsetController.clear();
    });
  }

  void _applyInlineCustomOffset() {
    final forStart = _customForStart;
    if (forStart == null) return;

    final text = _customOffsetController.text.trim();
    final minutes = int.tryParse(text);

    if (minutes == null) {
      setState(() => _customOffsetError = 'Vui lòng nhập số phút.');
      return;
    }

    if (minutes > 10080) {
      setState(() => _customOffsetError = 'Chỉ nên nhắc tối đa trước 7 ngày.');
      return;
    }

    final targetDateTime = forStart ? widget.startDateTime : widget.endDateTime;
    final isValid = _isScheduledReminderInFuture(
      targetDateTime: targetDateTime,
      offsetMinutes: minutes,
    );

    if (!isValid) {
      _showSheetMessage(
        forStart
            ? 'Thời điểm nhắc bắt đầu đã qua. Vui lòng chọn thời gian khác.'
            : 'Thời điểm nhắc deadline đã qua. Vui lòng chọn thời gian khác.',
      );
      return;
    }

    setState(() {
      if (forStart) {
        _tempStartOffset = minutes;
      } else {
        _tempDeadlineOffset = minutes;
      }
      _customForStart = null;
      _customOffsetError = null;
      _customOffsetController.clear();
    });
  }

  void _handleStartSwitch(bool value) {
    if (value && widget.startDateTime == null) {
      _showSheetMessage(
        'Bạn cần chọn thời gian bắt đầu trước khi bật nhắc nhở.',
      );
      return;
    }

    setState(() {
      _tempRemindAtStart = value;
      if (!value && _customForStart == true) {
        _customForStart = null;
        _customOffsetError = null;
        _customOffsetController.clear();
      }
    });
  }

  void _handleDeadlineSwitch(bool value) {
    if (value && widget.endDateTime == null) {
      _showSheetMessage(
        'Bạn cần chọn thời gian kết thúc trước khi bật nhắc deadline.',
      );
      return;
    }

    setState(() {
      _tempRemindAtDeadline = value;
      if (!value && _customForStart == false) {
        _customForStart = null;
        _customOffsetError = null;
        _customOffsetController.clear();
      }
    });
  }

  void _handleStartOffsetChanged(int minutes) {
    if (!_isScheduledReminderInFuture(
      targetDateTime: widget.startDateTime,
      offsetMinutes: minutes,
    )) {
      _showSheetMessage(
        'Thời điểm nhắc bắt đầu đã qua. Vui lòng chọn thời gian khác.',
      );
      return;
    }

    setState(() {
      _tempStartOffset = minutes;
      if (_customForStart == true) {
        _customForStart = null;
        _customOffsetError = null;
        _customOffsetController.clear();
      }
    });
  }

  void _handleDeadlineOffsetChanged(int minutes) {
    if (!_isScheduledReminderInFuture(
      targetDateTime: widget.endDateTime,
      offsetMinutes: minutes,
    )) {
      _showSheetMessage(
        'Thời điểm nhắc deadline đã qua. Vui lòng chọn thời gian khác.',
      );
      return;
    }

    setState(() {
      _tempDeadlineOffset = minutes;
      if (_customForStart == false) {
        _customForStart = null;
        _customOffsetError = null;
        _customOffsetController.clear();
      }
    });
  }

  Widget _buildCompactInlineCustomOffsetEditor({required bool isDark}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 196,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF64DA56), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _customOffsetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    cursorColor: const Color(0xFF64DA56),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF2E2B3A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'phút',
                      suffixText: 'p',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      filled: true,
                      fillColor:
                      isDark ? const Color(0xFF242623) : const Color(0xFFF7F7F7),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF64DA56)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _applyInlineCustomOffset(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _applyInlineCustomOffset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64DA56),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _closeInlineCustomOffset,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF6F6A78),
                  ),
                ),
              ),
            ],
          ),
          if (_customOffsetError != null) ...[
            const SizedBox(height: 6),
            Text(
              _customOffsetError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhắc nhở',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF2E2B3A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Có thể bật nhắc khi bắt đầu, khi gần deadline hoặc cả hai.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.72)
                    : const Color(0xFF6F6A78),
              ),
            ),
            _buildSheetMessage(isDark: isDark),
            const SizedBox(height: 16),
            ReminderSwitchSection(
              title: 'Nhắc khi bắt đầu',
              subtitle: 'Dựa trên thời gian bắt đầu nhiệm vụ',
              icon: Icons.play_circle_outline_rounded,
              value: _tempRemindAtStart,
              selectedOffsetMinutes: _tempStartOffset,
              offsetOptions: const [0, 10, 30, 60],
              offsetLabelBuilder: widget.offsetLabelBuilder,
              onCustomOffsetPressed: () => _openInlineCustomOffset(forStart: true),
              customEditor: _customForStart == true
                  ? _buildCompactInlineCustomOffsetEditor(isDark: isDark)
                  : null,
              onChanged: _handleStartSwitch,
              onOffsetChanged: _handleStartOffsetChanged,
            ),
            const SizedBox(height: 12),
            ReminderSwitchSection(
              title: 'Nhắc deadline',
              subtitle: 'Dựa trên thời gian kết thúc nhiệm vụ',
              icon: Icons.alarm_on_rounded,
              value: _tempRemindAtDeadline,
              selectedOffsetMinutes: _tempDeadlineOffset,
              offsetOptions: const [0, 10, 30, 60, 1440],
              offsetLabelBuilder: widget.offsetLabelBuilder,
              onCustomOffsetPressed: () => _openInlineCustomOffset(forStart: false),
              customEditor: _customForStart == false
                  ? _buildCompactInlineCustomOffsetEditor(isDark: isDark)
                  : null,
              onChanged: _handleDeadlineSwitch,
              onOffsetChanged: _handleDeadlineOffsetChanged,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const ReminderPickerResult(
                          remindAtStart: false,
                          startOffsetMinutes: 0,
                          remindAtDeadline: false,
                          deadlineOffsetMinutes: 0,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Tắt nhắc'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        ReminderPickerResult(
                          remindAtStart: _tempRemindAtStart,
                          startOffsetMinutes: _tempStartOffset,
                          remindAtDeadline: _tempRemindAtDeadline,
                          deadlineOffsetMinutes: _tempDeadlineOffset,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64DA56),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Xác nhận',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReminderPickerResult {
  final bool remindAtStart;
  final int startOffsetMinutes;
  final bool remindAtDeadline;
  final int deadlineOffsetMinutes;

  const ReminderPickerResult({
    required this.remindAtStart,
    required this.startOffsetMinutes,
    required this.remindAtDeadline,
    required this.deadlineOffsetMinutes,
  });
}

class ReminderSwitchSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final int selectedOffsetMinutes;
  final List<int> offsetOptions;
  final String Function(int minutes) offsetLabelBuilder;
  final VoidCallback onCustomOffsetPressed;
  final Widget? customEditor;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onOffsetChanged;

  const ReminderSwitchSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selectedOffsetMinutes,
    required this.offsetOptions,
    required this.offsetLabelBuilder,
    required this.onCustomOffsetPressed,
    this.customEditor,
    required this.onChanged,
    required this.onOffsetChanged,
  });

  static const Color _primaryGreen = Color(0xFF64DA56);

  String _compactCustomOffsetLabel(int minutes) {
    final fullLabel = offsetLabelBuilder(minutes);
    return fullLabel.replaceFirst('Trước ', '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF5F1F8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? _primaryGreen : Colors.transparent,
          width: 1.5,
        ),
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
                  color: value
                      ? _primaryGreen
                      : _primaryGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: value ? Colors.white : _primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF2E2B3A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : const Color(0xFF77717F),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeThumbColor: _primaryGreen,
                onChanged: onChanged,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: value
                ? Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...offsetOptions.map((minutes) {
                    final selected = selectedOffsetMinutes == minutes;
                    return ChoiceChip(
                      label: Text(offsetLabelBuilder(minutes)),
                      selected: selected,
                      onSelected: (_) => onOffsetChanged(minutes),
                      selectedColor: _primaryGreen,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : (isDark
                            ? Colors.white
                            : const Color(0xFF2E2B3A)),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      side: BorderSide(
                        color: selected ? _primaryGreen : Colors.transparent,
                      ),
                    );
                  }),
                  CustomReminderChoiceChip(
                    selected: !offsetOptions.contains(selectedOffsetMinutes),
                    label: offsetOptions.contains(selectedOffsetMinutes)
                        ? 'Tùy chỉnh'
                        : 'Tùy chỉnh: ${_compactCustomOffsetLabel(selectedOffsetMinutes)}',
                    isDark: isDark,
                    onTap: onCustomOffsetPressed,
                  ),
                  if (customEditor != null) customEditor!,
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


class CustomReminderChoiceChip extends StatelessWidget {
  final bool selected;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const CustomReminderChoiceChip({
    required this.selected,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  static const Color _primaryGreen = Color(0xFF64DA56);

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        Icons.tune_rounded,
        size: 16,
        color: selected
            ? Colors.white
            : (isDark ? Colors.white70 : const Color(0xFF2E2B3A)),
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _primaryGreen,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : (isDark ? Colors.white : const Color(0xFF2E2B3A)),
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      backgroundColor:
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      side: BorderSide(
        color: selected ? _primaryGreen : Colors.transparent,
      ),
    );
  }
}
