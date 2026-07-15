# Review policy

| Risk | Examples | Required evidence |
|---|---|---|
| R0 | Copy, comments | Fast lane |
| R1 | UI state and layout | Widget test, accessibility check |
| R2 | Network, parser, cache | Fixture and integration test |
| R3 | Migration, crypto, billing, background audio | Two reviewers, platform test, rollback plan |

Populate `.github/CODEOWNERS` only after real GitHub users or teams exist. Parser, migration, prompt, billing and platform-channel changes must name a domain reviewer in the pull request.

## Definition of done

- Tests and fixtures cover the change.
- Telemetry excludes private content.
- Data migration and rollback are documented where applicable.
- User-visible failures have recovery paths.
- AI changes report quality, latency and cost deltas.
- Platform changes identify Android, iOS and Windows behavior.
