import 'dart:convert';

import 'package:river_domain/river_domain.dart';

import 'notion_models.dart';
import 'notion_oauth.dart';

final class NotionOAuthPendingFlow {
  const NotionOAuthPendingFlow({
    required this.flowId,
    required this.state,
    required this.appRedirectUri,
    required this.expiresAt,
  });

  final String flowId;
  final String state;
  final Uri appRedirectUri;
  final DateTime expiresAt;
}

abstract interface class NotionOAuthGrantStore {
  Future<void> savePending(NotionOAuthPendingFlow flow);

  /// Atomically consumes a state. A replay must return null.
  Future<NotionOAuthPendingFlow?> consumePending(String state);

  Future<void> saveGrant({
    required String flowId,
    required String completionCode,
    required NotionAuthorization authorization,
    required DateTime expiresAt,
  });

  /// Atomically consumes a one-time grant. A replay must return null.
  Future<NotionAuthorization?> consumeGrant({
    required String flowId,
    required String completionCode,
    required DateTime now,
  });
}

abstract interface class NotionOAuthCodeGenerator {
  String next();
}

abstract interface class NotionOAuthUpstream {
  Future<NotionAuthorization> exchange(String authorizationCode);
  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken);
  Future<void> revoke(OpaqueNotionToken accessToken);
}

final class NotionOAuthCallbackResult {
  const NotionOAuthCallbackResult({
    required this.appRedirectUri,
    required this.flowId,
    required this.completionCode,
  });

  final Uri appRedirectUri;
  final String flowId;
  final String completionCode;
}

/// Server-only OAuth kernel. The upstream implementation is the only object
/// that receives the Notion client secret.
final class NotionOAuthServerKernel {
  NotionOAuthServerKernel({
    required String clientId,
    required Uri serverRedirectUri,
    required NotionOAuthGrantStore store,
    required NotionOAuthCodeGenerator codeGenerator,
    required NotionOAuthUpstream upstream,
    required Clock clock,
    this.flowTtl = const Duration(minutes: 10),
    this.grantTtl = const Duration(minutes: 2),
    Uri? authorizationEndpoint,
  })  : _clientId = _identifier(clientId, 'clientId'),
        _serverRedirectUri = _https(serverRedirectUri, 'serverRedirectUri'),
        _store = store,
        _codeGenerator = codeGenerator,
        _upstream = upstream,
        _clock = clock,
        _authorizationEndpoint = _https(
          authorizationEndpoint ??
              Uri.https('api.notion.com', '/v1/oauth/authorize'),
          'authorizationEndpoint',
        );

  final String _clientId;
  final Uri _serverRedirectUri;
  final NotionOAuthGrantStore _store;
  final NotionOAuthCodeGenerator _codeGenerator;
  final NotionOAuthUpstream _upstream;
  final Clock _clock;
  final Uri _authorizationEndpoint;
  final Duration flowTtl;
  final Duration grantTtl;

  Future<NotionOAuthFlow> start({required Uri appRedirectUri}) async {
    if (!isSafeNotionAppRedirect(appRedirectUri)) {
      throw ArgumentError.value(appRedirectUri, 'appRedirectUri');
    }
    final now = _clock.now().toUtc();
    final flowId = _identifier(_codeGenerator.next(), 'flowId');
    final state = _identifier(_codeGenerator.next(), 'state');
    final expiresAt = now.add(flowTtl);
    await _store.savePending(
      NotionOAuthPendingFlow(
        flowId: flowId,
        state: state,
        appRedirectUri: appRedirectUri,
        expiresAt: expiresAt,
      ),
    );
    return NotionOAuthFlow(
      flowId: flowId,
      authorizationUri: _authorizationEndpoint.replace(
        queryParameters: <String, String>{
          'client_id': _clientId,
          'response_type': 'code',
          'owner': 'user',
          'redirect_uri': _serverRedirectUri.toString(),
          'state': state,
        },
      ),
      expiresAt: expiresAt,
    );
  }

