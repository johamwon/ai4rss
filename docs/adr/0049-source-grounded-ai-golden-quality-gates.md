# ADR 0049: Source-grounded AI golden quality gates

## Status

Accepted for AI-006.

## Context

The initial summary replay contained one low-risk Chinese product case and
checked two literal phrases. It proved schema stability but could not measure
the PRD threshold of at least 90% necessary-fact coverage or a zero forbidden-
claim hit rate. It also did not read the referenced source fixture, so a replay
assertion could drift away from its evidence.

High-risk financial, health, legal, and security summaries need explicit
uncertainty and applicability boundaries. The PR gate must remain deterministic,
offline, copyright-safe, and inexpensive; live model behavior belongs to the
Nightly lane.

## Decision

1. Every summary case references a synthetic source fixture with matching case
   ID, BCP-47 language, content type, risk level, and non-empty body.
2. A necessary fact has a stable ID, one or more verbatim source-evidence
   alternatives, and one or more acceptable normalized output expressions.
   Evidence must exist in the source before the fact enters the coverage
   denominator.
3. A forbidden claim has a stable ID and normalized expression variants. Any
   variant in the structured summary is a case failure.
4. The corpus gate requires at least eight cases, both `zh-CN` and `en-US`, all
   eight declared content types, and at least four high-risk cases. Necessary-
   fact coverage is aggregated across the valid corpus and must be at least
   90%; forbidden-claim hits divided by assertions must equal zero.
5. `EvalReport` carries reader-facing metrics in addition to failures. CI output
   exposes matched/total facts, forbidden hits/assertions, languages, content
   types, and high-risk count so reviewers can see the evidence behind a pass.
6. PR replay remains static and makes no provider request, making latency and
   cost deltas zero for corpus-only changes. A model or Prompt change must report
   quality deltas on this fixed corpus and use Nightly live eval for measured
   provider latency and cost.

## Evidence

- Eight source-grounded cases cover 24 necessary facts and 16 forbidden
  assertions across product, finance, health, legal, news, research, tutorial,
  and security content.
- Four cases are high risk and preserve return, medical-population, controlling-
  agreement, and open-investigation boundaries.
- Production replay scores 24/24 facts and 0/16 forbidden claims. A separate
  negative test with 50% coverage and one forbidden hit proves both thresholds
  block the harness.
- The fixture manifest now validates all 23 registered deterministic fixtures.

## Consequences and rollback

Golden-case additions are expected to make the gate harder over time. Difficult
cases and assertions are immutable regression evidence; fixes must improve the
Prompt, model, parser, or accepted evidence variants rather than delete them.

Rollback may disable the new metric check only if the evaluator itself is
broken. The expanded synthetic fixtures remain in the repository, and schema
validation continues to run. Removing high-risk cases or weakening the zero-hit
claim gate is not an acceptable feature rollback.
