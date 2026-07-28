# Migration fixtures

Keep one sanitized, deterministic SQL database fixture for every shipped schema
version. Tests materialize these files into temporary SQLite databases:

```text
v001_populated.sql
v002_populated.sql
v003_populated.sql
v004_populated.sql
v009_audio_state.sql
```

Never rewrite or delete a released fixture. Migration tests must cover upgrade to current, interruption recovery, idempotent retry and downgrade/export behavior where supported.

Schemas v5 through v8 are exercised by migrating the immutable v4 fixture and
by interrupted additive/table-creation cases. `v009_audio_state.sql` is the
immutable predecessor fixture for the v10 persistent unified audio queue and
retains populated playback, Podcast catalog and resumable-download state.
