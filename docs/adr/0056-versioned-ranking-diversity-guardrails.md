# ADR 0056: Versioned ranking diversity guardrails

## Status

Accepted on 2026-07-30.

## Context

A linear relevance score can concentrate a feed around one source, repeat a
narrow topic, or suppress all exploration. Strong negative feedback and an
explicit topic block also need predictable effects that cannot be outweighed by
semantic relevance. These rules must be deterministic, locally enforceable,
bounded against hostile input, and separately observable from the RANK-002
score.

## Decision

`river.ranking-guardrails/1` applies the following stages to RANK-002 results:

1. Normalize at most 64 explicit blocked topics and remove candidates matching
   any of them.
2. Remove candidates whose RANK-001 source score or any normalized topic score
   is at or below `-3.5`. Explicit topic blocks are counted before negative
   feedback so diagnostics are mutually exclusive.
3. For a requested result size, allow at most
   `floor(resultSize * 0.5)`, with a minimum of one, from a single source.
4. Reserve `ceil(resultSize * 0.2)` exploration selections, bounded by actual
   availability, from candidates with exploration probability at least `0.7`.
5. Fill remaining slots in RANK-002 order without violating the source cap,
   then restore the selected set to that same score/time/ID order.

Exploration selection therefore changes inclusion, not the meaning of the
underlying score or its explanation. Reversed input produces the same output.

The source cap is strict. If the candidate pool lacks enough sources, the
result is shorter rather than silently violating the cap. The result reports
requested and eligible counts, the applied cap, observed maximum source share,
exploration target/count, filter counts, and whether the list was filled.

Configuration and inputs fail closed for unsupported model versions, invalid
fractions or thresholds, more than 10,000 candidates, more than 500 requested
results, duplicate article IDs, and oversized blocked-topic sets.

## Verification

- A dominant-source scenario verifies a 50% maximum share and deterministic
  selection after reversing input.
- A fixed production replay verifies source diversity, two exploration
  selections, one explicit block, two strong-negative removals, model version,
  and exact final order.
- Tests cover insufficient-source reporting, custom exploration thresholds,
  duplicate candidates, invalid versions, hostile candidate counts, and
  oversized blocked-topic input.
- RANK-001 continues to bound event replay and accumulated profile dimensions,
  so repeated or conflicting behavior evidence cannot bypass these limits.

## Rollback and evolution

Changing filter precedence, thresholds, quotas, cap behavior, or selection
order requires a guardrail model version increment and old/new production
Replay comparison. Rollback selects the prior guardrail version or bypasses
personalized ranking in favor of chronological order; it does not alter stored
behavior evidence.

## Consequences

RANK-004 can expose blocked topics and filter/selection reasons without
reconstructing policy. It can also explain a deliberately shorter list when
strict diversity cannot be satisfied. User editing, disabling, clearing, and
chronological fallback remain RANK-004 work.

The guardrail reads only IDs, numeric scores, normalized topics, and RANK-001
profile dimensions. It adds no network, upload, article-content, note, or AI
output path.
