/**
 * Pure utility class for ETH Zurich semester boundary computation.
 * No Firebase dependency — safe to test and use anywhere.
 *
 * ETH semester schedule:
 *   Autumn Semester (HS): ISO calendar weeks 38–51
 *   Spring Semester (FS): ISO calendar weeks 8–22
 */
export class EthSemesterCalendar {
  /** First ISO week of the Autumn Semester (Herbstsemester). */
  private static readonly HS_START_WEEK = 38;
  /** Last ISO week of the Autumn Semester. */
  private static readonly HS_END_WEEK = 51;
  /** First ISO week of the Spring Semester (Frühjahrssemester). */
  private static readonly FS_START_WEEK = 8;
  /** Last ISO week of the Spring Semester. */
  private static readonly FS_END_WEEK = 22;

  /**
   * Returns the ISO week number (1–53) for the given date.
   * Uses the ISO 8601 definition: weeks start on Monday; week 1 contains the first Thursday.
   */
  static isoWeekNumber(date: Date): number {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    // Set to nearest Thursday: current date + 4 - current day (Monday=1)
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  }

  /**
   * Returns true when the given date falls within an active ETH semester
   * (either Autumn or Spring).
   */
  static isInSemester(date: Date): boolean {
    const week = EthSemesterCalendar.isoWeekNumber(date);
    return (
      (week >= EthSemesterCalendar.HS_START_WEEK && week <= EthSemesterCalendar.HS_END_WEEK) ||
      (week >= EthSemesterCalendar.FS_START_WEEK && week <= EthSemesterCalendar.FS_END_WEEK)
    );
  }

  /**
   * Returns the Monday of ISO week `week` in the given `year`.
   */
  private static mondayOfIsoWeek(year: number, week: number): Date {
    // Jan 4 is always in week 1 per ISO 8601
    const jan4 = new Date(Date.UTC(year, 0, 4));
    const jan4DayOfWeek = jan4.getUTCDay() || 7; // 1=Mon … 7=Sun
    const week1Monday = new Date(jan4);
    week1Monday.setUTCDate(jan4.getUTCDate() - (jan4DayOfWeek - 1));
    const targetMonday = new Date(week1Monday);
    targetMonday.setUTCDate(week1Monday.getUTCDate() + (week - 1) * 7);
    return targetMonday;
  }

  /**
   * Returns the start date (Monday) of the ETH semester that contains `date`.
   * Returns null when `date` is not in any semester.
   */
  static currentSemesterStart(date: Date): Date | null {
    const week = EthSemesterCalendar.isoWeekNumber(date);
    const year = date.getFullYear();

    if (week >= EthSemesterCalendar.HS_START_WEEK && week <= EthSemesterCalendar.HS_END_WEEK) {
      return EthSemesterCalendar.mondayOfIsoWeek(year, EthSemesterCalendar.HS_START_WEEK);
    }
    if (week >= EthSemesterCalendar.FS_START_WEEK && week <= EthSemesterCalendar.FS_END_WEEK) {
      return EthSemesterCalendar.mondayOfIsoWeek(year, EthSemesterCalendar.FS_START_WEEK);
    }
    return null;
  }

  /**
   * Returns the start date (Monday) of the next ETH semester after `date`.
   *
   * Logic:
   *   - If currently in HS (weeks 38–51) or between semesters after HS (weeks 52+): next is FS next year
   *   - If currently in FS (weeks 8–22) or between semesters before HS (weeks 23–37): next is HS same year
   *   - If in weeks 1–7 (before FS starts): next is FS this year
   */
  static nextSemesterStart(date: Date): Date {
    const week = EthSemesterCalendar.isoWeekNumber(date);
    const year = date.getFullYear();

    // Currently in HS or after HS (weeks 38+) → next is FS in the following year
    if (week >= EthSemesterCalendar.HS_START_WEEK) {
      return EthSemesterCalendar.mondayOfIsoWeek(year + 1, EthSemesterCalendar.FS_START_WEEK);
    }

    // Between FS end and HS start (weeks 23–37) → next is HS this year
    if (week > EthSemesterCalendar.FS_END_WEEK) {
      return EthSemesterCalendar.mondayOfIsoWeek(year, EthSemesterCalendar.HS_START_WEEK);
    }

    // Currently in FS or before FS (weeks 1–22) → next is HS this year
    return EthSemesterCalendar.mondayOfIsoWeek(year, EthSemesterCalendar.HS_START_WEEK);
  }
}
