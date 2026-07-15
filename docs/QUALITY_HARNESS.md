# River Quality Harness

## Test lanes

| Lane | Trigger | Blocking scope |
|---|---|---|
| Fast | Every PR | format, analyze, unit/widget, fixtures, replay evals |
| Merge | Main branch | Windows integration, Android smoke, migrations, build |
| Nightly | Schedule | full corpus, live canary, AI live eval, performance |
| Release | Candidate | physical devices, N-2 upgrade, signing, rollback |

## Non-negotiable contracts

- No real network in unit or widget tests.
- Every platform-channel feature has Dart contract tests, native unit tests and one platform integration test.
- Every parser incident adds a minimized fixture.
- Every database release keeps its migration fixture forever.
- AI changes include quality, latency and cost deltas.
- Logs never contain article bodies, credentials or provider keys.

## Initial gates

| Gate | Threshold |
|---|---:|
| RSS corpus parse success | >=99% |
| WeChat extraction corpus success | >=95% |
| Unsafe HTML nodes/attributes | 0 |
| AI replay schema success | 100% |
| Required fact coverage | >=90% |
| Crash-free sessions after launch | >=99.5% |

Live canaries are advisory for PRs and blocking only after a confirmed regression. Copyrighted full pages must not be committed; use synthetic or minimized fixtures.
