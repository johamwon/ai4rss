# ADR 0059: Local ranking control experiment and aggregate metrics

## Status

Accepted for RANK-006 on 2026-08-06.

## Context

River has a deterministic personalized ranker, diversity guardrails and bounded
automatic summaries, but offline replay alone cannot establish whether the
experience improves real reading. Remote analytics would create an unnecessary
content and behavior privacy boundary. Comparing only personalized sessions
against their own history would also confound feed mix, user maturity and time.

## Decision

1. The experiment is disabled by default and requires explicit local opt-in.
   Enrollment uses a stable device-local entropy and experiment version to
   assign either chronological control or personalized treatment. Reopening the
   app cannot change the arm for the same experiment.
2. Only the smart article list is controlled. The control arm receives the
   existing newest-first result; treatment receives the existing RANK-002/003
   result. Background refresh is excluded from exposure counts. Disabling the
   experiment immediately restores the pre-experiment behavior and retains
   aggregate history until the user explicitly clears it.
3. The primary KPI is effective completion after an article open. Guardrails
   are under-ten-second quick exit and normalized source diversity. AI
   diagnostics are automatic-summary eligibility, validated cache hit,
   successful generation, failure, provider calls, perceived generation
   latency and exact cost persisted in the validated artifact.
4. Drift v18 stores one enrollment row and daily arm-level aggregates. It never
   stores article/source IDs, title, URL, body, note, prompt, provider output or
   a per-event experiment trail. The product has no automatic upload path.
   Export is aggregate-only and fails closed before the minimum sample.
5. The default minimum is 100 opens and 20 visible list exposures per arm.
   River ships the treatment only when the completion-rate lift lower 95%
   confidence bound is above zero, quick-exit delta upper bound is at most
   `+0.02`, and source-diversity delta lower bound is at least `-0.05`.
   Otherwise the result is `hold`; an undersized sample is
   `insufficientData`, not a product conclusion.
6. All timestamps and elapsed clocks are injectable. Experiment writes are
   best-effort observability and may never block article lists, reading,
   extraction, summaries, or durable job outcomes.

## Verification

- Domain tests reject invalid identities, local timestamps, inconsistent
  outcomes and unbounded observations.
- Assignment, diversity, confidence intervals, sample gates and export privacy
  have deterministic unit and Harness replay coverage.
- Drift tests cover stable enrollment, wrong-arm/disabled write rejection,
  concurrent exact aggregation, explicit timestamps, clear, v17→v18 migration
  and interrupted table creation.
- Application tests cover control ordering, foreground exposure, background
  exclusion, real reading-session outcomes, automatic-summary accounting and
  explicit local-only consent UI.

## Rollback

Disable or remove the enrollment row. Smart lists then use the exact
pre-experiment behavior and no new experiment aggregates are written. The
additive v18 tables can remain unread, and users can independently clear their
metrics. Changing assignment, KPI definitions, privacy fields or decision
thresholds requires a new experiment version and side-by-side replay evidence.
