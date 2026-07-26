# ADR-0019: Restartable article TTS playback

Status: Accepted

River owns playback policy in a platform-neutral `AudioPlaybackController`.
The controller consumes the `AudioEngine` event stream, advances article
segments without reentrant callbacks, and exposes one immutable state for the
reader UI. Native adapters remain responsible only for truthful capabilities
and commands. This keeps play, pause, restart, previous/next sentence, rate,
voice, sleep timer, completion, interruption, and stable failure behavior
identical on Android, iOS, and Windows.

Article progress is stored in SQLite schema v5 as segment index plus UTF-16
character offset, together with the content revision and playback settings.
Podcast rows use media duration instead. Restoration is accepted only when the
audio kind and article content revision still match the current load request.
Malformed positions are discarded, unavailable stored voices fall back to the
system voice, and additive migration columns are installed idempotently so an
interrupted upgrade can be retried safely.

Playing progress is debounced to reduce writes. Pause, stop, seek, settings
changes, and controller disposal flush immediately. Completing the final
segment clears the restart record; completing an intermediate segment seeks
and starts the next one. Events for stale item IDs and asynchronous results
from superseded loads are ignored. A sleep timer is process-local and capped
at two hours; it pauses playback but is intentionally not restored after an
app restart.

The article reader creates a speech plan only after the user starts playback.
It displays compact, wrapping controls for playback, sentence navigation,
rate, installed voice, and timer state. The current segment's retained source
range highlights the existing selectable document without replacing its
scroll or selection controller. If progressively extracted content changes
revision, the previous highlight and restart position are not applied to the
new document.

The production composition root installs the Drift playback repository beside
the system TTS adapter. Tests use an in-memory repository and a deterministic
engine to verify restoration through the real reader controls. Core tests
cover stale events, automatic advancement, immediate and debounced
persistence, invalid voices, sleep timer expiry, and disposal.

Rollback may remove the playback controls and inject the unavailable
repository. Schema v5 columns are additive and can remain unused; article
reading and the platform TTS adapter continue to work independently.
