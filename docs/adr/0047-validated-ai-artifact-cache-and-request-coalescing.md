# ADR 0047: Validated AI artifact cache and request coalescing

## Status

Accepted for AI-004.

## Context

FR-AI-004 requires summary reuse by body hash, requested model, immutable
prompt version, and output language. A cache hit must not call or charge the
provider, while concurrent identical requests must converge on one provider
operation. AI-001 also requires River to cache only output that already passed
the strict production schema.

The cache is local-first and must survive Android, iOS, and Windows process
restarts. It contains article-derived output, so diagnostics must expose only
bounded metadata and never the structured result.

## Decision

1. `SummaryCacheIdentity` hashes a canonical versioned JSON tuple containing
   the normalized body SHA-256, requested model, prompt version, and BCP-47
   output language. The opaque key is another SHA-256 value. Article IDs and
   titles are intentionally excluded to match FR-AI-004 and allow duplicate
   content to reuse a result.
2. `SummaryService` and `LongArticleSummaryService` resolve the prompt version
   before cache lookup and share `AiSummaryRequestCoalescer`. The coordinator
   retains one Future per cache key and removes it after either success or
   failure. Failures are therefore retryable and never become cached Futures.
3. River writes an artifact only after the final `ArticleSummarySchema` parse
   succeeds. Cache reads parse the stored canonical JSON through the same
   schema. A wrong identity, malformed structure, future schema, invalid
   language, or invalid value is never returned and is deleted on a best-effort
   basis before a normal provider retry.
4. Long-summary artifacts additionally persist only the reduce facts actually
   supplied to the final prompt and the omitted-fact count. Because article ID
   is not a key component, a duplicate article reuses the facts but remaps
   their paragraph citations to the requesting article ID.
5. `AiArtifact` records both requested and resolved model identities, prompt
   version, language, content hash, canonical structured result, input/output
   tokens, provider-call count, actual USD cost, and an injected-clock
   timestamp. Its diagnostics report metadata and result size, not article
   content or the result itself.
6. Drift schema v14 adds `ai_artifacts`, keyed by the opaque cache key, plus an
   article/time cleanup index. `DriftAiArtifactRepository` uses conflict-safe
   replacement, explicit deletion, and UTC timestamps. The table is device
   local and is not part of encrypted sync.
7. Cache read happens before provider work. A hit reports zero current-request
   token usage. Persistence failure after a valid provider response does not
   discard the response; the next request may call the provider again.

## Evidence

- Eight new `river_ai` tests cover short and long cache hits, recreated service
  instances, duplicate-article citation remapping, four-dimensional key
  invalidation, malformed-value eviction, validated-output-only writes, and
  short/long concurrent request coalescing, plus cache-read degradation. The
  package total is 45 tests.
- Two repository tests cover replace/delete semantics and close/reopen SQLite
  persistence.
- The immutable v13 fixture migrates to v14 while preserving an unrelated row.
  An interrupted state with the v14 table but no cleanup index preserves the
  cached row and repairs the index idempotently. All 23 migration cases pass.
- Deterministic `ai-cache-replay` is 1/1. It proves two simultaneous calls plus
  a recreated-service call make one provider request, retain token/cost
  metadata, and produce five distinct keys when any required dimension changes.
- Quality delta is neutral because hits are parsed through the production
  schema. A hit reduces provider latency and billed tokens to zero; a miss adds
  one local SQLite read and one best-effort write while preserving the existing
  provider call and repair ceilings.

## Consequences and rollback

The cache reduces repeated BYOK and managed-AI cost without enabling automatic
summaries. AI-005 may inject the Drift repository at the composition root and
present cached results without changing provider contracts.

Feature rollback stops injecting `AiArtifactRepository`; reading and summary
generation continue without cache reuse. Schema v14 is additive and the table
may remain unused. A binary that only understands v13 must not open a committed
v14 database; release rollback therefore keeps the v14 database layer and
disables only the cache orchestration.