  Future<NotionOAuthCallbackResult> callback({
    required String state,
    required String authorizationCode,
  }) async {
    final pending = await _store.consumePending(state);
    final now = _clock.now().toUtc();
    if (pending == null || !now.isBefore(pending.expiresAt)) {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.expired);
    }
    final authorization = await _upstream.exchange(authorizationCode);
    final completionCode = _identifier(
      _codeGenerator.next(),
      'completionCode',
    );
    await _store.saveGrant(
      flowId: pending.flowId,
      completionCode: completionCode,
      authorization: authorization,
      expiresAt: now.add(grantTtl),
    );
    return NotionOAuthCallbackResult(
      appRedirectUri: pending.appRedirectUri.replace(
        queryParameters: <String, String>{
          'flow': pending.flowId,
          'code': completionCode,
        },
      ),
      flowId: pending.flowId,
      completionCode: completionCode,
    );
  }

  Future<NotionAuthorization> complete({
    required String flowId,
    required String completionCode,
  }) async {
    final authorization = await _store.consumeGrant(
      flowId: flowId,
      completionCode: completionCode,
      now: _clock.now().toUtc(),
    );
    if (authorization == null) {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidGrant);
    }
    return authorization;
  }

  Future<NotionAuthorization> refresh(OpaqueNotionToken token) =>
      _upstream.refresh(token);

  Future<void> revoke(OpaqueNotionToken token) => _upstream.revoke(token);
}

/// Actual Notion token endpoint adapter. Construct this only in River's server
/// composition root and inject the client secret from a secret manager.
final class HttpNotionOAuthUpstream implements NotionOAuthUpstream {
  HttpNotionOAuthUpstream({
    required String clientId,
    required String clientSecret,
    required Uri redirectUri,
    required NotionHttpTransport transport,
  })  : _basic = base64Encode(
          utf8.encode(
            '${_identifier(clientId, 'clientId')}:'
            '${_identifier(clientSecret, 'clientSecret')}',
          ),
        ),
        _redirectUri = _https(redirectUri, 'redirectUri'),
        _transport = transport;

  static const _apiVersion = '2026-03-11';
  static final _tokenUri = Uri.https('api.notion.com', '/v1/oauth/token');
  static final _revokeUri = Uri.https('api.notion.com', '/v1/oauth/revoke');

  final String _basic;
  final Uri _redirectUri;
  final NotionHttpTransport _transport;

  @override
  Future<NotionAuthorization> exchange(String authorizationCode) => _token(
        <String, Object?>{
          'grant_type': 'authorization_code',
          'code': _identifier(authorizationCode, 'authorizationCode'),
          'redirect_uri': _redirectUri.toString(),
        },
      );

  @override
  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken) => _token(
        <String, Object?>{
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken.reveal(),
        },
      );

  @override
  Future<void> revoke(OpaqueNotionToken accessToken) async {
    final response = await _transport.send(
      NotionHttpRequest.json(
        method: 'POST',
        uri: _revokeUri,
        headers: _headers,
        body: <String, Object?>{'token': accessToken.reveal()},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.unavailable);
    }
  }

  Future<NotionAuthorization> _token(Map<String, Object?> body) async {
    final response = await _transport.send(
      NotionHttpRequest.json(
        method: 'POST',
        uri: _tokenUri,
        headers: _headers,
        body: body,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotionOAuthFailure(
        response.statusCode == 400
            ? NotionOAuthFailureCode.invalidGrant
            : NotionOAuthFailureCode.unavailable,
      );
    }
    try {
      final value = Map<String, Object?>.from(
        jsonDecode(response.body) as Map,
      );
      return NotionAuthorization(
        accessToken: OpaqueNotionToken(value['access_token'] as String),
        refreshToken: OpaqueNotionToken(value['refresh_token'] as String),
        botId: value['bot_id'] as String,
        workspaceId: value['workspace_id'] as String,
        workspaceName: (value['workspace_name'] as String?) ?? 'Notion',
        workspaceIcon: switch (value['workspace_icon']) {
          final String icon => Uri.parse(icon),
          _ => null,
        },
      );
    } on Object {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidResponse);
    }
  }

  Map<String, String> get _headers => <String, String>{
        'accept': 'application/json',
        'authorization': 'Basic $_basic',
        'notion-version': _apiVersion,
      };
}

String _identifier(String value, String name) {
  if (value.trim() != value || value.isEmpty || value.length > 8192) {
    throw ArgumentError.value('<redacted>', name);
  }
  return value;
}

Uri _https(Uri uri, String name) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw ArgumentError.value(uri, name);
  }
  return uri;
}
