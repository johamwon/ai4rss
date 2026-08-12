# ADR-0080: Resilient summaries and semantic reading workspace

## Status

Accepted, 2026-08-12.

## Context

Several OpenAI-compatible providers return valid structured content inside Markdown fences, prose, a `result`/`data` wrapper, content blocks, or a parsed-object field. Some omit token usage. River previously treated each variation as an unavailable provider and discarded the result after one strict repair, while the reader only told the user that validation failed. The inbox also stacked subscription management above the article list at every window width, and the reader persisted sanitized HTML but rendered only its plain text.

Users also need an explicit cross-article brief rather than N unrelated single-article summaries.

## Decision

- Keep capability schemas strict, but normalize a bounded allow-list of harmless transport wrappers before schema validation. Accept content blocks, parsed objects and missing usage accounting as zero; never invent missing summary fields or expose raw model output.
- Map malformed JSON, missing fields, wrong language and invalid values to distinct user-facing recovery messages. A failed repair remains retryable and never replaces the article body or enters the validated cache.
- Add `river.multi-article-summary.v1` and immutable v1 generation/repair prompts. The explicit UI selects 2–20 articles, discloses provider, model, article count, transmitted character count and the two-call maximum, then returns an overview, themes, one canonical-ID takeaway per article, and cross-article connections.
- Bound batch input to 60,000 normalized characters, allocated evenly with a 12,000-character per-article ceiling. Require every requested article ID exactly once in output and use local canonical titles rather than model-supplied titles.
- Use a left subscription rail plus full-height article list at widths of at least 840 logical pixels. On narrow screens, collapse subscription management above the full-height list by default.
- Render heading, emphasis, quote, code, link, list, caption and table semantics from sanitized HTML onto the canonical plain-text offsets. Publisher CSS, classes, scripts and event handlers remain excluded, preserving annotation, TTS and progress anchors.

## Quality, latency, and cost delta

The existing single-article prompt and schema are unchanged, so the fixed single-article golden corpus has a quality delta of zero. Static replay has zero provider latency and cost. Local wrapper extraction is linear over the already bounded response; fenced/wrapped valid JSON can now avoid one repair call, reducing live cost and latency in those cases.

Multi-article summary is a new capability with no previous quality baseline. Deterministic tests cover exact article coverage, canonical titles, fenced output, one repair, duplicate rejection and input bounds. One request is normal and two is the hard maximum; output is capped at 4,000 tokens and normalized input at 60,000 characters. Live provider quality, latency and billed cost remain Nightly measurements and must not be inferred from static fixtures.

## Risk and rollback

This combines R1 adaptive UI work with R2 AI parsing and HTML-derived presentation. Rollback may hide the multi-select action and restore the prior inbox composition without changing stored data. Removing semantic ranges falls back to the same canonical plain text, so annotations and TTS remain valid. Removing tolerant normalization restores strict parse behavior; no tolerant-only response is written unless it passes the unchanged capability schema.
