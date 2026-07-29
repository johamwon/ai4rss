import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  group('Notion OAuth server kernel', () {
    test('uses one-time state and one-time completion grant', () async {
      final store = _GrantStore();
      final upstream = _Upstream();
      final kernel = NotionOAuthServerKernel(
        clientId: 'public-client-id',
        serverRedirectUri: Uri.parse(
          'https://api.river.example/v1/oauth/notion/callback',
        ),
        store: store,
        codeGenerator: _Codes(<String>['flow-1', 'state-1', 'grant-1']),
        upstream: upstream,
        clock: _Clock(DateTime.utc(2026, 7, 29)),
      );

      final flow = await kernel.start(
        appRedirectUri: Uri.parse('river:/oauth/notion'),
      );
      expect(flow.flowId, 'flow-1');
      expect(
        flow.authorizationUri.queryParameters,
        containsPair('owner', 'user'),
      );
      expect(
        flow.authorizationUri.queryParameters,
        containsPair('state', 'state-1'),
      );
      expect(
        flow.authorizationUri.queryParameters,
        containsPair(
          'redirect_uri',
          'https://api.river.example/v1/oauth/notion/callback',
        ),
      );

      final callback = await kernel.callback(
        state: 'state-1',
        authorizationCode: 'notion-code',
      );
      expect(callback.appRedirectUri.scheme, 'river');
      expect(callback.appRedirectUri.queryParameters['code'], 'grant-1');
      expect(upstream.exchanges, <String>['notion-code']);

      final authorization = await kernel.complete(
        flowId: 'flow-1',
        completionCode: 'grant-1',
      );
      expect(authorization.workspaceId, 'workspace-1');
      await expectLater(
        kernel.complete(flowId: 'flow-1', completionCode: 'grant-1'),
        throwsA(
          isA<NotionOAuthFailure>().having(
            (failure) => failure.code,
            'code',
            NotionOAuthFailureCode.invalidGrant,
          ),
        ),
      );
      await expectLater(
        kernel.callback(
          state: 'state-1',
          authorizationCode: 'replayed-code',
        ),
        throwsA(
          isA<NotionOAuthFailure>().having(
            (failure) => failure.code,
            'code',
            NotionOAuthFailureCode.expired,
          ),
        ),
      );
    });

    test('rejects expired state before exchanging a token', () async {
      final store = _GrantStore();
      final clock = _Clock(DateTime.utc(2026, 7, 29));
      final upstream = _Upstream();
      final kernel = NotionOAuthServerKernel(
        clientId: 'public-client-id',
        serverRedirectUri: Uri.parse('https://api.river.example/callback'),
        store: store,
        codeGenerator: _Codes(<String>['flow-1', 'state-1']),
        upstream: upstream,
        clock: clock,
        flowTtl: const Duration(minutes: 1),
      );
      await kernel.start(appRedirectUri: Uri.parse('river:/oauth/notion'));
      clock.value = clock.value.add(const Duration(minutes: 2));

      await expectLater(
        kernel.callback(state: 'state-1', authorizationCode: 'late-code'),
        throwsA(isA<NotionOAuthFailure>()),
      );
      expect(upstream.exchanges, isEmpty);
    });
  });

  test(
      'HTTP broker never needs a client secret and stores result via controller',
      () async {
    final transport = _JsonTransport((request) {
      final body = jsonDecode(request.body!) as Map<String, Object?>;
      expect(body.containsKey('clientSecret'), isFalse);
      if (request.uri.path.endsWith('/start')) {
        return <String, Object?>{
          'flowId': 'flow-1',
          'authorizationUrl':
              'https://api.notion.com/v1/oauth/authorize?state=state-1',
          'expiresAt': '2026-07-29T00:10:00.000Z',
        };
      }
      if (request.uri.path.endsWith('/complete')) {
        expect(body, <String, Object?>{
          'flowId': 'flow-1',
          'completionCode': 'grant-1',
        });
        return encodeNotionAuthorization(_authorization());
      }
      if (request.uri.path.endsWith('/revoke')) return <String, Object?>{};
      fail('Unexpected broker request: ${request.uri.path}');
    });
    final broker = HttpNotionOAuthBroker(
      brokerBaseUri: Uri.parse('https://api.river.example/'),
      transport: transport,
    );
    final vault = _Vault();
    final controller = NotionConnectionController(
      broker: broker,
      vault: vault,
    );

    final flow = await controller.begin(
      appRedirectUri: Uri.parse('river:/oauth/notion'),
    );
    await controller.complete(
      flowId: flow.flowId,
      completionCode: 'grant-1',
    );
    expect((await vault.read())?.botId, 'bot-1');
    await controller.disconnect();
    expect(await vault.read(), isNull);
  });

  test('server upstream keeps Basic secret out of JSON request bodies',
      () async {
    final requests = <NotionHttpRequest>[];
    final upstream = HttpNotionOAuthUpstream(
      clientId: 'client-id',
      clientSecret: 'server-secret',
      redirectUri: Uri.parse('https://api.river.example/callback'),
      transport: _JsonTransport((request) {
        requests.add(request);
        return <String, Object?>{
          'access_token': 'access-token-value',
          'refresh_token': 'refresh-token-value',
          'bot_id': 'bot-1',
          'workspace_id': 'workspace-1',
          'workspace_name': 'River Lab',
          'workspace_icon': null,
        };
      }),
    );

    await upstream.exchange('temporary-code');
    final request = requests.single;
    expect(request.headers['authorization'], startsWith('Basic '));
    expect(request.headers['notion-version'], '2026-03-11');
    expect(request.body, isNot(contains('server-secret')));
    expect(request.body, isNot(contains('client-id')));
  });
}

