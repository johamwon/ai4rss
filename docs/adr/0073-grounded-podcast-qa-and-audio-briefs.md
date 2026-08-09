# ADR 0073: Grounded podcast QA and bounded audio briefs

- Status: Accepted
- Date: 2026-08-06

## Context

River already produces bounded podcast transcripts with ordered timestamps and
exact transcription/intelligence usage records. Users also need to ask questions
about a transcript and generate a daily listening brief, optionally as a
two-speaker dialogue. These features can create unsupported claims, unsafe audio,
unexpected provider cost, and cancellation races if treated as ordinary text
generation.

## Decision

Add provider-neutral orchestration in `river_ai` with two flows.

Podcast QA first performs deterministic lexical evidence selection over the
trusted transcript. No matching evidence means refusal before the answer
Provider. Every accepted statement cites one to five segment indexes from the
evidence actually sent; River materializes quote, speaker, start, and end from
the trusted transcript. Unknown, duplicate, missing, or excessive citations
fail closed.

Daily audio briefs bind a UTC day, language, style, source IDs, source hashes,
and a total integer-micro cost budget into one fingerprint. Narration is the
default. Dialogue output only accepts alternating `host` and `guest` turns.
Every turn cites one to five known sources, and River materializes source titles
rather than trusting Provider citation text. Completed same-fingerprint retries
return the existing artifact.

Source text is safety-checked before script generation. The generated script is
checked again before audio rendering. A rejected source spends no generation
cost; a rejected script keeps any already-incurred script cost but never calls
the audio renderer.

Script and audio stages receive the remaining cost budget separately. Actual
cost is recorded before validating Provider output, so invalid or late results
cannot escape accounting. Cancellation returns promptly; if an ignored
cancellation later produces billable audio, the stable usage key still records
it exactly once. Audio bytes, duration, media type, script length, turn count,
source count, and all costs are independently bounded.

## Consequences

- Answers and brief turns have inspectable source evidence.
- Safety and cost failures cannot silently fall through to audio generation.
- Provider, model, safety implementation, and renderer remain replaceable.
- Production adapters must preserve stable operation IDs and cancellation;
  persistent artifact storage can replace the in-memory completed-result cache
  without changing the orchestration contract.

## Verification

Unit tests cover grounded/no-evidence/forged-citation QA, narration, dialogue,
completed retry, source/script safety, remaining cost, late cancellation cost,
and idempotency conflict. A fixed six-case replay blocks regressions in evidence,
safety, cancellation accounting, and diagnostic privacy.
