import 'dart:convert';
import 'dart:typed_data';

import 'package:river_domain/river_domain.dart';

import 'knowledge_markdown.dart';

enum KnowledgeDocumentStoreFailureCode {
  offline,
  timeout,
  conflict,
  notFound,
  forbidden,
  quotaExceeded,
  unavailable,
}

final class KnowledgeDocumentStoreFailure implements Exception {
  const KnowledgeDocumentStoreFailure(this.code);

  final KnowledgeDocumentStoreFailureCode code;
}

final class KnowledgeStoredDocument {
  KnowledgeStoredDocument({
    required this.path,
    required Iterable<int> bytes,
    required this.revision,
  }) : bytes = Uint8List.fromList(bytes.toList(growable: false));

  final String path;
  final Uint8List bytes;
  final String revision;
}

abstract interface class KnowledgeDocumentStore {
  Future<bool> isAvailable();
  Future<KnowledgeStoredDocument?> read(String path);
  Future<KnowledgeStoredDocument> write(
    String path,
    List<int> bytes, {
    required String? expectedRevision,
    required bool createOnly,
  });
  Future<void> delete(String path, {required String expectedRevision});
}

final class ObsidianKnowledgeConnector implements KnowledgeConnector {
  ObsidianKnowledgeConnector({
    required KnowledgeDocumentStore store,
    required Map<String, String> destinations,
    KnowledgeMarkdownRenderer renderer = const KnowledgeMarkdownRenderer(),
  })  : _store = store,
        _renderer = renderer,
        _destinations = Map<String, String>.unmodifiable(
          destinations.map(
            (id, root) => MapEntry(id, _safeDirectory(root)),
          ),
        ) {
    if (_destinations.isEmpty ||
        _destinations.keys.any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Invalid Obsidian destinations');
    }
  }

  final KnowledgeDocumentStore _store;
  final KnowledgeMarkdownRenderer _renderer;
  final Map<String, String> _destinations;

  @override
  String get id => 'obsidian';

  @override
  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  ) async {
    final rendered = _renderer.render(request.item);
    final path = _path(request.destinationId, rendered.fileName);
    final bytes = utf8.encode(rendered.contents);
    try {
      final existing = await _store.read(path);
      if (existing != null) {
        if (_sameBytes(existing.bytes, bytes)) {
          return KnowledgeConnectorObject(externalObjectId: path);
        }
        throw const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.conflict,
          retryable: false,
        );
      }
      await _store.write(
        path,
        bytes,
        expectedRevision: null,
        createOnly: true,
      );
      return KnowledgeConnectorObject(externalObjectId: path);
    } on KnowledgeDocumentStoreFailure catch (failure) {
      throw _mapStoreFailure(failure);
    }
  }

  @override
  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  ) async {
    final rendered = _renderer.render(request.item);
    final root = _destination(request.destinationId);
    if (!_within(root, request.externalObjectId) ||
        !_sameRiverFileIdentity(
          request.externalObjectId.split('/').last,
          rendered.fileName,
        )) {
      _invalidRequest();
    }
    final path = request.externalObjectId;
    final bytes = utf8.encode(rendered.contents);
    try {
      final existing = await _store.read(path);
      if (existing == null) {
        throw const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.notFound,
          retryable: false,
        );
      }
      if (_sameBytes(existing.bytes, bytes)) {
        return KnowledgeConnectorObject(externalObjectId: path);
      }
      await _store.write(
        path,
        bytes,
        expectedRevision: existing.revision,
        createOnly: false,
      );
      return KnowledgeConnectorObject(externalObjectId: path);
    } on KnowledgeDocumentStoreFailure catch (failure) {
      throw _mapStoreFailure(failure);
    }
  }

  @override
  Future<void> delete(KnowledgeConnectorDeleteRequest request) async {
    final root = _destination(request.destinationId);
    if (!_within(root, request.externalObjectId)) _invalidRequest();
    try {
      final existing = await _store.read(request.externalObjectId);
      if (existing == null) {
        throw const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.notFound,
          retryable: false,
        );
      }
      await _store.delete(
        request.externalObjectId,
        expectedRevision: existing.revision,
      );
    } on KnowledgeDocumentStoreFailure catch (failure) {
      throw _mapStoreFailure(failure);
    }
  }

  @override
  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  ) async {
    final root = _destination(request.destinationId);
    if (!_within(root, request.externalObjectId)) _invalidRequest();
    try {
      final existing = await _store.read(request.externalObjectId);
      return KnowledgeConnectorObjectStatus(
        phase: existing == null
            ? KnowledgeConnectorObjectPhase.missing
            : KnowledgeConnectorObjectPhase.available,
      );
    } on KnowledgeDocumentStoreFailure catch (failure) {
      final mapped = _mapStoreFailure(failure);
      return KnowledgeConnectorObjectStatus(
        phase: KnowledgeConnectorObjectPhase.unavailable,
        code: mapped.code,
      );
    }
  }

  @override
  Future<KnowledgeConnectorConnectionStatus> testConnection() async {
    try {
      return KnowledgeConnectorConnectionStatus(
        phase: await _store.isAvailable()
            ? KnowledgeConnectorConnectionPhase.connected
            : KnowledgeConnectorConnectionPhase.unavailable,
      );
    } on KnowledgeDocumentStoreFailure catch (failure) {
      return KnowledgeConnectorConnectionStatus(
        phase: KnowledgeConnectorConnectionPhase.unavailable,
        code: _mapStoreFailure(failure).code,
      );
    }
  }

  String _path(String destinationId, String fileName) =>
      '${_destination(destinationId)}/$fileName';

  String _destination(String id) {
    final value = _destinations[id];
    if (value == null) _invalidRequest();
    return value;
  }
}

