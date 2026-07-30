# ADR 0045: OpenAI-compatible BYOK and secure provider profiles

## Status

Accepted for AI-002.

## Context

FR-AI-003 requires a replaceable BYOK path with templates for OpenAI,
Anthropic, Gemini, DeepSeek, and Qwen. The implementation must preserve the
provider-neutral AI-001 contract, keep keys outside ordinary storage and logs,
and work on Android, iOS, and Windows without adding five vendor SDKs.

Chat Completions is the shared compatibility surface. OpenAI recommends the
Responses API for new OpenAI-only projects, but still documents Chat
Completions, Bearer authentication, `max_completion_tokens`, structured
`json_schema` output, response choices, and token usage. Gemini, DeepSeek,
Anthropic, and Alibaba Model Studio each publish an OpenAI-compatible Chat
Completions endpoint:

- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Gemini OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai)
- [DeepSeek OpenAI-compatible API](https://api-docs.deepseek.com/guides/function_calling/)
- [Anthropic OpenAI SDK compatibility](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk)
- [Alibaba Model Studio base URLs](https://help.aliyun.com/en/model-studio/base-url)

The compatibility surfaces are not identical. In particular, Anthropic states
that `response_format` is ignored, while some compatible providers use the
older `max_tokens` and JSON-object mode.

## Decision

1. `river_ai` implements one bounded Chat Completions adapter behind
   `AiProvider`. It sends exactly one system and one user message, never sends
   River's operation/article identifier as provider metadata, and returns the
   AI-001 response envelope for local schema validation.
2. The standard catalog contains endpoint templates, not volatile default model
   names:
   - OpenAI and Gemini use strict `json_schema` plus
     `max_completion_tokens`.
   - Anthropic uses prompt-only JSON instructions plus
     `max_completion_tokens`, because its compatibility layer ignores
     `response_format`.
   - DeepSeek and Qwen use `json_object` plus `max_tokens`.
   Users still choose an explicit model. A custom profile may choose any of the
   three output modes and either token-limit parameter.
3. Base URLs must be credential-free HTTPS origins or HTTPS paths, with no
   query or fragment. The adapter appends `/chat/completions`, disables
   redirects so a Bearer key cannot be forwarded to a second host, bounds
   request/response bytes and time, and accepts only a single non-streaming
   choice with explicit token usage.
4. HTTP 401/403, 402, 408, 429, other 4xx, and 5xx responses map to stable
   `AiProviderFailure` codes. Numeric `Retry-After` is capped at one hour.
   Remote error bodies, response text, prompts, articles, and keys never enter
   diagnostics. Transport errors also collapse to stable offline, timeout,
   invalid-response, or size failures.
5. API keys are represented by an opaque value whose diagnostics are always
   redacted. The complete BYOK profile is stored by `river_platform` in the
   existing versioned `flutter_secure_storage` boundary: Android Keystore,
   device-only iOS Keychain, and Windows platform-protected storage. Reads and
   writes are serialized; corrupt or future schema values fail without silent
   deletion.
6. AI-002 provides infrastructure and secure persistence only. AI-005 owns the
   disclosure/configuration UI, and the commerce stages own enforcement of the
   `bringYourOwnKey` entitlement. No temporary test entitlement is encoded in
   the provider.

## Evidence

- `river_ai` contract tests cover all three structured-output modes, both token
  parameter variants, request/response parsing, status and transport failures,
  truncation, model mismatch, one-hour retry bounds, HTTPS validation, and
  diagnostic redaction.
- The deterministic provider replay matrix exercises all five presets. Current
  provider replay success is 5/5 (100%), while the production summary replay
  remains 1/1 (100%).
- `river_platform` tests cover secure round-trip, deletion, serialization after
  failure, corrupt values, and future schemas. A real Windows secure-storage
  integration journey is part of Merge and Nightly CI.
- No real provider or API key is used. Quality coverage increases without live
  latency or model cost; measured model latency and cost deltas are both zero.
  Runtime overhead is bounded JSON encoding/decoding plus one HTTP request.

## Consequences and rollback

The common adapter deliberately does not expose provider-native tools,
thinking, files, citations, or prompt caching. A later native provider can
implement `AiProvider` without changing summaries or stored artifacts.

If a provider changes its compatibility surface, River can update or disable
that preset while retaining the saved profile for explicit recovery. Rolling
back the adapter stops constructing `OpenAiCompatibleProvider`; clearing the
secure profile is an explicit user action and is never required for rollback.
