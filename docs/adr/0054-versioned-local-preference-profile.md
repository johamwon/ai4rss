# ADR 0054: Versioned local preference profile

## Status

Accepted for RANK-001.

## Context

PREF-001 through PREF-004 provide bounded, consent-gated local behavior
evidence. Ranking needs a deterministic first model before semantic candidate
scoring is introduced. A collection of ad-hoc weights would be difficult to
replay, could let repeated clicks overpower deliberate actions, and would make
model changes invisible to stored experiments.

## Decision

1. The first model is identified as `river.preference-profile/1`. Unsupported
   model versions fail closed; any future weight, decay, aggregation, or
   normalization change must increment the model version.
2. Signal weights are fixed for v1:

   | Signal | Weight |
   |---|---:|
   | impression | 0 |
   | open | 0.2 |
   | active read | 0.25–1.0 from bounded active seconds |
   | completed | 1.5–2.5 from completion ratio |
   | starred | 2.5 |
   | saved to knowledge | 3.0 |
   | not interested | -4.0 |

   Thus every individual click is weaker than any valid effective-reading or
   deliberate signal, and explicit negative feedback dominates every positive
   signal.
3. Repeated open events for one article contribute at most once. The latest
   open is retained so an old, heavily decayed click cannot hide a newer
   revisit. Stable event identity still deduplicates all exact replays, while
   conflicting reuse of an event ID fails closed.
4. All evidence uses exponential time decay with a 30-day half-life and
   microsecond precision. Evidence after profile generation is rejected.
5. A source receives the event's full decayed score. Canonical, deduplicated
   topics share that score evenly, so attaching more labels cannot amplify the
   event. Source and topic dimensions are sorted and independently bounded to
   ±1000 after summation.
6. Profile generation consumes only event envelopes plus bounded source IDs and
   topic labels. It does not read article bodies, titles, URLs, notes, AI
   output, accounts, or network services.

## Evidence

- A deterministic 1,000-sample property test checks that clicks remain weaker
  than active reading, completion, starring, and knowledge saves, while
  negative feedback remains strongest.
- Half-life tests prove 30- and 60-day positive/negative decay and reject
  future timestamps and invalid configuration.
- A simulated session proves exact source/topic scores, topic conservation,
  normalization, stable model identity, and duplicate replay handling.
- A 100-click session contributes 0.2 for one article; a later reopen replaces
  the older click contribution.
- The production ranking replay Harness covers weight ordering, half-life,
  click cap, model version, and complete source/topic profile output.

## Consequences

RANK-002 can combine this profile with semantic, freshness, source, completion,
and exploration candidate features without redefining evidence. RANK-003 will
add diversity and exploration constraints, while RANK-004 will expose editing
and recommendation explanations.

The v1 score is preference evidence, not a probability and not a final ranking
score. Profiles can be rebuilt from retained events. A rollback must keep the
model version attached to outputs; silently interpreting v1 scores under
different weights is prohibited.
