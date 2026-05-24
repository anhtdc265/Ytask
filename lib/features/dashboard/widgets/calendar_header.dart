import 'package:flutter/material.dart';
import 'package:todo_app/core/theme/app_theme.dart';

enum CalendarDayIndicator {
  none,
  incomplete,
  overdue,
}

class CalendarHeader extends StatelessWidget {
  final DateTime today;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final bool isExpanded;
  final Map<DateTime, CalendarDayIndicator> dayIndicators;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonthYear;
  final VoidCallback onGoToToday;

  const CalendarHeader({
    super.key,
    required this.today,
    required this.selectedDate,
    required this.displayedMonth,
    required this.isExpanded,
    this.dayIndicators = const {},
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickMonthYear,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = isExpanded
        ? _getMonthGridDays(displayedMonth)
        : _getWeekDays(selectedDate);
    final shouldShowTodayButton = !_isSameDay(selectedDate, today) ||
        displayedMonth.year != today.year ||
        displayedMonth.month != today.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPickMonthYear,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Tháng ${displayedMonth.month}, ${displayedMonth.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                      color: isDark ? yColors.textPrimary : yColors.brandDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CircleNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPreviousMonth,
              ),
              const SizedBox(width: 10),
              _CircleNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextMonth,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: shouldShowTodayButton
                ? Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: _TodayButton(onTap: onGoToToday),
              ),
            )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: shouldShowTodayButton ? 16 : 22),
          _WeekLabelBar(isDark: isDark),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isExpanded
                  ? _ExpandedMonthGrid(
                key: ValueKey(
                  'month-${displayedMonth.year}-${displayedMonth.month}',
                ),
                days: days,
                today: today,
                selectedDate: selectedDate,
                displayedMonth: displayedMonth,
                dayIndicators: dayIndicators,
                onDateSelected: onDateSelected,
              )
                  : _CompactWeekRow(
                key: ValueKey(
                  'week-${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                ),
                days: days,
                today: today,
                selectedDate: selectedDate,
                displayedMonth: displayedMonth,
                dayIndicators: dayIndicators,
                onDateSelected: onDateSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  List<DateTime> _getMonthGridDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    final gridStart = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday - 1),
    );

    final gridEnd = lastDayOfMonth.add(
      Duration(days: 7 - lastDayOfMonth.weekday),
    );

    final totalDays = gridEnd.difference(gridStart).inDays + 1;

    return List.generate(
      totalDays,
          (index) => gridStart.add(Duration(days: index)),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleNavButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);

    return Material(
      color: yColors.brand,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: yColors.brand.withValues(alpha: 0.38),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TodayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? yColors.brand.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(999),
      elevation: isDark ? 0 : 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: isDark ? Colors.white70 : yColors.brand,
              ),
              const SizedBox(width: 7),
              Text(
                'Hôm nay',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : yColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekLabelBar extends StatelessWidget {
  final bool isDark;

  const _WeekLabelBar({
    required this.isDark,
  });

  static const List<String> _weekLabels = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.62),
        ),
      ),
      child: Row(
        children: _weekLabels
            .map(
              (label) => Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white54
                      : const Color(0xFF6A6D73),
                ),
              ),
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}

class _CompactWeekRow extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final Map<DateTime, CalendarDayIndicator> dayIndicators;
  final ValueChanged<DateTime> onDateSelected;

  const _CompactWeekRow({
    super.key,
    required this.days,
    required this.today,
    required this.selectedDate,
    required this.displayedMonth,
    required this.dayIndicators,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: days
          .map(
            (date) => Expanded(
          child: _DateCell(
            date: date,
            today: today,
            selectedDate: selectedDate,
            displayedMonth: displayedMonth,
            indicator: _indicatorForDate(dayIndicators, date),
            onTap: () => onDateSelected(date),
          ),
        ),
      )
          .toList(),
    );
  }
}

