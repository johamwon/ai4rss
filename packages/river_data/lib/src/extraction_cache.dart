import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftExtractionCache implements domain.ExtractionCache {
  const DriftExtractionCache(this.database);

  final RiverDatabase database;

  @override
  Future<domain.CachedExtraction?> read({
    required Uri sourceUri,
    String? articleId,
  }) async {
    if (articleId != null) {
      final article = await (database.select(
        database.articles,
      )..where((table) => table.id.equals(articleId))).getSingleOrNull();
      final entry = article == null ? null : await _entryFor(article);
      if (entry != null) return entry;
    }

    final sourceText = sourceUri.toString();
    final canonicalUrl = sourceUri.hasFragment
        ? sourceText.substring(0, sourceText.indexOf('#'))
        : sourceText;
    final query = database.select(database.articles)
      ..where((table) => table.canonicalUrl.equals(canonicalUrl))
      ..orderBy(<OrderingTerm Function($ArticlesTable)>[
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    for (final article in await query.get()) {
      final entry = await _entryFor(article);
      if (entry != null) return entry;
    }
    return null;
  }

  @override
  Future<void> writeSuccess({
    required String articleId,
    required domain.ExtractedArticle article,
    required String contentHash,
    required DateTime extractedAt,
    String? etag,
    String? lastModified,
  }) {
    return database.transaction(() async {
      if (!await _articleExists(articleId)) return;
      await database
          .into(database.articleContents)
          .insertOnConflictUpdate(
            ArticleContentsCompanion.insert(
              articleId: articleId,
              sanitizedHtml: article.html,
              markdown: article.plainText,
              plainText: article.plainText,
              extractorName: article.extractor,
              extractorVersion: article.extractorVersion,
              etag: Value<String?>(etag),
              lastModified: Value<String?>(lastModified),
              extractedAt: extractedAt,
              failureCode: const Value<String?>(null),
            ),
          );
      await (database.update(database.articles)
            ..where((table) => table.id.equals(articleId)))
          .write(ArticlesCompanion(contentHash: Value<String>(contentHash)));
    });
  }

  @override
  Future<void> writeFailure({
    required String articleId,
    required domain.ExtractionFailureCode failureCode,
    required String extractorVersion,
    required DateTime attemptedAt,
    String? etag,
    String? lastModified,
  }) {
    return database.transaction(() async {
      if (!await _articleExists(articleId)) return;
      final existing = await (database.select(
        database.articleContents,
      )..where((table) => table.articleId.equals(articleId))).getSingleOrNull();
      if (existing == null) {
        await database
            .into(database.articleContents)
            .insert(
              ArticleContentsCompanion.insert(
                articleId: articleId,
                sanitizedHtml: '',
                markdown: '',
                plainText: '',
                extractorName: 'pipeline',
                extractorVersion: extractorVersion,
                etag: Value<String?>(etag),
                lastModified: Value<String?>(lastModified),
                extractedAt: attemptedAt,
                failureCode: Value<String?>(failureCode.name),
              ),
            );
        return;
      }
      await (database.update(
        database.articleContents,
      )..where((table) => table.articleId.equals(articleId))).write(
        ArticleContentsCompanion(
          etag: etag == null ? const Value.absent() : Value<String>(etag),
          lastModified: lastModified == null
              ? const Value.absent()
              : Value<String>(lastModified),
          failureCode: Value<String>(failureCode.name),
        ),
      );
    });
  }

  Future<bool> _articleExists(String articleId) async =>
      await (database.selectOnly(database.articles)
            ..addColumns(<Expression<Object>>[database.articles.id])
            ..where(database.articles.id.equals(articleId)))
          .getSingleOrNull() !=
      null;

  Future<domain.CachedExtraction?> _entryFor(Article article) async {
    final content = await (database.select(
      database.articleContents,
    )..where((table) => table.articleId.equals(article.id))).getSingleOrNull();
    if (content == null || content.sanitizedHtml.trim().isEmpty) return null;
    final hash = article.contentHash;
    if (hash == null || hash.isEmpty) return null;
    return domain.CachedExtraction(
      articleId: article.id,
      article: domain.ExtractedArticle(
        title: article.title,
        author: article.author,
        canonicalUri: Uri.tryParse(article.canonicalUrl),
        publishedAt: article.publishedAt,
        html: content.sanitizedHtml,
        plainText: content.plainText,
        extractor: content.extractorName,
        extractorVersion: content.extractorVersion,
      ),
      contentHash: hash,
      extractedAt: content.extractedAt.toUtc(),
      etag: content.etag,
      lastModified: content.lastModified,
      lastFailureCode: _failureCode(content.failureCode),
    );
  }
}

domain.ExtractionFailureCode? _failureCode(String? value) {
  if (value == null) return null;
  for (final code in domain.ExtractionFailureCode.values) {
    if (code.name == value) return code;
  }
  return null;
}
