# Migration fixtures

Keep one sanitized, deterministic SQL database fixture for every shipped schema
version. Tests materialize these files into temporary SQLite databases:

```text
v001_populated.sql
v002_populated.sql
v003_populated.sql
```

Never rewrite or delete a released fixture. Migration tests must cover upgrade to current, interruption recovery, idempotent retry and downgrade/export behavior where supported.
