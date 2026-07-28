# ADR-0035: Global audio player shell

## Context

River already persists a mixed article and Podcast queue and can continue
playing it through one process-level controller. Navigation was still page
local: readers could open the queue from selected screens, but they could not
see or control the active item while moving between the inbox, reader, Podcast
library and secondary routes.

Placing controls beside `MaterialApp`'s navigator also has a Flutter-specific
constraint. Tooltips, popup menus and other transient surfaces need an
`Overlay` ancestor, while the navigator must retain its existing route stack
and global key.

## Decision

`RiverApp` owns one global audio shell around its existing navigator:

- an outer, bounded `Overlay` hosts the navigator and mini player;
- the mini player appears only when the controller or persistent queue exposes
  an item;
- tapping the item opens a dedicated player page, while the queue icon opens
  the existing full queue;
- both surfaces observe the same `PersistentAudioQueue` and
  `AudioPlaybackController`; they do not copy playback state;
- previous and next controls operate on queue position, while play, pause,
  rate and sleep timer continue through the existing controller contracts.

The player page does not invent a Podcast duration when the engine has not
reported one. It shows elapsed media time or the current article segment
instead.

## Consequences

Audio state remains consistent across every route and process-local playback
continues without page-owned controllers. The extra outer overlay is required
for accessible Windows tooltips and popup menus; its entry is constrained to
the app viewport so narrow layouts cannot acquire unbounded width.

This change does not alter native background audio, media-session or database
contracts. Android, iOS and Windows background-continuity acceptance remains a
physical-device release check.

Widget tests cover the app-level navigation shell, mixed-source controls,
rate, sleep timer, empty state, semantics and 320-pixel layout. A phone Golden
locks the approved full-player surface.

## Rollback

Remove the global shell and restore `MaterialApp`'s navigator as the direct
builder child. The persistent queue, audio controller, native media session
and playback progress remain valid; existing page-level queue entry points
continue to work.
