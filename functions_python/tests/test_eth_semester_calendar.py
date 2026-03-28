"""BDD tests for EthSemesterCalendar.

Mirrors functions/tests/ethSemesterCalendar.test.ts exactly.
"""

from __future__ import annotations

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime, timezone

from services.eth_semester_calendar import EthSemesterCalendar


# ── ISO week number ────────────────────────────────────────────────────────────

class TestIsoWeekNumber:
    def test_returns_week_1_for_jan_4(self):
        """Jan 4 is always in week 1 per ISO 8601."""
        assert EthSemesterCalendar.iso_week_number(datetime(2024, 1, 4, tzinfo=timezone.utc)) == 1

    def test_returns_week_38_for_hs_start_2024(self):
        """Returns week 38 for the known HS start date in 2024 (Sep 16)."""
        assert EthSemesterCalendar.iso_week_number(datetime(2024, 9, 16, tzinfo=timezone.utc)) == 38

    def test_returns_week_8_for_fs_start_2025(self):
        """Returns week 8 for the known FS start date in 2025 (Feb 17)."""
        assert EthSemesterCalendar.iso_week_number(datetime(2025, 2, 17, tzinfo=timezone.utc)) == 8


# ── isInSemester ──────────────────────────────────────────────────────────────

class TestIsInSemester:
    def test_returns_true_during_hs_week_38(self):
        """Returns true during Autumn Semester (week 38)."""
        assert EthSemesterCalendar.is_in_semester(datetime(2024, 9, 16, tzinfo=timezone.utc)) is True

    def test_returns_true_during_hs_week_51(self):
        """Returns true during Autumn Semester (week 51)."""
        assert EthSemesterCalendar.is_in_semester(datetime(2024, 12, 16, tzinfo=timezone.utc)) is True

    def test_returns_true_during_fs_week_8(self):
        """Returns true during Spring Semester (week 8)."""
        assert EthSemesterCalendar.is_in_semester(datetime(2025, 2, 17, tzinfo=timezone.utc)) is True

    def test_returns_true_during_fs_week_22(self):
        """Returns true during Spring Semester (week 22). May 26 2025 is in week 22."""
        assert EthSemesterCalendar.is_in_semester(datetime(2025, 5, 26, tzinfo=timezone.utc)) is True

    def test_returns_false_between_semesters_christmas_break(self):
        """Returns false between semesters (week 2 — Christmas break)."""
        assert EthSemesterCalendar.is_in_semester(datetime(2025, 1, 6, tzinfo=timezone.utc)) is False

    def test_returns_false_between_fs_end_and_hs_start(self):
        """Returns false between FS end and HS start (week 30). July 21 2025."""
        assert EthSemesterCalendar.is_in_semester(datetime(2025, 7, 21, tzinfo=timezone.utc)) is False


# ── currentSemesterStart ──────────────────────────────────────────────────────

class TestCurrentSemesterStart:
    def test_returns_monday_of_week_38_when_inside_hs(self):
        """Returns the Monday of week 38 when inside HS."""
        result = EthSemesterCalendar.current_semester_start(datetime(2024, 10, 1, tzinfo=timezone.utc))
        assert result is not None
        assert result.weekday() == 0  # Monday
        assert EthSemesterCalendar.iso_week_number(result) == 38

    def test_returns_monday_of_week_8_when_inside_fs(self):
        """Returns the Monday of week 8 when inside FS."""
        result = EthSemesterCalendar.current_semester_start(datetime(2025, 3, 1, tzinfo=timezone.utc))
        assert result is not None
        assert result.weekday() == 0  # Monday
        assert EthSemesterCalendar.iso_week_number(result) == 8

    def test_returns_none_when_not_in_any_semester(self):
        """Returns None when not in any semester (summer break)."""
        assert EthSemesterCalendar.current_semester_start(datetime(2025, 7, 15, tzinfo=timezone.utc)) is None


# ── nextSemesterStart ─────────────────────────────────────────────────────────

class TestNextSemesterStart:
    def test_returns_hs_start_week_38_when_before_hs_same_year(self):
        """Returns the HS start (week 38) when currently before HS in the same year."""
        # July 2025 — between FS end (week 22) and HS start (week 38)
        result = EthSemesterCalendar.next_semester_start(datetime(2025, 7, 15, tzinfo=timezone.utc))
        assert EthSemesterCalendar.iso_week_number(result) == 38
        assert result.year == 2025

    def test_returns_fs_start_following_year_when_currently_in_hs(self):
        """Returns the FS start of the following year when currently in HS."""
        # Oct 2025 — inside HS
        result = EthSemesterCalendar.next_semester_start(datetime(2025, 10, 1, tzinfo=timezone.utc))
        assert EthSemesterCalendar.iso_week_number(result) == 8
        assert result.year == 2026

    def test_returns_hs_start_same_year_when_currently_in_fs(self):
        """Returns HS start of same year when currently in FS."""
        # March 2025 — inside FS
        result = EthSemesterCalendar.next_semester_start(datetime(2025, 3, 15, tzinfo=timezone.utc))
        assert EthSemesterCalendar.iso_week_number(result) == 38
        assert result.year == 2025
