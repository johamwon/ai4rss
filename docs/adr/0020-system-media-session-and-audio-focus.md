# ADR-0020: System media session and audio focus

Status: Accepted

River keeps playback policy in the platform-neutral
`AudioPlaybackController` and adds an `AudioSystemSession` port for operating
system commands, metadata, playback state, audio focus, interruptions, and
route changes. The controller remains the only owner of automatic-resume
policy. It may resume only when playback was active before an interruption and
the operating system explicitly permits resumption. A becoming-noisy event,
such as unplugging headphones, always pauses and never authorizes a later
automatic resume.

Android and iOS use pinned `audio_service` and `audio_session` adapters. They
provide the foreground media service, notification or lock-screen controls,
headset commands, audio-session activation, interruption events, and noisy
route events. The Android runner declares wake-lock and media-playback
foreground-service permissions, the audio service, and media-button receiver.
The iOS runner declares the audio background mode. The speech audio-session
configuration is applied after plugin initialization so TTS does not silently
replace the requested focus policy.

Windows owns a small C++/WinRT adapter instead of depending on the young,
unverified `audio_service_win` package. The adapter publishes title, playback
status, and available next/previous actions through
`SystemMediaTransportControls`. Button events are posted back to the Flutter
window thread before crossing the method channel. The channel exposes only
bounded domain fields and stable command names. The adapter unregisters its
event token and releases the channel before the Flutter engine is destroyed.

The application composition root owns one playback controller and system
session for the process lifetime. Reader routes subscribe to that shared
controller but do not dispose it, allowing notification, lock-screen, headset,
and Windows SMTC commands to continue after navigation. Test compositions may
still inject unavailable or deterministic adapters without initializing
plugins.

Windows compilation enables MSVC `/utf-8` while retaining `/WX`, preventing
third-party plugin source characters from failing on non-English system code
pages without weakening warning policy. Unit tests cover focus denial, command
routing, state publication, interruption authorization, and headphone removal.
A Windows device integration test creates, publishes, deactivates, and clears
the real native media session. Android and iOS builds validate registration;
physical lock-screen, incoming-call, Bluetooth, and process-background
acceptance remain release-device matrix work.

Rollback injects `UnavailableAudioSystemSession`, removes native registration,
and leaves the TTS engine and restartable playback controller functional.
