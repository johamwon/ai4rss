import 'dart:convert';

enum NotionTargetKind { page, dataSource }

final class NotionTarget {
  NotionTarget({
    required this.kind,
    required this.id,
    required this.title,
    this.url,
  }) {
    _requireIdentifier(id, 'id');
    if (title.trim().isEmpty || title.length > 2048) {
      throw ArgumentError.value(title, 'title');
    }
    if (url != null && !_isPublicWebUri(url!)) {
      throw ArgumentError.value(url, 'url');
    }
  }

  final NotionTargetKind kind;
  final String id;
  final String title;
  final Uri? url;

  String get destinationId => '${kind.name}:$id';

  static NotionTargetReference parseDestination(String destinationId) {
    final separator = destinationId.indexOf(':');
    if (separator <= 0 || separator == destinationId.length - 1) {
      throw ArgumentError.value(destinationId, 'destinationId');
    }
    final kind = switch (destinationId.substring(0, separator)) {
      'page' => NotionTargetKind.page,
      'dataSource' => NotionTargetKind.dataSource,
      _ => throw ArgumentError.value(destinationId, 'destinationId'),
    };
    return NotionTargetReference(
      kind: kind,
      id: destinationId.substring(separator + 1),
    );
  }
}

final class NotionTargetReference {
  NotionTargetReference({required this.kind, required this.id}) {
    _requireIdentifier(id, 'id');
  }

  final NotionTargetKind kind;
  final String id;
}

final class OpaqueNotionToken {
  OpaqueNotionToken(String value) : _value = value {
    if (value.trim() != value || value.length < 8 || value.length > 8192) {
      throw ArgumentError.value('<redacted>', 'value');
    }
  }

  final String _value;

  String reveal() => _value;

  @override
  String toString() => 'OpaqueNotionToken(<redacted>)';
}

final class NotionAuthorization {
  NotionAuthorization({
    required this.accessToken,
    required this.refreshToken,
    required this.botId,
    required this.workspaceId,
    required this.workspaceName,
    this.workspaceIcon,
  }) {
    _requireIdentifier(botId, 'botId');
    _requireIdentifier(workspaceId, 'workspaceId');
    if (workspaceName.trim().isEmpty || workspaceName.length > 2048) {
      throw ArgumentError.value(workspaceName, 'workspaceName');
    }
    if (workspaceIcon != null && !_isPublicWebUri(workspaceIcon!)) {
      throw ArgumentError.value(workspaceIcon, 'workspaceIcon');
    }
  }

  final OpaqueNotionToken accessToken;
  final OpaqueNotionToken refreshToken;
  final String botId;
  final String workspaceId;
  final String workspaceName;
  final Uri? workspaceIcon;
}

abstract interface class NotionAuthorizationVault {
  Future<NotionAuthorization?> read();
  Future<void> write(NotionAuthorization authorization);
  Future<void> clear();
}

final class NotionOAuthFlow {
  NotionOAuthFlow({
    required this.flowId,
    required this.authorizationUri,
    required this.expiresAt,
  }) {
    _requireIdentifier(flowId, 'flowId');
    if (!_isPublicWebUri(authorizationUri) ||
        authorizationUri.scheme != 'https') {
      throw ArgumentError.value(authorizationUri, 'authorizationUri');
    }
  }

  final String flowId;
  final Uri authorizationUri;
  final DateTime expiresAt;
}

abstract interface class NotionOAuthBroker {
  Future<NotionOAuthFlow> start({required Uri appRedirectUri});

  Future<NotionAuthorization> complete({
    required String flowId,
    required String completionCode,
  });

  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken);

  Future<void> revoke(OpaqueNotionToken accessToken);
}

abstract interface class NotionTargetCatalog {
  Future<List<NotionTarget>> list({String? query});
}

enum NotionTransportFailureCode { offline, timeout, responseTooLarge, invalid }

final class NotionTransportFailure implements Exception {
  const NotionTransportFailure(this.code);

  final NotionTransportFailureCode code;

  @override
  String toString() => 'NotionTransportFailure(${code.name})';
}

final class NotionHttpRequest {
  NotionHttpRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
  }) {
    if (!const <String>{'GET', 'POST', 'PATCH', 'DELETE'}.contains(method)) {
      throw ArgumentError.value(method, 'method');
    }
    if (!_isPublicWebUri(uri) || uri.scheme != 'https') {
      throw ArgumentError.value(uri, 'uri');
    }
  }

  factory NotionHttpRequest.json({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) =>
      NotionHttpRequest(
        method: method,
        uri: uri,
        headers: <String, String>{
          'content-type': 'application/json',
          ...headers,
        },
        body: jsonEncode(body),
      );

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

final class NotionHttpResponse {
  const NotionHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

abstract interface class NotionHttpTransport {
  Future<NotionHttpResponse> send(NotionHttpRequest request);
}

bool isSafeNotionAppRedirect(Uri uri) {
  if (uri.userInfo.isNotEmpty || uri.scheme != 'river' || uri.hasPort) {
    return false;
  }
  return (uri.host.isEmpty &&
          uri.pathSegments.length == 2 &&
          uri.pathSegments[0] == 'oauth' &&
          uri.pathSegments[1] == 'notion') ||
      (uri.host == 'oauth' &&
          uri.pathSegments.length == 1 &&
          uri.pathSegments[0] == 'notion');
}

void _requireIdentifier(String value, String name) {
  if (value.trim() != value || value.isEmpty || value.length > 1024) {
    throw ArgumentError.value(value, name);
  }
}

bool _isPublicWebUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;
