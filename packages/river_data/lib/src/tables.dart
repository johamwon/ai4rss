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
  TextColumn get feedContentHtml => text().nullable()();
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

@DataClassName('AiArtifactRow')
class AiArtifacts extends Table {
  TextColumn get cacheKey => text().withLength(min: 71, max: 71)();
  TextColumn get articleId => text().withLength(min: 1, max: 240)();
  TextColumn get artifactType => text()();
  TextColumn get requestModel => text().withLength(min: 1, max: 200)();
  TextColumn get resolvedModel => text().withLength(min: 1, max: 200)();
  TextColumn get promptVersion => text()();
  TextColumn get language => text()();
  TextColumn get contentHash => text().withLength(min: 64, max: 64)();
  TextColumn get structuredResult => text()();
  IntColumn get inputTokens => integer()();
  IntColumn get outputTokens => integer()();
  IntColumn get providerCalls => integer()();
  RealColumn get costUsd => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cacheKey};
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

@DataClassName('ReadingBehaviorSettingsRow')
class ReadingBehaviorSettingsRows extends Table {
  TextColumn get id => text()();
  BoolColumn get captureEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get retentionDays => integer().withDefault(const Constant(90))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class ReaderSettingsRows extends Table {
  TextColumn get id => text()();
  TextColumn get fontFamily => text().withDefault(const Constant('system'))();
  RealColumn get fontScale => real().withDefault(const Constant(1))();
  RealColumn get lineHeight => real().withDefault(const Constant(1.75))();
  RealColumn get contentWidth => real().withDefault(const Constant(760))();
  TextColumn get theme => text().withDefault(const Constant('system'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('KnowledgeItemRow')
class KnowledgeItems extends Table {
  TextColumn get id => text()();
  TextColumn get articleId => text().nullable().references(
    Articles,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get sourceKind => text().withDefault(const Constant('article'))();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceTitle => text().nullable()();
  TextColumn get author => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get originalUrl => text()();
  TextColumn get markdown => text()();
  TextColumn get sanitizedHtml => text().withDefault(const Constant(''))();
  TextColumn get summaryJson => text().nullable()();
  TextColumn get highlightsJson => text().withDefault(const Constant('[]'))();
  TextColumn get notesJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get topicsJson => text().withDefault(const Constant('[]'))();
  TextColumn get entitiesJson => text().withDefault(const Constant('[]'))();
  TextColumn get contentHash => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('KnowledgeExternalMappingRow')
class KnowledgeExternalMappings extends Table {
  TextColumn get knowledgeItemId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get connectorId => text()();
  TextColumn get destinationId => text()();
  TextColumn get externalObjectId => text()();
  TextColumn get externalUrl => text().nullable()();
  TextColumn get exportedContentHash => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    knowledgeItemId,
    connectorId,
    destinationId,
  };
}

@DataClassName('ArticleAnnotationRow')
class ArticleAnnotations extends Table {
  TextColumn get id => text()();
  TextColumn get articleId =>
      text().references(Articles, #id, onDelete: KeyAction.cascade)();
  TextColumn get exactText => text()();
  TextColumn get prefixText => text()();
  TextColumn get suffixText => text()();
  IntColumn get originalStart => integer()();
  IntColumn get originalEnd => integer()();
  TextColumn get contentRevision => text()();
  TextColumn get startDomPath => text()();
  IntColumn get startDomOffset => integer()();
  TextColumn get endDomPath => text()();
  IntColumn get endDomOffset => integer()();
  TextColumn get color => text().withDefault(const Constant('yellow'))();
  TextColumn get note => text().nullable()();
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
  IntColumn get segmentIndex => integer().nullable()();
  IntColumn get characterOffset => integer().nullable()();
  TextColumn get contentRevision => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  RealColumn get playbackRate => real().withDefault(const Constant(1))();
  RealColumn get pitch => real().withDefault(const Constant(1))();
  TextColumn get voiceId => text().nullable()();
  TextColumn get languageTag => text().nullable()();
  TextColumn get downloadedPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AudioQueueEntries extends Table {
  TextColumn get itemId => text()();
  TextColumn get kind => text()();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get sourceUri => text()();
  TextColumn get contentRevision => text().nullable()();
  IntColumn get queuePosition => integer()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get enqueuedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{itemId};
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

class SyncReplicaEntries extends Table {
  TextColumn get accountId => text()();
  TextColumn get objectKind => text()();
  TextColumn get objectId => text()();
  TextColumn get envelopeJson => text()();
  TextColumn get clearPayloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    accountId,
    objectKind,
    objectId,
  };
}

class SyncOutboxRows extends Table {
  TextColumn get mutationId => text()();
  TextColumn get accountId => text()();
  TextColumn get deviceId => text()();
  TextColumn get envelopeJson => text()();
  DateTimeColumn get queuedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{mutationId};
}

class SyncCursorRows extends Table {
  TextColumn get accountId => text()();
  TextColumn get deviceId => text()();
  IntColumn get protocolVersion => integer()();
  IntColumn get serverSequence => integer()();
  TextColumn get opaqueToken => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{accountId, deviceId};
}

class SyncConflictRows extends Table {
  TextColumn get mutationId => text()();
  TextColumn get accountId => text()();
  TextColumn get objectKind => text()();
  TextColumn get objectId => text()();
  TextColumn get envelopeJson => text()();
  TextColumn get clearPayloadJson => text()();
  DateTimeColumn get detectedAt => dateTime()();
  TextColumn get resolutionKind =>
      text().withDefault(const Constant('unresolved'))();
  TextColumn get resolutionMutationId => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{mutationId};
}

class SyncSeenMutationRows extends Table {
  TextColumn get mutationId => text()();
  TextColumn get accountId => text()();
  TextColumn get envelopeJson => text()();
  DateTimeColumn get firstSeenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{mutationId};
}

class PodcastShows extends Table {
  TextColumn get id => text()();
  TextColumn get canonicalFeedUrl => text()();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get description => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get websiteUrl => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get explicitRating => text()();
  RealColumn get defaultPlaybackRate => real().withDefault(const Constant(1))();
  TextColumn get downloadPolicy =>
      text().withDefault(const Constant('manual'))();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  DateTimeColumn get lastRefreshedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{canonicalFeedUrl},
  ];
}

class PodcastEpisodes extends Table {
  TextColumn get id => text()();
  TextColumn get showId =>
      text().references(PodcastShows, #id, onDelete: KeyAction.cascade)();
  TextColumn get externalId => text()();
  TextColumn get title => text().withLength(min: 1, max: 2048)();
  TextColumn get description => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get episodeUrl => text().nullable()();
  TextColumn get mediaUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get mediaMimeType => text().nullable()();
  IntColumn get mediaLengthBytes => integer().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  IntColumn get seasonNumber => integer().nullable()();
  TextColumn get chaptersUrl => text().nullable()();
  TextColumn get chaptersMimeType => text().nullable()();
  TextColumn get transcriptsJson => text().withDefault(const Constant('[]'))();
  TextColumn get explicitRating => text()();
  TextColumn get episodeType => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{showId, externalId},
  ];
}

class PodcastDownloads extends Table {
  TextColumn get episodeId =>
      text().references(PodcastEpisodes, #id, onDelete: KeyAction.cascade)();
  TextColumn get state => text().withDefault(const Constant('notDownloaded'))();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get partialPath => text().nullable()();
  TextColumn get availablePath => text().nullable()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get failureCode => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{episodeId};
}
