PRAGMA user_version = 13;

CREATE TABLE migration_marker (
  id TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO migration_marker (id, value)
VALUES ('v13', 'preserve-before-ai-cache');
