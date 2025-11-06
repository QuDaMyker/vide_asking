import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  // ==================== DATE FORMATS ====================
  
  /// Formats date as "Nov 4, 2025"
  String toReadableDate() {
    return DateFormat('MMM d, yyyy').format(this);
  }

  /// Formats date as "November 4, 2025"
  String toFullReadableDate() {
    return DateFormat('MMMM d, yyyy').format(this);
  }

  /// Formats date as "11/04/2025"
  String toShortDate() {
    return DateFormat('MM/dd/yyyy').format(this);
  }

  /// Formats date as "2025-11-04"
  String toIsoDate() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  /// Formats date as "04/11/2025" (European format)
  String toEuropeanDate() {
    return DateFormat('dd/MM/yyyy').format(this);
  }

  /// Formats date as "Nov 4" (no year)
  String toShortReadableDate() {
    return DateFormat('MMM d').format(this);
  }

  /// Formats date as "Monday, November 4, 2025"
  String toFullDate() {
    return DateFormat('EEEE, MMMM d, yyyy').format(this);
  }

  /// Formats date as "Mon, Nov 4, 2025"
  String toMediumDate() {
    return DateFormat('EEE, MMM d, yyyy').format(this);
  }

  // ==================== TIME FORMATS ====================

  /// Formats time as "10:30 AM"
  String toReadableTime() {
    return DateFormat('h:mm a').format(this);
  }

  /// Formats time as "10:30:45 AM"
  String toReadableTimeWithSeconds() {
    return DateFormat('h:mm:ss a').format(this);
  }

  /// Formats time as "22:30" (24-hour format)
  String to24HourTime() {
    return DateFormat('HH:mm').format(this);
  }

  /// Formats time as "22:30:45" (24-hour format with seconds)
  String to24HourTimeWithSeconds() {
    return DateFormat('HH:mm:ss').format(this);
  }

  // ==================== DATE & TIME FORMATS ====================

  /// Formats as "Nov 4, 2025 10:30 AM"
  String toReadableDateTime() {
    return DateFormat('MMM d, yyyy h:mm a').format(this);
  }

  /// Formats as "November 4, 2025 10:30 AM"
  String toFullReadableDateTime() {
    return DateFormat('MMMM d, yyyy h:mm a').format(this);
  }

  /// Formats as "11/04/2025 10:30 AM"
  String toShortDateTime() {
    return DateFormat('MM/dd/yyyy h:mm a').format(this);
  }

  /// Formats as "2025-11-04 22:30:45"
  String toIsoDateTime() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(this);
  }

  /// Formats as "Monday, Nov 4, 10:30 AM"
  String toMediumDateTime() {
    return DateFormat('EEEE, MMM d, h:mm a').format(this);
  }

  /// Formats as "04/11/2025 22:30" (European format with 24h time)
  String toEuropeanDateTime() {
    return DateFormat('dd/MM/yyyy HH:mm').format(this);
  }

  // ==================== RELATIVE TIME FORMATS ====================

  /// Returns relative time like "Today", "Yesterday", or formatted date
  String toRelativeDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(year, month, day);
    final difference = today.difference(dateToCheck).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else if (difference > 1 && difference < 7) {
      return '$difference days ago';
    } else if (difference < -1 && difference > -7) {
      return 'In ${-difference} days';
    } else {
      return toReadableDate();
    }
  }

  /// Returns relative time like "Just now", "5 minutes ago", "2 hours ago"
  String toRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Returns combined relative date and time like "Today at 10:30 AM" or "Yesterday at 3:45 PM"
  String toRelativeDateTime() {
    final relativeDate = toRelativeDate();
    if (relativeDate == 'Today' || relativeDate == 'Yesterday' || relativeDate == 'Tomorrow') {
      return '$relativeDate at ${toReadableTime()}';
    }
    return toReadableDateTime();
  }

  // ==================== DAY & MONTH ONLY ====================

  /// Formats as "Monday"
  String toDayName() {
    return DateFormat('EEEE').format(this);
  }

  /// Formats as "Mon"
  String toShortDayName() {
    return DateFormat('EEE').format(this);
  }

  /// Formats as "November"
  String toMonthName() {
    return DateFormat('MMMM').format(this);
  }

  /// Formats as "Nov"
  String toShortMonthName() {
    return DateFormat('MMM').format(this);
  }

  /// Formats as "November 2025"
  String toMonthYear() {
    return DateFormat('MMMM yyyy').format(this);
  }

  /// Formats as "Nov 2025"
  String toShortMonthYear() {
    return DateFormat('MMM yyyy').format(this);
  }

  // ==================== SPECIAL FORMATS ====================

  /// Formats as "Q4 2025" (quarter and year)
  String toQuarterYear() {
    final quarter = ((month - 1) ~/ 3) + 1;
    return 'Q$quarter $year';
  }

  /// Formats as "Week 45, 2025"
  String toWeekYear() {
    final weekNumber = ((dayOfYear - weekday + 10) / 7).floor();
    return 'Week $weekNumber, $year';
  }

  /// Returns day of year (1-365/366)
  int get dayOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    return difference(firstDayOfYear).inDays + 1;
  }

  /// Formats as "2025-11-04T22:30:45.000Z" (ISO 8601)
  String toIso8601String() {
    return toIso8601String();
  }

  /// Formats with custom pattern
  String toCustomFormat(String pattern) {
    return DateFormat(pattern).format(this);
  }

  // ==================== UTILITY METHODS ====================

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// Check if date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  /// Check if date is in current week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return isAfter(startOfWeek) && isBefore(endOfWeek);
  }

  /// Check if date is in current month
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Check if date is in current year
  bool get isThisYear {
    return year == DateTime.now().year;
  }
}
