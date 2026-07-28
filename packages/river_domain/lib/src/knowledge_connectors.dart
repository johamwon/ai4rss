import 'knowledge.dart';

enum KnowledgeConnectorConnectionPhase {
  connected,
  authenticationRequired,
  unavailable,
}

final class KnowledgeConnectorConnectionStatus {
  const KnowledgeConnectorConnectionStatus({
    required this.phase,
    this.code,
  });

  final KnowledgeConnectorConnectionPhase phase;
  final KnowledgeConnectorFailureCode? code;
}

final class KnowledgeConnectorObject {
  KnowledgeConnectorObject({
    required this.externalObjectId,
    this.externalUrl,
  }) {
    _validateIdentifier(externalObjectId, 'externalObjectId');
    if (externalUrl != null && !_isPublicWebUri(externalUrl!)) {
      throw ArgumentError.value(externalUrl, 'externalUrl');
    }
  }

  final String externalObjectId;
  final Uri? externalUrl;
}

enum KnowledgeConnectorObjectPhase { available, missing, unavailable }

final class KnowledgeConnectorObjectStatus {
  KnowledgeConnectorObjectStatus({
    required this.phase,
    this.externalUrl,
    this.code,
  }) {
    if (externalUrl != null && !_isPublicWebUri(externalUrl!)) {
      throw ArgumentError.value(externalUrl, 'externalUrl');
    }
  }

  final KnowledgeConnectorObjectPhase phase;
  final Uri? externalUrl;
  final KnowledgeConnectorFailureCode? code;
}

final class KnowledgeConnectorCreateRequest {
  KnowledgeConnectorCreateRequest({
    required this.item,
    required this.destinationId,
    required this.idempotencyKey,
  }) {
    _validateIdentifier(destinationId, 'destinationId');
    _validateIdentifier(idempotencyKey, 'idempotencyKey', maxLength: 1024);
  }

  final KnowledgeItem item;
  final String destinationId;
  final String idempotencyKey;
}

final class KnowledgeConnectorUpdateRequest {
  KnowledgeConnectorUpdateRequest({
    required this.item,
    required this.destinationId,
    required this.externalObjectId,
    required this.idempotencyKey,
  }) {
    _validateIdentifier(destinationId, 'destinationId');
    _validateIdentifier(externalObjectId, 'externalObjectId');
    _validateIdentifier(idempotencyKey, 'idempotencyKey', maxLength: 1024);
  }

  final KnowledgeItem item;
  final String destinationId;
  final String externalObjectId;
  final String idempotencyKey;
}

final class KnowledgeConnectorDeleteRequest {
  KnowledgeConnectorDeleteRequest({
    required this.knowledgeItemId,
    required this.destinationId,
    required this.externalObjectId,
    required this.idempotencyKey,
  }) {
    _validateIdentifier(knowledgeItemId, 'knowledgeItemId');
    _validateIdentifier(destinationId, 'destinationId');
    _validateIdentifier(externalObjectId, 'externalObjectId');
    _validateIdentifier(idempotencyKey, 'idempotencyKey', maxLength: 1024);
  }

  final String knowledgeItemId;
  final String destinationId;
  final String externalObjectId;
  final String idempotencyKey;
}

final class KnowledgeConnectorStatusRequest {
  KnowledgeConnectorStatusRequest({
    required this.destinationId,
    required this.externalObjectId,
  }) {
    _validateIdentifier(destinationId, 'destinationId');
    _validateIdentifier(externalObjectId, 'externalObjectId');
  }

  final String destinationId;
  final String externalObjectId;
}

enum KnowledgeConnectorFailureCode {
  offline,
  timeout,
  rateLimited,
  authenticationRequired,
  forbidden,
  notFound,
  invalidRequest,
  quotaExceeded,
  conflict,
  unavailable,
  unexpected,
}

final class KnowledgeConnectorFailure implements Exception {
  const KnowledgeConnectorFailure({
    required this.code,
    required this.retryable,
    this.retryAfter,
  });

  final KnowledgeConnectorFailureCode code;
  final bool retryable;
  final Duration? retryAfter;

  @override
  String toString() => 'KnowledgeConnectorFailure(${code.name})';
}

abstract interface class KnowledgeConnector {
  String get id;

  Future<KnowledgeConnectorConnectionStatus> testConnection();

  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  );

  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  );

  Future<void> delete(KnowledgeConnectorDeleteRequest request);

  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  );
}

enum KnowledgeExportOperation { upsert, delete }

enum KnowledgeExportPhase {
  notQueued,
  queued,
  running,
  succeeded,
  failed,
  cancelled,
}

final class KnowledgeExportTarget {
  KnowledgeExportTarget({
    required this.knowledgeItemId,
    required this.connectorId,
    required this.destinationId,
  }) {
    _validateIdentifier(knowledgeItemId, 'knowledgeItemId', maxLength: 256);
    _validateIdentifier(connectorId, 'connectorId', maxLength: 256);
    _validateIdentifier(destinationId, 'destinationId', maxLength: 256);
  }

  final String knowledgeItemId;
  final String connectorId;
  final String destinationId;

  String get stableKey => '${_component(knowledgeItemId)}'
      '${_component(connectorId)}'
      '${_component(destinationId)}';
}

final class KnowledgeExportState {
  const KnowledgeExportState({
    required this.target,
    required this.operation,
    required this.phase,
    this.attempt = 0,
    this.failureCode,
    this.externalUrl,
  });

  final KnowledgeExportTarget target;
  final KnowledgeExportOperation operation;
  final KnowledgeExportPhase phase;
  final int attempt;
  final String? failureCode;
  final Uri? externalUrl;
}

abstract interface class KnowledgeExportManager {
  Stream<KnowledgeExportState> watch(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  );

  Future<KnowledgeExportState> status(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  );

  Future<void> enqueueUpsert(KnowledgeExportTarget target);

  Future<void> enqueueDelete(KnowledgeExportTarget target);

  Future<void> retry(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  );
}

void _validateIdentifier(
  String value,
  String name, {
  int maxLength = 512,
}) {
  if (value != value.trim() || value.isEmpty || value.length > maxLength) {
    throw ArgumentError.value(value, name);
  }
}

bool _isPublicWebUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

String _component(String value) => '${value.length}:$value';
