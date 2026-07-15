# Migration fixtures

When persistence is introduced, keep one sanitized database fixture for every shipped schema version:

```text
v001_empty.db
v001_populated.db
v002_interrupted_job.db
```

Never rewrite or delete a released fixture. Migration tests must cover upgrade to current, interruption recovery, idempotent retry and downgrade/export behavior where supported.
