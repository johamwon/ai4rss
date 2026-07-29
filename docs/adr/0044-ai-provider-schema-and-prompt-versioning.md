# ADR 0044: AI provider, summary schema, and prompt versioning

## Status

Accepted for AI-001.

## Context

River must support BYOK and managed AI without allowing a vendor SDK, a model's
free-form response, or a mutable prompt to define product behavior. FR-AI-001
requires one sentence, 3–7 key points, reading value, topic/entity labels, and
estimated reading time. It also requires structured output and at most one
repair attempt. Later tasks add real providers, long-document orchestration,
caching, and UI; AI-001 must give those tasks one deterministic contract.

## Decision

1. `river_ai` owns the provider port. A request carries a stable operation ID,
   model, rendered versioned prompt, matching JSON Schema, output-token bound,
   and timeout. A response carries bounded output, resolved model, token counts,
   elapsed time, and an optional provider request ID. Stable failures expose only
   a code, retryability, and a Retry-After value capped at one hour.
2. Provider request/response, prompt, and failure diagnostics never include
   article text, rendered prompt text, model output, tokens, or remote error
   bodies. AI-002 is responsible for enforcing the same boundary in HTTP logs.
3. `river.article-summary.v1` is strict Draft 2020-12 JSON Schema with
   `additionalProperties: false`. It requires every FR-AI-001 field and enforces
   cardinality, uniqueness, length, reading-time, schema-version, and exact
   output-language bounds. The parser rejects Markdown fences and all other
   non-JSON output.
4. `SummaryService` makes one structured request. A schema failure may make one
   request with `article-summary-repair@1`; a second invalid response fails with
   a stable `AiSchemaFailureCode`. Provider failures are not disguised as schema
   failures and do not trigger repair.
5. Prompt identities use `{id}@{positive integer version}`. The registry accepts
   registering the same immutable definition again, but rejects different
   content, variables, or schema under an existing version. Any behavior or
   wording change therefore requires a new version. Templates declare their
   variables exactly and rendered prompt diagnostics expose only sizes.
6. `ArticleSummary` gains the reading-value, topic, entity, and estimated-time
   fields additively. No database migration or network provider is introduced in
   AI-001.

## Evidence

- Provider contract tests cover request bounds, stable failures, usage bounds,
  schema-name matching, and redacted diagnostics.
- Prompt tests cover exact variable binding, redacted diagnostics, deterministic
  lookup, and rejection of same-version changes.
- Schema and service tests cover every required field, strict extra-field and
  language rejection, cardinality, one repair, and failure after a second
  invalid response.
- The deterministic AI replay harness parses the production schema. Current
  replay schema success is 1/1 (100%).
- Quality delta: schema validation rises from a two-field presence check to the
  complete production v1 contract. Latency and cost deltas are zero because
  AI-001 performs no live model calls; the repair path is deterministic and
  capped at one extra request for later provider implementations.

## Consequences and rollback

AI-002 providers must implement this port and cannot return a domain summary
directly. AI-003 may change how article content is prepared but must keep prompt
and schema identities explicit. AI-004 may cache only validated summaries.

Rollback can stop constructing `SummaryService` without touching stored data.
The additive `ArticleSummary` fields may remain. Prompt or schema changes never
rewrite an accepted version; a corrected contract is published under a new
version and compared through the replay/golden harness.
