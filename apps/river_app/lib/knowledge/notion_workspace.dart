import 'dart:async';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

enum NotionWorkspacePhase {
  loading,
  disconnected,
  authorizing,
  connected,
  unavailable,
}

final class NotionWorkspaceState {
  const NotionWorkspaceState({
    required this.phase,
    this.authorization,
    this.targets = const <NotionTarget>[],
    this.selectedTarget,
    this.pendingFlow,
    this.failureCode,
  });

  const NotionWorkspaceState.loading()
      : this(phase: NotionWorkspacePhase.loading);

  final NotionWorkspacePhase phase;
  final NotionAuthorization? authorization;
  final List<NotionTarget> targets;
  final NotionTarget? selectedTarget;
  final NotionOAuthFlow? pendingFlow;
  final String? failureCode;

  bool get isConnected =>
      phase == NotionWorkspacePhase.connected && authorization != null;
}

abstract interface class NotionWorkspaceExperience {
  NotionWorkspaceState get state;
  Stream<NotionWorkspaceState> get states;

  Future<void> load();
  Future<void> beginAuthorization();
  Future<void> completeAuthorization(String completionCodeOrRedirect);
  Future<void> refreshTargets({String? query});
  Future<void> selectTarget(NotionTarget target);
  Future<void> disconnect();
  Future<void> close();
}

abstract interface class NotionTargetSelectionStore {
  Future<String?> read();
  Future<void> write(String destinationId);
  Future<void> clear();
}

