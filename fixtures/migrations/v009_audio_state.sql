PRAGMA foreign_keys = ON;

CREATE TABLE audio_items (
  id TEXT NOT NULL PRIMARY KEY,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  source_uri TEXT NOT NULL,
  position_ms INTEGER NOT NULL DEFAULT 0,
  segment_index INTEGER,
  character_offset INTEGER,
  content_revision TEXT,
  duration_ms INTEGER,
  playback_rate REAL NOT NULL DEFAULT 1,
  pitch REAL NOT NULL DEFAULT 1,
  voice_id TEXT,
  language_tag TEXT,
  downloaded_path TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE podcast_shows (
  id TEXT NOT NULL PRIMARY KEY,
  canonical_feed_url TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  author TEXT,
  image_url TEXT,
  etag TEXT,
  last_modified TEXT,
  default_playback_rate REAL NOT NULL DEFAULT 1,
  download_policy TEXT NOT NULL DEFAULT 'manual',
  last_refreshed_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE podcast_episodes (
  id TEXT NOT NULL PRIMARY KEY,
  show_id TEXT NOT NULL REFERENCES podcast_shows(id) ON DELETE CASCADE,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  author TEXT,
  episode_url TEXT,
  media_url TEXT NOT NULL,
  image_url TEXT,
  media_mime_type TEXT,
  media_length_bytes INTEGER,
  published_at INTEGER,
  duration_ms INTEGER,
  episode_number INTEGER,
  season_number INTEGER,
  explicit_rating TEXT NOT NULL,
  episode_type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(show_id, external_id)
);

CREATE TABLE podcast_downloads (
  episode_id TEXT NOT NULL PRIMARY KEY
    REFERENCES podcast_episodes(id) ON DELETE CASCADE,
  state TEXT NOT NULL DEFAULT 'notDownloaded',
  source_url TEXT,
  partial_path TEXT,
  available_path TEXT,
  downloaded_bytes INTEGER NOT NULL DEFAULT 0,
  total_bytes INTEGER,
  etag TEXT,
  failure_code TEXT,
  updated_at INTEGER NOT NULL
);

INSERT INTO audio_items (
  id, kind, title, source_uri, position_ms, segment_index, character_offset,
  content_revision, duration_ms, playback_rate, pitch, voice_id, language_tag,
  downloaded_path, created_at, updated_at
) VALUES (
  'audio-v9', 'podcastEpisode', 'Persisted v9 episode',
  'https://example.test/audio-v9.mp3', 42000, NULL, NULL, NULL, 180000,
  1.25, 1, NULL, NULL, NULL, 1784995200, 1784995260
);

INSERT INTO podcast_shows VALUES (
  'show-v9', 'https://example.test/feed.xml', 'River v9 Show',
  'Migration fixture', 'River', NULL, '"feed-v9"', NULL, 1.25, 'manual',
  1784995200, 1784995200, 1784995200
);

INSERT INTO podcast_episodes VALUES (
  'episode-v9', 'show-v9', 'guid-v9', 'Persisted v9 episode',
  NULL, NULL, 'https://example.test/episodes/v9',
  'https://example.test/audio-v9.mp3', NULL, 'audio/mpeg', 2048,
  1784995200, 180000, 9, 1, 'clean', 'full',
  1784995200, 1784995200
);

INSERT INTO podcast_downloads VALUES (
  'episode-v9', 'downloading', 'https://example.test/audio-v9.mp3',
  'C:\River\episode-v9.part', NULL, 1024, 2048, '"media-v9"', NULL,
  1784995260
);

PRAGMA user_version = 9;
