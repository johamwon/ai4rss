PRAGMA foreign_keys = ON;

CREATE TABLE folders (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE feed_subscriptions (
  id TEXT NOT NULL PRIMARY KEY,
  canonical_url TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  folder_id TEXT REFERENCES folders(id),
  feed_kind TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
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
  starred INTEGER NOT NULL DEFAULT 0,
  read_later INTEGER NOT NULL DEFAULT 0,
  active_read_seconds INTEGER NOT NULL DEFAULT 0,
  scroll_depth REAL NOT NULL DEFAULT 0,
  completed_at INTEGER,
  content_hash TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(feed_id, canonical_url)
);
CREATE TABLE article_contents (
  article_id TEXT NOT NULL PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  sanitized_html TEXT NOT NULL,
  markdown TEXT NOT NULL,
  plain_text TEXT NOT NULL,
  extractor_name TEXT NOT NULL,
  extractor_version TEXT NOT NULL,
  etag TEXT,
  last_modified TEXT,
  extracted_at INTEGER NOT NULL,
  failure_code TEXT
);
CREATE TABLE reading_events (
  id TEXT NOT NULL PRIMARY KEY,
  article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  event_key TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  active_seconds INTEGER NOT NULL DEFAULT 0,
  completion_ratio REAL NOT NULL DEFAULT 0
);
CREATE TABLE reader_settings_rows (
  id TEXT NOT NULL PRIMARY KEY,
  font_family TEXT NOT NULL DEFAULT 'system',
  font_scale REAL NOT NULL DEFAULT 1,
  line_height REAL NOT NULL DEFAULT 1.75,
  content_width REAL NOT NULL DEFAULT 760,
  theme TEXT NOT NULL DEFAULT 'system',
  updated_at INTEGER NOT NULL
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
CREATE TABLE audio_items (
  id TEXT NOT NULL PRIMARY KEY,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  source_uri TEXT NOT NULL,
  position_ms INTEGER NOT NULL DEFAULT 0,
  duration_ms INTEGER,
  playback_rate REAL NOT NULL DEFAULT 1,
  downloaded_path TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE background_jobs (
  id TEXT NOT NULL PRIMARY KEY,
  type TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  attempt INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 5,
  available_at INTEGER NOT NULL,
  lease_until INTEGER,
  last_error_code TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE sync_tombstones (
  id TEXT NOT NULL PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  deleted_at INTEGER NOT NULL,
  device_id TEXT NOT NULL,
  UNIQUE(entity_type, entity_id)
);

INSERT INTO folders VALUES ('folder-1', 'Technology', 0, 1784390400, 1784390400);
INSERT INTO feed_subscriptions VALUES (
  'feed-1', 'https://example.test/feed.xml', 'Synthetic River Feed',
  'folder-1', 'rss', 1, NULL, NULL, 1784390400, 1784390400, 1784390400
);
INSERT INTO articles VALUES (
  'article-1', 'feed-1', 'https://example.test/article-1',
  'River v4 migration fixture', 'River Lab', 1784390400,
  'Saved reading state', '<p>Current immediate body</p>', 'read', 1, 1,
  82, 0.63, NULL, NULL, 1784390400, 1784390400
);
INSERT INTO reader_settings_rows VALUES (
  'default', 'serif', 1.2, 1.9, 680, 'dark', 1784390400
);

CREATE VIRTUAL TABLE article_search_index USING fts5(
  article_id UNINDEXED,
  title,
  author,
  source,
  summary,
  body,
  tags,
  notes,
  tokenize='trigram'
);

INSERT INTO article_search_index(
  article_id, title, author, source, summary, body, tags, notes
)
SELECT
  a.id,
  a.title,
  COALESCE(a.author, ''),
  f.title,
  COALESCE(a.feed_summary, ''),
  COALESCE(c.plain_text, ''),
  COALESCE((
    SELECT group_concat(k.tags_json, ' ')
    FROM knowledge_items k WHERE k.article_id = a.id
  ), ''),
  COALESCE((
    SELECT group_concat(
      COALESCE(k.summary_json, '') || ' ' || COALESCE(k.markdown, ''), ' '
    )
    FROM knowledge_items k WHERE k.article_id = a.id
  ), '')
FROM articles a
INNER JOIN feed_subscriptions f ON f.id = a.feed_id
LEFT JOIN article_contents c ON c.article_id = a.id;

CREATE TRIGGER article_search_articles_ai AFTER INSERT ON articles BEGIN
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT new.id, new.title, COALESCE(new.author, ''), f.title,
    COALESCE(new.feed_summary, ''), '', '', ''
  FROM feed_subscriptions f WHERE f.id = new.feed_id;
END;

CREATE TRIGGER article_search_articles_au
AFTER UPDATE OF title, author, feed_summary, feed_id ON articles BEGIN
  DELETE FROM article_search_index WHERE article_id = new.id;
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), COALESCE(c.plain_text, ''),
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a
  INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  LEFT JOIN article_contents c ON c.article_id = a.id
  WHERE a.id = new.id;
END;

CREATE TRIGGER article_search_articles_ad AFTER DELETE ON articles BEGIN
  DELETE FROM article_search_index WHERE article_id = old.id;
END;

CREATE TRIGGER article_search_contents_ai AFTER INSERT ON article_contents BEGIN
  DELETE FROM article_search_index WHERE article_id = new.article_id;
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), new.plain_text,
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  WHERE a.id = new.article_id;
END;

CREATE TRIGGER article_search_contents_au
AFTER UPDATE OF plain_text ON article_contents BEGIN
  DELETE FROM article_search_index WHERE article_id = new.article_id;
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), new.plain_text,
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  WHERE a.id = new.article_id;
END;

CREATE TRIGGER article_search_contents_ad AFTER DELETE ON article_contents BEGIN
  DELETE FROM article_search_index WHERE article_id = old.article_id;
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), '',
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  WHERE a.id = old.article_id;
END;

