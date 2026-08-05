import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Folders,
    FeedSubscriptions,
    Articles,
    ArticleContents,
    AiArtifacts,
    ReadingEvents,
    ReadingBehaviorSettingsRows,
    ReaderSettingsRows,
    KnowledgeItems,
    KnowledgeExternalMappings,
    ArticleAnnotations,
    AudioItems,
    AudioQueueEntries,
    BackgroundJobs,
    SyncTombstones,
    SyncReplicaEntries,
    SyncOutboxRows,
    SyncCursorRows,
    SyncConflictRows,
    SyncSeenMutationRows,
    PodcastShows,
    PodcastEpisodes,
    PodcastDownloads,
  ],
)
final class RiverDatabase extends _$RiverDatabase {
  RiverDatabase(super.executor);

  RiverDatabase.inMemory() : super(NativeDatabase.memory());

  Future<void> verifyReady() async {
    await customSelect('SELECT 1').getSingle();
  }

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createArticleSearchInfrastructure();
      await _createKnowledgeSourceIndex();
      await _createAiArtifactIndex();
      await rebuildArticleSearchIndex();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2 && !await _hasColumn('articles', 'feed_content_html')) {
        await migrator.addColumn(articles, articles.feedContentHtml);
      }
      if (from < 3 && !await _hasTable('reader_settings_rows')) {
        await migrator.createTable(readerSettingsRows);
      }
      if (from < 4) {
        await _createArticleSearchInfrastructure();
        await rebuildArticleSearchIndex();
      }
      if (from < 5) {
        await _addAudioColumnIfMissing(
          migrator,
          'segment_index',
          audioItems.segmentIndex,
        );
        await _addAudioColumnIfMissing(
          migrator,
          'character_offset',
          audioItems.characterOffset,
        );
        await _addAudioColumnIfMissing(
          migrator,
          'content_revision',
          audioItems.contentRevision,
        );
        await _addAudioColumnIfMissing(migrator, 'pitch', audioItems.pitch);
        await _addAudioColumnIfMissing(
          migrator,
          'voice_id',
          audioItems.voiceId,
        );
        await _addAudioColumnIfMissing(
          migrator,
          'language_tag',
          audioItems.languageTag,
        );
      }
      if (from < 6) {
        if (!await _hasTable('sync_replica_entries')) {
          await migrator.createTable(syncReplicaEntries);
        }
        if (!await _hasTable('sync_outbox_rows')) {
          await migrator.createTable(syncOutboxRows);
        }
        if (!await _hasTable('sync_cursor_rows')) {
          await migrator.createTable(syncCursorRows);
        }
        if (!await _hasTable('sync_conflict_rows')) {
          await migrator.createTable(syncConflictRows);
        }
      }
      if (from < 7) {
        if (!await _hasColumn('sync_conflict_rows', 'resolution_kind')) {
          await migrator.addColumn(
            syncConflictRows,
            syncConflictRows.resolutionKind,
          );
        }
        if (!await _hasColumn('sync_conflict_rows', 'resolution_mutation_id')) {
          await migrator.addColumn(
            syncConflictRows,
            syncConflictRows.resolutionMutationId,
          );
        }
        if (!await _hasColumn('sync_conflict_rows', 'resolved_at')) {
          await migrator.addColumn(
            syncConflictRows,
            syncConflictRows.resolvedAt,
          );
        }
        if (!await _hasTable('sync_seen_mutation_rows')) {
          await migrator.createTable(syncSeenMutationRows);
        }
      }
      if (from < 8) {
        if (!await _hasTable('podcast_shows')) {
          await migrator.createTable(podcastShows);
        }
        if (!await _hasTable('podcast_episodes')) {
          await migrator.createTable(podcastEpisodes);
        }
        if (!await _hasTable('podcast_downloads')) {
          await migrator.createTable(podcastDownloads);
        }
      }
      if (from < 9 && !await _hasColumn('podcast_downloads', 'source_url')) {
        await migrator.addColumn(podcastDownloads, podcastDownloads.sourceUrl);
      }
      if (from < 10 && !await _hasTable('audio_queue_entries')) {
        await migrator.createTable(audioQueueEntries);
      }
      if (from < 11) {
        await _addPodcastEpisodeColumnIfMissing(
          migrator,
          'chapters_url',
          podcastEpisodes.chaptersUrl,
        );
        await _addPodcastEpisodeColumnIfMissing(
          migrator,
          'chapters_mime_type',
          podcastEpisodes.chaptersMimeType,
        );
        await _addPodcastEpisodeColumnIfMissing(
          migrator,
          'transcripts_json',
          podcastEpisodes.transcriptsJson,
        );
      }
      if (from < 12 && !await _hasTable('article_annotations')) {
        await migrator.createTable(articleAnnotations);
      }
      if (from < 13) {
        if (!await _hasTable('knowledge_items')) {
          await migrator.createTable(knowledgeItems);
        } else {
          await _addKnowledgeColumnIfMissing(
            migrator,
            'source_kind',
            knowledgeItems.sourceKind,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'source_id',
            knowledgeItems.sourceId,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'source_title',
            knowledgeItems.sourceTitle,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'author',
            knowledgeItems.author,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'published_at',
            knowledgeItems.publishedAt,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'sanitized_html',
            knowledgeItems.sanitizedHtml,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'highlights_json',
            knowledgeItems.highlightsJson,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'notes_json',
            knowledgeItems.notesJson,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'topics_json',
            knowledgeItems.topicsJson,
          );
          await _addKnowledgeColumnIfMissing(
            migrator,
            'entities_json',
            knowledgeItems.entitiesJson,
          );
        }
        await customStatement('''
          UPDATE knowledge_items
          SET source_kind = CASE
                WHEN article_id IS NULL THEN 'manual'
                ELSE 'article'
              END,
              source_id = COALESCE(source_id, article_id, 'legacy:' || id),
              source_title = COALESCE(source_title, title)
          WHERE source_id IS NULL OR source_title IS NULL
        ''');
        await customStatement('''
          UPDATE knowledge_items
          SET source_kind = 'manual',
              source_id = 'legacy:' || id
          WHERE source_id IS NOT NULL
            AND rowid NOT IN (
              SELECT MIN(rowid)
              FROM knowledge_items
              WHERE source_id IS NOT NULL
              GROUP BY source_kind, source_id
            )
        ''');
        await _createKnowledgeSourceIndex();
        if (!await _hasTable('knowledge_external_mappings')) {
          await migrator.createTable(knowledgeExternalMappings);
        }
      }
      if (from < 14) {
        if (!await _hasTable('ai_artifacts')) {
          await migrator.createTable(aiArtifacts);
        }
        await _createAiArtifactIndex();
      }
      if (from < 15 && !await _hasTable('reading_behavior_settings_rows')) {
        await migrator.createTable(readingBehaviorSettingsRows);
      }
      if (from < 16) {
        await _addReadingBehaviorSettingsColumnIfMissing(
          migrator,
          'source_score_adjustments_json',
          readingBehaviorSettingsRows.sourceScoreAdjustmentsJson,
        );
        await _addReadingBehaviorSettingsColumnIfMissing(
          migrator,
          'topic_score_adjustments_json',
          readingBehaviorSettingsRows.topicScoreAdjustmentsJson,
        );
        await _addReadingBehaviorSettingsColumnIfMissing(
          migrator,
          'blocked_source_ids_json',
          readingBehaviorSettingsRows.blockedSourceIdsJson,
        );
        await _addReadingBehaviorSettingsColumnIfMissing(
          migrator,
          'blocked_topics_json',
          readingBehaviorSettingsRows.blockedTopicsJson,
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA secure_delete = ON');
    },
  );

  Future<bool> _hasColumn(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }

  Future<bool> _hasTable(String tableName) async {
    final row = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      variables: <Variable<Object>>[Variable<String>(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

  Future<void> _createAiArtifactIndex() => customStatement(
    'CREATE INDEX IF NOT EXISTS ai_artifacts_article_created_idx '
    'ON ai_artifacts(article_id, created_at)',
  );

  Future<void> _addAudioColumnIfMissing(
    Migrator migrator,
    String columnName,
    GeneratedColumn<Object> column,
  ) async {
    if (!await _hasColumn('audio_items', columnName)) {
      await migrator.addColumn(audioItems, column);
    }
  }

  Future<void> _addPodcastEpisodeColumnIfMissing(
    Migrator migrator,
    String columnName,
    GeneratedColumn<Object> column,
  ) async {
    if (!await _hasColumn('podcast_episodes', columnName)) {
      await migrator.addColumn(podcastEpisodes, column);
    }
  }

  Future<void> _addKnowledgeColumnIfMissing(
    Migrator migrator,
    String columnName,
    GeneratedColumn<Object> column,
  ) async {
    if (!await _hasColumn('knowledge_items', columnName)) {
      await migrator.addColumn(knowledgeItems, column);
    }
  }

  Future<void> _addReadingBehaviorSettingsColumnIfMissing(
    Migrator migrator,
    String columnName,
    GeneratedColumn<Object> column,
  ) async {
    if (!await _hasColumn('reading_behavior_settings_rows', columnName)) {
      await migrator.addColumn(readingBehaviorSettingsRows, column);
    }
  }

  Future<void> _createKnowledgeSourceIndex() => customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS knowledge_items_source_unique
        ON knowledge_items(source_kind, source_id)
        WHERE source_id IS NOT NULL
      ''');

  Future<void> rebuildArticleSearchIndex() async {
    await customStatement('DELETE FROM article_search_index');
    await customStatement(_populateArticleSearchIndex);
  }

  Future<void> _createArticleSearchInfrastructure() async {
    await customStatement(_createArticleSearchIndex);
    for (final statement in _articleSearchTriggers) {
      await customStatement(statement);
    }
  }
}

const _createArticleSearchIndex = '''
CREATE VIRTUAL TABLE IF NOT EXISTS article_search_index USING fts5(
  article_id UNINDEXED,
  title,
  author,
  source,
  summary,
  body,
  tags,
  notes,
  tokenize='trigram'
)''';

const _articleSearchProjection = '''
SELECT
  a.id,
  a.title,
  COALESCE(a.author, ''),
  f.title,
  COALESCE(a.feed_summary, ''),
  COALESCE(c.plain_text, ''),
  COALESCE((
    SELECT group_concat(k.tags_json, ' ')
    FROM knowledge_items k
    WHERE k.article_id = a.id
  ), ''),
  COALESCE((
    SELECT group_concat(
      COALESCE(k.summary_json, '') || ' ' || COALESCE(k.markdown, ''),
      ' '
    )
    FROM knowledge_items k
    WHERE k.article_id = a.id
  ), '')
FROM articles a
INNER JOIN feed_subscriptions f ON f.id = a.feed_id
LEFT JOIN article_contents c ON c.article_id = a.id
''';

const _populateArticleSearchIndex =
    '''
INSERT INTO article_search_index(
  article_id, title, author, source, summary, body, tags, notes
)
$_articleSearchProjection
''';

String _refreshSearchIndexFor(String articleIdExpression) =>
    '''
DELETE FROM article_search_index WHERE article_id = $articleIdExpression;
INSERT INTO article_search_index(
  article_id, title, author, source, summary, body, tags, notes
)
$_articleSearchProjection
WHERE a.id = $articleIdExpression;
''';

final List<String> _articleSearchTriggers = <String>[
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_articles_ai
  AFTER INSERT ON articles
  BEGIN
    ${_refreshSearchIndexFor('new.id')}
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_articles_au
  AFTER UPDATE OF title, author, feed_summary, feed_id ON articles
  BEGIN
    ${_refreshSearchIndexFor('new.id')}
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_articles_ad
  AFTER DELETE ON articles
  BEGIN
    DELETE FROM article_search_index WHERE article_id = old.id;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_contents_ai
  AFTER INSERT ON article_contents
  BEGIN
    ${_refreshSearchIndexFor('new.article_id')}
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_contents_au
  AFTER UPDATE OF plain_text ON article_contents
  BEGIN
    ${_refreshSearchIndexFor('new.article_id')}
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_contents_ad
  AFTER DELETE ON article_contents
  BEGIN
    ${_refreshSearchIndexFor('old.article_id')}
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_feeds_au
  AFTER UPDATE OF title ON feed_subscriptions
  BEGIN
    DELETE FROM article_search_index
    WHERE article_id IN (SELECT id FROM articles WHERE feed_id = new.id);
    INSERT INTO article_search_index(
      article_id, title, author, source, summary, body, tags, notes
    )
    $_articleSearchProjection
    WHERE a.feed_id = new.id;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_knowledge_ai
  AFTER INSERT ON knowledge_items
  WHEN new.article_id IS NOT NULL
  BEGIN
    ${_refreshSearchIndexFor('new.article_id')}
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_knowledge_au
  AFTER UPDATE OF article_id, summary_json, tags_json, markdown
  ON knowledge_items
  BEGIN
    DELETE FROM article_search_index
    WHERE article_id IN (old.article_id, new.article_id);
    INSERT INTO article_search_index(
      article_id, title, author, source, summary, body, tags, notes
    )
    $_articleSearchProjection
    WHERE a.id IN (old.article_id, new.article_id);
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS article_search_knowledge_ad
  AFTER DELETE ON knowledge_items
  WHEN old.article_id IS NOT NULL
  BEGIN
    ${_refreshSearchIndexFor('old.article_id')}
  END
  ''',
];
