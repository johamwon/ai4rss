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
    ReadingEvents,
    ReaderSettingsRows,
    KnowledgeItems,
    AudioItems,
    BackgroundJobs,
    SyncTombstones,
  ],
)
final class RiverDatabase extends _$RiverDatabase {
  RiverDatabase(super.executor);

  RiverDatabase.inMemory() : super(NativeDatabase.memory());

  Future<void> verifyReady() async {
    await customSelect('SELECT 1').getSingle();
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createArticleSearchInfrastructure();
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
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

  Future<bool> _hasColumn(String tableName, String columnName) async {
    final columns = await customSelect(
      'PRAGMA table_info($tableName)',
      readsFrom: <ResultSetImplementation<Table, Object?>>{articles},
    ).get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }

  Future<bool> _hasTable(String tableName) async {
    final row = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      variables: <Variable<Object>>[Variable<String>(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

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