enum WebDavMethod { head, get, put, delete }

final class WebDavRequest {
  WebDavRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const <String, String>{},
    Iterable<int> body = const <int>[],
  })  : headers = Map<String, String>.unmodifiable(headers),
        body = Uint8List.fromList(body.toList(growable: false));

  final WebDavMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final Uint8List body;
}

final class WebDavResponse {
  WebDavResponse({
    required this.statusCode,
    Map<String, String> headers = const <String, String>{},
    Iterable<int> body = const <int>[],
  })  : headers = Map<String, String>.unmodifiable(headers),
        body = Uint8List.fromList(body.toList(growable: false));

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;

  String? header(String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }
}

enum WebDavTransportFailureCode { offline, timeout, unavailable }

final class WebDavTransportFailure implements Exception {
  const WebDavTransportFailure(this.code);

  final WebDavTransportFailureCode code;
}

abstract interface class WebDavTransport {
  Future<WebDavResponse> send(WebDavRequest request);
}

final class WebDavKnowledgeConnector implements KnowledgeConnector {
  WebDavKnowledgeConnector({
    required WebDavTransport transport,
    required Map<String, Uri> destinations,
    KnowledgeMarkdownRenderer renderer = const KnowledgeMarkdownRenderer(),
    this.allowInsecureHttp = false,
  })  : _transport = transport,
        _renderer = renderer,
        _destinations = Map<String, Uri>.unmodifiable(
          destinations.map((id, uri) => MapEntry(id, _safeWebDavBase(uri))),
        ) {
    if (_destinations.isEmpty ||
        (!allowInsecureHttp &&
            _destinations.values.any((uri) => uri.scheme != 'https'))) {
      throw ArgumentError('Invalid WebDAV destinations');
    }
  }

  final WebDavTransport _transport;
  final KnowledgeMarkdownRenderer _renderer;
  final Map<String, Uri> _destinations;
  final bool allowInsecureHttp;

  @override
  String get id => 'webdav';

