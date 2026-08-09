PRAGMA user_version = 16;

CREATE TABLE migration_marker (
  id TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO migration_marker (id, value)
VALUES ('v16', 'preserve-before-automatic-summaries');

CREATE TABLE reading_behavior_settings_rows (
  id TEXT NOT NULL PRIMARY KEY,
  capture_enabled INTEGER NOT NULL DEFAULT 1
    CHECK (capture_enabled IN (0, 1)),
  retention_days INTEGER NOT NULL DEFAULT 90,
  updated_at INTEGER NOT NULL,
  source_score_adjustments_json TEXT NOT NULL DEFAULT '{}',
  topic_score_adjustments_json TEXT NOT NULL DEFAULT '{}',
  blocked_source_ids_json TEXT NOT NULL DEFAULT '[]',
  blocked_topics_json TEXT NOT NULL DEFAULT '[]'
);

INSERT INTO reading_behavior_settings_rows VALUES (
  'reading-behavior', 1, 90, 1785340800,
  '{"feed-1":2.0}', '{}', '[]', '[]'
);
