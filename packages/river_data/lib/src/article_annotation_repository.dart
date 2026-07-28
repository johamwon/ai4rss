import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftArticleAnnotationRepository
    implements domain.ArticleAnnotationRepository {
  const DriftArticleAnnotationRepository(this.database);

  final RiverDatabase database;

  @override
  Stream<List<domain.ArticleAnnotation>> watchArticleAnnotations(
    String articleId,
  ) {
    final query = database.select(database.articleAnnotations)
      ..where((row) => row.articleId.equals(articleId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch().map(
      (rows) => List<domain.ArticleAnnotation>.unmodifiable(
        rows.map(_annotation).whereType<domain.ArticleAnnotation>(),
      ),
    );
  }

  @override
  Future<void> upsertAnnotation(domain.ArticleAnnotation annotation) async {
    _validate(annotation);
    await database
        .into(database.articleAnnotations)
        .insertOnConflictUpdate(
          ArticleAnnotationsCompanion.insert(
            id: annotation.id,
            articleId: annotation.articleId,
            exactText: annotation.anchor.exact,
            prefixText: annotation.anchor.prefix,
            suffixText: annotation.anchor.suffix,
            originalStart: annotation.anchor.originalStart,
            originalEnd: annotation.anchor.originalEnd,
            contentRevision: annotation.anchor.contentRevision,
            startDomPath: annotation.anchor.startDomPath,
            startDomOffset: annotation.anchor.startDomOffset,
            endDomPath: annotation.anchor.endDomPath,
            endDomOffset: annotation.anchor.endDomOffset,
            color: Value<String>(annotation.color.name),
            note: Value<String?>(_normalizedNote(annotation.note)),
            createdAt: annotation.createdAt.toUtc(),
            updatedAt: annotation.updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    await (database.delete(
      database.articleAnnotations,
    )..where((row) => row.id.equals(annotationId))).go();
  }
}

domain.ArticleAnnotation? _annotation(ArticleAnnotationRow row) {
  final color = domain.ArticleAnnotationColor.values
      .where((value) => value.name == row.color)
      .firstOrNull;
  if (color == null ||
      row.id.isEmpty ||
      row.articleId.isEmpty ||
      row.exactText.isEmpty ||
      row.exactText.length > 16384 ||
      row.prefixText.length > 64 ||
      row.suffixText.length > 64 ||
      row.originalStart < 0 ||
      row.originalEnd <= row.originalStart ||
      row.contentRevision.isEmpty ||
      row.contentRevision.length > 256 ||
      row.startDomPath.isEmpty ||
      row.startDomPath.length > 2048 ||
      row.endDomPath.isEmpty ||
      row.endDomPath.length > 2048 ||
      row.startDomOffset < 0 ||
      row.endDomOffset < 0 ||
      (row.note?.length ?? 0) > 20000) {
    return null;
  }
  return domain.ArticleAnnotation(
    id: row.id,
    articleId: row.articleId,
    anchor: domain.ArticleTextAnchor(
      exact: row.exactText,
      prefix: row.prefixText,
      suffix: row.suffixText,
      originalStart: row.originalStart,
      originalEnd: row.originalEnd,
      contentRevision: row.contentRevision,
      startDomPath: row.startDomPath,
      startDomOffset: row.startDomOffset,
      endDomPath: row.endDomPath,
      endDomOffset: row.endDomOffset,
    ),
    color: color,
    note: _normalizedNote(row.note),
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );
}

void _validate(domain.ArticleAnnotation annotation) {
  final anchor = annotation.anchor;
  if (annotation.id.isEmpty ||
      annotation.id.length > 256 ||
      annotation.articleId.isEmpty ||
      annotation.articleId.length > 256 ||
      anchor.exact.isEmpty ||
      anchor.exact.length > 16384 ||
      anchor.prefix.length > 64 ||
      anchor.suffix.length > 64 ||
      anchor.originalStart < 0 ||
      anchor.originalEnd <= anchor.originalStart ||
      anchor.contentRevision.isEmpty ||
      anchor.contentRevision.length > 256 ||
      anchor.startDomPath.isEmpty ||
      anchor.startDomPath.length > 2048 ||
      anchor.endDomPath.isEmpty ||
      anchor.endDomPath.length > 2048 ||
      anchor.startDomOffset < 0 ||
      anchor.endDomOffset < 0 ||
      (annotation.note?.length ?? 0) > 20000) {
    throw const FormatException('Invalid article annotation.');
  }
}

String? _normalizedNote(String? note) {
  final normalized = note?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
