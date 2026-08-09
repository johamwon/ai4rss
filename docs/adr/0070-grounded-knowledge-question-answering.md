# ADR-0070: Grounded knowledge question answering

## Status

Accepted — 2026-08-06

## Context

Semantic retrieval alone does not prevent a generative model from inventing facts or citations. River needs useful knowledge answers while making evidence insufficiency visible and ensuring every citation opens the exact saved source passage. The same contract must support local, BYOK, and managed answer Providers.

## Decision

1. Every question first runs through `KnowledgeSemanticSearch` with a fixed minimum evidence score and bounded hit/evidence counts.
2. Empty retrieval returns `insufficientEvidence` without calling the answer Provider. The Provider may also explicitly refuse after seeing evidence.
3. The Provider returns bounded statements and citation Chunk IDs only. Every statement requires one to five unique IDs from the evidence supplied in that request.
4. Unknown, duplicate, missing, or excessive citations fail closed. An insufficient-evidence response carrying statements also fails closed.
5. River materializes citation item ID, title, quote, Chunk ID, and exact source offsets from trusted search evidence. Provider text cannot replace citation content or location.
6. Question length, statement count, statement/total characters, evidence count, language tag, and citations are independently bounded.
7. Request diagnostics include only question length, language, and evidence count; question and evidence text are excluded.

## Consequences

- Users can navigate every accepted statement back to saved source text.
- Retrieval quality and answer grounding have separate failure states and tests.
- A capable model cannot bypass evidence policy by fabricating citation metadata.
- Provider-specific prompting and transport adapters can be added later without changing the domain contract.

## Verification

- Unit tests cover exact citation materialization, retrieval refusal with zero answer calls, Provider refusal, unknown citations, uncited statements, and contradictory refusal output.
- Fast Lane replays the same five release cases and asserts that private question/evidence content is absent from diagnostics.
