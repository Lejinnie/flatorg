/// Pure utility class for ETH Zurich semester boundary computation.
/// No Firebase dependency — safe to test and use anywhere in the app.
///
/// ETH semester schedule:
///   Autumn Semester (HS): ISO calendar weeks 38–51
///   Spring Semester (FS): ISO calendar weeks 8–22
class EthSemesterCalendar {
  /// First ISO week of the Autumn Semester (Herbstsemester).
  static const int _hsStartWeek = 38;

  /// Last ISO week of the Autumn Semester.
  static const int _hsEndWeek = 51;

  /// First ISO week of the Spring Semester (Frühjahrssemester).
  static const int _fsStartWeek = 8;

  /// Last ISO week of the Spring Semester.
  static const int _fsEndWeek = 22;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns true when [date] falls within an active ETH semester.
  static bool isInSemester(DateTime date) {
    final week = isoWeekNumber(date);
    return (week >= _hsStartWeek && week <= _hsEndWeek) ||
        (week >= _fsStartWeek && week <= _fsEndWeek);
  }

  /// Returns the start date (Monday) of the ETH semester containing [date].
  /// Returns null when [date] is not in any semester.
  static DateTime? currentSemesterStart(DateTime date) {
    final week = isoWeekNumber(date);
    final year = date.year;
    if (week >= _hsStartWeek && week <= _hsEndWeek) {
      return _mondayOfIsoWeek(year, _hsStartWeek);
    }
    if (week >= _fsStartWeek && week <= _fsEndWeek) {
      return _mondayOfIsoWeek(year, _fsStartWeek);
    }
    return null;
  }

  /// Returns the start date (Monday) of the next ETH semester after [date].
  static DateTime nextSemesterStart(DateTime date) {
    final week = isoWeekNumber(date);
    final year = date.year;

    // Currently in HS or after HS → next is FS in the following year
    if (week >= _hsStartWeek) {
      return _mondayOfIsoWeek(year + 1, _fsStartWeek);
    }

    // Between FS end and HS start → next is HS this year
    if (week > _fsEndWeek) {
      return _mondayOfIsoWeek(year, _hsStartWeek);
    }

    // In FS or before FS → next is HS this year
    return _mondayOfIsoWeek(year, _hsStartWeek);
  }

  /// Returns the ISO week number (1–53) for [date].
  /// Uses the ISO 8601 definition: weeks start on Monday;
  /// week 1 contains the first Thursday of the year.
  static int isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    // Shift to nearest Thursday (ISO week is defined by Thursday)
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    return ((thursday.difference(yearStart).inDays) ~/ 7) + 1;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Returns the Monday of ISO week [week] in [year].
  static DateTime _mondayOfIsoWeek(int year, int week) {
    // Jan 4 is always in ISO week 1
    final jan4 = DateTime.utc(year, 1, 4);
    final jan4Weekday = jan4.weekday; // 1=Mon … 7=Sun
    final week1Monday = jan4.subtract(Duration(days: jan4Weekday - 1));
    return week1Monday.add(Duration(days: (week - 1) * 7));
  }
}
