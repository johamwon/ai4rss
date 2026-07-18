# ADR-0007: Local extraction cache and request coordination

Status: Accepted

River wraps the classified extraction pipeline with a cache-aware coordinator.
The coordinator depends on the domain `ExtractionCache` port; the production
adapter stores content in the existing Drift `article_contents` table and the
SHA-256 content hash in `articles.content_hash`. The v1 schema already contains
the extractor name/version, ETag, Last-Modified, extraction time, and failure
code fields, so this change requires no database migration.

Cache validity is determined by the successful extractor name/version and any
HTTP validators supplied with the request. A changed ETag or Last-Modified
value, an unknown/older extractor version, or an explicit `forceReparse`
request triggers parsing again. Successful content is hashed from the sanitized
HTML, which makes the hash stable across platforms and suitable for downstream
AI cache keys. Failed refreshes record a classified failure code without
discarding the last readable body.

Concurrent requests use a normalized URL key. Identical URLs share one Future;
distinct work is limited to four active extractions globally and two per HTTP
origin. Cache hits do not consume extraction permits. Cache adapter failures are
contained and never prevent the underlying extractor from returning content.
When stale content exists and re-extraction fails, River returns that content so
offline reading remains available.

This is an R2 cache and parser-coordination change. Tests cover cache hits,
same-URL coalescing, global/per-origin limits, version and validator invalidation,
stable hashing, persistence, classified failures, and stale-content fallback.
Rollback restores the raw `LayeredFullTextExtractor` in the composition root;
the existing cache rows remain compatible and no schema rollback is required.
