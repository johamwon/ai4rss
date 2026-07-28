PRAGMA foreign_keys = ON;

CREATE TABLE feed_subscriptions (
  id TEXT NOT NULL PRIMARY KEY,
  canonical_url TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  folder_id TEXT,
  feed_kind TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  etag TEXT,
  last_modified TEXT,
  last_refreshed_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE articles (
  id TEXT NOT NULL PRIMARY KEY,
  feed_id TEXT NOT NULL REFERENCES feed_subscriptions(id) ON DELETE CASCADE,
  canonical_url TEXT NOT NULL,
  title TEXT NOT NULL,
  author TEXT,
  published_at INTEGER,
  feed_summary TEXT,
  feed_content_html TEXT,
  read_state TEXT NOT NULL DEFAULT 'unread',
  starred INTEGER NOT NULL DEFAULT 0 CHECK (starred IN (0, 1)),
  read_later INTEGER NOT NULL DEFAULT 0 CHECK (read_later IN (0, 1)),
  active_read_seconds INTEGER NOT NULL DEFAULT 0,
  scroll_depth REAL NOT NULL DEFAULT 0,
  completed_at INTEGER,
  content_hash TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(feed_id, canonical_url)
);

INSERT INTO feed_subscriptions VALUES (
  'feed-v11',
  'https://example.test/feed-v11.xml',
  'Feed before annotation migration',
  NULL,
  'rss',
  1,
  NULL,
  NULL,
  1785211200,
  1785211200,
  1785211200
);

INSERT INTO articles VALUES (
  'article-v11',
  'feed-v11',
  'https://example.test/articles/v11',
  'Article before annotation migration',
  'River Author',
  1785211200,
  'Existing content remains readable',
  '<p>Existing selected fact remains readable.</p>',
  'read',
  1,
  0,
  90,
  0.75,
  NULL,
  'sha256:v11',
  1785211200,
  1785211200
);

PRAGMA user_version = 11;