CREATE TRIGGER article_search_feeds_au
AFTER UPDATE OF title ON feed_subscriptions BEGIN
  DELETE FROM article_search_index
  WHERE article_id IN (SELECT id FROM articles WHERE feed_id = new.id);
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), new.title,
    COALESCE(a.feed_summary, ''), COALESCE(c.plain_text, ''),
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a LEFT JOIN article_contents c ON c.article_id = a.id
  WHERE a.feed_id = new.id;
END;

CREATE TRIGGER article_search_knowledge_ai
AFTER INSERT ON knowledge_items WHEN new.article_id IS NOT NULL BEGIN
  DELETE FROM article_search_index WHERE article_id = new.article_id;
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), COALESCE(c.plain_text, ''),
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  LEFT JOIN article_contents c ON c.article_id = a.id
  WHERE a.id = new.article_id;
END;

CREATE TRIGGER article_search_knowledge_au
AFTER UPDATE OF article_id, summary_json, tags_json, markdown
ON knowledge_items BEGIN
  DELETE FROM article_search_index
  WHERE article_id IN (old.article_id, new.article_id);
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), COALESCE(c.plain_text, ''),
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  LEFT JOIN article_contents c ON c.article_id = a.id
  WHERE a.id IN (old.article_id, new.article_id);
END;

CREATE TRIGGER article_search_knowledge_ad
AFTER DELETE ON knowledge_items WHEN old.article_id IS NOT NULL BEGIN
  DELETE FROM article_search_index WHERE article_id = old.article_id;
  INSERT INTO article_search_index(
    article_id, title, author, source, summary, body, tags, notes
  )
  SELECT a.id, a.title, COALESCE(a.author, ''), f.title,
    COALESCE(a.feed_summary, ''), COALESCE(c.plain_text, ''),
    COALESCE((SELECT group_concat(k.tags_json, ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), ''),
    COALESCE((SELECT group_concat(COALESCE(k.summary_json, '') || ' ' ||
      COALESCE(k.markdown, ''), ' ') FROM knowledge_items k
      WHERE k.article_id = a.id), '')
  FROM articles a INNER JOIN feed_subscriptions f ON f.id = a.feed_id
  LEFT JOIN article_contents c ON c.article_id = a.id
  WHERE a.id = old.article_id;
END;

PRAGMA user_version = 4;
