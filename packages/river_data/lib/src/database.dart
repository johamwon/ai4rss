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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2 && !await _hasColumn('articles', 'feed_content_html')) {
        await migrator.addColumn(articles, articles.feedContentHtml);
      }
      if (from < 3 && !await _hasTable('reader_settings_rows')) {
        await migrator.createTable(readerSettingsRows);
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
}
