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

CREATE TABLE knowledge_items (
  id TEXT NOT NULL PRIMARY KEY,
  article_id TEXT REFERENCES articles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  original_url TEXT NOT NULL,
  markdown TEXT NOT NULL,
  summary_json TEXT,
  tags_json TEXT NOT NULL DEFAULT '[]',
  content_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE article_annotations (
  id TEXT NOT NULL PRIMARY KEY,
  article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  exact_text TEXT NOT NULL,
  prefix_text TEXT NOT NULL,
  suffix_text TEXT NOT NULL,
  original_start INTEGER NOT NULL,
  original_end INTEGER NOT NULL,
  content_revision TEXT NOT NULL,
  start_dom_path TEXT NOT NULL,
  start_dom_offset INTEGER NOT NULL,
  end_dom_path TEXT NOT NULL,
  end_dom_offset INTEGER NOT NULL,
  color TEXT NOT NULL DEFAULT 'yellow',
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

INSERT INTO feed_subscriptions VALUES (
  'feed-v12',
  'https://example.test/feed-v12.xml',
  'Feed before knowledge migration',
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
  'article-v12',
  'feed-v12',
  'https://example.test/articles/v12',
  'Article before knowledge migration',
  'River Author',
  1785211200,
  'Existing knowledge remains readable',
  '<p>Existing knowledge remains readable.</p>',
  'read',
  1,
  0,
  90,
  0.75,
  NULL,
  'sha256:v12',
  1785211200,
  1785211200
);

INSERT INTO knowledge_items VALUES (
  'knowledge-v12',
  'article-v12',
  'Legacy knowledge',
  'https://example.test/articles/v12',
  '# Legacy knowledge',
  NULL,
  '["legacy"]',
  'legacy-hash',
  1785211200,
  1785211200
);

INSERT INTO knowledge_items VALUES (
  'knowledge-v12-duplicate',
  'article-v12',
  'Second legacy knowledge',
  'https://example.test/articles/v12',
  '# Second legacy knowledge',
  NULL,
  '["legacy","second"]',
  'legacy-hash-second',
  1785211260,
  1785211260
);

PRAGMA user_version = 12;
