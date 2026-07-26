# ADR-0031: Podcast catalog schema v8

## Decision

Database schema v8 adds three local-first tables:

- `podcast_shows` stores feed metadata, validators and user-owned default speed
  and download policy;
- `podcast_episodes` stores stable external identity and current playable media
  metadata;
- `podcast_downloads` stores durable transfer state separately from feed
  metadata and playback progress.

`DriftPodcastRepository` applies show metadata and changed episode upserts in
one transaction. Every episode must belong to the refreshed show. Feed refresh
does not delete omitted episodes and does not reset show policy: the refresh
service reads the existing policy into the new show record before writing it.
The `(show_id, external_id)` unique key is the persistent form of POD-001's
GUID-first identity decision.

Download state is separated so a changed enclosure URL cannot silently mark a
partial or verified file as current. POD-002's transfer coordinator will own
state transitions in that table; the playback repository continues to own
media position and speed snapshots.

## Migration and recovery

The v8 migration creates each table only when missing and orders show, episode
and download creation by foreign-key dependency. This makes recovery
idempotent if the process stops after only the show table is created.

Existing v1–v4 fixtures remain permanent old-schema inputs and now migrate
through v8. A targeted interruption test opens a full database, removes the
dependent podcast tables, resets `user_version` to 7, and verifies that reopen
recreates all three tables without affecting prior data.

## Verification and rollback

Repository tests cover policy preservation, changed media metadata retaining
the River episode ID, and transaction rollback for a cross-show episode.
Migration tests cover every retained fixture and partial v8 recovery.

Rollback code may stop composing the Podcast repository, but a shipped v8
database must not be downgraded in place. The release rollback must use an
older application build that tolerates a newer database only after explicit
compatibility validation, or restore a pre-upgrade backup.
