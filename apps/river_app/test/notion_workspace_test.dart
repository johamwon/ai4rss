import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/knowledge/notion_workspace.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';

void main() {
  test('live workspace completes a bounded redirect and selects a target',
      () async {
    final vault = _Vault();
    final broker = _Broker();
    final connector = _Connector(vault);
    final external = _ExternalUri();
    final selection = MemoryNotionTargetSelectionStore();
    final experience = LiveNotionWorkspaceExperience(
      vault: vault,
      connection: NotionConnectionController(broker: broker, vault: vault),
      targets: connector,
      connector: connector,
      externalUri: external,
      selectionStore: selection,
    );
    addTearDown(experience.close);

    await experience.load();
    expect(experience.state.phase, NotionWorkspacePhase.disconnected);

    await experience.beginAuthorization();
    expect(experience.state.phase, NotionWorkspacePhase.authorizing);
    expect(external.last, Uri.parse('https://notion.test/authorize'));

    await experience.completeAuthorization(
      'river://oauth/notion?flowId=flow-1&completionCode=finish-1',
    );
    expect(broker.completedCode, 'finish-1');
    expect(experience.state.phase, NotionWorkspacePhase.connected);
    expect(experience.state.authorization?.workspaceName, 'Test Workspace');
    expect(experience.state.targets.single.title, 'Research');
    expect(experience.state.selectedTarget, isNull);

    await experience.selectTarget(experience.state.targets.single);
    expect(experience.state.selectedTarget?.destinationId, 'dataSource:db-1');

    final restored = LiveNotionWorkspaceExperience(
      vault: vault,
      connection: NotionConnectionController(broker: broker, vault: vault),
      targets: connector,
      connector: connector,
      externalUri: external,
      selectionStore: selection,
    );
    addTearDown(restored.close);
    await restored.load();
    expect(restored.state.selectedTarget?.destinationId, 'dataSource:db-1');

    await experience.disconnect();
    expect(broker.revoked, isTrue);
    expect(await vault.read(), isNull);
    expect(experience.state.phase, NotionWorkspacePhase.disconnected);
  });

  test('mismatched redirect flow is rejected before token exchange', () async {
    final vault = _Vault();
    final broker = _Broker();
    final connector = _Connector(vault);
    final experience = LiveNotionWorkspaceExperience(
      vault: vault,
      connection: NotionConnectionController(broker: broker, vault: vault),
      targets: connector,
      connector: connector,
      externalUri: _ExternalUri(),
    );
    addTearDown(experience.close);

    await experience.beginAuthorization();
    await expectLater(
      experience.completeAuthorization(
        'river://oauth/notion?flowId=other&completionCode=finish-1',
      ),
      throwsA(
        isA<NotionOAuthFailure>().having(
          (failure) => failure.code,
          'code',
          NotionOAuthFailureCode.invalidGrant,
        ),
      ),
    );
    expect(broker.completedCode, isNull);
    expect(await vault.read(), isNull);
  });
}

final class _Vault implements NotionAuthorizationVault {
  NotionAuthorization? value;

  @override
  Future<NotionAuthorization?> read() async => value;

  @override
  Future<void> write(NotionAuthorization authorization) async {
    value = authorization;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

final class _Broker implements NotionOAuthBroker {
  String? completedCode;
  var revoked = false;

  @override
  Future<NotionOAuthFlow> start({required Uri appRedirectUri}) async {
    expect(appRedirectUri, Uri.parse('river://oauth/notion'));
    return NotionOAuthFlow(
      flowId: 'flow-1',
      authorizationUri: Uri.parse('https://notion.test/authorize'),
      expiresAt: DateTime.utc(2026, 7, 30),
    );
  }

  @override
  Future<NotionAuthorization> complete({
    required String flowId,
    required String completionCode,
  }) async {
    expect(flowId, 'flow-1');
    completedCode = completionCode;
    return _authorization();
  }

  @override
  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken) async =>
      _authorization();

  @override
  Future<void> revoke(OpaqueNotionToken accessToken) async {
    revoked = true;
  }
}

final class _Connector implements KnowledgeConnector, NotionTargetCatalog {
  const _Connector(this.vault);

  final _Vault vault;

  @override
  String get id => 'notion';

  @override
  Future<KnowledgeConnectorConnectionStatus> testConnection() async =>
      KnowledgeConnectorConnectionStatus(
        phase: await vault.read() == null
            ? KnowledgeConnectorConnectionPhase.authenticationRequired
            : KnowledgeConnectorConnectionPhase.connected,
      );

  @override
  Future<List<NotionTarget>> list({String? query}) async => <NotionTarget>[
        NotionTarget(
          kind: NotionTargetKind.dataSource,
          id: 'db-1',
          title: 'Research',
        ),
      ];

  @override
  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(KnowledgeConnectorDeleteRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  ) {
    throw UnimplementedError();
  }
}

final class _ExternalUri implements ExternalUriGateway {
  Uri? last;

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async {
    last = uri;
    return ExternalUriOpenOutcome.opened;
  }
}

NotionAuthorization _authorization() => NotionAuthorization(
      accessToken: OpaqueNotionToken('access-token'),
      refreshToken: OpaqueNotionToken('refresh-token'),
      botId: 'bot-1',
      workspaceId: 'workspace-1',
      workspaceName: 'Test Workspace',
    );
