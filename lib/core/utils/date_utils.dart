import 'package:intl/intl.dart';

/// Date helpers. All timestamps are stored in UTC (timestamptz) and shown in
/// the device's local time.
abstract final class AppDates {
  static final DateFormat _day = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _short = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _iso = DateFormat('yyyy-MM-dd');

  static String day(DateTime d) => _day.format(d.toLocal());
  static String short(DateTime d) => _short.format(d.toLocal());
  static String time(DateTime d) => _time.format(d.toLocal());
  static String dayTime(DateTime d) => '${day(d)} · ${time(d)}';
  static String monthYear(DateTime d) => _monthYear.format(d.toLocal());

  /// `yyyy-MM-dd` for Postgres `date` columns.
  static String isoDate(DateTime d) => _iso.format(d);

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String relative(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final today = dateOnly(now ?? DateTime.now());
    final diff = today.difference(dateOnly(local)).inDays;
    if (diff == 0) return 'Today, ${time(local)}';
    if (diff == 1) return 'Yesterday, ${time(local)}';
    if (diff > 1 && diff < 7) return '${DateFormat('EEEE').format(local)}, ${time(local)}';
    return day(local);
  }

  static String greeting({DateTime? now}) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Monday of the week containing [d].
  static DateTime startOfWeek(DateTime d) =>
      dateOnly(d).subtract(Duration(days: d.weekday - 1));
}
