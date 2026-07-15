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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