final class MemoryNotionTargetSelectionStore
    implements NotionTargetSelectionStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String destinationId) async {
    NotionTarget.parseDestination(destinationId);
    _value = destinationId;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

final class SecureNotionTargetSelectionStore
    implements NotionTargetSelectionStore {
  SecureNotionTargetSelectionStore({required SecureKeyValueStore store})
      : _store = store;

  factory SecureNotionTargetSelectionStore.standard() =>
      SecureNotionTargetSelectionStore(store: FlutterSecureKeyValueStore());

  static const _storageKey = 'river.notion.v1.destination';
  final SecureKeyValueStore _store;
  Future<void> _tail = Future<void>.value();

  @override
  Future<String?> read() => _serialized(() async {
        final value = await _store.read(_storageKey);
        if (value != null) NotionTarget.parseDestination(value);
        return value;
      });

  @override
  Future<void> write(String destinationId) {
    NotionTarget.parseDestination(destinationId);
    return _serialized(() => _store.write(_storageKey, destinationId));
  }

  @override
  Future<void> clear() => _serialized(() => _store.delete(_storageKey));

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}

final class LiveNotionWorkspaceExperience implements NotionWorkspaceExperience {
  LiveNotionWorkspaceExperience({
    required NotionAuthorizationVault vault,
    required NotionConnectionController connection,
    required NotionTargetCatalog targets,
    required KnowledgeConnector connector,
    required ExternalUriGateway externalUri,
    NotionTargetSelectionStore? selectionStore,
    Uri? appRedirectUri,
  })  : _vault = vault,
        _connection = connection,
        _targets = targets,
        _connector = connector,
        _externalUri = externalUri,
        _selectionStore = selectionStore ?? MemoryNotionTargetSelectionStore(),
        appRedirectUri = appRedirectUri ?? Uri.parse('river://oauth/notion') {
    if (!isSafeNotionAppRedirect(this.appRedirectUri)) {
      throw ArgumentError.value(this.appRedirectUri, 'appRedirectUri');
    }
  }

  final NotionAuthorizationVault _vault;
  final NotionConnectionController _connection;
  final NotionTargetCatalog _targets;
  final KnowledgeConnector _connector;
  final ExternalUriGateway _externalUri;
  final NotionTargetSelectionStore _selectionStore;
  final Uri appRedirectUri;
  final StreamController<NotionWorkspaceState> _states =
      StreamController<NotionWorkspaceState>.broadcast(sync: true);

  NotionWorkspaceState _state = const NotionWorkspaceState.loading();
  var _generation = 0;
  var _targetGeneration = 0;

  @override
  NotionWorkspaceState get state => _state;

  @override
  Stream<NotionWorkspaceState> get states => _states.stream;

  @override
  Future<void> load() async {
    final generation = ++_generation;
    _emit(const NotionWorkspaceState.loading());
    try {
      final authorization = await _vault.read();
      if (generation != _generation) return;
      if (authorization == null) {
        _emit(
          const NotionWorkspaceState(
            phase: NotionWorkspacePhase.disconnected,
          ),
        );
        return;
      }
      final connection = await _connector.testConnection();
      if (generation != _generation) return;
      switch (connection.phase) {
        case KnowledgeConnectorConnectionPhase.connected:
          _emit(
            NotionWorkspaceState(
              phase: NotionWorkspacePhase.connected,
              authorization: authorization,
            ),
          );
          await refreshTargets();
        case KnowledgeConnectorConnectionPhase.authenticationRequired:
          _emit(
            const NotionWorkspaceState(
              phase: NotionWorkspacePhase.disconnected,
              failureCode: 'authentication_required',
            ),
          );
        case KnowledgeConnectorConnectionPhase.unavailable:
          _emit(
            NotionWorkspaceState(
              phase: NotionWorkspacePhase.unavailable,
              authorization: authorization,
              failureCode: connection.code?.name ?? 'unavailable',
            ),
          );
      }
    } on Object {
      if (generation == _generation) {
        _emit(
          const NotionWorkspaceState(
            phase: NotionWorkspacePhase.unavailable,
            failureCode: 'authorization_unavailable',
          ),
        );
      }
    }
  }

  @override
  Future<void> beginAuthorization() async {
    final flow = await _connection.begin(appRedirectUri: appRedirectUri);
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.authorizing,
        pendingFlow: flow,
      ),
    );
    final outcome = await _externalUri.open(flow.authorizationUri);
    if (outcome != ExternalUriOpenOutcome.opened) {
      _emit(
        NotionWorkspaceState(
          phase: NotionWorkspacePhase.unavailable,
          pendingFlow: flow,
          failureCode: 'browser_unavailable',
        ),
      );
    }
  }

  @override
  Future<void> completeAuthorization(String completionCodeOrRedirect) async {
    final flow = _state.pendingFlow;
    if (flow == null) {
      throw const NotionOAuthFailure(NotionOAuthFailureCode.expired);
    }
    final completion = _completion(completionCodeOrRedirect, flow.flowId);
    final authorization = await _connection.complete(
      flowId: flow.flowId,
      completionCode: completion,
    );
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.connected,
        authorization: authorization,
      ),
    );
    await refreshTargets();
  }

  @override
  Future<void> refreshTargets({String? query}) async {
    final generation = ++_targetGeneration;
    final authorization = _state.authorization ?? await _vault.read();
    if (generation != _targetGeneration) return;
    if (authorization == null) {
      _emit(
        const NotionWorkspaceState(
          phase: NotionWorkspacePhase.disconnected,
        ),
      );
      return;
    }
    try {
      final values = await _targets.list(query: query);
      if (generation != _targetGeneration) return;
      final storedDestination = await _selectionStore.read();
      if (generation != _targetGeneration) return;
      final selected = _retainSelection(_state.selectedTarget, values) ??
          _selectionForDestination(storedDestination, values);
      _emit(
        NotionWorkspaceState(
          phase: NotionWorkspacePhase.connected,
          authorization: authorization,
          targets: values,
          selectedTarget: selected,
        ),
      );
    } on KnowledgeConnectorFailure catch (failure) {
      _emit(
        NotionWorkspaceState(
          phase: failure.code ==
                  KnowledgeConnectorFailureCode.authenticationRequired
              ? NotionWorkspacePhase.disconnected
              : NotionWorkspacePhase.unavailable,
          authorization: authorization,
          selectedTarget: _state.selectedTarget,
          failureCode: failure.code.name,
        ),
      );
    }
  }

  @override
  Future<void> selectTarget(NotionTarget target) async {
    if (!_state.targets.any(
      (candidate) => candidate.destinationId == target.destinationId,
    )) {
      throw ArgumentError.value(target.destinationId, 'target');
    }
    await _selectionStore.write(target.destinationId);
    _emit(
      NotionWorkspaceState(
        phase: NotionWorkspacePhase.connected,
        authorization: _state.authorization,
        targets: _state.targets,
        selectedTarget: target,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    ++_generation;
    ++_targetGeneration;
    await _connection.disconnect();
    await _selectionStore.clear();
    _emit(
      const NotionWorkspaceState(
        phase: NotionWorkspacePhase.disconnected,
      ),
    );
  }

  @override
  Future<void> close() => _states.close();

  void _emit(NotionWorkspaceState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}

String _completion(String value, String expectedFlowId) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 8192) {
    throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidGrant);
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return trimmed;
  if (!isSafeNotionAppRedirect(uri)) {
    throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidGrant);
  }
  final flowId = uri.queryParameters['flowId'];
  if (flowId != null && flowId != expectedFlowId) {
    throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidGrant);
  }
  final completion =
      uri.queryParameters['completionCode'] ?? uri.queryParameters['code'];
  if (completion == null || completion.trim().isEmpty) {
    throw const NotionOAuthFailure(NotionOAuthFailureCode.invalidGrant);
  }
  return completion.trim();
}

NotionTarget? _retainSelection(
  NotionTarget? selected,
  List<NotionTarget> targets,
) {
  if (selected == null) return null;
  for (final target in targets) {
    if (target.destinationId == selected.destinationId) return target;
  }
  return null;
}

NotionTarget? _selectionForDestination(
  String? destinationId,
  List<NotionTarget> targets,
) {
  if (destinationId == null) return null;
  for (final target in targets) {
    if (target.destinationId == destinationId) return target;
  }
  return null;
}
