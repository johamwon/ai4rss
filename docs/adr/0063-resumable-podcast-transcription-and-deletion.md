# ADR-0063: Resumable podcast transcription and deletion

## Status

Accepted for CLOUD-004 core on 2026-08-06.

## Context

Podcast transcription may ingest multi-hour media by authenticated upload or
remote pull, invoke an expensive speech Provider, and then derive chapters and
a summary. A process interruption must not upload or transcribe the same media
again. Invalid formats, unbounded transcripts, duplicate requests, partial
deletion, remote-media SSRF, and raw transcript diagnostics are unacceptable.

## Decision

1. `PodcastTranscriptionService` accepts either an opaque authenticated upload
   ID with declared media metadata or an absolute HTTPS remote URI without
   credentials, fragments, non-default ports, or obvious local addresses. The
   core preflight is not the SSRF boundary: a production remote ingestor must
   resolve and pin only public DNS answers, revalidate every redirect, preserve
   TLS hostname verification, stream with byte limits, and never re-resolve in
   the transport.
2. Ingestion returns a trusted asset ID, SHA-256 content digest, exact media
   type, byte count, and duration. These values must match upload declarations
   or optional remote expectations. Defaults allow an explicit audio/video
   allowlist, 2 GiB, and six hours. Unsupported, empty, oversized, overlong, or
   mismatched media never reaches the transcription Provider.
3. The request fingerprint hashes the remote URI or upload ID and binds all
   declared metadata, output language, and chapter/summary choices. The job ID
   is an idempotency scope. Concurrent identical callers share one operation;
   the same job with a different fingerprint fails closed. A completed artifact
   is replayed without repeating any cloud stage.
4. Durable checkpoints are written after ingestion and after transcription.
   Restart resumes from the last validated checkpoint. Provider operation IDs
   remain stable so a failure between a Provider response and checkpoint write
   can still be deduplicated by the adapter. Checkpoints contain private
   transcript data and production storage must be encrypted, access-controlled,
   tenant-scoped, and covered by the same deletion policy as final artifacts.
5. The final caller cancellation propagates to active adapters. Work completed
   before cancellation remains checkpointed and accurately metered, but later
   stages do not start. A resumed request can continue from that checkpoint.
6. Transcripts are limited to 20,000 contiguous ordered segments and two
   million characters. Timestamps must be non-overlapping, positive, and
   within media duration; language, Provider version, text, and optional
   speaker labels are bounded. Requested output language must match the result.
7. Generated chapters are ordered and limited to 500; timestamps, titles, and
   descriptions are bounded. Summaries require bounded unique key points,
   topics, language, and one-line text. Disabled outputs must be absent and
   requested summaries must be present. Invalid intelligence is not persisted.
8. Transcription and intelligence use separate stable usage operations. Each
   records billable duration, integer micro-cost, stage, job hash, and injected
   UTC time exactly once. Stage cost and duration are bounded; metering failure
   fails closed before a final artifact is released.
9. Privacy deletion cancels active work and removes the ingested asset,
   checkpoint, final artifact, and job-scoped usage through injected adapters.
   Diagnostics expose only hashes, counts, durations, formats, stages, costs,
   and booleans—not URLs, upload IDs, episode identity, transcript text,
   chapters, summaries, credentials, or Provider error bodies.

## Verification

- Unit tests cover unsafe remote sources, six-hour media, exact usage, invalid
  media/declaration mismatch, interrupted intelligence recovery, concurrent and
  completed duplicate requests, last-waiter cancellation, job conflicts,
  invalid transcript/intelligence output, privacy-safe diagnostics, and full
  deletion.
- Deterministic Harness replay fixes five release cases: six-hour audio,
  invalid format, interrupted resume, concurrent duplicate, and privacy delete.
  It proves five ingests, four transcription calls, skipped completed stages,
  complete deletion, and no private diagnostics.
- All tests use injected adapters. No upload bucket, remote fetch service,
  speech Provider, production database, credential, or cloud resource is
  created by this change.

## Rollback

Disable the podcast-transcription entitlement and stop enqueueing new jobs.
Existing podcast RSS metadata, official transcript links, downloads, queue,
playback, local articles, system TTS, and knowledge objects continue to work.
Run the deletion adapter for retained CLOUD-004 assets before removing storage.
