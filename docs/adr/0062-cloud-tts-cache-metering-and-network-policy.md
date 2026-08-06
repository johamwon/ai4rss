# ADR-0062: Cloud TTS cache, metering, and network policy

## Status

Accepted for CLOUD-003 core on 2026-08-06.

## Context

Cloud TTS sends selected article segments and voice settings to a paid remote
service. Naive prefetch can generate the same segment multiple times, charge a
reader after cancellation, retain audio indefinitely, consume metered data, or
reuse speech after the article or voice configuration changes. Provider output
and cache failures must not break the free system-TTS path.

## Decision

1. `CloudTtsPreparationBackend` implements the existing vendor-neutral segment
   preparation contract. A versioned server-owned profile selects the provider
   route and output format; clients do not send provider credentials, models,
   endpoints, or prices through the audio package.
2. Each segment uses a SHA-256 identity over the content-revision hash, segment
   text hash and source range, segment kind, complete rate/pitch/voice/language
   tuple, profile version, and audio format. Article IDs, titles, URLs, raw
   revisions, text, and credentials are absent from keys and diagnostics.
3. A valid unexpired cache entry is reusable without a network or generation
   entitlement check. This permits already-generated speech to continue
   offline and after a plan change until normal cache expiry. An entitlement is
   still required for every cache miss. The default new-generation policy is
   Wi-Fi only; offline and unknown links fail closed, and metered links require
   explicit opt-in.
4. Concurrent callers for the same identity share one Provider operation and
   one usage record. Each caller remains independently cancellable. When the
   final waiter cancels, cancellation is propagated to the Provider. If an
   uncooperative Provider returns usable audio after cancellation, incurred
   duration and cost are still recorded accurately, but the late audio is not
   cached or returned.
5. Usage is written once per content-addressed operation and records Unicode
   character count, actual audio duration, Provider billable duration, integer
   micro-cost, and an injected UTC timestamp. A metering failure fails closed;
   a cache write or touch failure does not discard an otherwise valid metered
   response.
6. Defaults bound a segment to 5,000 Unicode characters, 8 MiB of MP3/M4A
   audio, ten minutes of playable duration, fifteen minutes of billable
   duration, ten million integer micro-cost units, and 45 seconds of Provider
   time. Empty, oversized, mismatched-media, invalid-cost, or
   impossible-duration responses are neither metered nor cached.
7. Cache entries carry an audio digest and are revalidated before reuse.
   Corrupt or expired values are removed and regenerated. Cleanup is
   deterministic least-recently-used eviction with defaults of 30 days,
   512 MiB, and 10,000 entries. Releasing a prepared in-memory segment drops
   its lease but does not delete the reusable cache asset.
8. The cloud backend remains a non-fatal prefetch dependency. Existing bounded
   look-ahead, memory eviction, generation cancellation, and `AudioEngine`
   playback ownership remain unchanged. Injecting
   `UnavailableAudioSegmentPrefetcher` immediately restores free system TTS.

## Verification

- Unit tests cover exact billable duration and micro-cost, offline cache reuse,
  concurrent duplicate generation, last-waiter cancellation and late output,
  article revision/text/settings invalidation, entitlement and network gates,
  invalid Provider output, corrupt cache recovery, LRU/TTL cleanup, and
  diagnostic privacy.
- Deterministic Harness replay fixes five release cases: exact billing,
  duplicate generation, cancellation, content revision change, and metered
  network blocking. It asserts five Provider calls, 17,500 billed milliseconds,
  propagated cancellation, and no private content in diagnostics.
- Tests use injected adapters only. This change creates no Provider account,
  production secret, remote cache, billing backend, or cloud resource.

## Rollback

Disable the cloud-TTS entitlement or inject
`UnavailableAudioSegmentPrefetcher`. Cached cloud assets may be removed by the
cache adapter without touching articles, subscriptions, playback progress, or
the local system-TTS engine.
