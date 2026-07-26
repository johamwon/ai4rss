# ADR-0017: Vendor-neutral audio contract and speech segmentation

Status: Accepted

River keeps the audio port in `river_domain` and platform-neutral. An
`AudioLoadRequest` identifies the shared `AudioItem` and carries either an
article speech plan or a podcast URI. Article speech plans require contiguous,
zero-based segments and a stable content revision; podcast requests must not
carry speech text. This preserves one queue identity without making the domain
depend on Android TextToSpeech, AVSpeechSynthesizer, Windows speech APIs, or a
cloud provider.

The engine contract exposes capabilities, installed voices, a sanitized event
stream, playback settings, explicit play/pause/resume/stop operations, and a
position that is either media time or article segment plus character offset.
The contract declares bounded rate and pitch ranges; TTS-002 adapters must
validate them again at the platform boundary. Failed events carry only a
stable failure code, not vendor exceptions or article content.

`ArticleSpeechSegmenter` runs locally and deterministically. It retains UTF-16
source offsets so Flutter selections and the future current-sentence highlight
can map back to the reader document. Chinese and English terminators, closing
quotes, decimal points, common abbreviations, paragraph breaks, and bounded
long-sentence splits are handled without breaking surrogate pairs. A segment
receives a language hint only when one script clearly dominates; mixed text
uses the platform default.

Fenced code is represented by one localized placeholder whose source range
covers the block. Raw code is not sent sentence by sentence to system TTS.
Whitespace-only input produces no load request. The default 280 UTF-16 code
unit limit is conservative for native utterance APIs; long-document streaming
and prefetch remain TTS-005 work.

TTS-002 adapters will encode this contract over platform channels and must
prove identical behavior on Android, iOS, and Windows. TTS-003 will own the
queue/player state machine and persistence instead of placing policy in native
adapters.

Rollback can restore the previous minimal engine signature while leaving the
pure-Dart segmenter unused. No schema or persisted user data changes are
introduced.
