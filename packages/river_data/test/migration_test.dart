import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  test('v1 fixture migrates to v5 without losing article state', () async {
    final fixture = await _materializeFixture('v001_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.title, 'River v1 migration fixture');
    expect(article.feedSummary, 'Existing preview survives migration');
    expect(article.starred, isTrue);
    expect(article.feedContentHtml, isNull);
    expect(await _userVersion(migrated), 5);
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
    expect(await _userVersion(recovered), 5);
  });

  test('v2 fixture creates the settings table and preserves article', () async {
    final fixture = await _materializeFixture('v002_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.feedContentHtml, '<p>Current immediate body</p>');
    expect(await _userVersion(migrated), 5);
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
    expect(await _userVersion(recovered), 5);
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
    expect(await _userVersion(current), 5);
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
    expect(await _userVersion(recovered), 5);
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
    expect(await _userVersion(current), 5);
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
    expect(await _userVersion(recovered), 5);
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
    (await database.customSelect('PRAGMA table_info(audio_items)').get())
        .map((row) => row.read<String>('name'))
        .toList(growable: false);
