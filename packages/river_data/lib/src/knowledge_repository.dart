import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftKnowledgeRepository implements domain.KnowledgeRepository {
  const DriftKnowledgeRepository(this.database);

  final RiverDatabase database;

  @override
  Stream<List<domain.KnowledgeItem>> watchItems() {
    final query = database.select(database.knowledgeItems)
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch().map(
      (rows) => List<domain.KnowledgeItem>.unmodifiable(
        rows.map(_item).whereType<domain.KnowledgeItem>(),
      ),
    );
  }

  @override
  Stream<domain.KnowledgeItem?> watchItem(String itemId) {
    final query = database.select(database.knowledgeItems)
      ..where((row) => row.id.equals(itemId));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _item(row),
    );
  }

  @override
  Future<domain.KnowledgeItem?> findBySource(
    domain.KnowledgeSourceReference source,
  ) async {
    final query = database.select(database.knowledgeItems)
      ..where(
        (row) =>
            row.sourceKind.equals(source.kind.name) &
            row.sourceId.equals(source.sourceId),
      );
    final row = await query.getSingleOrNull();
    return row == null ? null : _item(row);
  }

  @override
  Future<domain.KnowledgeItem> saveItem(domain.KnowledgeItem item) {
    return database.transaction(() async {
      final existingQuery = database.select(database.knowledgeItems)
        ..where(
          (row) =>
              row.sourceKind.equals(item.source.kind.name) &
              row.sourceId.equals(item.source.sourceId),
        );
      final existing = await existingQuery.getSingleOrNull();
      if (existing != null && existing.updatedAt.isAfter(item.updatedAt)) {
        final current = _item(existing);
        if (current != null) return current;
      }
      final stored = existing == null
          ? item
          : item.withId(existing.id, savedAt: existing.createdAt.toUtc());
      final articleExists =
          stored.source.kind == domain.KnowledgeSourceKind.article &&
          await (database.select(database.articles)
                    ..where((row) => row.id.equals(stored.source.sourceId)))
                  .getSingleOrNull() !=
              null;
      await database
          .into(database.knowledgeItems)
          .insertOnConflictUpdate(
            KnowledgeItemsCompanion.insert(
              id: stored.id,
              articleId: Value<String?>(
                articleExists ? stored.source.sourceId : null,
              ),
              sourceKind: Value<String>(stored.source.kind.name),
              sourceId: Value<String?>(stored.source.sourceId),
              sourceTitle: Value<String?>(stored.source.sourceTitle),
              author: Value<String?>(stored.source.author),
              publishedAt: Value<DateTime?>(stored.source.publishedAt?.toUtc()),
              title: stored.title,
              originalUrl: stored.source.originalUrl.toString(),
              markdown: stored.markdown,
              sanitizedHtml: Value<String>(stored.sanitizedHtml),
              summaryJson: Value<String?>(_encodeSummary(stored.summary)),
              highlightsJson: Value<String>(_encodeExcerpts(stored.excerpts)),
              notesJson: Value<String>(jsonEncode(stored.notes)),
              tagsJson: Value<String>(jsonEncode(stored.tags)),
              topicsJson: Value<String>(jsonEncode(stored.topics)),
              entitiesJson: Value<String>(jsonEncode(stored.entities)),
              contentHash: stored.contentHash,
              createdAt: stored.savedAt.toUtc(),
              updatedAt: stored.updatedAt.toUtc(),
            ),
          );
      return stored;
    });
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await (database.delete(
      database.knowledgeItems,
    )..where((row) => row.id.equals(itemId))).go();
  }

  @override
  Stream<List<domain.KnowledgeExternalMapping>> watchExternalMappings(
    String itemId,
  ) {
    final query = database.select(database.knowledgeExternalMappings)
      ..where((row) => row.knowledgeItemId.equals(itemId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.connectorId),
        (row) => OrderingTerm.asc(row.destinationId),
      ]);
    return query.watch().map(
      (rows) => List<domain.KnowledgeExternalMapping>.unmodifiable(
        rows.map(_externalMapping).whereType<domain.KnowledgeExternalMapping>(),
      ),
    );
  }

  @override
  Future<void> upsertExternalMapping(domain.KnowledgeExternalMapping mapping) {
    return database.transaction(() async {
      final existingQuery = database.select(database.knowledgeExternalMappings)
        ..where(
          (row) =>
              row.knowledgeItemId.equals(mapping.knowledgeItemId) &
              row.connectorId.equals(mapping.connectorId) &
              row.destinationId.equals(mapping.destinationId),
        );
      final existing = await existingQuery.getSingleOrNull();
      if (existing != null && !mapping.updatedAt.isAfter(existing.updatedAt)) {
        return;
      }
      await database
          .into(database.knowledgeExternalMappings)
          .insertOnConflictUpdate(
            KnowledgeExternalMappingsCompanion.insert(
              knowledgeItemId: mapping.knowledgeItemId,
              connectorId: mapping.connectorId,
              destinationId: mapping.destinationId,
              externalObjectId: mapping.externalObjectId,
              externalUrl: Value<String?>(mapping.externalUrl?.toString()),
              exportedContentHash: mapping.exportedContentHash,
              createdAt: (existing?.createdAt ?? mapping.createdAt).toUtc(),
              updatedAt: mapping.updatedAt.toUtc(),
            ),
          );
    });
  }

  @override
  Future<void> deleteExternalMapping({
    required String knowledgeItemId,
    required String connectorId,
    required String destinationId,
  }) async {
    await (database.delete(database.knowledgeExternalMappings)..where(
          (row) =>
              row.knowledgeItemId.equals(knowledgeItemId) &
              row.connectorId.equals(connectorId) &
              row.destinationId.equals(destinationId),
        ))
        .go();
  }
}

