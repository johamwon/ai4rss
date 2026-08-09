# ADR-0068: Versioned knowledge vector index

## Status

Accepted — 2026-08-06

## Context

River needs semantic search and evidence-backed knowledge features across Android, iOS, and Windows. The index must work locally, allow a managed-cloud implementation later, and remain rebuildable when content, chunking, or embedding models change. Binding the domain to one vector database or model would make offline behavior, migration, privacy, and testing depend on that vendor.

## Decision

1. `KnowledgeChunker` produces bounded, Unicode-safe chunks with overlap. Chunk IDs are deterministic SHA-256 values over the chunker version, knowledge item identity, canonical content hash, ordinal, source offsets, and text.
2. `EmbeddingProfile` identifies the model, positive revision, vector dimensions, and execution location. Its identity is stored with every vector document and record.
3. `KnowledgeEmbeddingProvider` and `KnowledgeVectorIndex` are separate supplier-neutral ports. The initial memory/local implementation establishes semantics; a cloud index must implement the same port and contracts.
4. A matching content hash, profile identity, and chunker version skips all Provider work. Any mismatch rebuilds the complete document and atomically replaces the previous version only after every batch is valid.
5. Provider batches are bounded. Missing vectors, reordered chunk IDs, invalid dimensions, non-finite values, or partial failure abort the build and preserve the previous document.
6. Concurrent builds for the same item and fingerprint share one Future. A simultaneous different fingerprint fails closed instead of racing a stale write.
7. Deletion establishes a per-item barrier: it waits for an in-flight build, rejects new mutations until removal completes, and then removes the complete document so late work cannot resurrect private content. Stored structural corruption is rebuilt from the canonical `KnowledgeItem`; unrelated storage failures propagate and are not misclassified as corruption.

## Consequences

- Model, chunker, and content upgrades are explicit, deterministic, and testable.
- Local-first operation does not prevent managed embeddings or a cloud vector store later.
- The index stores content-derived chunks, so implementations must follow the same privacy and deletion boundaries as the knowledge item.
- INTEL-002 can add search and filtering over this port without choosing a permanent vendor.

## Verification

- `river_knowledge` unit tests cover deterministic chunking, Unicode boundaries, unchanged skips, model upgrades, content replacement, deletion, invalid Provider output, concurrent coalescing/conflicts, bounded batches, and corruption recovery.
- The deterministic Fast Lane Harness replays build/skip, model upgrade, content change, deletion, and corruption recovery with no network calls.
