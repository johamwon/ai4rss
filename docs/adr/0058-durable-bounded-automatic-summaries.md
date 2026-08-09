# ADR 0058: Durable and bounded automatic summaries

## Status

Accepted for RANK-005 on 2026-08-05.

## Context

River already generates validated manual summaries through the versioned
`article-summary@1` prompt and a content-addressed cache. Automatically calling
that path for every unread article would create uncontrolled provider cost,
send low-value content, and make transient network or process failure hard to
recover. Automatic work must also respect the local ranking and privacy choices
introduced by RANK-001 through RANK-004.

## Decision

1. Automatic summaries are disabled by default. The default policy requires
   Wi-Fi, permits three usable results per device-local calendar day, and only
   accepts unread personalized candidates with an exact RANK-002 score of at
   least `0.70`. The daily limit is user-selectable and bounded to `1..50`.
2. The scheduler consumes the already guarded RANK-004 snapshot. It never
   reconstructs a preference score and never schedules chronological,
   non-personalized, blocked, low-score, or already-read candidates.
3. Drift schema v17 adds a singleton automatic-summary policy table and a usage
   ledger. A transaction reserves a daily slot before a provider call. Reserved
   and completed slots both count against concurrent capacity; retryable or
   unusable results release the reservation, while a validated and durably
   cached result completes it idempotently. An unfinished reservation recovered
   after local midnight moves atomically into the current day's capacity; if
   that day is already full, the task remains deferred without bypassing quota.
4. `automatic-summary/v1` uses the existing persistent job queue and leases.
   Jobs store only the schema version, article ID, optional content hash,
   ranking score, and ranking model version. Article title, URL, body, notes,
   behavior events, provider keys, and AI output are excluded from payloads and
   error codes.
5. A pre-existing valid cache entry completes without using daily quota. When
   full text is not yet cached, the job invokes the existing bounded layered
   extractor after the network policy passes. The existing `SummaryService`
   then enforces the same content hash, prompt version, model, language, schema,
   repair, request coalescing, and cache behavior as manual summaries.
6. Wi-Fi-only jobs treat offline, unknown, Ethernet, and mobile hints as
   ineligible and defer without consuming provider attempts. A Wi-Fi transition
   expedites them. If Wi-Fi-only is disabled, unknown transport may be tried,
   while an explicit offline state still waits.
7. Feed background refresh runs a best-effort personalized scheduling follow-up
   and resumes durable automatic-summary work. Failure in this follow-up never
   changes the feed refresh result. Foreground smart-list updates use the same
   scheduler.
8. Turning automation off cancels queued/running queue records and prevents new
   work. A provider request already accepted by a remote service cannot be
   recalled by a local setting change; its validated cache write may finish,
   but no subsequent automatic task is started. Manual summaries remain
   independent.

## Verification

- Domain tests cover default-off and policy bounds.
- Drift tests cover settings persistence, concurrent atomic reservations,
  release-on-failure, idempotent completion, cross-day reservation recovery,
  v16→v17 migration, and recovery after only the policy table was created.
- Platform tests distinguish Wi-Fi, other, offline, and unknown transports and
  stream policy changes.
- Application tests cover high-score selection, daily limits, Wi-Fi deferral,
  retry without quota loss, cache hits, full-text extraction, interrupted
  reservation recovery, cancellation, and background-refresh follow-up.
- Widget tests cover explicit AI-content disclosure, accessible enablement,
  and daily-limit editing.

## Quality, latency, and cost delta

RANK-005 does not change the prompt, model route, output schema, or repair
policy, so the static summary quality delta is zero and existing AI replay
thresholds remain unchanged. A cache hit adds no provider latency or cost. A
cache miss adds the existing extraction and summary latency, bounded by the
user's daily cap; failed or non-durable output does not consume that cap. Live
provider latency and monetary cost remain Nightly measurements.

## Rollback

Disable the automatic-summary policy and cancel `automatic-summary/v1` jobs.
The additive v17 tables may remain unused, existing validated summary cache
entries remain readable, and manual summary behavior is unchanged. Any future
change to eligibility, quota accounting, payload fields, or daily-boundary
semantics requires a new job/policy version and migration evidence.