final class _Clock implements Clock {
  _Clock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _Codes implements NotionOAuthCodeGenerator {
  _Codes(this.values);

  final List<String> values;

  @override
  String next() => values.removeAt(0);
}

final class _Grant {
  const _Grant({
    required this.code,
    required this.authorization,
    required this.expiresAt,
  });

  final String code;
  final NotionAuthorization authorization;
  final DateTime expiresAt;
}

final class _GrantStore implements NotionOAuthGrantStore {
  final Map<String, NotionOAuthPendingFlow> pending =
      <String, NotionOAuthPendingFlow>{};
  final Map<String, _Grant> grants = <String, _Grant>{};

  @override
  Future<NotionOAuthPendingFlow?> consumePending(String state) async =>
      pending.remove(state);

  @override
  Future<NotionAuthorization?> consumeGrant({
    required String flowId,
    required String completionCode,
    required DateTime now,
  }) async {
    final grant = grants.remove(flowId);
    if (grant == null ||
        grant.code != completionCode ||
        !now.isBefore(grant.expiresAt)) {
      return null;
    }
    return grant.authorization;
  }

  @override
  Future<void> saveGrant({
    required String flowId,
    required String completionCode,
    required NotionAuthorization authorization,
    required DateTime expiresAt,
  }) async {
    grants[flowId] = _Grant(
      code: completionCode,
      authorization: authorization,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> savePending(NotionOAuthPendingFlow flow) async {
    pending[flow.state] = flow;
  }
}

final class _Upstream implements NotionOAuthUpstream {
  final List<String> exchanges = <String>[];

  @override
  Future<NotionAuthorization> exchange(String authorizationCode) async {
    exchanges.add(authorizationCode);
    return _authorization();
  }

  @override
  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken) async =>
      _authorization();

  @override
  Future<void> revoke(OpaqueNotionToken accessToken) async {}
}

final class _JsonTransport implements NotionHttpTransport {
  _JsonTransport(this.handler);

  final Map<String, Object?> Function(NotionHttpRequest request) handler;

  @override
  Future<NotionHttpResponse> send(NotionHttpRequest request) async =>
      NotionHttpResponse(
        statusCode: 200,
        body: jsonEncode(handler(request)),
      );
}

final class _Vault implements NotionAuthorizationVault {
  NotionAuthorization? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<NotionAuthorization?> read() async => value;

  @override
  Future<void> write(NotionAuthorization authorization) async {
    value = authorization;
  }
}

NotionAuthorization _authorization() => NotionAuthorization(
      accessToken: OpaqueNotionToken('access-token-value'),
      refreshToken: OpaqueNotionToken('refresh-token-value'),
      botId: 'bot-1',
      workspaceId: 'workspace-1',
      workspaceName: 'River Lab',
    );
