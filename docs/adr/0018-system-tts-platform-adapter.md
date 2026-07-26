# ADR-0018: System TTS platform adapter

Status: Accepted

River implements `AudioEngine` with a `SystemTtsAudioEngine` adapter in
`river_platform`. The adapter wraps the pinned `flutter_tts` 4.2.5 plugin,
whose native implementations use Android TextToSpeech, iOS
AVSpeechSynthesizer, and Windows system speech. The dependency is hidden behind
River's domain port and a small `SystemTtsClient` seam; app and feature code do
not import plugin or vendor types.

The adapter speaks one source-mapped segment at a time. Native word progress is
translated to the segment's absolute UTF-16 character offset, including after
a seek or resume. Android restarts the remaining substring after pause, whereas
iOS and Windows continue the original native utterance; the adapter uses the
correct progress-coordinate base for each behavior. Segment completion remains
an engine event; queue advancement and article completion policy belong to
TTS-003. Podcast loads are rejected
with a stable code because podcast media playback will use a dedicated native
backend behind the same domain contract.

Capabilities are truthful by target platform. Android, iOS, and Windows expose
article speech, pause/resume, seek-by-restart, rate, pitch, and voice selection;
unsupported Flutter targets remain side-effect free. Domain rate 1.0 maps to
the plugin's normalized 0.5 value, while the full 0.5x–3.0x River range maps
into 0.25–1.0. Native voice maps are reduced to stable ID, name, locale, and
local/network status. Malformed voices are ignored.

All vendor exceptions and callback payloads are converted into a bounded
failure-code vocabulary. Raw errors, article text, and native voice metadata
never leave the adapter. Matching command and native callbacks are
deduplicated. Android declares TTS service package visibility. Windows does not
support the plugin's clear-voice method, so a null voice leaves the current
system selection unchanged instead of producing a false failure; the future
settings UI must describe this platform behavior.

The production composition root installs the system adapter; tests use the
side-effect-free unavailable engine or a fake client. Merge and Nightly build
all three native targets. A Windows runner integration smoke lists installed
voices and completes a short real system utterance; Android and iOS build
compilation remains automated, with physical-device speech output retained as
a release acceptance gate.

Rollback removes the adapter from the composition root and restores
`UnavailableAudioEngine`. Article reading, extraction, and stored data are
unaffected.
