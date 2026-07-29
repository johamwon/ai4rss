import 'dart:convert';

import 'notion_models.dart';

enum NotionOAuthFailureCode {
  cancelled,
  expired,
  invalidGrant,
  unavailable,
  invalidResponse,
}

final class NotionOAuthFailure implements Exception {
  const NotionOAuthFailure(this.code);

  final NotionOAuthFailureCode code;

  @override
  String toString() => 'NotionOAuthFailure(${code.name})';
}

/// Client for River's OAuth broker. The Notion client secret is never sent to
/// this client; only one-time flow and completion codes cross the app boundary.
final class HttpNotionOAuthBroker implements NotionOAuthBroker {
  HttpNotionOAuthBroker({
    required Uri brokerBaseUri,
    required NotionHttpTransport transport,
  })  : _baseUri = _validatedBaseUri(brokerBaseUri),
        _transport = transport;

  final Uri _baseUri;
  final NotionHttpTransport _transport;

  @override
  Future<NotionOAuthFlow> start({required Uri appRedirectUri}) async {
    if (!isSafeNotionAppRedirect(appRedirectUri)) {
      throw ArgumentError.value(appRedirectUri, 'appRedirectUri');
    }
    final value = await _post(
      'v1/oauth/notion/start',
      <String, Object?>{'appRedirectUri': appRedirectUri.toString()},
    );
    try {
      return NotionOAuthFlow(
        flowId: _string(value, 'flowId'),
        authorizationUri: Uri.parse(_string(value, 'authorizationUrl')),
        expiresAt: DateTime.parse(_string(value, 'expiresAt')).toUtc(),
      );
    } on Object {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidResponse);
    }
  }

  @override
  Future<NotionAuthorization> complete({
    required String flowId,
    required String completionCode,
  }) async {
    final value = await _post(
      'v1/oauth/notion/complete',
      <String, Object?>{
        'flowId': flowId,
        'completionCode': completionCode,
      },
    );
    return decodeNotionAuthorization(value);
  }

  @override
  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken) async {
    final value = await _post(
      'v1/oauth/notion/refresh',
      <String, Object?>{'refreshToken': refreshToken.reveal()},
    );
    return decodeNotionAuthorization(value);
  }

  @override
  Future<void> revoke(OpaqueNotionToken accessToken) async {
    await _post(
      'v1/oauth/notion/revoke',
      <String, Object?>{'accessToken': accessToken.reveal()},
    );
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    late final NotionHttpResponse response;
    try {
      response = await _transport.send(
        NotionHttpRequest.json(
          method: 'POST',
          uri: _baseUri.resolve(path),
          headers: const <String, String>{'accept': 'application/json'},
          body: body,
        ),
      );
    } on NotionTransportFailure {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.unavailable);
    }
    final value = _decodeObject(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return value;
    }
    final error = value['error'];
    throw NotionOAuthFailure(
      switch (error) {
        'access_denied' => NotionOAuthFailureCode.cancelled,
        'expired_flow' => NotionOAuthFailureCode.expired,
        'invalid_grant' => NotionOAuthFailureCode.invalidGrant,
        _ => NotionOAuthFailureCode.unavailable,
      },
    );
  }
}

final class NotionConnectionController {
  const NotionConnectionController({
    required NotionOAuthBroker broker,
    required NotionAuthorizationVault vault,
  })  : _broker = broker,
        _vault = vault;

  final NotionOAuthBroker _broker;
  final NotionAuthorizationVault _vault;

  Future<NotionOAuthFlow> begin({required Uri appRedirectUri}) =>
      _broker.start(appRedirectUri: appRedirectUri);

  Future<NotionAuthorization> complete({
    required String flowId,
    required String completionCode,
  }) async {
    final authorization = await _broker.complete(
      flowId: flowId,
      completionCode: completionCode,
    );
    await _vault.write(authorization);
    return authorization;
  }

  Future<void> disconnect() async {
    final authorization = await _vault.read();
    if (authorization == null) return;
    await _broker.revoke(authorization.accessToken);
    await _vault.clear();
  }
}

Map<String, Object?> encodeNotionAuthorization(
  NotionAuthorization authorization,
) =>
    <String, Object?>{
      'accessToken': authorization.accessToken.reveal(),
      'refreshToken': authorization.refreshToken.reveal(),
      'botId': authorization.botId,
      'workspaceId': authorization.workspaceId,
      'workspaceName': authorization.workspaceName,
      'workspaceIcon': authorization.workspaceIcon?.toString(),
    };

NotionAuthorization decodeNotionAuthorization(Map<String, Object?> value) {
  try {
    final icon = value['workspaceIcon'];
    return NotionAuthorization(
      accessToken: OpaqueNotionToken(_string(value, 'accessToken')),
      refreshToken: OpaqueNotionToken(_string(value, 'refreshToken')),
      botId: _string(value, 'botId'),
      workspaceId: _string(value, 'workspaceId'),
      workspaceName: _string(value, 'workspaceName'),
      workspaceIcon: icon == null ? null : Uri.parse(icon as String),
    );
  } on Object {
    throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidResponse);
  }
}

Map<String, Object?> _decodeObject(String encoded) {
  try {
    final value = jsonDecode(encoded);
    if (value is! Map) throw const FormatException();
    return Map<String, Object?>.from(value);
  } on Object {
    throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidResponse);
  }
}

String _string(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) throw const FormatException();
  return field;
}

Uri _validatedBaseUri(Uri uri) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw ArgumentError.value(uri, 'brokerBaseUri');
  }
  return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
}
