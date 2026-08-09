PRAGMA user_version = 15;

CREATE TABLE migration_marker (
  id TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO migration_marker (id, value)
VALUES ('v15', 'preserve-before-preference-controls');

CREATE TABLE reading_behavior_settings_rows (
  id TEXT NOT NULL PRIMARY KEY,
  capture_enabled INTEGER NOT NULL DEFAULT 1
    CHECK (capture_enabled IN (0, 1)),
  retention_days INTEGER NOT NULL DEFAULT 90,
  updated_at INTEGER NOT NULL
);

INSERT INTO reading_behavior_settings_rows VALUES (
  'reading-behavior', 0, 30, 1785340800
);
