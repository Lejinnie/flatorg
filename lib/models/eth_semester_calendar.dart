/// Pure utility class for computing ETH semester boundaries.
///
/// ETH semester schedule:
/// - **Autumn Semester (HS):** calendar weeks 38–51 (mid-Sep to just before Christmas)
/// - **Spring Semester (FS):** calendar weeks 8–22 (mid-Feb to late May)
///
/// Used by the token-reset Cloud Function and anywhere semester dates are needed.
/// No Firebase dependency — all computation is local.
class EthSemesterCalendar {
  EthSemesterCalendar._();

  static const int _hsStartWeek = 38;
  static const int _hsEndWeek = 51;
  static const int _fsStartWeek = 8;
  static const int _fsEndWeek = 22;

  /// Whether [date] falls within an active ETH semester.
  static bool isInSemester(DateTime date) {
    final week = _isoWeekNumber(date);
    return (week >= _hsStartWeek && week <= _hsEndWeek) ||
        (week >= _fsStartWeek && week <= _fsEndWeek);
  }

  /// Returns the start date (Monday of the first week) of the semester
  /// containing [date].
  ///
  /// If [date] is not in a semester, returns the start of the most recent
  /// past semester.
  static DateTime currentSemesterStart(DateTime date) {
    final week = _isoWeekNumber(date);
    final year = date.year;

    // In autumn semester
    if (week >= _hsStartWeek && week <= _hsEndWeek) {
      return _mondayOfIsoWeek(year, _hsStartWeek);
    }

    // In spring semester
    if (week >= _fsStartWeek && week <= _fsEndWeek) {
      return _mondayOfIsoWeek(year, _fsStartWeek);
    }

    // Between FS end and HS start (summer break, weeks 23–37)
    if (week > _fsEndWeek && week < _hsStartWeek) {
      return _mondayOfIsoWeek(year, _fsStartWeek);
    }

    // Between HS end and next FS start (winter break, weeks 52/1–7)
    // Most recent semester is the HS of the current or previous year
    if (week > _hsEndWeek) {
      return _mondayOfIsoWeek(year, _hsStartWeek);
    }

    // Weeks 1–7: HS of previous year was the most recent semester
    return _mondayOfIsoWeek(year - 1, _hsStartWeek);
  }

  /// Returns the start date of the next semester after [date].
  ///
  /// If [date] is in HS or between HS and FS, returns the next FS start.
  /// If [date] is in FS or between FS and HS, returns the next HS start.
  static DateTime nextSemesterStart(DateTime date) {
    final week = _isoWeekNumber(date);
    final year = date.year;

    // In spring semester or before spring semester starts (weeks 1–22)
    if (week <= _fsEndWeek) {
      // Next is HS of the same year
      return _mondayOfIsoWeek(year, _hsStartWeek);
    }

    // Between FS end and HS start, or in HS (weeks 23–51)
    if (week < _hsStartWeek) {
      return _mondayOfIsoWeek(year, _hsStartWeek);
    }

    // In HS or after (weeks 38+), next is FS of the following year
    return _mondayOfIsoWeek(year + 1, _fsStartWeek);
  }

  /// Computes the ISO 8601 week number for [date].
  static int _isoWeekNumber(DateTime date) {
    // ISO week date: week 1 contains the first Thursday of the year
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(jan1).inDays;
    return ((dayOfYear) / 7).floor() + 1;
  }

  /// Returns the Monday of ISO week [week] in [year].
  static DateTime _mondayOfIsoWeek(int year, int week) {
    // Jan 4 is always in ISO week 1
    final jan4 = DateTime(year, 1, 4);
    final mondayOfWeek1 =
        jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
    return mondayOfWeek1.add(Duration(days: (week - 1) * 7));
  }
}