class _ExpandedMonthGrid extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final Map<DateTime, CalendarDayIndicator> dayIndicators;
  final ValueChanged<DateTime> onDateSelected;

  const _ExpandedMonthGrid({
    super.key,
    required this.days,
    required this.today,
    required this.selectedDate,
    required this.displayedMonth,
    required this.dayIndicators,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 44,
      ),
      itemBuilder: (context, index) {
        final date = days[index];

        return _DateCell(
          date: date,
          today: today,
          selectedDate: selectedDate,
          displayedMonth: displayedMonth,
          indicator: _indicatorForDate(dayIndicators, date),
          onTap: () => onDateSelected(date),
        );
      },
    );
  }
}

class _DateCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final CalendarDayIndicator indicator;
  final VoidCallback onTap;

  const _DateCell({
    required this.date,
    required this.today,
    required this.selectedDate,
    required this.displayedMonth,
    required this.indicator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final yColors = AppTheme.colors(context);
    final isToday = _isSameDay(date, today);
    final isSelected = _isSameDay(date, selectedDate);
    final isCurrentMonth =
        date.month == displayedMonth.month && date.year == displayedMonth.year;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = _textColor(
      yColors: yColors,
      isDark: isDark,
      isSelected: isSelected,
      isToday: isToday,
      isCurrentMonth: isCurrentMonth,
    );

    return Center(
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 38 : 36,
                  height: isSelected ? 38 : 36,
                  decoration: _cellDecoration(
                    yColors: yColors,
                    isDark: isDark,
                    isSelected: isSelected,
                    isToday: isToday,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.0,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                if (indicator != CalendarDayIndicator.none)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: _TaskIndicatorDot(
                      indicator: indicator,
                      isCurrentMonth: isCurrentMonth,
                      isSelected: isSelected,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _textColor({
    required YTaskColors yColors,
    required bool isDark,
    required bool isSelected,
    required bool isToday,
    required bool isCurrentMonth,
  }) {
    if (isSelected) return Colors.white;
    if (isToday) return yColors.brandDark;

    if (isCurrentMonth) {
      return isDark ? Colors.white70 : const Color(0xFF202124);
    }

    return isDark ? Colors.white24 : Colors.black26;
  }

  BoxDecoration? _cellDecoration({
    required YTaskColors yColors,
    required bool isDark,
    required bool isSelected,
    required bool isToday,
  }) {
    if (isSelected) {
      return BoxDecoration(
        color: yColors.brand,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: yColors.brand.withValues(alpha: isDark ? 0.22 : 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    if (isToday) {
      return BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? yColors.brand.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.48),
        border: Border.all(
          color: yColors.brand.withValues(alpha: 0.72),
          width: 1.6,
        ),
      );
    }

    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _TaskIndicatorDot extends StatelessWidget {
  final CalendarDayIndicator indicator;
  final bool isCurrentMonth;
  final bool isSelected;

  const _TaskIndicatorDot({
    required this.indicator,
    required this.isCurrentMonth,
    required this.isSelected,
  });

  static const Color _warningOrange = Color(0xFFFFA726);
  static const Color _dangerRed = Color(0xFFFF2F3D);

  @override
  Widget build(BuildContext context) {
    final color = indicator == CalendarDayIndicator.overdue
        ? _dangerRed
        : _warningOrange;
    final size = indicator == CalendarDayIndicator.overdue ? 8.0 : 6.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isCurrentMonth ? 1 : 0.42),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.92),
          width: isSelected ? 1.3 : 1,
        ),
        boxShadow: indicator == CalendarDayIndicator.overdue
            ? [
          BoxShadow(
            color: _dangerRed.withValues(alpha: 0.22),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
    );
  }
}

CalendarDayIndicator _indicatorForDate(
    Map<DateTime, CalendarDayIndicator> indicators,
    DateTime date,
    ) {
  final key = DateTime(date.year, date.month, date.day);
  return indicators[key] ?? CalendarDayIndicator.none;
}
