import { EthSemesterCalendar } from '../src/services/ethSemesterCalendar';

// ── ISO week number ────────────────────────────────────────────────────────────

describe('EthSemesterCalendar.isoWeekNumber', () => {
  it('returns week 1 for Jan 4 (always in week 1 per ISO 8601)', () => {
    expect(EthSemesterCalendar.isoWeekNumber(new Date('2024-01-04'))).toBe(1);
  });

  it('returns week 38 for the known HS start date in 2024 (Sep 16)', () => {
    expect(EthSemesterCalendar.isoWeekNumber(new Date('2024-09-16'))).toBe(38);
  });

  it('returns week 8 for the known FS start date in 2025 (Feb 17)', () => {
    expect(EthSemesterCalendar.isoWeekNumber(new Date('2025-02-17'))).toBe(8);
  });
});

// ── isInSemester ──────────────────────────────────────────────────────────────

describe('EthSemesterCalendar.isInSemester', () => {
  it('returns true during Autumn Semester (week 38)', () => {
    // Sep 16 2024 is in week 38
    expect(EthSemesterCalendar.isInSemester(new Date('2024-09-16'))).toBe(true);
  });

  it('returns true during Autumn Semester (week 51)', () => {
    // Dec 16 2024 is in week 51
    expect(EthSemesterCalendar.isInSemester(new Date('2024-12-16'))).toBe(true);
  });

  it('returns true during Spring Semester (week 8)', () => {
    expect(EthSemesterCalendar.isInSemester(new Date('2025-02-17'))).toBe(true);
  });

  it('returns true during Spring Semester (week 22)', () => {
    // May 26 2025 is in week 22
    expect(EthSemesterCalendar.isInSemester(new Date('2025-05-26'))).toBe(true);
  });

  it('returns false between semesters (week 1 — Christmas break)', () => {
    // Jan 6 2025 is in week 2
    expect(EthSemesterCalendar.isInSemester(new Date('2025-01-06'))).toBe(false);
  });

  it('returns false between FS end and HS start (week 30)', () => {
    // July 21 2025 is in week 30
    expect(EthSemesterCalendar.isInSemester(new Date('2025-07-21'))).toBe(false);
  });
});

// ── currentSemesterStart ──────────────────────────────────────────────────────

describe('EthSemesterCalendar.currentSemesterStart', () => {
  it('returns the Monday of week 38 when inside HS', () => {
    const result = EthSemesterCalendar.currentSemesterStart(new Date('2024-10-01'));
    expect(result).not.toBeNull();
    expect(result!.getUTCDay()).toBe(1); // Monday
    expect(EthSemesterCalendar.isoWeekNumber(result!)).toBe(38);
  });

  it('returns the Monday of week 8 when inside FS', () => {
    const result = EthSemesterCalendar.currentSemesterStart(new Date('2025-03-01'));
    expect(result).not.toBeNull();
    expect(result!.getUTCDay()).toBe(1);
    expect(EthSemesterCalendar.isoWeekNumber(result!)).toBe(8);
  });

  it('returns null when not in any semester (summer break)', () => {
    expect(EthSemesterCalendar.currentSemesterStart(new Date('2025-07-15'))).toBeNull();
  });
});

// ── nextSemesterStart ─────────────────────────────────────────────────────────

describe('EthSemesterCalendar.nextSemesterStart', () => {
  it('returns the HS start (week 38) when currently before HS in the same year', () => {
    // July 2025 — between FS end (week 22) and HS start (week 38)
    const result = EthSemesterCalendar.nextSemesterStart(new Date('2025-07-15'));
    expect(EthSemesterCalendar.isoWeekNumber(result)).toBe(38);
    expect(result.getUTCFullYear()).toBe(2025);
  });

  it('returns the FS start of the following year when currently in HS', () => {
    // Oct 2025 — inside HS
    const result = EthSemesterCalendar.nextSemesterStart(new Date('2025-10-01'));
    expect(EthSemesterCalendar.isoWeekNumber(result)).toBe(8);
    expect(result.getUTCFullYear()).toBe(2026);
  });

  it('returns HS start of same year when currently in FS', () => {
    // March 2025 — inside FS
    const result = EthSemesterCalendar.nextSemesterStart(new Date('2025-03-15'));
    expect(EthSemesterCalendar.isoWeekNumber(result)).toBe(38);
    expect(result.getUTCFullYear()).toBe(2025);
  });
});
