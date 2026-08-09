PRAGMA user_version = 17;

CREATE TABLE migration_marker (
  id TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO migration_marker (id, value)
VALUES ('v17', 'preserve-before-ranking-experiment');

CREATE TABLE automatic_summary_settings_rows (
  id INTEGER NOT NULL PRIMARY KEY DEFAULT 1,
  enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
  wifi_only INTEGER NOT NULL DEFAULT 1 CHECK (wifi_only IN (0, 1)),
  daily_limit INTEGER NOT NULL DEFAULT 3,
  minimum_ranking_score REAL NOT NULL DEFAULT 0.7,
  updated_at INTEGER NOT NULL
);

INSERT INTO automatic_summary_settings_rows VALUES (
  1, 1, 1, 5, 0.75, 1785945600
);

CREATE TABLE automatic_summary_usage_rows (
  idempotency_key TEXT NOT NULL PRIMARY KEY,
  article_id TEXT NOT NULL,
  day_key TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX automatic_summary_usage_day_idx
ON automatic_summary_usage_rows(day_key, status);
