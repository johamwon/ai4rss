# ADR-0069: Evidence-bearing semantic knowledge search

## Status

Accepted — 2026-08-06

## Context

River needs semantic knowledge search and related-article discovery before it can provide evidence-backed question answering. Search must work with local or managed embeddings, avoid returning stale vectors after model upgrades, support useful library filters, and retain enough source context for later citations. A vendor-specific query API would couple product behavior and quality metrics to one database.

## Decision

1. Query embeddings use the same explicit `EmbeddingProfile` as indexed chunks. The vector index only searches documents with an identical profile identity.
2. `KnowledgeVectorIndex.searchRecords` is the supplier-neutral retrieval port. The memory/local reference implementation uses cosine similarity, bounded candidates, pre-score filtering, and stable score/item/chunk ordering. Cloud implementations may use ANN internally but must preserve the port semantics.
3. Search groups record matches by knowledge item, ranks by the best chunk, and returns bounded evidence containing chunk identity, text, ordinal, source offsets, and score.
4. Similar-item lookup computes a centroid from the stored item vectors, excludes the source item, and does not call the query embedding Provider.
5. Filters compose source kinds, source IDs, tags, topics, an inclusive saved-from time, an exclusive saved-before time, and excluded item IDs. Filtering occurs before similarity scoring.
6. Filterable document metadata is stored with the vector document. A metadata change invalidates the incremental fingerprint even when canonical body content is unchanged.
7. Requests, candidate counts, evidence counts, filter values, vector dimensions, and scores are bounded. Invalid query vectors fail before index access.

## Consequences

- INTEL-003 can construct paragraph citations directly from search evidence.
- Model upgrades cannot mix incompatible vectors.
- Managed vector stores remain replaceable, but must reproduce deterministic filtering and result contracts.
- Search quality is measured against a fixed synthetic golden set rather than asserted only by unit examples.

## Verification

- Unit tests cover ranking, evidence, combined filters, similar-item behavior, profile isolation, invalid query vectors, deterministic ties, and metadata-only rebuilds.
- Fast Lane evaluates six query/similarity cases. Recall@K and Precision@K are reported and block below 0.90; the current baseline is 1.00 for both with evidence on every returned result.
