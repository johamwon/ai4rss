PRAGMA user_version = 14;

CREATE TABLE migration_marker (
  id TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO migration_marker (id, value)
VALUES ('v14', 'preserve-before-reading-behavior-settings');
