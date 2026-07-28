import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftAudioQueueRepository implements domain.AudioQueueRepository {
  const DriftAudioQueueRepository(this.database);

  final RiverDatabase database;

  @override
  Stream<domain.AudioQueueSnapshot> watch() {
    final query = database.select(database.audioQueueEntries)
      ..orderBy(<OrderingTerm Function($AudioQueueEntriesTable)>[
        (table) => OrderingTerm.asc(table.queuePosition),
        (table) => OrderingTerm.asc(table.enqueuedAt),
        (table) => OrderingTerm.asc(table.itemId),
      ]);
    return query.watch().map(_snapshot);
  }

  @override
  Future<domain.AudioQueueSnapshot> read() async =>
      _snapshot(await _orderedRows());

  @override
  Future<bool> enqueue({
    required domain.AudioItem item,
    required String? contentRevision,
    required DateTime enqueuedAt,
  }) async {
    _validateCandidate(item, contentRevision);
    return database.transaction(() async {
      final rows = await _orderedRows();
      if (rows.any((row) => row.itemId == item.id)) return false;
      await database
          .into(database.audioQueueEntries)
          .insert(
            AudioQueueEntriesCompanion.insert(
              itemId: item.id,
              kind: item.kind.name,
              title: item.title,
              sourceUri: item.sourceUri.toString(),
              contentRevision: Value<String?>(contentRevision),
              queuePosition: rows.length,
              isCurrent: Value<bool>(rows.isEmpty),
              enqueuedAt: enqueuedAt.toUtc(),
              updatedAt: enqueuedAt.toUtc(),
            ),
          );
      return true;
    });
  }

  @override
  Future<void> move({
    required String itemId,
    required int targetIndex,
    required DateTime updatedAt,
  }) async {
    if (targetIndex < 0) {
      throw RangeError.value(targetIndex, 'targetIndex');
    }
    await database.transaction(() async {
      final rows = await _orderedRows();
      final from = rows.indexWhere((row) => row.itemId == itemId);
      if (from < 0 || rows.length < 2) return;
      final target = targetIndex.clamp(0, rows.length - 1);
      if (from == target) return;
      final moved = rows.removeAt(from);
      rows.insert(target, moved);
      await _writeOrder(
        rows,
        currentItemId: _currentId(rows),
        updatedAt: updatedAt,
      );
    });
  }

  @override
  Future<void> select({
    required String itemId,
    required DateTime updatedAt,
  }) async {
    await database.transaction(() async {
      final rows = await _orderedRows();
      if (!rows.any((row) => row.itemId == itemId)) return;
      await _writeOrder(rows, currentItemId: itemId, updatedAt: updatedAt);
    });
  }

  @override
  Future<void> remove({
    required String itemId,
    required DateTime updatedAt,
  }) async {
    await database.transaction(() async {
      final rows = await _orderedRows();
      final removedIndex = rows.indexWhere((row) => row.itemId == itemId);
      if (removedIndex < 0) return;
      final removedWasCurrent = rows[removedIndex].isCurrent;
      rows.removeAt(removedIndex);
      await (database.delete(
        database.audioQueueEntries,
      )..where((table) => table.itemId.equals(itemId))).go();
      if (rows.isEmpty) return;
      final currentItemId = removedWasCurrent
          ? rows[removedIndex.clamp(0, rows.length - 1)].itemId
          : _currentId(rows);
      await _writeOrder(
        rows,
        currentItemId: currentItemId,
        updatedAt: updatedAt,
      );
    });
  }

  @override
  Future<domain.AudioQueueEntry?> consumeCurrent({
    required DateTime updatedAt,
  }) async => database.transaction(() async {
    final rows = await _orderedRows();
    if (rows.isEmpty) return null;
    var currentIndex = rows.indexWhere((row) => row.isCurrent);
    if (currentIndex < 0) currentIndex = 0;
    final consumed = rows.removeAt(currentIndex);
    await (database.delete(
      database.audioQueueEntries,
    )..where((table) => table.itemId.equals(consumed.itemId))).go();
    if (rows.isNotEmpty) {
      await _writeOrder(
        rows,
        currentItemId: rows[currentIndex.clamp(0, rows.length - 1)].itemId,
        updatedAt: updatedAt,
      );
    }
    return _entry(consumed, position: currentIndex, isCurrent: true);
  });

  @override
  Future<void> clear() async {
    await database.delete(database.audioQueueEntries).go();
  }

  Future<List<AudioQueueEntry>> _orderedRows() =>
      (database.select(database.audioQueueEntries)
            ..orderBy(<OrderingTerm Function($AudioQueueEntriesTable)>[
              (table) => OrderingTerm.asc(table.queuePosition),
              (table) => OrderingTerm.asc(table.enqueuedAt),
              (table) => OrderingTerm.asc(table.itemId),
            ]))
          .get();

  Future<void> _writeOrder(
    List<AudioQueueEntry> rows, {
    required String? currentItemId,
    required DateTime updatedAt,
  }) async {
    final timestamp = updatedAt.toUtc();
    for (final (index, row) in rows.indexed) {
      await (database.update(
        database.audioQueueEntries,
      )..where((table) => table.itemId.equals(row.itemId))).write(
        AudioQueueEntriesCompanion(
          queuePosition: Value<int>(index),
          isCurrent: Value<bool>(row.itemId == currentItemId),
          updatedAt: Value<DateTime>(timestamp),
        ),
      );
    }
  }

  domain.AudioQueueSnapshot _snapshot(List<AudioQueueEntry> rows) {
    final entries = <domain.AudioQueueEntry>[];
    var currentAssigned = false;
    for (final row in rows) {
      final parsed = _tryEntry(
        row,
        position: entries.length,
        isCurrent: row.isCurrent && !currentAssigned,
      );
      if (parsed == null) continue;
      if (parsed.isCurrent) currentAssigned = true;
      entries.add(parsed);
    }
    if (entries.isNotEmpty && !currentAssigned) {
      final first = entries.first;
      entries[0] = domain.AudioQueueEntry(
        item: first.item,
        position: first.position,
        isCurrent: true,
        contentRevision: first.contentRevision,
        enqueuedAt: first.enqueuedAt,
        updatedAt: first.updatedAt,
      );
    }
    return domain.AudioQueueSnapshot(entries);
  }

  domain.AudioQueueEntry _entry(
    AudioQueueEntry row, {
    required int position,
    required bool isCurrent,
  }) => _tryEntry(row, position: position, isCurrent: isCurrent)!;

  domain.AudioQueueEntry? _tryEntry(
    AudioQueueEntry row, {
    required int position,
    required bool isCurrent,
  }) {
    final kind = domain.AudioKind.values
        .where((candidate) => candidate.name == row.kind)
        .firstOrNull;
    final sourceUri = Uri.tryParse(row.sourceUri);
    final revision = _nonEmpty(row.contentRevision);
    if (kind == null ||
        sourceUri == null ||
        !sourceUri.hasScheme ||
        sourceUri.hasAuthority && sourceUri.userInfo.isNotEmpty ||
        row.itemId.trim().isEmpty ||
        row.title.trim().isEmpty ||
        (kind == domain.AudioKind.articleTts && revision == null) ||
        (kind == domain.AudioKind.podcastEpisode && revision != null)) {
      return null;
    }
    return domain.AudioQueueEntry(
      item: domain.AudioItem(
        id: row.itemId,
        kind: kind,
        title: row.title,
        sourceUri: sourceUri,
      ),
      position: position,
      isCurrent: isCurrent,
      contentRevision: revision,
      enqueuedAt: row.enqueuedAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  String? _currentId(List<AudioQueueEntry> rows) {
    for (final row in rows) {
      if (row.isCurrent) return row.itemId;
    }
    return rows.firstOrNull?.itemId;
  }
}

void _validateCandidate(domain.AudioItem item, String? contentRevision) {
  if (item.id.trim().isEmpty ||
      item.title.trim().isEmpty ||
      !item.sourceUri.hasScheme ||
      item.sourceUri.hasAuthority && item.sourceUri.userInfo.isNotEmpty) {
    throw ArgumentError('Audio queue item is invalid.');
  }
  final revision = _nonEmpty(contentRevision);
  if (item.kind == domain.AudioKind.articleTts && revision == null) {
    throw ArgumentError('Queued article TTS requires a content revision.');
  }
  if (item.kind == domain.AudioKind.podcastEpisode && revision != null) {
    throw ArgumentError('Queued Podcast media cannot use content revision.');
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
