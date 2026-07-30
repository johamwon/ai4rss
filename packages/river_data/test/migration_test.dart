import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  test('v1 fixture migrates to v14 without losing article state', () async {
    final fixture = await _materializeFixture('v001_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.title, 'River v1 migration fixture');
    expect(article.feedSummary, 'Existing preview survives migration');
    expect(article.starred, isTrue);
    expect(article.feedContentHtml, isNull);
    expect(await _userVersion(migrated), 14);
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
    expect(await _userVersion(recovered), 14);
  });

  test('v2 fixture creates the settings table and preserves article', () async {
    final fixture = await _materializeFixture('v002_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.feedContentHtml, '<p>Current immediate body</p>');
    expect(await _userVersion(migrated), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(current), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(current), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(recovered), 14);
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
    expect(await _userVersion(recovered), 14);
  });

  test('v9 fixture adds an empty queue without losing audio state', () async {
    final fixture = await _materializeFixture('v009_audio_state.sql');
    final migrated = await _openFixture(fixture);

    final playback = await migrated.select(migrated.audioItems).getSingle();
    final download = await migrated
        .select(migrated.podcastDownloads)
        .getSingle();
    expect(playback.id, 'audio-v9');
    expect(playback.positionMs, 42000);
    expect(playback.playbackRate, 1.25);
    expect(download.sourceUrl, 'https://example.test/audio-v9.mp3');
    expect(
      await DriftAudioQueueRepository(migrated).read(),
      isA<AudioQueueSnapshot>(),
    );
    expect((await DriftAudioQueueRepository(migrated).read()).entries, isEmpty);
    expect(await _userVersion(migrated), 14);
  });

  test('interrupted v10 queue creation retries without losing rows', () async {
    final fixture = await _materializeFixture('v009_audio_state.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('''
        CREATE TABLE audio_queue_entries (
          item_id TEXT NOT NULL PRIMARY KEY,
          kind TEXT NOT NULL,
          title TEXT NOT NULL,
          source_uri TEXT NOT NULL,
          content_revision TEXT,
          queue_position INTEGER NOT NULL,
          is_current INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
          enqueued_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        INSERT INTO audio_queue_entries VALUES (
          'queued-v9', 'articleTts', 'Queued before interruption',
          'https://example.test/articles/queued-v9', 'sha256:queued-v9',
          0, 1, 1784995200, 1784995200
        )
      ''')
      ..close();
    final recovered = await _openFixture(fixture);

    final queue = await DriftAudioQueueRepository(recovered).read();
    expect(queue.entries.single.item.id, 'queued-v9');
    expect(queue.current?.item.id, 'queued-v9');
    expect(await _userVersion(recovered), 14);
  });

  test('v10 fixture adds empty Podcasting 2.0 metadata safely', () async {
    final fixture = await _materializeFixture('v010_podcast_metadata.sql');
    final migrated = await _openFixture(fixture);

    final episode = await DriftPodcastRepository(
      migrated,
    ).findEpisodeById('episode-v10');
    expect(episode?.title, 'Episode before metadata migration');
    expect(episode?.chapterSource, isNull);
    expect(episode?.transcripts, isEmpty);
    expect(
      await _columnNames(migrated, 'podcast_episodes'),
      containsAll(<String>[
        'chapters_url',
        'chapters_mime_type',
        'transcripts_json',
      ]),
    );
    expect(await _userVersion(migrated), 14);
  });

  test(
    'interrupted v11 metadata columns retry without losing values',
    () async {
      final fixture = await _materializeFixture('v010_podcast_metadata.sql');
      final raw = sqlite.sqlite3.open(fixture.path);
      raw
        ..execute('ALTER TABLE podcast_episodes ADD COLUMN chapters_url TEXT')
        ..execute(
          "UPDATE podcast_episodes SET chapters_url = "
          "'https://example.test/chapters-v10.json'",
        )
        ..close();
      final recovered = await _openFixture(fixture);

      final row = await recovered
          .customSelect(
            'SELECT chapters_url, transcripts_json FROM podcast_episodes',
          )
          .getSingle();
      expect(
        row.read<String>('chapters_url'),
        'https://example.test/chapters-v10.json',
      );
      expect(row.read<String>('transcripts_json'), '[]');
      expect(await _userVersion(recovered), 14);
    },
  );

  test(
    'v11 fixture creates annotations without losing article state',
    () async {
      final fixture = await _materializeFixture('v011_article_annotations.sql');
      final migrated = await _openFixture(fixture);

      final article = await migrated.select(migrated.articles).getSingle();
      expect(article.title, 'Article before annotation migration');
      expect(article.contentHash, 'sha256:v11');
      expect(
        await DriftArticleAnnotationRepository(
          migrated,
        ).watchArticleAnnotations('article-v11').first,
        isEmpty,
      );
      expect(await _userVersion(migrated), 14);
    },
  );

  test(
    'interrupted v12 annotation creation retries without losing rows',
    () async {
      final fixture = await _materializeFixture('v011_article_annotations.sql');
      final raw = sqlite.sqlite3.open(fixture.path);
      raw
        ..execute('''
          CREATE TABLE article_annotations (
            id TEXT NOT NULL PRIMARY KEY,
            article_id TEXT NOT NULL
              REFERENCES articles(id) ON DELETE CASCADE,
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
          )
        ''')
        ..execute('''
          INSERT INTO article_annotations VALUES (
            'annotation-v11', 'article-v11', 'selected fact',
            'Existing ', ' remains', 9, 22, 'sha256:v11',
            '/article/text()[1]', 9, '/article/text()[1]', 22,
            'yellow', 'Survives interruption', 1785211200, 1785211200
          )
        ''')
        ..close();
      final recovered = await _openFixture(fixture);

      final annotation = (await DriftArticleAnnotationRepository(
        recovered,
      ).watchArticleAnnotations('article-v11').first).single;
      expect(annotation.anchor.exact, 'selected fact');
      expect(annotation.note, 'Survives interruption');
      expect(await _userVersion(recovered), 14);
    },
  );

  test(
    'v12 fixture backfills a stable knowledge source and mapping schema',
    () async {
      final fixture = await _materializeFixture('v012_knowledge_model.sql');
      final migrated = await _openFixture(fixture);
      final repository = DriftKnowledgeRepository(migrated);

      final items = await repository.watchItems().first;
      final item = items.singleWhere((item) => item.id == 'knowledge-v12');
      final duplicate = items.singleWhere(
        (item) => item.id == 'knowledge-v12-duplicate',
      );
      expect(items, hasLength(2));
      expect(item.id, 'knowledge-v12');
      expect(item.source.kind, KnowledgeSourceKind.article);
      expect(item.source.sourceId, 'article-v12');
      expect(item.source.sourceTitle, 'Legacy knowledge');
      expect(item.contentHash, 'legacy-hash');
      expect(duplicate.source.kind, KnowledgeSourceKind.manual);
      expect(duplicate.source.sourceId, 'legacy:knowledge-v12-duplicate');
      expect(await repository.watchExternalMappings(item.id).first, isEmpty);
      expect(
        await _indexNames(migrated, 'knowledge_items'),
        contains('knowledge_items_source_unique'),
      );
      expect(await _userVersion(migrated), 14);
    },
  );

  test(
    'interrupted v13 knowledge migration preserves an external mapping',
    () async {
      final fixture = await _materializeFixture('v012_knowledge_model.sql');
      final raw = sqlite.sqlite3.open(fixture.path);
      raw
        ..execute(
          "ALTER TABLE knowledge_items ADD source_kind "
          "TEXT NOT NULL DEFAULT 'article'",
        )
        ..execute('ALTER TABLE knowledge_items ADD source_id TEXT')
        ..execute('UPDATE knowledge_items SET source_id = article_id')
        ..execute('''
          CREATE TABLE knowledge_external_mappings (
            knowledge_item_id TEXT NOT NULL
              REFERENCES knowledge_items(id) ON DELETE CASCADE,
            connector_id TEXT NOT NULL,
            destination_id TEXT NOT NULL,
            external_object_id TEXT NOT NULL,
            external_url TEXT,
            exported_content_hash TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (
              knowledge_item_id,
              connector_id,
              destination_id
            )
          )
        ''')
        ..execute('''
          INSERT INTO knowledge_external_mappings VALUES (
            'knowledge-v12', 'notion', 'database-v12', 'page-v12',
            'https://notion.so/page-v12', 'legacy-hash',
            1785211200, 1785211200
          )
        ''')
        ..close();
      final recovered = await _openFixture(fixture);
      final repository = DriftKnowledgeRepository(recovered);

      final item = (await repository.watchItems().first).singleWhere(
        (item) => item.id == 'knowledge-v12',
      );
      final mapping =
          (await repository.watchExternalMappings(item.id).first).single;
      expect(item.source.sourceId, 'article-v12');
      expect(mapping.externalObjectId, 'page-v12');
      expect(mapping.destinationId, 'database-v12');
      expect(await _userVersion(recovered), 14);
    },
  );

  test('v13 fixture adds the AI artifact cache without data loss', () async {
    final fixture = await _materializeFixture('v013_ai_artifact_cache.sql');
    final migrated = await _openFixture(fixture);

    final marker = await migrated
        .customSelect("SELECT value FROM migration_marker WHERE id = 'v13'")
        .getSingle();
    expect(marker.read<String>('value'), 'preserve-before-ai-cache');
    expect(
      await _columnNames(migrated, 'ai_artifacts'),
      containsAll(<String>[
        'cache_key',
        'article_id',
        'artifact_type',
        'request_model',
        'resolved_model',
        'prompt_version',
        'language',
        'content_hash',
        'structured_result',
        'input_tokens',
        'output_tokens',
        'provider_calls',
        'cost_usd',
        'created_at',
      ]),
    );
    expect(
      await _indexNames(migrated, 'ai_artifacts'),
      contains('ai_artifacts_article_created_idx'),
    );
    expect(await _userVersion(migrated), 14);
  });

  test('interrupted v14 index creation preserves cached rows', () async {
    final fixture = await _materializeFixture('v013_ai_artifact_cache.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('''
        CREATE TABLE ai_artifacts (
          cache_key TEXT NOT NULL PRIMARY KEY,
          article_id TEXT NOT NULL,
          artifact_type TEXT NOT NULL,
          request_model TEXT NOT NULL,
          resolved_model TEXT NOT NULL,
          prompt_version TEXT NOT NULL,
          language TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          structured_result TEXT NOT NULL,
          input_tokens INTEGER NOT NULL,
          output_tokens INTEGER NOT NULL,
          provider_calls INTEGER NOT NULL,
          cost_usd REAL NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        INSERT INTO ai_artifacts VALUES (
          'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'article-v13', 'articleSummary', 'model-v1', 'model-v1',
          'article-summary@1', 'zh-CN',
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          '{}', 10, 5, 1, 0.001, 1785340800
        )
      ''')
      ..close();
    final recovered = await _openFixture(fixture);

    final cached = await recovered
        .customSelect('SELECT article_id FROM ai_artifacts')
        .getSingle();
    expect(cached.read<String>('article_id'), 'article-v13');
    expect(
      await _indexNames(recovered, 'ai_artifacts'),
      contains('ai_artifacts_article_created_idx'),
    );
    expect(await _userVersion(recovered), 14);
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

Future<List<String>> _indexNames(
  RiverDatabase database,
  String tableName,
) async => (await database.customSelect('PRAGMA index_list($tableName)').get())
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
