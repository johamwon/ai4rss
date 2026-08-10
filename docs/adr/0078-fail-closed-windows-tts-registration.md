# 0078 Fail-closed Windows TTS registration

## Context

`flutter_tts` 4.2.5 constructs Windows speech synthesis and media playback objects while its native plugin is being registered, before Dart `main` runs. Windows editions or execution environments without an activatable speech/media component can throw from that constructor. The upstream registration function lets the exception cross its C ABI boundary, which terminates the complete River process with Windows fast-fail `0xC0000409`.

## Decision

- River keeps the reviewed 4.2.5 package as a source-controlled local dependency, including its upstream licence.
- The Windows registration implementation constructs the plugin inside a catch-all native boundary before installing its method-channel handler.
- If native speech activation fails, registration returns without a channel. Dart observes TTS as unavailable through the existing platform adapter; Feed, reading, knowledge, AI, Podcast, and settings remain usable.
- Android, iOS, macOS, Web, and the successful Windows registration path remain unchanged.

## Consequences

- Windows variants without speech/media components no longer crash during startup.
- System TTS is unavailable on those variants until the missing Windows component is installed, which is preferable to losing the whole application.
- Upgrading `flutter_tts` requires reviewing whether upstream has fixed this boundary and replaying the real Windows startup and TTS smoke tests.

## Evidence

- A repository test pins the local dependency and its exception boundary.
- A clean Windows Release build must remain alive through the startup smoke before a package can be handed off.
