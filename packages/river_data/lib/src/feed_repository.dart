import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;
import 'package:river_feed/river_feed.dart' as feed;

import 'database.dart';

final class DriftFeedRepository
    implements
        feed.FeedRepository,
        feed.SubscriptionOrganizerRepository,
        feed.ArticleReaderRepository {
  const DriftFeedRepository(this.database);

  final RiverDatabase database;

  @override
  Future<feed.FeedSubscriptionRecord?> findByCanonicalUrl(
    Uri canonicalUrl,
  ) async {
    final query = database.select(database.feedSubscriptions)
      ..where((table) => table.canonicalUrl.equals(canonicalUrl.toString()));
    final row = await query.getSingleOrNull();
    return row == null ? null : _subscription(row);
  }

  @override
  Stream<List<feed.FeedSubscriptionRecord>> watchSubscriptions() {
    final query = database.select(database.feedSubscriptions)
      ..orderBy(<OrderingTerm Function($FeedSubscriptionsTable)>[
        (table) => OrderingTerm.asc(table.title),
      ]);
    return query.watch().map(
      (rows) => rows.map(_subscription).toList(growable: false),
    );
  }

  @override
  Stream<List<feed.FeedFolderRecord>> watchFolders() {
    final query = database.select(database.folders)
      ..orderBy(<OrderingTerm Function($FoldersTable)>[
        (table) => OrderingTerm.asc(table.position),
        (table) => OrderingTerm.asc(table.name),
      ]);
    return query.watch().map(
      (rows) => rows.map(_folder).toList(growable: false),
    );
  }

  @override
  Future<feed.FeedFolderRecord> createFolder({
    required String id,
    required List<String> path,
    required DateTime createdAt,
  }) {
    return database.transaction(() async {
      final rows = await database.select(database.folders).get();
      _ensureUniqueFolderPath(rows, path);
      final position =
          rows.fold<int>(
            -1,
            (maximum, row) => row.position > maximum ? row.position : maximum,
          ) +
          1;
      final storedPath = _encodeFolderPath(path);
      await database
          .into(database.folders)
          .insert(
            FoldersCompanion.insert(
              id: id,
              name: storedPath,
              position: Value<int>(position),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      return feed.FeedFolderRecord(
        id: id,
        path: List<String>.unmodifiable(path),
        position: position,
      );
    });
  }

  @override
  Future<void> renameFolder({
    required String folderId,
    required String name,
    required DateTime updatedAt,
  }) {
    return database.transaction(() async {
      final rows = await database.select(database.folders).get();
      final row = rows.where((folder) => folder.id == folderId).firstOrNull;
      if (row == null) {
        throw const feed.SubscriptionOrganizerException('文件夹不存在');
      }
      final path = _decodeFolderPath(row.name);
      final renamedPath = <String>[...path.take(path.length - 1), name];
      _ensureUniqueFolderPath(rows, renamedPath, excludingId: folderId);
      await (database.update(
        database.folders,
      )..where((table) => table.id.equals(folderId))).write(
        FoldersCompanion(
          name: Value<String>(_encodeFolderPath(renamedPath)),
          updatedAt: Value<DateTime>(updatedAt),
        ),
      );
    });
  }

  @override
  Future<void> deleteFolder({
    required String folderId,
    required DateTime updatedAt,
  }) {
    return database.transaction(() async {
      await (database.update(
        database.feedSubscriptions,
      )..where((table) => table.folderId.equals(folderId))).write(
        FeedSubscriptionsCompanion(
          folderId: const Value<String?>(null),
          updatedAt: Value<DateTime>(updatedAt),
        ),
      );
      await (database.delete(
        database.folders,
      )..where((table) => table.id.equals(folderId))).go();
    });
  }

  @override
  Future<void> moveFeed({
    required String feedId,
    required String? folderId,
    required DateTime updatedAt,
  }) async {
    if (folderId != null) {
      final folder = await (database.select(
        database.folders,
      )..where((table) => table.id.equals(folderId))).getSingleOrNull();
      if (folder == null) {
        throw const feed.SubscriptionOrganizerException('目标文件夹不存在');
      }
    }
    final changed =
        await (database.update(
          database.feedSubscriptions,
        )..where((table) => table.id.equals(feedId))).write(
          FeedSubscriptionsCompanion(
            folderId: Value<String?>(folderId),
            updatedAt: Value<DateTime>(updatedAt),
          ),
        );
    if (changed == 0) {
      throw const feed.SubscriptionOrganizerException('订阅源不存在');
    }
  }

  @override
  Future<feed.OpmlImportReport> importOpml({
    required feed.OpmlDocument document,
    required domain.IdGenerator ids,
    required DateTime importedAt,
  }) {
    return database.transaction(() async {
      final folderRows = await database.select(database.folders).get();
      final foldersByPath = <String, Folder>{
        for (final row in folderRows)
          _folderPathKey(_decodeFolderPath(row.name)): row,
      };
      final subscriptionRows = await database
          .select(database.feedSubscriptions)
          .get();
      final existingUrls = subscriptionRows
          .map((row) => row.canonicalUrl)
          .toSet();
      var nextPosition =
          folderRows.fold<int>(
            -1,
            (maximum, row) => row.position > maximum ? row.position : maximum,
          ) +
          1;
      var createdFolders = 0;
      var importedSubscriptions = 0;
      var existingDuplicates = 0;

      for (final entry in document.feeds) {
        final canonicalUrl = entry.xmlUrl.toString();
        if (!existingUrls.add(canonicalUrl)) {
          existingDuplicates += 1;
          continue;
        }

        String? folderId;
        if (entry.folderPath.isNotEmpty) {
          final key = _folderPathKey(entry.folderPath);
          var folder = foldersByPath[key];
          if (folder == null) {
            final id = ids.next();
            final storedPath = _encodeFolderPath(entry.folderPath);
            await database
                .into(database.folders)
                .insert(
                  FoldersCompanion.insert(
                    id: id,
                    name: storedPath,
                    position: Value<int>(nextPosition),
                    createdAt: importedAt,
                    updatedAt: importedAt,
                  ),
                );
            folder = Folder(
              id: id,
              name: storedPath,
              position: nextPosition,
              createdAt: importedAt,
              updatedAt: importedAt,
            );
            foldersByPath[key] = folder;
            nextPosition += 1;
            createdFolders += 1;
          }
          folderId = folder.id;
        }

        await database
            .into(database.feedSubscriptions)
            .insert(
              FeedSubscriptionsCompanion.insert(
                id: ids.next(),
                canonicalUrl: canonicalUrl,
                title: _limited(entry.title, 1024),
                folderId: Value<String?>(folderId),
                feedKind: feed.FeedDocumentKind.unknown.name,
                createdAt: importedAt,
                updatedAt: importedAt,
              ),
            );
        importedSubscriptions += 1;
      }

      return feed.OpmlImportReport(
        importedSubscriptions: importedSubscriptions,
        createdFolders: createdFolders,
        skippedDuplicates:
            document.skippedDuplicateEntries + existingDuplicates,
        skippedInvalid: document.skippedInvalidEntries,
      );
    });
  }

  @override
  Future<feed.OpmlDocument> exportOpml() async {
    final folderRows = await database.select(database.folders).get();
    final paths = <String, List<String>>{
      for (final row in folderRows) row.id: _decodeFolderPath(row.name),
    };
    final query = database.select(database.feedSubscriptions)
      ..orderBy(<OrderingTerm Function($FeedSubscriptionsTable)>[
        (table) => OrderingTerm.asc(table.title),
      ]);
    final subscriptions = await query.get();
    return feed.OpmlDocument(
      title: 'River subscriptions',
      feeds: subscriptions
          .map(
            (row) => feed.OpmlFeedEntry(
              title: row.title,
              xmlUrl: Uri.parse(row.canonicalUrl),
              folderPath: row.folderId == null
                  ? const <String>[]
                  : List<String>.unmodifiable(
                      paths[row.folderId] ?? const <String>[],
                    ),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<feed.FeedArticleRecord>> watchArticles({
    feed.FeedArticleQuery query = const feed.FeedArticleQuery(),
  }) {
    final cachedTextLength = ifNull<int>(
      database.articleContents.plainText.length,
      const Constant<int>(0),
    );
    final effectivePublishedAt = coalesce<DateTime>(<Expression<DateTime>>[
      database.articles.publishedAt,
      database.articles.createdAt,
    ]);
    final statement = database.select(database.articles).join(<Join>[
      innerJoin(
        database.feedSubscriptions,
        database.feedSubscriptions.id.equalsExp(database.articles.feedId),
      ),
      leftOuterJoin(
        database.articleContents,
        database.articleContents.articleId.equalsExp(database.articles.id),
        useColumns: false,
      ),
    ]);
    statement.addColumns(<Expression<Object>>[cachedTextLength]);
    if (query.feedId case final feedId?) {
      statement.where(database.articles.feedId.equals(feedId));
    }
    switch (query.view) {
      case feed.FeedArticleView.inbox:
        break;
      case feed.FeedArticleView.unread:
        statement.where(database.articles.readState.equals('unread'));
      case feed.FeedArticleView.starred:
        statement.where(database.articles.starred.equals(true));
      case feed.FeedArticleView.readLater:
        statement.where(database.articles.readLater.equals(true));
      case feed.FeedArticleView.folder:
        statement.where(
          database.feedSubscriptions.folderId.equals(query.folderId!),
        );
    }
    final descending = query.sort == feed.FeedArticleSort.newest;
    statement.orderBy(<OrderingTerm>[
      descending
          ? OrderingTerm.desc(effectivePublishedAt)
          : OrderingTerm.asc(effectivePublishedAt),
      OrderingTerm.asc(database.articles.id),
    ]);
    return statement.watch().map(
      (rows) => rows
          .map(
            (row) => _article(
              row.readTable(database.articles),
              subscription: row.readTable(database.feedSubscriptions),
              cachedTextLength: row.read(cachedTextLength),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<feed.FeedArticleDetailRecord?> watchArticle(String articleId) {
    final statement = database.select(database.articles).join(<Join>[
      innerJoin(
        database.feedSubscriptions,
        database.feedSubscriptions.id.equalsExp(database.articles.feedId),
      ),
      leftOuterJoin(
        database.articleContents,
        database.articleContents.articleId.equalsExp(database.articles.id),
      ),
    ])..where(database.articles.id.equals(articleId));
    return statement.watchSingleOrNull().map((row) {
      if (row == null) return null;
      final article = row.readTable(database.articles);
      return _articleDetail(
        article,
        subscription: row.readTable(database.feedSubscriptions),
        content: row.readTableOrNull(database.articleContents),
      );
    });
  }

  @override
  Future<void> setRead(
    String articleId, {
    required bool read,
    required DateTime updatedAt,
  }) => _writeArticleState(
    articleId,
    ArticlesCompanion(
      readState: Value<String>(read ? 'read' : 'unread'),
      updatedAt: Value<DateTime>(updatedAt),
    ),
  );

  @override
  Future<void> setStarred(
    String articleId, {
    required bool starred,
    required DateTime updatedAt,
  }) => _writeArticleState(
    articleId,
    ArticlesCompanion(
      starred: Value<bool>(starred),
      updatedAt: Value<DateTime>(updatedAt),
    ),
  );

  @override
  Future<void> setReadLater(
    String articleId, {
    required bool readLater,
    required DateTime updatedAt,
  }) => _writeArticleState(
    articleId,
    ArticlesCompanion(
      readLater: Value<bool>(readLater),
      updatedAt: Value<DateTime>(updatedAt),
    ),
  );

  @override
  Future<void> saveReadingProgress(
    String articleId, {
    required double scrollDepth,
    required DateTime updatedAt,
  }) {
    final normalized = scrollDepth.clamp(0, 1).toDouble();
    return _writeArticleState(
      articleId,
      ArticlesCompanion(
        scrollDepth: Value<double>(normalized),
        completedAt: normalized >= 0.9
            ? Value<DateTime?>(updatedAt)
            : const Value<DateTime?>.absent(),
        readState: normalized >= 0.9
            ? const Value<String>('read')
            : const Value<String>.absent(),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  Future<void> _writeArticleState(
    String articleId,
    ArticlesCompanion companion,
  ) async {
    final changed = await (database.update(
      database.articles,
    )..where((table) => table.id.equals(articleId))).write(companion);
    if (changed == 0) {
      throw const feed.ArticleReaderException('article_missing');
    }
  }

  @override
  Future<void> applyRefresh({
    required String feedId,
    required Uri canonicalUrl,
    required feed.ParsedFeed feed,
    required List<feed.FeedArticleDraft> articles,
    required DateTime refreshedAt,
    String? etag,
    String? lastModified,
  }) {
    return database.transaction(() async {
      final existingFeed = await (database.select(
        database.feedSubscriptions,
      )..where((table) => table.id.equals(feedId))).getSingleOrNull();
      if (existingFeed == null) {
        await database
            .into(database.feedSubscriptions)
            .insert(
              FeedSubscriptionsCompanion.insert(
                id: feedId,
                canonicalUrl: canonicalUrl.toString(),
                title: _limited(feed.title, 1024),
                feedKind: feed.kind.name,
                etag: Value<String?>(etag),
                lastModified: Value<String?>(lastModified),
                lastRefreshedAt: Value<DateTime>(refreshedAt),
                createdAt: refreshedAt,
                updatedAt: refreshedAt,
              ),
            );
      } else {
        await (database.update(
          database.feedSubscriptions,
        )..where((table) => table.id.equals(feedId))).write(
          FeedSubscriptionsCompanion(
            canonicalUrl: Value<String>(canonicalUrl.toString()),
            title: Value<String>(_limited(feed.title, 1024)),
            feedKind: Value<String>(feed.kind.name),
            etag: Value<String?>(etag),
            lastModified: Value<String?>(lastModified),
            lastRefreshedAt: Value<DateTime>(refreshedAt),
            updatedAt: Value<DateTime>(refreshedAt),
          ),
        );
      }

      for (final article in articles) {
        await _upsertArticle(
          feedId: feedId,
          article: article,
          refreshedAt: refreshedAt,
        );
      }
    });
  }

  Future<void> _upsertArticle({
    required String feedId,
    required feed.FeedArticleDraft article,
    required DateTime refreshedAt,
  }) async {
    final existing =
        await (database.select(database.articles)..where(
              (table) =>
                  table.feedId.equals(feedId) &
                  table.canonicalUrl.equals(article.canonicalUrl.toString()),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await database
          .into(database.articles)
          .insert(
            ArticlesCompanion.insert(
              id: article.id,
              feedId: feedId,
              canonicalUrl: article.canonicalUrl.toString(),
              title: _limited(article.title, 2048),
              author: Value<String?>(article.author),
              publishedAt: Value<DateTime?>(article.publishedAt),
              feedSummary: Value<String?>(article.summary),
              feedContentHtml: Value<String?>(article.contentHtml),
              createdAt: refreshedAt,
              updatedAt: refreshedAt,
            ),
          );
      return;
    }
    await (database.update(
      database.articles,
    )..where((table) => table.id.equals(existing.id))).write(
      ArticlesCompanion(
        title: Value<String>(_limited(article.title, 2048)),
        author: Value<String?>(article.author),
        publishedAt: Value<DateTime?>(article.publishedAt),
        feedSummary: Value<String?>(article.summary),
        feedContentHtml: Value<String?>(article.contentHtml),
        updatedAt: Value<DateTime>(refreshedAt),
      ),
    );
  }

  @override
  Future<void> markNotModified({
    required String feedId,
    required DateTime refreshedAt,
  }) {
    return (database.update(
      database.feedSubscriptions,
    )..where((table) => table.id.equals(feedId))).write(
      FeedSubscriptionsCompanion(
        lastRefreshedAt: Value<DateTime>(refreshedAt),
        updatedAt: Value<DateTime>(refreshedAt),
      ),
    );
  }

  @override
  Future<void> setEnabled(
    String feedId, {
    required bool enabled,
    required DateTime updatedAt,
  }) {
    return (database.update(
      database.feedSubscriptions,
    )..where((table) => table.id.equals(feedId))).write(
      FeedSubscriptionsCompanion(
        enabled: Value<bool>(enabled),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  @override
  Future<void> delete(String feedId) {
    return (database.delete(
      database.feedSubscriptions,
    )..where((table) => table.id.equals(feedId))).go();
  }
}

feed.FeedSubscriptionRecord _subscription(FeedSubscription row) =>
    feed.FeedSubscriptionRecord(
      id: row.id,
      canonicalUrl: Uri.parse(row.canonicalUrl),
      title: row.title,
      kind: feed.FeedDocumentKind.values.byName(row.feedKind),
      enabled: row.enabled,
      etag: row.etag,
      lastModified: row.lastModified,
      lastRefreshedAt: row.lastRefreshedAt,
      folderId: row.folderId,
    );

feed.FeedFolderRecord _folder(Folder row) => feed.FeedFolderRecord(
  id: row.id,
  path: List<String>.unmodifiable(_decodeFolderPath(row.name)),
  position: row.position,
);

feed.FeedArticleRecord _article(
  Article row, {
  required FeedSubscription subscription,
  required int? cachedTextLength,
}) => feed.FeedArticleRecord(
  id: row.id,
  feedId: row.feedId,
  feedTitle: subscription.title,
  canonicalUrl: Uri.parse(row.canonicalUrl),
  title: row.title,
  author: row.author,
  publishedAt: row.publishedAt,
  summary: row.feedSummary,
  read: row.readState != 'unread',
  starred: row.starred,
  readLater: row.readLater,
  folderId: subscription.folderId,
  estimatedReadingMinutes:
      feed.estimateReadingMinutesFromCharacterCount(cachedTextLength) ??
      feed.estimateReadingMinutes(row.feedSummary),
);

feed.FeedArticleDetailRecord _articleDetail(
  Article row, {
  required FeedSubscription subscription,
  required ArticleContent? content,
}) => feed.FeedArticleDetailRecord(
  id: row.id,
  feedId: row.feedId,
  feedTitle: subscription.title,
  canonicalUrl: Uri.parse(row.canonicalUrl),
  title: row.title,
  author: row.author,
  publishedAt: row.publishedAt,
  summary: row.feedSummary,
  feedContentHtml: row.feedContentHtml,
  read: row.readState != 'unread',
  starred: row.starred,
  readLater: row.readLater,
  scrollDepth: row.scrollDepth.clamp(0, 1).toDouble(),
  activeReadSeconds: row.activeReadSeconds,
  completedAt: row.completedAt,
  content: content == null
      ? null
      : feed.FeedArticleContentRecord(
          sanitizedHtml: content.sanitizedHtml,
          markdown: content.markdown,
          plainText: content.plainText,
          extractorName: content.extractorName,
          extractorVersion: content.extractorVersion,
          extractedAt: content.extractedAt,
          contentHash: row.contentHash,
          failureCode: content.failureCode,
        ),
);

String _limited(String value, int maxLength) =>
    value.length <= maxLength ? value : value.substring(0, maxLength);

const _folderPathPrefix = '@river:path:';

String _encodeFolderPath(List<String> path) {
  final normalized = path
      .map((segment) => segment.trim())
      .toList(growable: false);
  if (normalized.isEmpty || normalized.any((segment) => segment.isEmpty)) {
    throw const feed.SubscriptionOrganizerException('文件夹路径无效');
  }
  final encoded = '$_folderPathPrefix${jsonEncode(normalized)}';
  if (encoded.length > 256) {
    throw const feed.SubscriptionOrganizerException('文件夹路径不能超过 256 个字符');
  }
  return encoded;
}

List<String> _decodeFolderPath(String stored) {
  if (!stored.startsWith(_folderPathPrefix)) {
    return <String>[stored];
  }
  try {
    final decoded = jsonDecode(stored.substring(_folderPathPrefix.length));
    if (decoded is List<Object?> && decoded.every((item) => item is String)) {
      return decoded.cast<String>();
    }
  } on Object {
    // Preserve legacy or manually edited values as a visible single folder.
  }
  return <String>[stored];
}

String _folderPathKey(List<String> path) =>
    path.map((segment) => segment.trim().toLowerCase()).join('\u001f');

void _ensureUniqueFolderPath(
  List<Folder> rows,
  List<String> path, {
  String? excludingId,
}) {
  final key = _folderPathKey(path);
  if (rows.any(
    (row) =>
        row.id != excludingId &&
        _folderPathKey(_decodeFolderPath(row.name)) == key,
  )) {
    throw const feed.SubscriptionOrganizerException('同名文件夹已存在');
  }
}
