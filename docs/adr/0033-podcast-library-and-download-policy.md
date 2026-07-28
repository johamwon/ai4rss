# ADR-0033: Podcast library and download policy

## Decision

Podcast is a first-class destination from the existing River home app bar. The
library accepts safe HTTP(S) Podcast RSS addresses, watches persisted Shows,
and opens a Show page that watches Episodes. This keeps the existing article
inbox navigation stable while making Podcast discovery, refresh, playback and
download available without a separate application mode.

The Show owns a default playback rate and one of three download policies:

- `manual` never queues work automatically;
- `newestOnly` ensures the newest Episode is queued after each refresh and when
  the policy is selected;
- `all` queues only newly inserted Episodes after refresh, while explicitly
  selecting the policy queues all currently known Episodes.

Download enqueue returns after the durable job and state are committed. The
transfer runs asynchronously so adding a large back catalog never blocks the
UI. The existing serial job worker still bounds actual transfers.

Before playback, the manager verifies that an `available` file still exists
inside the Podcast directory. A missing file clears stale state. The Show page
then resolves the source as verified local file first and remote enclosure
second, loads it through the shared audio controller, and applies the Show's
default rate. Existing Podcast playback progress remains keyed by Episode ID,
independent of source choice.

Deleting a Show first removes every Episode download through the manager, then
deletes the Show. SQLite cascades Episode and download rows, while the explicit
manager step prevents orphaned media files.

## Verification

Widget tests cover the River Podcast entry, empty library, safe address
validation, Episode rendering, verified local-file playback, Show rate
application and downloaded-file deletion. Policy tests cover newest-only,
all-new and an explicit switch to all. Repository tests cover live Show and
Episode streams plus delete cascade. Download tests cover a missing local file
falling back to `notDownloaded`.

## Rollback

The Podcast destination may be hidden without changing stored Shows, Episodes,
downloads or playback progress. Policy execution can be disabled while manual
download remains available. No schema change is introduced by this decision.
