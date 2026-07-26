# ADR-0030: Routed podcast media engine

## Decision

River uses one `AudioPlaybackController` and one system media session for
article TTS and podcast audio. A pure-Dart `RoutedAudioEngine` selects the
system-TTS engine for articles and a dedicated `PodcastAudioEngine` for
episodes. Switching content kinds stops the previous engine before loading the
next one; events from both engines retain their item identity and enter the
existing controller stream.

The podcast adapter uses `just_audio` 0.10.6 on Android and iOS and
`just_audio_windows` 0.2.3 on Windows. The latter is the WinRT MediaPlayer
implementation listed by the `just_audio` package as a Windows option. River
wraps the plugin behind `PodcastPlayerBackend`; no plugin type enters
`river_domain` or `river_audio`.

Only HTTP(S) sources without embedded credentials and local `file:` sources
are accepted. Podcast playback supports stream/file loading, pause, resume,
seek and 0.5x–3x speed. Pitch and voice selection remain article-TTS-only.
Plugin exceptions and asynchronous errors are reduced to stable River failure
codes without logging media URLs or plugin messages.

## Consequences

The existing playback repository already stores podcast media positions and
speed, so pause, interruption and periodic progress writes retain their
restart behavior. Background focus, lock-screen controls and Windows SMTC
continue through the shared `AudioSystemSession`.

POD-002 still requires durable downloads, partial-file resume, storage
failures and content validation. Those concerns stay outside the player and
will select a verified local `file:` source when available.

## Verification and rollback

Contract tests cover capability composition, article/podcast routing, engine
switch cleanup, event forwarding, remote playback controls, speed, seeking and
unsafe source rejection. The Windows Debug build verifies plugin registration
and native compilation.

Rollback restores `SystemTtsAudioEngine` as the composition-root engine and
removes the two pinned media-player dependencies. Article TTS and stored
progress remain compatible.
