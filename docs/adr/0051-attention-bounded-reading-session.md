# ADR 0051: Attention-bounded reading sessions

## Status

Accepted for PREF-002.

## Context

Elapsed wall-clock time on an open reader is not equivalent to reading. Mobile
apps can move to the background or lock, desktop windows can be covered, and a
reader can remain untouched for hours. Conversely, a visible split-screen reader
must not be discarded merely because it is not the only application on screen.
A jump to the bottom is useful progress evidence but is not enough on its own to
claim completion.

The state machine must be deterministic across Android, iOS, and Windows and
must feed the versioned PREF-001 event contract without reading global clocks or
random values.

## Decision

1. `ReadingSessionTracker` receives the article ID, domain `Clock`, and
   `IdGenerator`. Starting a session emits one open event. No timer, wall clock,
   or random source is accessed globally.
2. Time is eligible only while the reader page is visible and the session is
   foreground or visible in split-screen. Background, locked-screen, and
   invisible-reader intervals contribute zero duration.
3. Opening, scrolling, and explicit interaction establish attention. Without a
   later interaction, the eligible interval ends at a 60-second idle deadline.
   A return from a long background or lock does not resume counting until new
   interaction.
4. Scroll depth is bounded to 0–1 and retained monotonically as the maximum seen
   depth. Completion requires both at least 90% depth and at least 30 seconds of
   effective reading. This prevents a quick jump to the bottom from generating
   a completion event.
5. Active-read events report only new whole seconds since the previous flush;
   fractional time carries forward. Long unflushed sessions split into
   schema-valid chunks of at most one day. A completion event is emitted once,
   after any newly reportable active-read event.
6. Moving the injected clock backwards, invalid visibility/session operations,
   malformed depth, unsafe configuration, or invalid generated event identity
   fails closed.

## Evidence

- Fake-clock tests cover foreground reading, background/resume, visible
  split-screen, screen lock/unlock, reader-page invisibility, idle hanging, and
  jumping directly to 99% depth.
- A 30-second, 92%-depth session emits open → active read → completion in that
  order.
- Five minutes in background or locked state adds no active time; a ten-minute
  unattended foreground session is capped at 60 seconds.
- Repeated flushes emit only new whole seconds, close is terminal, a backwards
  clock is rejected, and a two-day synthetic session remains within the v1
  event payload bound.

## Consequences and rollback

Platform lifecycle adapters only translate their states into the four stable
visibility values and the page-visible flag; they do not implement their own
duration rules. PREF-003 owns durable retention, clearing, export, and the
capture-enabled privacy switch.

Thresholds are explicit constructor values for controlled experiments, but
production defaults remain 60 seconds idle, 30 seconds effective reading, and
90% completion. A feature rollback can stop constructing trackers without
changing the PREF-001 schema or existing local events.
