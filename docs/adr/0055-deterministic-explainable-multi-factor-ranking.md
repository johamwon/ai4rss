# ADR 0055: Deterministic explainable multi-factor ranking

## Status

Accepted on 2026-07-30.

## Context

RANK-001 produces a versioned local source/topic preference profile. The next
ranking stage must combine that evidence with candidate relevance, likely
completion, freshness, and controlled exploration. The same candidate set must
produce the same order on Android, iOS, Windows, unit tests, and offline replay.
Every displayed score also needs a stable factor decomposition so later
recommendation explanations cannot disagree with the actual ordering.

This stage is a scoring kernel. Source diversity, exploration quotas, topic
blocking, user-facing explanations, and time-order fallback remain RANK-003 and
RANK-004 concerns.

## Decision

`river.article-ranking/1` is a pure Dart, local-only linear model:

| Factor | Weight | Candidate/profile input |
|---|---:|---|
| semantic | 0.30 | bounded semantic similarity |
| source | 0.15 | RANK-001 source score |
| topic | 0.15 | mean RANK-001 topic affinity |
| completion | 0.20 | bounded predicted completion probability |
| freshness | 0.15 | publication-time decay |
| exploration | 0.05 | bounded caller-provided exploration probability |

All factor values are in `[0, 1]`. The final score is the exact sum of each
factor value multiplied by its configured weight. Weights must be finite,
non-negative, and sum to one.

Raw source and topic preference scores use the bounded monotonic transform:

`affinity = 0.5 + 0.5 * score / (abs(score) + 4)`

Zero or missing evidence is neutral at `0.5`. Candidate topics are trimmed,
lower-cased, sorted, and deduplicated, then averaged so adding duplicate tags
cannot amplify an article. Freshness uses a 72-hour half-life:

`freshness = 0.5 ^ (ageHours / 72)`

The ranker does not generate randomness. The caller supplies an exploration
probability, which keeps fixed-candidate replay deterministic. RANK-003 may
later allocate exploration slots around these scores.

Candidates reject empty or oversized identities, more than 16 bounded topics,
non-finite/out-of-range probabilities, future publication times, and duplicate
article IDs. The ranker rejects invalid configuration or an unsupported
preference profile version.

Results sort by descending score, then newer publication time, then ascending
article ID. Every result carries all six factor values, weights, contributions,
model version, and the same summed score used for ordering.

## Verification

- A fixed production candidate replay asserts model version, exact order,
  exact scores, all six factor values for the leading article, and explanation
  sum consistency.
- Unit tests replay reversed input, verify exact score ties use publication
  time and stable article identity, and cover the 72-hour half-life.
- A fixed-seed 1,000-candidate property test verifies score bounds, descending
  order, and input-order independence.
- Negative tests cover invalid weights, invalid probabilities, duplicate IDs,
  and future publication times.

## Rollback and evolution

The previous chronological list remains available outside this kernel. A
behavior-changing factor, transform, default weight, or tie-break rule requires
an incremented ranking model version and side-by-side replay evidence. Rollback
selects the previous model version or chronological ordering; stored RANK-001
evidence is unchanged.

## Consequences

RANK-003 can add diversity, exploration allocation, negative-feedback
constraints, and topic blocking without changing the v1 factor calculation.
RANK-004 can render explanations directly from the returned factor
contributions instead of reconstructing reasons separately.

The kernel accepts numeric semantic and completion features but does not define
their training or network transport. It reads no article body, title, URL,
note, AI output, credential, or personal identifier.
