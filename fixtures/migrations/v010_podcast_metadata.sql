PRAGMA foreign_keys = ON;

CREATE TABLE podcast_shows (
  id TEXT NOT NULL PRIMARY KEY,
  canonical_feed_url TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  author TEXT,
  website_url TEXT,
  image_url TEXT,
  language TEXT,
  explicit_rating TEXT NOT NULL,
  default_playback_rate REAL NOT NULL DEFAULT 1,
  download_policy TEXT NOT NULL DEFAULT 'manual',
  etag TEXT,
  last_modified TEXT,
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

CREATE TABLE audio_queue_entries (
  item_id TEXT NOT NULL PRIMARY KEY,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  source_uri TEXT NOT NULL,
  content_revision TEXT,
  queue_position INTEGER NOT NULL,
  is_current INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
  enqueued_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

INSERT INTO podcast_shows VALUES (
  'show-v10',
  'https://example.test/podcast-v10.xml',
  'Podcast before metadata migration',
  'Existing description',
  'River Lab',
  'https://example.test/podcast',
  'https://example.test/show.jpg',
  'zh-CN',
  'clean',
  1.25,
  'manual',
  '"v10"',
  'Mon, 27 Jul 2026 10:00:00 GMT',
  1785124800,
  1785124800,
  1785124800
);

INSERT INTO podcast_episodes VALUES (
  'episode-v10',
  'show-v10',
  'external-v10',
  'Episode before metadata migration',
  'Existing episode description',
  'River Host',
  'https://example.test/episodes/v10',
  'https://example.test/audio/v10.mp3',
  'https://example.test/episode-v10.jpg',
  'audio/mpeg',
  2048,
  1785124800,
  3600000,
  10,
  1,
  'clean',
  'full',
  1785124800,
  1785124800
);

INSERT INTO audio_queue_entries VALUES (
  'episode-v10',
  'podcastEpisode',
  'Episode before metadata migration',
  'https://example.test/audio/v10.mp3',
  NULL,
  0,
  1,
  1785124800,
  1785124800
);

PRAGMA user_version = 10;
