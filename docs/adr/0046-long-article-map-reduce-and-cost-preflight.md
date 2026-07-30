# ADR 0046: Long-article map-reduce and cost preflight

## Status

Accepted for AI-003.

## Context

FR-AI-002 requires long articles to stay inside a provider's safe context
window without losing boundary or cross-chunk facts. Every intermediate result
must retain the source article and paragraph range. The implementation also
needs deterministic interruption recovery, explicit output language, and a
cost estimate before a paid request begins.

Character-only limits are insufficient for the AI-002 transport because CJK
text can require three UTF-8 bytes per character. A successful orchestration
must therefore respect prompt-character, serialized-request-byte, chunk-count,
output-token, and provider-call bounds together.

## Decision

1. `ArticleSummaryChunkPlanner` normalizes non-empty paragraphs, packs them into
   bounded chunks, and overlaps one preceding paragraph unit by default.
   Ordinary paragraph numbers remain stable and are encoded as `[P<n>]`.
   A single paragraph larger than the content budget is split at nearby
   whitespace or punctuation without cutting a UTF-16 surrogate pair; each
   piece still cites the original paragraph.
2. Map calls use the immutable `article-summary-map@1` prompt and
   `river.article-summary.chunk.v1` schema. The response repeats the article ID,
   chunk index, half-open chunk range, and for every fact its article ID and
   half-open paragraph range. Local parsing rejects missing, extra, mismatched,
   out-of-range, oversized, or wrong-language values.
3. Identical normalized facts are deduplicated while retaining every distinct
   citation. Reduce selection first reserves one fact from every map result.
   Additional facts are admitted only while both the configured character
   budget and a 240 KiB serialized request budget remain valid. River fails
   with a stable context-budget code instead of silently dropping the only
   evidence from any chunk. The result reports how many non-mandatory facts
   were omitted.
4. Reduce calls use `article-summary-reduce@1`, sourced-fact JSON, the requested
   BCP-47 language tag, and River's deterministic reading-time estimate. The
   existing strict final schema and single repair attempt remain in force.
   The returned provenance list contains only facts actually supplied to the
   reduce call.
5. Preflight runs before any provider call. A Unicode-aware estimator counts
   CJK/Kana/Hangul code points conservatively and estimates other text at four
   characters per token. Configured per-million input/output prices produce an
   upper-bound USD estimate. The bound includes all map calls, one reduce call,
   and the permitted final repair call; real provider usage is accumulated
   separately.
6. After each valid map response, River writes a versioned checkpoint including
   the content/model/prompt/language/budget fingerprint, completed chunk
   outputs, and accumulated token usage. A mismatched checkpoint is ignored.
   Successful reduce clears it. A cleanup failure is reported on the result but
   does not discard a valid summary.
7. `river_platform` persists the checkpoint in the OS application-support
   directory using a SHA-256 article filename, a 4 MiB codec bound, serialized
   operations, flushed temporary writes, and a recoverable backup. Android,
   iOS, and Windows can therefore resume after process restart. Corrupt or
   future values return a stable failure and are not silently deleted.

## Evidence

- Eleven AI-003 package tests cover overlap, oversized paragraphs, surrogate
  safety, chunk-count refusal, 60-chunk preflight latency, boundary facts,
  cross-chunk deduplication, multilingual output, preflight pricing,
  interruption/resume with usage preservation, cleanup degradation, mandatory reduce facts,
  UTF-8 request bytes, and invalid citations.
- Two platform tests recreate the store to prove persistence, then verify
  explicit clearing and corrupt/future-schema retention.
- The deterministic long-summary replay is 1/1 and requires opening,
  cross-block, and closing facts with source citations.
- The 60-chunk/approximately 480,000-character preflight has an automated
  two-second CPU ceiling. No live model is called by tests, so model latency and
  billed-cost deltas are zero; preflight token/call/USD bounds are still
  exercised with non-zero pricing.

## Consequences and rollback

Map checkpoints contain article-derived facts. They stay in the app-private
support directory, never enter diagnostics, and are deleted after success.
They are not cloud-synced by this task.

The planner and orchestrator are additive. Rolling back AI-003 routes articles
through the existing short-summary service and leaves reading unaffected.
Checkpoint files may be explicitly cleared or ignored; no article content or
summary schema migration is required.
