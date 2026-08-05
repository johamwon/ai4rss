# ADR 0057: Local preference controls and recommendation explanations

## Status

Accepted for RANK-004 on 2026-08-03.

## Context

RANK-001 through RANK-003 produce versioned local preference evidence, exact
six-factor ranking explanations, and deterministic diversity guardrails. The
product still needs a user-facing way to understand and control those results.
Reconstructing recommendation copy from article content would risk disagreeing
with the score, while treating event capture and ranking as unrelated switches
could continue collecting evidence after the reader believed personalization
was disabled.

## Decision

1. `river.recommendation-explanation/1` reads the exact factor values, weights,
   contributions, score, ranking model version, guardrail model version, and
   exploration selection kind already returned by RANK-002/003. It emits at
   most three stable reason kinds and prioritizes an exploration-quota reason
   when that policy changed inclusion. It does not read or regenerate article
   text, titles, URLs, notes, or AI output.
2. The existing local behavior `captureEnabled` setting is the single visible
   personalization switch. Turning it off stops new events in the repository
   and makes the article controller replace smart ordering with deterministic
   newest-first ordering immediately. Existing evidence remains local until
   the reader explicitly clears it.
3. Drift schema v16 adds four additive JSON columns to the singleton behavior
   settings row: source/topic score adjustments and blocked source/topic sets.
   Source dimensions are limited to 256, topic dimensions to 64, identifiers
   remain bounded, and each manual score adjustment is limited to `[-4, 4]`.
   JSON is sorted before persistence and invalid or future-shaped values fail
   closed.
4. Manual score adjustments are an overlay on a freshly rebuilt v1 profile;
   they never rewrite retained evidence. Explicit source blocks are applied
   before the unchanged RANK-003 guardrail and reported separately. Explicit
   topic blocks continue through the versioned guardrail input.
5. The first production article adapter uses only retained event envelopes,
   article/source IDs, timestamps, read state, and deterministic bounded
   candidate features. It has no network or content path. Invalid, future, or
   oversized input falls back to chronological ordering instead of exposing a
   partial personalized result.
6. “Clear profile” deletes retained behavior evidence and resets all manual
   controls in one database transaction, then performs the existing secure
   deletion checkpoint. It preserves the capture choice, subscriptions,
   articles, reading state, annotations, and knowledge objects.

## Verification

- Pure Dart tests prove control bounds, stable equality/export, overlay
  behavior, and exact explanation contributions.
- Drift tests cover deterministic control persistence, the v15→v16 fixture,
  and recovery after only one v16 column was added.
- A real in-memory Drift vertical test covers event→profile→ranking→explanation,
  source blocking, disabled chronological fallback, and atomic profile clear.
- Widget tests cover the accessible profile switch, source adjustment,
  disable confirmation, clear confirmation, and the “why recommended” sheet.

## Rollback and evolution

The immediate rollback is to disable personalized ordering and use newest-first
queries; retained v1 evidence remains readable. The v16 columns are additive
with empty defaults and may remain unused during rollback. Changing reason
selection semantics, control bounds, or the relationship between consent and
ranking requires a new explanation/control version and old/new replay evidence.

Future topic features must continue to exclude article bodies, titles, URLs,
notes, and AI output unless a separately reviewed privacy contract changes the
allowed evidence surface.
