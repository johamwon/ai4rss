# ADR-0060: Managed AI routing and provider resilience

## Status

Accepted for CLOUD-001 core on 2026-08-06.

## Context

River already supports device-owned OpenAI-compatible BYOK profiles. Managed
AI has a different trust boundary: authenticated clients may submit an allowed
capability request, but must never receive or choose a provider credential,
endpoint, concrete upstream model, price, or fallback order. A single provider
failure must not break local reading, while retries and fallbacks must remain
bounded so they cannot multiply cost or bypass usage accounting.

## Decision

1. `ManagedAiGatewayRequest` contains a capability, idempotency key, versioned
   prompt, response schema, output language, output bound, and total deadline.
   It contains no provider key, endpoint, upstream route, or concrete model.
   The authenticated server context supplies the opaque account key and trusted
   plan; client-supplied plan claims are outside this core contract.
2. A version-controlled routing table maps `plan + capability` to one ordered
   list of at most four server routes. `ManagedAiGatewayProviderAdapter` ignores
   the caller's model alias. The selected route ID resolves through a
   server-owned registry whose provider client is already bound to its secret.
   Secrets never enter routing values, responses, diagnostics, or exceptions.
3. The gateway fingerprints the complete semantic request with SHA-256.
   Concurrent duplicates share one future and successful duplicates replay the
   same response for 24 hours without another provider call or rate-limit unit.
   Reusing an idempotency key with different input fails closed. The reference
   store is explicitly bounded to 10,000 completed requests; a production
   multi-instance adapter must preserve the same atomic contract in shared
   storage or route one account shard to one stateful instance.
4. Unique requests consume an account-and-capability fixed-window allowance
   before any provider call. Rejected requests return a bounded `retryAfter`.
   Fallback does not consume another account allowance because it remains one
   logical request.
5. The request carries one total deadline and each route has a shorter per-call
   deadline. A timeout, unavailable provider, provider quota/authentication
   failure, rate limit, or locally rejected output quality may advance once to
   the next configured route. Invalid requests and cancellation never invoke a
   second billable provider.
6. Each route owns a circuit breaker. Two consecutive failures open it for 30
   seconds by default; open routes are skipped, and after the interval only one
   half-open probe is admitted. Accepted output closes the circuit. Policies
   are injected and bounded for deterministic tests and later remote config.
7. An output is usable only after a capability-specific local validator accepts
   it. Article summaries reuse `river.article-summary.v1`, including exact
   language validation. Costs use server-known per-million-token prices and
   integer micro-units. A rejected but completed provider response remains in
   incurred cost, while the client receives only the accepted result.
8. Diagnostics contain only a truncated operation hash, capability, route ID,
   attempt, stable outcome/failure code, elapsed time, and integer cost. They do
   not contain account IDs, article IDs, titles, URLs, bodies, prompts, model
   output, credentials, provider error bodies, or secret endpoint paths.

## Verification

- Unit tests cover trusted plan routing, caller-model rejection, provider
  failure, timeout, invalid-request no-fallback, quality fallback, exact cost,
  concurrent coalescing, completed replay, fingerprint collision, retention,
  rate-window reset, circuit open/skip/half-open recovery, and diagnostic
  privacy.
- The deterministic Harness replays four release scenarios: provider failure,
  timeout, duplicate request, and quality fallback. It asserts route choice,
  bounded provider-call counts, accepted-result cost, and zero private content
  in diagnostics.
- Existing bilingual/high-risk summary golden cases and all five BYOK Provider
  replay cases remain unchanged and blocking.

## Quality, latency, and cost delta

CLOUD-001 does not change any prompt or summary schema, so static summary
quality delta is zero. The local routing/validation overhead is deterministic
and negligible relative to a provider call. A healthy request remains one
provider call; an exact duplicate remains zero additional calls. A quality
fallback incurs both completed calls and reports both costs (the current replay
totals seven calls and 750 micro-units across four scenarios). Real provider
latency and price comparisons remain a Nightly live-eval responsibility once
deployment credentials and an approved cloud environment exist.

## Rollback

Remove the managed gateway adapter from the server composition root or disable
the managed-AI entitlement. BYOK, cached summaries, local ranking, system TTS,
podcast playback, knowledge items, and all base reading paths remain available.
No database migration or client data deletion is involved.
