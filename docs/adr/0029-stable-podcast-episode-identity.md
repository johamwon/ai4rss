# ADR-0029: Stable podcast episode identity

## Decision

POD-001 uses a pure-Dart Podcast RSS parser and refresh service in
`river_feed`. Podcast shows and episodes remain provider-neutral records behind
a repository port. HTTP validators and every application of show metadata plus
episode upserts are delegated to that repository as one atomic refresh.

An episode's publisher GUID is its preferred external identity. When a GUID is
missing, River conservatively falls back to the episode page URL and then the
audio enclosure URL. Duplicate external identities in one document retain the
first feed-ordered entry and are reported in the refresh result. Across
refreshes, a matching identity retains its River ID even when enclosure,
artwork, title, duration, or other metadata changes. An unchanged episode is
not rewritten.

Only HTTP(S), authority-bearing enclosure URLs without embedded credentials
are accepted. An explicit `audio/*` MIME type is required when a type is
present; a bounded list of common audio extensions is used when it is absent.
Invalid optional duration, numbering, explicit, or episode-type metadata
degrades to an unknown value rather than losing a playable episode.

## Consequences

Publisher GUID mistakes can still collapse two entries. River exposes the
duplicate count for diagnostics but does not invent a second identity because
doing so would make later updates unstable. A feed without GUID and without a
stable episode page cannot survive a changed enclosure URL as the same episode;
creating a new episode is safer than silently merging unrelated audio.

POD-001 deliberately does not add a database migration or media player. POD-002
will implement durable show/episode storage, streaming, downloads, and
show-level policy using these records and repository contracts.

## Verification and rollback

The minimized synthetic fixture covers enclosure, artwork, duration, explicit
metadata, numbering, episode type, author, date, relative URLs, and a duplicate
GUID. Tests also cover unsafe or non-audio enclosures, malformed optional
metadata, conditional 304 refreshes, unchanged refreshes, and a changed media
URL retaining the same River episode ID.

Rollback may stop composing `PodcastRefreshService`; existing article-feed
parsing is untouched.
