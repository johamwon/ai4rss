import 'package:drift/drift.dart';

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 256)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class FeedSubscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get canonicalUrl => text()();
  TextColumn get title => text().withLength(min: 1, max: 1024)();
  TextColumn get folderId => text().nullable().references(Folders, #id)();
  TextColumn get feedKind => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  DateTimeColumn get lastRefreshedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{canonicalUrl},
  ];
}

class Articles extends Table {
  TextColumn get id => text()();
  TextColumn get feedId =>
      text().references(FeedSubscriptions, #id, onDelete: KeyAction.cascade)();
  TextColumn get canonicalUrl => text()();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get author => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  TextColumn get feedSummary => text().nullable()();
  TextColumn get readState => text().withDefault(const Constant('unread'))();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  BoolColumn get readLater => boolean().withDefault(const Constant(false))();
  IntColumn get activeReadSeconds => integer().withDefault(const Constant(0))();
  RealColumn get scrollDepth => real().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{feedId, canonicalUrl},
  ];
}

class ArticleContents extends Table {
  TextColumn get articleId =>
      text().references(Articles, #id, onDelete: KeyAction.cascade)();
  TextColumn get sanitizedHtml => text()();
  TextColumn get markdown => text()();
  TextColumn get plainText => text()();
  TextColumn get extractorName => text()();
  TextColumn get extractorVersion => text()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  DateTimeColumn get extractedAt => dateTime()();
  TextColumn get failureCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{articleId};
}

class ReadingEvents extends Table {
  TextColumn get id => text()();
  TextColumn get articleId =>
      text().references(Articles, #id, onDelete: KeyAction.cascade)();
  TextColumn get eventKey => text()();
  TextColumn get eventType => text()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get activeSeconds => integer().withDefault(const Constant(0))();
  RealColumn get completionRatio => real().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{eventKey},
  ];
}

class KnowledgeItems extends Table {
  TextColumn get id => text()();
  TextColumn get articleId => text().nullable().references(
    Articles,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get originalUrl => text()();
  TextColumn get markdown => text()();
  TextColumn get summaryJson => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get contentHash => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AudioItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get sourceUri => text()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().nullable()();
  RealColumn get playbackRate => real().withDefault(const Constant(1))();
  TextColumn get downloadedPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class BackgroundJobs extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  IntColumn get maxAttempts => integer().withDefault(const Constant(5))();
  DateTimeColumn get availableAt => dateTime()();
  DateTimeColumn get leaseUntil => dateTime().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{idempotencyKey},
  ];
}

class SyncTombstones extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{entityType, entityId},
  ];
}
