# ADR-0076: Direct BYOK AI and media provider connections

## Status

Accepted, 2026-08-09.

## Context

River already supports direct OpenAI-compatible AI summaries, but users had no
shared settings surface and cloud TTS or podcast transcription had no real
provider adapter. A River-operated proxy would receive every customer API key,
article prompt and media request without adding value to the first BYOK release.

## Decision

- Android, iOS and Windows connect directly to the HTTPS endpoint entered by the
  user. River does not proxy or persist BYOK credentials in a River service.
- AI continues to use the existing versioned `AiByokConfiguration` contract.
  TTS and podcast transcription use capability-scoped media profiles.
- Complete profiles are stored only in Keychain, Android Keystore or Windows
  Credential Manager through the platform secure-store adapter. An empty key
  field preserves the stored key; deleting one capability cannot delete another.
- The first adapter family is OpenAI-compatible: `/models`,
  `/chat/completions`, `/audio/speech` and `/audio/transcriptions` beneath a
  user-supplied HTTPS base URI. Redirects are disabled and request/response size
  and time budgets are explicit.
- Connection tests call `/models` and never include response bodies or keys in
  diagnostics. A provider that omits model discovery may still be saved and used.
- TTS accepts only a configured media type with a matching file signature.
  Provider-declared duration is used when available; otherwise River uses a
  conservative estimate until playback metadata is available. BYOK cost is zero
  in River's ledger because the provider bills the user directly.
- Podcast upload bytes must match the ingested asset byte count, media type and
  SHA-256 digest before upload. The initial direct multipart adapter is capped at
  100 MiB; larger and resumable jobs remain behind the existing cloud workflow
  port.

## Privacy and security

Credential objects redact their value, HTTP diagnostics expose header names but
not values, remote error bodies are never surfaced, and tests use synthetic
content without real network access. HTTPS is mandatory and URLs containing
credentials, query secrets, fragments or non-default ports are rejected.

## Quality, latency and cost

The change does not alter prompts or summary schemas, so deterministic summary
quality and Provider-call counts are unchanged. Connection tests add one bounded
`GET /models`; TTS and transcription add one Provider call per cache miss/job.
River incurs no model charge for BYOK calls. Live model latency, voice quality and
transcription accuracy remain Nightly evidence after test credentials exist.

## Rollback

Remove the settings entry and inject unavailable media adapters. Existing AI
profiles remain readable by the previous vault, while local reading, system TTS,
podcast playback and all local knowledge features continue unchanged.
