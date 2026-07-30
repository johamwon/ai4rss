# ADR 0050: Versioned and idempotent reading events

## Status

Accepted for PREF-001.

## Context

The initial domain model named the seven preference signals but had no stable
wire names, schema version, event identity, validation, or persistence
contract. Enum names alone are unsafe storage values because a source rename can
silently change their representation. Retried UI actions and concurrent writes
could also count one user action multiple times and bias the future preference
profile.

The existing Drift v14 `reading_events` table already has a primary event ID and
a unique event key, so the contract can become durable without a database
migration.

## Decision

1. The wire envelope is `river.reading-event` version 1. It contains an opaque
   event ID, article ID, stable snake-case event type, UTC occurrence time, and
   a bounded progress payload. Unknown schemas, future versions, unknown event
   types, malformed identifiers, and invalid payloads fail closed.
2. Version 1 covers impression, open, active read, completion, star, save to
   knowledge, and not-interested. Active-read events require positive active
   seconds; completion requires positive progress; discrete events cannot carry
   progress fields.
3. The capture layer must supply a stable, opaque event ID. Its deterministic
   idempotency key is `river.reading-event/<version>/<eventId>` and deliberately
   excludes mutable payload and timestamps. No global clock or random source is
   read inside the contract or repository.
4. The domain repository returns `inserted` or `duplicate`. Replaying the exact
   same event is a successful no-op. Reusing an ID or idempotency key with
   different article, type, time, or progress throws an identity conflict
   instead of silently accepting corrupt evidence.
5. The Drift adapter validates before writing, checks both unique identities,
   uses an insert-or-ignore race boundary, then re-reads and classifies a
   concurrent winner. The existing primary and unique constraints are the final
   source of truth.
6. Event data remains local. The schema contains no article body, title, search
   text, note, credential, or AI output. Upload, retention, export, and
   preference-learning controls remain separate PREF-003 responsibilities.

## Evidence

- All seven event types round-trip through the v1 envelope with explicit wire
  names.
- Future versions and unknown types are rejected.
- Event-specific progress validation rejects inactive reads, zero-progress
  completion, and progress attached to a discrete click event.
- Sequential replay and four concurrent replays produce one database row.
- A same-ID, different-type replay raises an identity conflict and preserves the
  original row.

## Consequences and rollback

PREF-002 can focus on the foreground, activity-duration, and scroll-depth state
machine while emitting this stable contract. PREF-003 can add retention,
privacy settings, clearing, and export without redefining event identity.

No schema migration or remote protocol was added. A feature rollback can stop
new capture and leave existing rows untouched; the v1 decoder remains available
for previously recorded events. Changing a wire name or payload meaning
requires a new schema version rather than editing version 1.
