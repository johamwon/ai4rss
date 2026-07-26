# ADR-0021: Bounded audio segment prefetch

Status: Accepted

River separates segment preparation from playback. An
`AudioSegmentPreparationBackend` may prepare an opaque, releasable resource for
one article speech segment. The playback controller depends only on the
`AudioSegmentPrefetcher` lifecycle and continues to use `AudioEngine` as the
authoritative playback path. A preparation failure therefore degrades prefetch
but never changes the playback phase or blocks local system TTS.

The default bounded coordinator retains the current segment and at most three
future segments, runs at most two preparations concurrently, and caps retained
resources at 8 MiB. Configuration itself is bounded to sixteen future segments,
four workers, and a minimum 64 KiB budget. Backends report retained bytes and
must provide an asynchronous, single-use release operation; raw provider types
and credentials never cross the audio package boundary.

Every window has a generation. Loading another article, moving to another
segment, or changing rate, pitch, language, or voice cancels the previous
generation through both an immediate flag and a completion future. Cached
resources outside the new window are released immediately. A backend that
ignores cooperative cancellation may finish late, but its stale result is
released instead of entering the cache. Stop, final completion, replacement
load, and controller disposal cancel work and release retained resources.

Playback character progress inside the same segment does not restart prefetch.
Only the stable article revision, segment index, and complete settings tuple
move the window. Tuple equality is structural, avoiding delimiter or hash-key
collisions from provider-defined voice identifiers.

The free system-TTS composition uses the unavailable prefetcher because native
utterance APIs already consume one sentence just in time and duplicating text
would waste memory. Stage 12 `CLOUD-003` may inject a backend for synthesized
file resources without changing the controller or reader. This preserves the
commercial boundary: cloud generation, metering, cache policy, and network
policy are not smuggled into the free local playback core.

Tests cover concurrency and look-ahead bounds, generation cancellation, a
misbehaving late backend, non-fatal preparation errors, memory-budget eviction,
settings invalidation, and disposal. A two-hour synthetic reading plan
(108,000 source characters) must segment in under five seconds with a
conservative retained-plan estimate below 2 MiB.

Rollback injects `UnavailableAudioSegmentPrefetcher`; article segmentation,
system TTS, restart positions, and system media controls remain functional.
