import 'package:river_domain/river_domain.dart';

import 'opml_codec.dart';

final class FeedFolderRecord {
  const FeedFolderRecord({
    required this.id,
    required this.path,
    required this.position,
  });

  final String id;
  final List<String> path;
  final int position;

  String get name => path.isEmpty ? '' : path.last;

  String get displayPath => path.join(' / ');
}

final class OpmlImportReport {
  const OpmlImportReport({
    required this.importedSubscriptions,
    required this.createdFolders,
    required this.skippedDuplicates,
    required this.skippedInvalid,
  });

  final int importedSubscriptions;
  final int createdFolders;
  final int skippedDuplicates;
  final int skippedInvalid;
}

final class SubscriptionOrganizerException implements Exception {
  const SubscriptionOrganizerException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SubscriptionOrganizerRepository {
  Stream<List<FeedFolderRecord>> watchFolders();

  Future<FeedFolderRecord> createFolder({
    required String id,
    required List<String> path,
    required DateTime createdAt,
  });

  Future<void> renameFolder({
    required String folderId,
    required String name,
    required DateTime updatedAt,
  });

  Future<void> deleteFolder({
    required String folderId,
    required DateTime updatedAt,
  });

  Future<void> moveFeed({
    required String feedId,
    required String? folderId,
    required DateTime updatedAt,
  });

  Future<OpmlImportReport> importOpml({
    required OpmlDocument document,
    required IdGenerator ids,
    required DateTime importedAt,
  });

  Future<OpmlDocument> exportOpml();
}

final class SubscriptionOrganizerService {
  const SubscriptionOrganizerService({
    required this.repository,
    required this.clock,
    required this.ids,
    this.codec = const OpmlCodec(),
  });

  final SubscriptionOrganizerRepository repository;
  final Clock clock;
  final IdGenerator ids;
  final OpmlCodec codec;

  Stream<List<FeedFolderRecord>> watchFolders() => repository.watchFolders();

  Future<FeedFolderRecord> createFolder(String name) {
    final normalized = _folderName(name);
    return repository.createFolder(
      id: ids.next(),
      path: <String>[normalized],
      createdAt: clock.now().toUtc(),
    );
  }

  Future<void> renameFolder(String folderId, String name) =>
      repository.renameFolder(
        folderId: folderId,
        name: _folderName(name),
        updatedAt: clock.now().toUtc(),
      );

  Future<void> deleteFolder(String folderId) => repository.deleteFolder(
        folderId: folderId,
        updatedAt: clock.now().toUtc(),
      );

  Future<void> moveFeed(String feedId, String? folderId) => repository.moveFeed(
        feedId: feedId,
        folderId: folderId,
        updatedAt: clock.now().toUtc(),
      );

  Future<OpmlImportReport> import(String source) => repository.importOpml(
        document: codec.parse(source),
        ids: ids,
        importedAt: clock.now().toUtc(),
      );

  Future<String> export() async => codec.encode(await repository.exportOpml());
}

String _folderName(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw const SubscriptionOrganizerException('文件夹名称不能为空');
  }
  if (normalized.length > 128) {
    throw const SubscriptionOrganizerException('文件夹名称不能超过 128 个字符');
  }
  return normalized;
}
