# Migration fixtures

Keep one sanitized, deterministic SQL database fixture for every shipped schema
version. Tests materialize these files into temporary SQLite databases:

```text
v001_populated.sql
v002_populated.sql
v003_populated.sql
v004_populated.sql
```

Never rewrite or delete a released fixture. Migration tests must cover upgrade to current, interruption recovery, idempotent retry and downgrade/export behavior where supported.

Schema v5 is exercised by migrating the immutable v4 fixture because its only
changes are additive audio playback columns. A populated v5 fixture will be
added when the next schema ships.
