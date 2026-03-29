"""Pure utility class for ETH Zurich semester boundary computation.

No Firebase dependency — safe to test and use anywhere.

ETH semester schedule:
    Autumn Semester (HS): ISO calendar weeks 38–51
    Spring Semester (FS): ISO calendar weeks 8–22
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta


class EthSemesterCalendar:
    """Static methods for ETH Zurich semester boundary calculations."""

    # First ISO week of the Autumn Semester (Herbstsemester).
    _HS_START_WEEK: int = 38
    # Last ISO week of the Autumn Semester.
    _HS_END_WEEK: int = 51
    # First ISO week of the Spring Semester (Frühjahrssemester).
    _FS_START_WEEK: int = 8
    # Last ISO week of the Spring Semester.
    _FS_END_WEEK: int = 22

    @staticmethod
    def iso_week_number(dt: datetime) -> int:
        """Return the ISO week number (1–53) for the given datetime.

        Uses the ISO 8601 definition: weeks start on Monday;
        week 1 contains the first Thursday of the year.
        """
        return dt.isocalendar()[1]

    @staticmethod
    def is_in_semester(dt: datetime) -> bool:
        """Return True when the given datetime falls within an active ETH semester."""
        week = EthSemesterCalendar.iso_week_number(dt)
        return (
            EthSemesterCalendar._HS_START_WEEK <= week <= EthSemesterCalendar._HS_END_WEEK
            or EthSemesterCalendar._FS_START_WEEK <= week <= EthSemesterCalendar._FS_END_WEEK
        )

    @staticmethod
    def _monday_of_iso_week(year: int, week: int) -> datetime:
        """Return the Monday (UTC midnight) of ISO week `week` in the given `year`."""
        # Jan 4 is always in week 1 per ISO 8601
        jan4 = datetime(year, 1, 4, tzinfo=UTC)
        # Weekday: Monday = 0, Sunday = 6  (Python datetime.weekday())
        jan4_weekday = jan4.weekday()  # 0 = Monday
        week1_monday = jan4 - timedelta(days=jan4_weekday)
        return week1_monday + timedelta(weeks=week - 1)

    @staticmethod
    def current_semester_start(dt: datetime) -> datetime | None:
        """Return the start date (Monday) of the ETH semester containing `dt`.

        Returns None when `dt` is not inside any active semester.
        """
        week = EthSemesterCalendar.iso_week_number(dt)
        year = dt.year

        if EthSemesterCalendar._HS_START_WEEK <= week <= EthSemesterCalendar._HS_END_WEEK:
            return EthSemesterCalendar._monday_of_iso_week(year, EthSemesterCalendar._HS_START_WEEK)
        if EthSemesterCalendar._FS_START_WEEK <= week <= EthSemesterCalendar._FS_END_WEEK:
            return EthSemesterCalendar._monday_of_iso_week(year, EthSemesterCalendar._FS_START_WEEK)
        return None

    @staticmethod
    def next_semester_start(dt: datetime) -> datetime:
        """Return the start date (Monday) of the next ETH semester after `dt`.

        Logic:
          - If in HS (weeks 38–51) or after HS (weeks 52+): next is FS of following year
          - If in FS (weeks 8–22) or between FS end and HS start (weeks 23–37): next is HS same year
          - If in weeks 1–7 (before FS starts): next is FS this year
        """
        week = EthSemesterCalendar.iso_week_number(dt)
        year = dt.year

        # Currently in HS or after HS (weeks 38+) → next is FS in the following year
        if week >= EthSemesterCalendar._HS_START_WEEK:
            return EthSemesterCalendar._monday_of_iso_week(year + 1, EthSemesterCalendar._FS_START_WEEK)

        # Between FS end and HS start (weeks 23–37) → next is HS this year
        if week > EthSemesterCalendar._FS_END_WEEK:
            return EthSemesterCalendar._monday_of_iso_week(year, EthSemesterCalendar._HS_START_WEEK)

        # Currently in FS or before FS (weeks 1–22) → next is HS this year
        return EthSemesterCalendar._monday_of_iso_week(year, EthSemesterCalendar._HS_START_WEEK)