domain.KnowledgeItem? _item(KnowledgeItemRow row) {
  try {
    final kind = domain.KnowledgeSourceKind.values
        .where((value) => value.name == row.sourceKind)
        .firstOrNull;
    final sourceId = row.sourceId;
    if (kind == null || sourceId == null) return null;
    return domain.KnowledgeItem(
      id: row.id,
      source: domain.KnowledgeSourceReference(
        kind: kind,
        sourceId: sourceId,
        originalUrl: Uri.parse(row.originalUrl),
        sourceTitle: row.sourceTitle ?? row.title,
        author: row.author,
        publishedAt: row.publishedAt?.toUtc(),
      ),
      title: row.title,
      markdown: row.markdown,
      sanitizedHtml: row.sanitizedHtml,
      summary: _decodeSummary(row.summaryJson),
      excerpts: _decodeExcerpts(row.highlightsJson),
      notes: _decodeStringList(row.notesJson),
      tags: _decodeStringList(row.tagsJson),
      topics: _decodeStringList(row.topicsJson),
      entities: _decodeStringList(row.entitiesJson),
      contentHash: row.contentHash,
      savedAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  } on Object {
    return null;
  }
}

domain.KnowledgeExternalMapping? _externalMapping(
  KnowledgeExternalMappingRow row,
) {
  try {
    return domain.KnowledgeExternalMapping(
      knowledgeItemId: row.knowledgeItemId,
      connectorId: row.connectorId,
      destinationId: row.destinationId,
      externalObjectId: row.externalObjectId,
      externalUrl: row.externalUrl == null ? null : Uri.parse(row.externalUrl!),
      exportedContentHash: row.exportedContentHash,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  } on Object {
    return null;
  }
}

String? _encodeSummary(domain.ArticleSummary? summary) => summary == null
    ? null
    : jsonEncode(<String, Object>{
        'oneLine': summary.oneLine,
        'keyPoints': summary.keyPoints,
        'whyItMatters': summary.whyItMatters,
        'topics': summary.topics,
        'entities': summary.entities,
        'estimatedReadingMinutes': summary.estimatedReadingMinutes,
        'language': summary.language,
        'model': summary.model,
        'promptVersion': summary.promptVersion,
      });

domain.ArticleSummary? _decodeSummary(String? encoded) {
  if (encoded == null) return null;
  try {
    final value = jsonDecode(encoded);
    if (value is! Map<String, Object?>) return null;
    final keyPoints = value['keyPoints'];
    if (keyPoints is! List<Object?>) return null;
    return domain.ArticleSummary(
      oneLine: value['oneLine'] as String,
      keyPoints: keyPoints.cast<String>(),
      whyItMatters: value['whyItMatters'] as String? ?? '',
      topics:
          (value['topics'] as List<Object?>?)?.cast<String>() ??
          const <String>[],
      entities:
          (value['entities'] as List<Object?>?)?.cast<String>() ??
          const <String>[],
      estimatedReadingMinutes: value['estimatedReadingMinutes'] as int? ?? 0,
      language: value['language'] as String,
      model: value['model'] as String,
      promptVersion: value['promptVersion'] as String,
    );
  } on Object {
    return null;
  }
}

String _encodeExcerpts(List<domain.KnowledgeExcerpt> excerpts) => jsonEncode(
  excerpts
      .map(
        (excerpt) => <String, Object?>{
          'quote': excerpt.quote,
          'note': excerpt.note,
          'annotationId': excerpt.annotationId,
        },
      )
      .toList(growable: false),
);

List<domain.KnowledgeExcerpt> _decodeExcerpts(String encoded) {
  final value = jsonDecode(encoded);
  if (value is! List<Object?>) throw const FormatException('Invalid excerpts');
  return value
      .map((entry) {
        if (entry is! Map<String, Object?>) {
          throw const FormatException('Invalid excerpt');
        }
        return domain.KnowledgeExcerpt(
          quote: entry['quote'] as String,
          note: entry['note'] as String?,
          annotationId: entry['annotationId'] as String?,
        );
      })
      .toList(growable: false);
}

List<String> _decodeStringList(String encoded) {
  final value = jsonDecode(encoded);
  if (value is! List<Object?>) throw const FormatException('Invalid list');
  return value.cast<String>();
}
