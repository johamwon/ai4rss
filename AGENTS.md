# River engineering instructions

These rules apply to the entire `river/` tree.

## Before changing code

1. Read `../outputs/River-PRD.md` for product requirements.
2. Read `docs/ARCHITECTURE.md` and `docs/QUALITY_HARNESS.md`.
3. Identify the change risk using `docs/REVIEW_POLICY.md`.

## Architecture boundaries

- Keep `river_domain` pure Dart and vendor-independent.
- Add external SDKs only in adapter packages; expose stable ports to callers.
- Never read wall-clock time, random values, network or secrets through globals.
- Keep article and user content out of logs, analytics and test snapshots.
- Do not add executable remote parser rules.

## Required evidence

- A parser bug requires a minimized fixture and regression eval.
- An AI change requires replay cases plus quality/cost notes.
- A migration requires fixtures for the old schema and interrupted recovery.
- A platform-channel change requires a Dart contract test and platform integration coverage.
- A billing change requires idempotency, refund, offline and duplicate-event tests.

Run `dart run tool/ci.dart fast` before handoff. If the SDK or platform is unavailable, state exactly which checks were not run.
