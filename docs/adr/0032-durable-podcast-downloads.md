# ADR-0032: Durable Podcast downloads

## Decision

Podcast downloads use the existing SQLite-backed `PersistentJobQueue` with the
versioned job type `podcast-download/v1`. A job payload contains only an
`episodeId`; every attempt reloads the current Episode and never persists a
remote media URL in queue JSON.

`podcast_downloads` owns transfer state independently from Episode metadata and
audio playback progress. Database schema v9 adds a nullable `source_url` to
bind partial and available files to the enclosure that produced them. A source
change discards the stale artifact and resets the completed job before any
redownload. The migration adds the column only when missing, so both a real v8
database and a process interruption after `ALTER TABLE` recover safely.

`DurablePodcastDownloadManager` owns the state machine:

`notDownloaded -> queued -> downloading -> available|failed`

Network and timeout failures retain partial bytes and use bounded exponential
backoff. Reconnection expedites only queued network/timeout failures. Startup
recovers Podcast download leases, including unexpired leases left by the
previous process. Storage-full failures retain their partial file for an
explicit retry; corrupt media removes the partial file. Delete cancels queued
work, removes both partial and available files, and permits a clean redownload.

## Platform transfer contract

`IoPodcastTransferBackend` is shared by Android, iOS and Windows. It stores
files under the application's support directory, derives opaque filenames from
SHA-256 Episode IDs, and supports:

- bounded HTTP(S) redirects without credentials or HTTPS downgrade;
- `Range` plus `If-Range` continuation using the saved byte count and ETag;
- safe restart from byte zero when a server ignores Range;
- a two-GiB default response bound and exact response-length checks;
- common MP3, MP4/M4A, Ogg/Opus and WAV signature validation;
- stable failures without logging source URLs or native error details.

All filesystem deletion is confined to the configured Podcast directory.
Platform storage and HTTP behavior remain injectable for deterministic tests.

## Verification

Coordinator tests cover network reconnection, storage full, corrupt media,
delete/redownload and cold restart with an unexpired lease. Real loopback HTTP
tests cover byte-range continuation, Range rejection fallback, corrupt
length-correct media and credentialed redirects. Migration tests cover both a
v8 table missing `source_url` and an interrupted v9 migration where the column
already exists.

## Rollback

The application may stop composing the manager and leave Podcast files
untouched. A shipped v9 database must not be downgraded in place. Restore a
pre-upgrade backup or use a build explicitly validated to tolerate a newer
schema. The nullable v9 column does not change existing Show or Episode rows.
