# ADR-0079: Fish Audio BYOK TTS provider

## Status

Accepted, 2026-08-10.

## Context

River's first media BYOK adapter assumed OpenAI-compatible `/audio/speech` semantics. Fish Audio exposes a distinct `POST /v1/tts` contract: bearer authentication, a dedicated `model` header, optional `reference_id`, and binary audio output. Treating it as a base-URL variation would save a profile that cannot synthesize correctly.

## Decision

- Add the fixed `fish-audio` provider profile in the adapter package. Its origin is pinned to `https://api.fish.audio`.
- Support the documented `s2.1-pro`, `s2.1-pro-free`, `s2-pro`, and `s1` model identifiers and MP3, WAV, or Opus output.
- Send the selected model in the `model` request header. Send a configured Voice Model ID as `reference_id`; omit it when the user chooses the default voice.
- Preserve River's bounded 45-second request, 8 MiB response, cancellation, stable failure mapping, audio signature validation, credential redaction, and zero River-side BYOK cost.
- Validate a key with the read-only `/wallet/self/api-credit` endpoint. A connection check must not create billable speech.
- Keep the provider behind `CloudTtsSynthesizer`; no Fish SDK or vendor type enters the domain or audio orchestration packages.

## Risk and rollback

This is R2 network-adapter work. Deterministic transport fixtures cover request shape, endpoint pinning, credentials, default/custom voice, connection checks, audio validation, and failure mapping. Rollback removes the provider preset and factory branch; saved Fish profiles remain isolated in the TTS secure-vault slot and can be cleared without affecting AI, transcription, local reading, or system TTS.
