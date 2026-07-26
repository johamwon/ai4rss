import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  test('v1 fixture migrates to v9 without losing article state', () async {
    final fixture = await _materializeFixture('v001_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.title, 'River v1 migration fixture');
    expect(article.feedSummary, 'Existing preview survives migration');
    expect(article.starred, isTrue);
    expect(article.feedContentHtml, isNull);
    expect(await _userVersion(migrated), 9);
    expect(
      await _syncTableNames(migrated),
      containsAll(<String>[
        'sync_replica_entries',
        'sync_outbox_rows',
        'sync_cursor_rows',
        'sync_conflict_rows',
        'sync_seen_mutation_rows',
      ]),
    );
    expect(
      await DriftReaderSettingsRepository(migrated).watchSettings().first,
      const ReaderSettings(),
    );
  });

  test('interrupted v2 column addition retries idempotently', () async {
    final fixture = await _materializeFixture('v001_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('ALTER TABLE articles ADD COLUMN feed_content_html TEXT')
      ..execute(
        "UPDATE articles SET feed_content_html = '<p>Recovered body</p>'",
      )
      ..close();
    final recovered = await _openFixture(fixture);

    final article = await recovered.select(recovered.articles).getSingle();
    expect(article.feedContentHtml, '<p>Recovered body</p>');
    expect(await _userVersion(recovered), 9);
  });

  test('v2 fixture creates the settings table and preserves article', () async {
    final fixture = await _materializeFixture('v002_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.feedContentHtml, '<p>Current immediate body</p>');
    expect(await _userVersion(migrated), 9);
    expect(
      await DriftReaderSettingsRepository(migrated).watchSettings().first,
      const ReaderSettings(),
    );
  });

  test('interrupted v3 table creation retries idempotently', () async {
    final fixture = await _materializeFixture('v002_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('''
        CREATE TABLE reader_settings_rows (
          id TEXT NOT NULL PRIMARY KEY,
          font_family TEXT NOT NULL DEFAULT 'system',
          font_scale REAL NOT NULL DEFAULT 1,
          line_height REAL NOT NULL DEFAULT 1.75,
          content_width REAL NOT NULL DEFAULT 760,
          theme TEXT NOT NULL DEFAULT 'system',
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        INSERT INTO reader_settings_rows VALUES
        ('default', 'serif', 1.3, 1.9, 700, 'dark', 1784390400)
      ''')
      ..close();
    final recovered = await _openFixture(fixture);

    final settings = await DriftReaderSettingsRepository(
      recovered,
    ).watchSettings().first;
    expect(settings.fontFamily, ReaderFontFamily.serif);
    expect(settings.fontScale, 1.3);
    expect(settings.theme, ReaderThemePreference.dark);
    expect(await _userVersion(recovered), 9);
  });

  test('v3 fixture creates a searchable index without data loss', () async {
    final fixture = await _materializeFixture('v003_populated.sql');
    final current = await _openFixture(fixture);

    final article = await current.select(current.articles).getSingle();
    expect(article.scrollDepth, 0.63);
    expect(article.starred, isTrue);
    final settings = await DriftReaderSettingsRepository(
      current,
    ).watchSettings().first;
    expect(settings.fontFamily, ReaderFontFamily.serif);
    expect(settings.contentWidth, 680);
    expect(settings.theme, ReaderThemePreference.dark);
    expect(
      (await DriftFeedRepository(current)
              .watchSearch(
                const ArticleSearchQuery(text: 'Saved reading state'),
              )
              .first)
          .single
          .article
          .id,
      'article-1',
    );
    expect(await _userVersion(current), 9);
  });

  test('interrupted v4 index creation rebuilds and creates triggers', () async {
    final fixture = await _materializeFixture('v003_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('''
        CREATE VIRTUAL TABLE article_search_index USING fts5(
          article_id UNINDEXED, title, author, source, summary, body,
          tags, notes, tokenize='trigram'
        )
      ''')
      ..execute('''
        INSERT INTO article_search_index VALUES
        ('stale', 'partial row', '', '', '', '', '', '')
      ''')
      ..close();
    final recovered = await _openFixture(fixture);

    final rows = await recovered
        .customSelect('SELECT article_id FROM article_search_index')
        .get();
    expect(rows.map((row) => row.read<String>('article_id')), <String>[
      'article-1',
    ]);
    expect(await _searchTriggerCount(recovered), 10);
    expect(await _userVersion(recovered), 9);
  });

  test('v4 fixture adds restartable audio state with index intact', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final current = await _openFixture(fixture);

    expect(
      (await current.select(current.articles).getSingle()).starred,
      isTrue,
    );
    expect(
      (await DriftFeedRepository(
            current,
          ).watchSearch(const ArticleSearchQuery(text: 'River v4')).first)
          .single
          .article
          .id,
      'article-1',
    );
    expect(await _searchTriggerCount(current), 10);
    expect(
      await _audioColumnNames(current),
      containsAll(<String>[
        'segment_index',
        'character_offset',
        'content_revision',
        'pitch',
        'voice_id',
        'language_tag',
      ]),
    );
    expect(await _userVersion(current), 9);
  });

  test('interrupted v5 audio column additions retry idempotently', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute(
        'ALTER TABLE audio_items '
        'ADD COLUMN segment_index INTEGER NULL',
      )
      ..close();
    final recovered = await _openFixture(fixture);

    expect(
      await _audioColumnNames(recovered),
      containsAll(<String>[
        'segment_index',
        'character_offset',
        'content_revision',
        'pitch',
        'voice_id',
        'language_tag',
      ]),
    );
    expect(await _userVersion(recovered), 9);
  });

  test('interrupted v6 sync table creation retries idempotently', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('ALTER TABLE audio_items ADD COLUMN segment_index INTEGER NULL')
      ..execute(
        'ALTER TABLE audio_items ADD COLUMN character_offset INTEGER NULL',
      )
      ..execute('ALTER TABLE audio_items ADD COLUMN content_revision TEXT NULL')
      ..execute(
        'ALTER TABLE audio_items ADD COLUMN pitch REAL NOT NULL DEFAULT 1',
      )
      ..execute('ALTER TABLE audio_items ADD COLUMN voice_id TEXT NULL')
      ..execute('ALTER TABLE audio_items ADD COLUMN language_tag TEXT NULL')
      ..execute('''
        CREATE TABLE sync_replica_entries (
          account_id TEXT NOT NULL,
          object_kind TEXT NOT NULL,
          object_id TEXT NOT NULL,
          envelope_json TEXT NOT NULL,
          clear_payload_json TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (account_id, object_kind, object_id)
        )
      ''')
      ..execute('PRAGMA user_version = 5')
      ..close();
    final recovered = await _openFixture(fixture);

    expect(
      await _syncTableNames(recovered),
      containsAll(<String>[
        'sync_replica_entries',
        'sync_outbox_rows',
        'sync_cursor_rows',
        'sync_conflict_rows',
        'sync_seen_mutation_rows',
      ]),
    );
    expect(await _userVersion(recovered), 9);
  });

  test('interrupted v7 sync history migration retries idempotently', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final prepared = RiverDatabase(NativeDatabase(fixture));
    await prepared.verifyReady();
    await prepared.close();
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('DROP TABLE sync_seen_mutation_rows')
      ..execute('ALTER TABLE sync_conflict_rows RENAME TO old_conflicts')
      ..execute('''
        CREATE TABLE sync_conflict_rows (
          mutation_id TEXT NOT NULL PRIMARY KEY,
          account_id TEXT NOT NULL,
          object_kind TEXT NOT NULL,
          object_id TEXT NOT NULL,
          envelope_json TEXT NOT NULL,
          clear_payload_json TEXT NOT NULL,
          detected_at INTEGER NOT NULL
        )
      ''')
      ..execute('DROP TABLE old_conflicts')
      ..execute('PRAGMA user_version = 6')
      ..close();
    final recovered = await _openFixture(fixture);

    expect(
      await _syncTableNames(recovered),
      contains('sync_seen_mutation_rows'),
    );
    expect(
      await _columnNames(recovered, 'sync_conflict_rows'),
      containsAll(<String>[
        'resolution_kind',
        'resolution_mutation_id',
        'resolved_at',
      ]),
    );
    expect(await _userVersion(recovered), 9);
  });

  test('interrupted v8 podcast table creation retries idempotently', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final prepared = RiverDatabase(NativeDatabase(fixture));
    await prepared.verifyReady();
    await prepared.close();
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('DROP TABLE podcast_downloads')
      ..execute('DROP TABLE podcast_episodes')
      ..execute('PRAGMA user_version = 7')
      ..close();
    final recovered = await _openFixture(fixture);

    expect(await _podcastTableNames(recovered), <String>[
      'podcast_downloads',
      'podcast_episodes',
      'podcast_shows',
    ]);
    expect(
      await _columnNames(recovered, 'podcast_downloads'),
      contains('source_url'),
    );
    expect(await _userVersion(recovered), 9);
  });

  test('v8 source binding migration adds the missing column', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final prepared = RiverDatabase(NativeDatabase(fixture));
    await prepared.verifyReady();
    await prepared.close();
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('ALTER TABLE podcast_downloads DROP COLUMN source_url')
      ..execute('PRAGMA user_version = 8')
      ..close();
    final recovered = await _openFixture(fixture);

    expect(
      await _columnNames(recovered, 'podcast_downloads'),
      contains('source_url'),
    );
    expect(await _userVersion(recovered), 9);
  });

  test('interrupted v9 source binding retries idempotently', () async {
    final fixture = await _materializeFixture('v004_populated.sql');
    final prepared = RiverDatabase(NativeDatabase(fixture));
    await prepared.verifyReady();
    await prepared.close();
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('PRAGMA user_version = 8')
      ..close();
    final recovered = await _openFixture(fixture);

    expect(
      await _columnNames(recovered, 'podcast_downloads'),
      contains('source_url'),
    );
    expect(await _userVersion(recovered), 9);
  });
}

Future<File> _materializeFixture(String name) async {
  final directory = await Directory.systemTemp.createTemp('river-migration-');
  final file = File('${directory.path}${Platform.pathSeparator}fixture.db');
  final source = File('../../fixtures/migrations/$name').readAsStringSync();
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute(source);
  } finally {
    raw.close();
  }
  return file;
}

Future<RiverDatabase> _openFixture(File fixture) async {
  final database = RiverDatabase(NativeDatabase(fixture));
  await database.verifyReady();
  addTearDown(() async {
    await database.close();
    if (fixture.parent.existsSync()) {
      await fixture.parent.delete(recursive: true);
    }
  });
  return database;
}

Future<int> _userVersion(RiverDatabase database) async =>
    (await database.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

Future<int> _searchTriggerCount(RiverDatabase database) async =>
    (await database.customSelect('''
      SELECT count(*) AS trigger_count
      FROM sqlite_master
      WHERE type = 'trigger' AND name LIKE 'article_search_%'
      ''').getSingle()).read<int>('trigger_count');

Future<List<String>> _audioColumnNames(RiverDatabase database) async =>
    _columnNames(database, 'audio_items');

Future<List<String>> _columnNames(
  RiverDatabase database,
  String tableName,
) async => (await database.customSelect('PRAGMA table_info($tableName)').get())
    .map((row) => row.read<String>('name'))
    .toList(growable: false);

Future<List<String>> _syncTableNames(RiverDatabase database) async =>
    (await database.customSelect(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name LIKE 'sync_%'
      ORDER BY name
      ''',
    ).get()).map((row) => row.read<String>('name')).toList(growable: false);

Future<List<String>> _podcastTableNames(RiverDatabase database) async =>
    (await database.customSelect(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name LIKE 'podcast_%'
      ORDER BY name
      ''',
    ).get()).map((row) => row.read<String>('name')).toList(growable: false);