  @override
  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  ) async {
    final rendered = _renderer.render(request.item);
    final objectId = Uri(pathSegments: <String>[rendered.fileName]).toString();
    final uri = _objectUri(request.destinationId, objectId);
    final bytes = utf8.encode(rendered.contents);
    final response = await _send(
      WebDavRequest(
        method: WebDavMethod.put,
        uri: uri,
        headers: <String, String>{
          'Content-Type': 'text/markdown; charset=utf-8',
          'If-None-Match': '*',
          'Idempotency-Key': request.idempotencyKey,
        },
        body: bytes,
      ),
    );
    if (_success(response.statusCode)) {
      return KnowledgeConnectorObject(
        externalObjectId: objectId,
        externalUrl: uri,
      );
    }
    if (response.statusCode == 409 || response.statusCode == 412) {
      final existing = await _get(uri);
      if (existing != null && _sameBytes(existing.body, bytes)) {
        return KnowledgeConnectorObject(
          externalObjectId: objectId,
          externalUrl: uri,
        );
      }
    }
    throw _mapWebDavResponse(response);
  }

  @override
  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  ) async {
    final uri = _objectUri(request.destinationId, request.externalObjectId);
    final existing = await _get(uri);
    if (existing == null) _notFound();
    final rendered = _renderer.render(request.item);
    final expectedId =
        Uri(pathSegments: <String>[rendered.fileName]).toString();
    if (!_sameRiverFileIdentity(
      Uri.parse(request.externalObjectId).pathSegments.single,
      Uri.parse(expectedId).pathSegments.single,
    )) {
      _invalidRequest();
    }
    final bytes = utf8.encode(rendered.contents);
    if (_sameBytes(existing.body, bytes)) {
      return KnowledgeConnectorObject(
        externalObjectId: request.externalObjectId,
        externalUrl: uri,
      );
    }
    final etag = existing.header('etag');
    if (etag == null || etag.isEmpty) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.conflict,
        retryable: true,
      );
    }
    final response = await _send(
      WebDavRequest(
        method: WebDavMethod.put,
        uri: uri,
        headers: <String, String>{
          'Content-Type': 'text/markdown; charset=utf-8',
          'If-Match': etag,
          'Idempotency-Key': request.idempotencyKey,
        },
        body: bytes,
      ),
    );
    if (!_success(response.statusCode)) throw _mapWebDavResponse(response);
    return KnowledgeConnectorObject(
      externalObjectId: request.externalObjectId,
      externalUrl: uri,
    );
  }

  @override
  Future<void> delete(KnowledgeConnectorDeleteRequest request) async {
    final uri = _objectUri(request.destinationId, request.externalObjectId);
    final existing = await _get(uri);
    if (existing == null) _notFound();
    final etag = existing.header('etag');
    if (etag == null || etag.isEmpty) _conflict();
    final response = await _send(
      WebDavRequest(
        method: WebDavMethod.delete,
        uri: uri,
        headers: <String, String>{
          'If-Match': etag,
          'Idempotency-Key': request.idempotencyKey,
        },
      ),
    );
    if (!_success(response.statusCode)) throw _mapWebDavResponse(response);
  }

  @override
  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  ) async {
    final uri = _objectUri(request.destinationId, request.externalObjectId);
    try {
      final response = await _send(
        WebDavRequest(method: WebDavMethod.head, uri: uri),
      );
      if (response.statusCode == 404) {
        return KnowledgeConnectorObjectStatus(
          phase: KnowledgeConnectorObjectPhase.missing,
        );
      }
      if (!_success(response.statusCode)) {
        final failure = _mapWebDavResponse(response);
        return KnowledgeConnectorObjectStatus(
          phase: KnowledgeConnectorObjectPhase.unavailable,
          code: failure.code,
        );
      }
      return KnowledgeConnectorObjectStatus(
        phase: KnowledgeConnectorObjectPhase.available,
        externalUrl: uri,
      );
    } on KnowledgeConnectorFailure catch (failure) {
      return KnowledgeConnectorObjectStatus(
        phase: KnowledgeConnectorObjectPhase.unavailable,
        code: failure.code,
      );
    }
  }

  @override
  Future<KnowledgeConnectorConnectionStatus> testConnection() async {
    try {
      for (final uri in _destinations.values) {
        final response = await _send(
          WebDavRequest(method: WebDavMethod.head, uri: uri),
        );
        if (!_success(response.statusCode)) {
          final failure = _mapWebDavResponse(response);
          return KnowledgeConnectorConnectionStatus(
            phase: failure.code ==
                    KnowledgeConnectorFailureCode.authenticationRequired
                ? KnowledgeConnectorConnectionPhase.authenticationRequired
                : KnowledgeConnectorConnectionPhase.unavailable,
            code: failure.code,
          );
        }
      }
      return const KnowledgeConnectorConnectionStatus(
        phase: KnowledgeConnectorConnectionPhase.connected,
      );
    } on KnowledgeConnectorFailure catch (failure) {
      return KnowledgeConnectorConnectionStatus(
        phase: KnowledgeConnectorConnectionPhase.unavailable,
        code: failure.code,
      );
    }
  }

  Future<WebDavResponse?> _get(Uri uri) async {
    final response = await _send(
      WebDavRequest(method: WebDavMethod.get, uri: uri),
    );
    if (response.statusCode == 404) return null;
    if (!_success(response.statusCode)) throw _mapWebDavResponse(response);
    if (response.body.length > 8 * 1024 * 1024) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.quotaExceeded,
        retryable: false,
      );
    }
    return response;
  }

  Future<WebDavResponse> _send(WebDavRequest request) async {
    try {
      return await _transport.send(request);
    } on WebDavTransportFailure catch (failure) {
      throw KnowledgeConnectorFailure(
        code: switch (failure.code) {
          WebDavTransportFailureCode.offline =>
            KnowledgeConnectorFailureCode.offline,
          WebDavTransportFailureCode.timeout =>
            KnowledgeConnectorFailureCode.timeout,
          WebDavTransportFailureCode.unavailable =>
            KnowledgeConnectorFailureCode.unavailable,
        },
        retryable: true,
      );
    }
  }

  Uri _objectUri(String destinationId, String objectId) {
    final base = _destinations[destinationId];
    if (base == null) _invalidRequest();
    final relative = Uri.tryParse(objectId);
    if (relative == null ||
        relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasQuery ||
        relative.hasFragment ||
        relative.pathSegments.length != 1 ||
        relative.pathSegments.single.isEmpty ||
        relative.pathSegments.single == '.' ||
        relative.pathSegments.single == '..') {
      _invalidRequest();
    }
    return base.resolveUri(relative);
  }
}

