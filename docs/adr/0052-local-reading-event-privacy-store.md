# ADR 0052: Local reading-event privacy store

## Status

Accepted for PREF-003.

## Context

PREF-001 established event identity and PREF-002 established attention
measurement, but neither made the user's capture choice durable or supplied
retention, inspection, export, and deletion controls. A process-only switch
would silently reset after restart. Logical SQLite deletion alone can also
leave removed bytes in free pages or the write-ahead log.

The product requirement is local-first: raw behavior events stay on the device
by default, disabling learning stops new evidence, and users can remove or
export their data independently of account or cloud availability.

## Decision

1. Drift schema v15 adds one additive singleton
   `reading_behavior_settings_rows` table. Capture defaults to enabled and
   retention defaults to 90 days; supported retention is 1–3650 days. No row is
   required for defaults, and an explicit disabled value persists across
   restart.
2. `ReadingBehaviorRepository` extends the event recorder with settings watch,
   read and save, ordered local event read, retention purge, complete clear, and
   JSON export. It exposes no network or upload method.
3. `record` validates the event and reads the capture setting in the same
   database transaction as identity checks and insertion. When disabled it
   returns `captureDisabled` and writes no row. Once the settings save
   completes, later record calls cannot bypass the gate.
4. Retention deletes events strictly older than `now - retentionDays`, keeping
   an event on the exact boundary. Full clear deletes all event rows but does
   not change the user's settings.
5. Every database connection enables SQLite `secure_delete`. After retention or
   complete deletion, the adapter checkpoints and truncates the WAL so deleted
   event identities do not remain in the database files.
6. `river.reading-event-export` v1 contains export time, capture/retention
   settings, and occurrence-time/ID ordered PREF-001 envelopes. It never joins
   articles, so titles, URLs, bodies, notes, credentials, and AI output cannot
   enter the export.
7. The v14 migration fixture is immutable. Tests cover normal v14→v15 upgrade
   and recovery when table creation completed but the schema version did not
   advance, preserving a disabled preference.

## Evidence

- Defaults are enabled/90 days and a saved disabled/30-day preference is
  observable and blocks new rows.
- Retention removes a 91-day-old event while preserving the exact 90-day
  boundary and a recent event.
- Export sorts out-of-order inserts and contains no seeded article title or
  URL.
- A file-backed test confirms `secure_delete = 1`, clears the event, truncates
  the WAL, and no longer finds the private event identity in database files.
- All predecessor migration fixtures reach v15; interrupted v15 recovery
  preserves the disabled setting.

## Consequences and rollback

PREF-004 can expose the already durable controls and explain them before capture
is first enabled in the UI. Existing events are not automatically deleted when
capture is disabled; users choose clear independently, and retention still
applies.

The v15 table is additive and may remain unused during a feature rollback.
However, a binary rollback to code that does not read the v15 capture gate could
violate a persisted opt-out. Rollback builds must therefore retain the
repository gate or globally disable new capture; they must not simply resume the
pre-v15 recorder.
