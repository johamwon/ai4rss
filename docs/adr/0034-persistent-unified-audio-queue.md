# ADR-0034: Persistent unified audio queue

## Status

Accepted on 2026-07-28.

## Context

River already routes article TTS and Podcast media through one playback
controller, but its `AudioQueue` was an in-memory list used only by a unit
test. It could not survive process death, remember the current item, preserve
an article content revision, or drive continuous mixed-source playback.
Reusing `audio_items` would require a queued-but-never-played item to invent a
playback position and would couple queue deletion to restart progress.

## Decision

Schema v10 adds `audio_queue_entries`. Each row stores the stable River item
identity, source kind, bounded display metadata, article content revision when
applicable, dense queue position, current-item flag and timestamps. Playback
progress remains in `audio_items`; removing or clearing the queue does not
erase a restart position.

`DriftAudioQueueRepository` owns all ordering and current-item mutations in
SQLite transactions. Enqueue is idempotent by item ID. Move, select, remove
and consume reindex the queue deterministically, and removing or consuming the
current item selects the following item, or the previous item at the end.
Invalid stored kinds, URIs and article revisions are not returned to callers.

`PersistentAudioQueue` supplies injected-clock commands. The
`AudioQueuePlaybackCoordinator` resolves an entry immediately before playback,
loads it through the existing shared controller and consumes it only after a
matching final completion event. A failed resolver keeps the current row for
explicit recovery. Podcast resolution revalidates a downloaded file before
preferring it, and applies the show default rate; article resolution requires
the queued revision to match available readable content before rebuilding the
speech plan.

The Flutter app exposes a common listening queue with play, reorder, remove
and clear actions. Articles and Podcast episodes enter the same queue through
source-specific add actions.

## Migration and recovery

The v9 predecessor fixture retains populated playback, Podcast catalog and
partial-download data. The v10 migration creates the queue table only when it
is absent. An interrupted fixture where the table and a row already exist but
`user_version` is still 9 proves that retry preserves the row and advances the
schema atomically. Queue order and current selection are also reopened from a
real file database.

## Rollback

Application code can stop exposing queue entry points without modifying
existing playback or Podcast tables. A shipped v10 database must not be opened
by a v9 binary. Rollback therefore uses an exported user-data backup or a
forward-compatible build; it never rewrites `user_version` in place.

## Consequences

The queue now survives restarts and continuously mixes article and Podcast
items without conflating progress and membership. Cross-device queue sync and
platform lock-screen next/previous semantics remain separate follow-up work.