KnowledgeConnectorFailure _mapStoreFailure(
  KnowledgeDocumentStoreFailure failure,
) =>
    KnowledgeConnectorFailure(
      code: switch (failure.code) {
        KnowledgeDocumentStoreFailureCode.offline =>
          KnowledgeConnectorFailureCode.offline,
        KnowledgeDocumentStoreFailureCode.timeout =>
          KnowledgeConnectorFailureCode.timeout,
        KnowledgeDocumentStoreFailureCode.conflict =>
          KnowledgeConnectorFailureCode.conflict,
        KnowledgeDocumentStoreFailureCode.notFound =>
          KnowledgeConnectorFailureCode.notFound,
        KnowledgeDocumentStoreFailureCode.forbidden =>
          KnowledgeConnectorFailureCode.forbidden,
        KnowledgeDocumentStoreFailureCode.quotaExceeded =>
          KnowledgeConnectorFailureCode.quotaExceeded,
        KnowledgeDocumentStoreFailureCode.unavailable =>
          KnowledgeConnectorFailureCode.unavailable,
      },
      retryable: failure.code == KnowledgeDocumentStoreFailureCode.offline ||
          failure.code == KnowledgeDocumentStoreFailureCode.timeout ||
          failure.code == KnowledgeDocumentStoreFailureCode.conflict ||
          failure.code == KnowledgeDocumentStoreFailureCode.unavailable,
    );

KnowledgeConnectorFailure _mapWebDavResponse(WebDavResponse response) {
  final retryAfter = _retryAfter(response.header('retry-after'));
  return KnowledgeConnectorFailure(
    code: switch (response.statusCode) {
      401 => KnowledgeConnectorFailureCode.authenticationRequired,
      403 => KnowledgeConnectorFailureCode.forbidden,
      404 => KnowledgeConnectorFailureCode.notFound,
      409 || 412 => KnowledgeConnectorFailureCode.conflict,
      413 || 507 => KnowledgeConnectorFailureCode.quotaExceeded,
      429 => KnowledgeConnectorFailureCode.rateLimited,
      >= 500 && <= 599 => KnowledgeConnectorFailureCode.unavailable,
      _ => KnowledgeConnectorFailureCode.unexpected,
    },
    retryable: response.statusCode == 408 ||
        response.statusCode == 409 ||
        response.statusCode == 412 ||
        response.statusCode == 429 ||
        response.statusCode >= 500,
    retryAfter: retryAfter,
  );
}

Duration? _retryAfter(String? value) {
  final seconds = int.tryParse(value ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds.clamp(0, 3600));
}

Uri _safeWebDavBase(Uri uri) {
  if ((uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ArgumentError.value(uri, 'destinations');
  }
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  return uri.replace(path: path);
}

String _safeDirectory(String value) {
  final normalized = value.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/');
  final segments = normalized.split('/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      normalized.endsWith('/') ||
      segments.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw ArgumentError.value(value, 'destinations');
  }
  return normalized;
}

bool _within(String root, String path) =>
    path.startsWith('$root/') && !path.substring(root.length + 1).contains('/');

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameRiverFileIdentity(String left, String right) {
  final leftMarker = left.lastIndexOf('--');
  final rightMarker = right.lastIndexOf('--');
  return leftMarker >= 0 &&
      rightMarker >= 0 &&
      left.substring(leftMarker) == right.substring(rightMarker);
}

bool _success(int status) => status >= 200 && status < 300;

Never _invalidRequest() => throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.invalidRequest,
      retryable: false,
    );

Never _notFound() => throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.notFound,
      retryable: false,
    );

Never _conflict() => throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.conflict,
      retryable: true,
    );
