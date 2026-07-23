# ADR-0010: Reader settings and durable reading state

Status: Accepted

Reader presentation preferences live behind the domain-level
`ReaderSettingsRepository`. A singleton `reader_settings_rows` table stores the
font family, font scale, line height, content width, theme preference and last
update time. The app observes this repository and keeps system text scaling
enabled. Explicit light and dark choices replace only the app theme; the
system choice continues to follow the host platform.

Article read, starred, read-later and scroll-depth state continues to use the
existing article columns. Repository operations write the requested target
value instead of toggling it, so a retry is idempotent. Opening a readable
article marks it read. Scroll depth is clamped to `0..1`, debounced for 450 ms
while scrolling and flushed when the reader closes. Reaching 90 percent marks
the article complete and records the completion time. A reopened reader
restores the stored depth.

System sharing is isolated behind `ShareGateway`. The reader shares only the
article title and canonical URL, never extracted article text. An optional
widget anchor supports iPad share-sheet placement. `share_plus` 12.0.2 is
pinned because the current workspace's vendored file picker requires `win32`
5.x, while share_plus 13.x requires 6.x. Android, iOS and Windows use the same
domain request and platform adapter; adapter tests verify parameter and result
mapping without opening an operating-system share sheet.

Schema v3 is additive. Versioned fixtures cover populated v1 and v2 upgrades,
an interrupted v2 column migration, an interrupted v3 table migration and a
current populated v3 database. A real file-backed test closes and reopens the
database to prove preference persistence. Invalid legacy enum or numeric
values recover to bounded defaults rather than preventing startup.

A rollback must retain schema version 3 and leave `reader_settings_rows` in
place. An older UI may ignore the table, but no release may downgrade or drop
it. The settings and sharing features can be disabled at the composition root
by substituting their ports while article state columns remain readable.
