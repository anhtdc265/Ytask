class TaskTimeFormatter {
  const TaskTimeFormatter._();

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String timeOnly(DateTime dateTime) {
    return '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  static String compactDate(DateTime dateTime, {int? baseYear}) {
    final year = baseYear ?? DateTime.now().year;
    if (dateTime.year == year) {
      return '${dateTime.day}/${dateTime.month}';
    }

    return '${dateTime.day}/${dateTime.month}/${_twoDigits(dateTime.year % 100)}';
  }

  /// Dùng cho ô chọn ngày giờ ở CreateTaskScreen và TimeEditDialog.
  /// Ví dụ: 12/05 • 08:00 hoặc 12/05/27 • 08:00.
  static String inputDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Chưa thiết lập';

    final day = _twoDigits(dateTime.day);
    final month = _twoDigits(dateTime.month);
    final time = timeOnly(dateTime);
    final currentYear = DateTime.now().year;
    final shortYear = _twoDigits(dateTime.year % 100);
    final date = dateTime.year == currentYear ? '$day/$month' : '$day/$month/$shortYear';

    return '$date • $time';
  }

  /// Dùng cho DetailTaskScreen.
  /// Ví dụ: 08:00, 12/5 - 10:00, 12/5 hoặc 08:00, 12/5 - 10:00, 12/5/27.
  static String detailTimeRange(DateTime? start, DateTime? end) {
    final currentYear = DateTime.now().year;

    if (start == null && end == null) {
      return 'Chưa thiết lập - Chưa thiết lập';
    }

    if (start == null) {
      return 'Chưa thiết lập - ${detailDateTime(end, baseYear: currentYear)}';
    }

    if (end == null) {
      return '${detailDateTime(start, baseYear: currentYear)} - Chưa thiết lập';
    }

    if (start.year == end.year) {
      return '${detailDateTime(start)} - ${detailDateTime(end)}';
    }

    return '${detailDateTime(start, baseYear: currentYear)} - ${detailDateTime(end, baseYear: currentYear)}';
  }

  static String detailDateTime(DateTime? dateTime, {int? baseYear}) {
    if (dateTime == null) return 'Chưa thiết lập';

    final time = timeOnly(dateTime);
    final year = baseYear ?? DateTime.now().year;
    final date = dateTime.year == year
        ? '${dateTime.day}/${dateTime.month}'
        : '${dateTime.day}/${dateTime.month}/${_twoDigits(dateTime.year % 100)}';

    return '$time, $date';
  }

  /// Dùng cho TaskScheduleCard. Dòng đầu có thể mang mốc ngày, dòng sau chỉ
  /// hiện ngày nếu khác ngày với dòng đầu. Như vậy card gọn mà vẫn đủ ngữ cảnh.
  static ({String start, String end}) scheduleRange({
    required DateTime? start,
    required DateTime? end,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    return (
      start: schedulePoint(
        start,
        now: current,
        forceDate: start != null && !isSameDay(start, current),
      ),
      end: schedulePoint(
        end,
        now: current,
        forceDate: end != null &&
            (start == null || !isSameDay(start, end)) &&
            !isSameDay(end, current),
      ),
    );
  }

  static String schedulePoint(
    DateTime? dateTime, {
    DateTime? now,
    bool forceDate = false,
  }) {
    if (dateTime == null) return '—';

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final time = timeOnly(dateTime);

    if (!forceDate || target == today) return time;

    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    if (target == yesterday) return 'Hôm qua, $time';
    if (target == tomorrow) return 'Mai, $time';

    if (dateTime.year != current.year) {
      return '${dateTime.day}/${dateTime.month}/${_twoDigits(dateTime.year % 100)}, $time';
    }

    if (dateTime.month == current.month) {
      return 'Ngày ${dateTime.day}, $time';
    }

    return '${dateTime.day}/${dateTime.month}, $time';
  }

  static String reminderOffsetLabel(int minutes) {
    switch (minutes) {
      case 0:
        return 'Đúng giờ';
      case 10:
        return 'Trước 10 phút';
      case 30:
        return 'Trước 30 phút';
      case 60:
        return 'Trước 1 giờ';
      case 1440:
        return 'Trước 1 ngày';
      default:
        if (minutes > 0 && minutes % 1440 == 0) {
          final days = minutes ~/ 1440;
          return 'Trước $days ngày';
        }

        if (minutes > 0 && minutes % 60 == 0) {
          final hours = minutes ~/ 60;
          return 'Trước $hours giờ';
        }

        return 'Trước $minutes phút';
    }
  }
}
