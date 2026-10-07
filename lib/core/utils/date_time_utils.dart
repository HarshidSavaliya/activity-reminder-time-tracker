import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// DateTimeUtils provides robust, formatted human-readable date and time representations.
class DateTimeUtils {
  DateTimeUtils._();

  static final DateFormat _dayMonthFormat = DateFormat('d MMMM');
  static final DateFormat _shortDayMonthFormat = DateFormat('d MMM');
  static final DateFormat _fullDateFormat = DateFormat('EEEE, d MMMM');
  static final DateFormat _weekdayFormat = DateFormat('EEEE');
  static final DateFormat _shortWeekdayFormat = DateFormat('EEE');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Returns contextual college greeting with emoji
  static String getGreeting({DateTime? currentTime}) {
    final hour = (currentTime ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning 👋';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon 👋';
    } else if (hour >= 17 && hour < 22) {
      return 'Good Evening 👋';
    } else {
      return 'Burning the Midnight Oil 🌙';
    }
  }

  static String formatDate(DateTime dateTime) {
    return _dayMonthFormat.format(dateTime);
  }

  static String formatShortDate(DateTime dateTime) {
    return _shortDayMonthFormat.format(dateTime);
  }

  static String formatFullDate(DateTime dateTime) {
    return _fullDateFormat.format(dateTime);
  }

  static String formatWeekday(DateTime dateTime) {
    return _weekdayFormat.format(dateTime);
  }

  static String formatShortWeekday(DateTime dateTime) {
    return _shortWeekdayFormat.format(dateTime);
  }

  static String weekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    if (weekday >= 1 && weekday <= 7) return names[weekday - 1];
    return 'Monday';
  }

  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  static String formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    return _timeFormat.format(dt);
  }

  static String formatTimeRange(DateTime start, DateTime? end) {
    final startStr = formatTime(start);
    if (end == null) return startStr;
    final endStr = formatTime(end);
    return '$startStr - $endStr';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime dateTime) {
    return isSameDay(dateTime, DateTime.now());
  }

  static bool isTomorrow(DateTime dateTime) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(dateTime, tomorrow);
  }

  static DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String toIsoDateString(DateTime date) {
    return _isoDateFormat.format(date);
  }

  static DateTime parseIsoDate(String dateStr) {
    return _isoDateFormat.parse(dateStr);
  }
}
