import 'dart:convert';

enum FeedServerKind { freshRss, miniflux }

enum FeedServerFailureCode {
  invalidAccount,
  authenticationFailed,
  rateLimited,
  transportFailure,
  invalidResponse,
  cursorRegression,
  mappingConflict,
}

final class FeedServerException implements Exception {
  const FeedServerException({required this.code, required this.retryable});

  final FeedServerFailureCode code;
  final bool retryable;

  @override
  String toString() =>
      'FeedServerException(code: ${code.name}, retryable: $retryable)';
}

final class FeedServerCredential {
  FeedServerCredential(String value) : _value = value {
    if (value.isEmpty ||
        value.length > 4096 ||
        value.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('Invalid feed server credential.');
    }
  }

  final String _value;

  String get value => _value;

  @override
  String toString() => 'FeedServerCredential(<redacted>)';
}

final class FeedServerAccount {
  FeedServerAccount({
    required this.id,
    required this.kind,
    required Uri baseUri,
    required this.credential,
  }) : baseUri = _validateBaseUri(baseUri) {
    if (!_identifier.hasMatch(id)) {
      throw ArgumentError('Invalid feed server account ID.');
    }
  }

  final String id;
  final FeedServerKind kind;
  final Uri baseUri;
  final FeedServerCredential credential;

  Map<String, Object> get diagnostic => <String, Object>{
        'accountId': id,
        'kind': kind.name,
        'secureTransport': true,
      };

  @override
  String toString() =>
      'FeedServerAccount(id: $id, kind: ${kind.name}, secureTransport: true)';
}

enum FeedServerHttpMethod { get, post, put }

final class FeedServerHttpRequest {
  FeedServerHttpRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const <String, String>{},
    List<int> body = const <int>[],
  })  : headers = Map<String, String>.unmodifiable(headers),
        body = List<int>.unmodifiable(body);

  final FeedServerHttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int> body;

  @override
  String toString() =>
      'FeedServerHttpRequest(method: ${method.name}, bodyBytes: ${body.length})';
}

final class FeedServerHttpResponse {
  FeedServerHttpResponse({
    required this.statusCode,
    List<int> body = const <int>[],
  }) : body = List<int>.unmodifiable(body);

  final int statusCode;
  final List<int> body;
}

abstract interface class FeedServerHttpPort {
  Future<FeedServerHttpResponse> send(FeedServerHttpRequest request);
}

final class RemoteFeedSubscription {
  RemoteFeedSubscription({
    required this.remoteId,
    required Uri feedUrl,
    required this.title,
  }) : feedUrl = _validateFeedUri(feedUrl) {
    if (remoteId.trim().isEmpty ||
        remoteId.length > 512 ||
        title.trim().isEmpty ||
        title.length > 1024) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidResponse,
        retryable: false,
      );
    }
  }

  final String remoteId;
  final Uri feedUrl;
  final String title;
}

final class RemoteEntryState {
  RemoteEntryState({
    required this.remoteEntryId,
    required this.remoteFeedId,
    required this.read,
    required this.starred,
    required this.changedAtMicros,
  }) {
    if (remoteEntryId.trim().isEmpty ||
        remoteEntryId.length > 512 ||
        remoteFeedId.trim().isEmpty ||
        remoteFeedId.length > 512 ||
        changedAtMicros < 0) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidResponse,
        retryable: false,
      );
    }
  }

  final String remoteEntryId;
  final String remoteFeedId;
  final bool read;
  final bool starred;
  final int changedAtMicros;
}

final class FeedServerPullResult {
  FeedServerPullResult({
    required List<RemoteFeedSubscription> subscriptions,
    required List<RemoteEntryState> entryStates,
    required this.nextCursor,
  })  : subscriptions =
            List<RemoteFeedSubscription>.unmodifiable(subscriptions),
        entryStates = List<RemoteEntryState>.unmodifiable(entryStates) {
    if (nextCursor < 0 ||
        subscriptions.length > 10000 ||
        entryStates.length > 10000) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidResponse,
        retryable: false,
      );
    }
  }

  final List<RemoteFeedSubscription> subscriptions;
  final List<RemoteEntryState> entryStates;
  final int nextCursor;
}

abstract interface class FeedServerAdapter {
  FeedServerKind get kind;

  Future<FeedServerPullResult> pull(
    FeedServerAccount account, {
    required int cursor,
  });

  Future<void> pushEntryStates(
    FeedServerAccount account,
    List<RemoteEntryState> states,
  );
}

final class FreshRssGoogleReaderAdapter implements FeedServerAdapter {
  const FreshRssGoogleReaderAdapter(this.http);

  final FeedServerHttpPort http;

  @override
  FeedServerKind get kind => FeedServerKind.freshRss;

  @override
  Future<FeedServerPullResult> pull(
    FeedServerAccount account, {
    required int cursor,
  }) async {
    _requireKind(account);
    final headers = _freshRssHeaders(account);
    final subscriptionsResponse = await _send(
      http,
      FeedServerHttpRequest(
        method: FeedServerHttpMethod.get,
        uri: _freshRssUri(
          account,
          'reader/api/0/subscription/list',
          <String, String>{'output': 'json'},
        ),
        headers: headers,
      ),
    );
    final streamResponse = await _send(
      http,
      FeedServerHttpRequest(
        method: FeedServerHttpMethod.get,
        uri: _freshRssUri(
          account,
          'reader/api/0/stream/contents/reading-list',
          <String, String>{
            'output': 'json',
            'n': '10000',
          },
        ),
        headers: headers,
      ),
    );
    final subscriptionJson = _jsonObject(subscriptionsResponse.body);
    final streamJson = _jsonObject(streamResponse.body);
    final subscriptions = <RemoteFeedSubscription>[];
    for (final value in _jsonList(subscriptionJson['subscriptions'])) {
      final item = _asObject(value);
      final remoteId = _string(item['id']);
      subscriptions.add(
        RemoteFeedSubscription(
          remoteId: remoteId,
          feedUrl: Uri.parse(_freshRssFeedUrl(remoteId)),
          title: _string(item['title']),
        ),
      );
    }
    var nextCursor = cursor;
    final states = <RemoteEntryState>[];
    for (final value in _jsonList(streamJson['items'])) {
      final item = _asObject(value);
      final origin = _asObject(item['origin']);
      final categories = _jsonList(item['categories']).map(_string).toSet();
      final changedAt = int.tryParse(_string(item['timestampUsec'])) ?? -1;
      final state = RemoteEntryState(
        remoteEntryId: _string(item['id']),
        remoteFeedId: _string(origin['streamId']),
        read: categories.contains('user/-/state/com.google/read'),
        starred: categories.contains('user/-/state/com.google/starred'),
        changedAtMicros: changedAt,
      );
      states.add(state);
      if (state.changedAtMicros > nextCursor)
        nextCursor = state.changedAtMicros;
    }
    return FeedServerPullResult(
      subscriptions: subscriptions,
      entryStates: states,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> pushEntryStates(
    FeedServerAccount account,
    List<RemoteEntryState> states,
  ) async {
    _requireKind(account);
    if (states.isEmpty) return;
    if (states.length > 1000) _invalidResponse();
    final headers = _freshRssHeaders(account);
    final tokenResponse = await _send(
      http,
      FeedServerHttpRequest(
        method: FeedServerHttpMethod.get,
        uri: _freshRssUri(
          account,
          'reader/api/0/token',
          const <String, String>{},
        ),
        headers: headers,
      ),
    );
    final token = utf8.decode(tokenResponse.body, allowMalformed: false).trim();
    if (token.isEmpty ||
        token.length > 4096 ||
        token.contains(RegExp(r'[\r\n]'))) {
      _invalidResponse();
    }
    for (final state in states) {
      final form = <MapEntry<String, String>>[
        MapEntry<String, String>('T', token),
        MapEntry<String, String>('i', state.remoteEntryId),
        MapEntry<String, String>(
          state.read ? 'a' : 'r',
          'user/-/state/com.google/read',
        ),
        MapEntry<String, String>(
          state.starred ? 'a' : 'r',
          'user/-/state/com.google/starred',
        ),
      ];
      await _send(
        http,
        FeedServerHttpRequest(
          method: FeedServerHttpMethod.post,
          uri: _freshRssUri(
            account,
            'reader/api/0/edit-tag',
            const <String, String>{},
          ),
          headers: <String, String>{
            ...headers,
            'content-type': 'application/x-www-form-urlencoded',
          },
          body: utf8.encode(_encodeForm(form)),
        ),
      );
    }
  }

  void _requireKind(FeedServerAccount account) {
    if (account.kind != kind) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidAccount,
        retryable: false,
      );
    }
  }
}

final class MinifluxAdapter implements FeedServerAdapter {
  const MinifluxAdapter(this.http);

  final FeedServerHttpPort http;

  @override
  FeedServerKind get kind => FeedServerKind.miniflux;

  @override
  Future<FeedServerPullResult> pull(
    FeedServerAccount account, {
    required int cursor,
  }) async {
    _requireKind(account);
    final headers = <String, String>{'X-Auth-Token': account.credential.value};
    final feedsResponse = await _send(
      http,
      FeedServerHttpRequest(
        method: FeedServerHttpMethod.get,
        uri: _minifluxUri(account, 'feeds'),
        headers: headers,
      ),
    );
    final feeds = <RemoteFeedSubscription>[];
    for (final value in _jsonList(_jsonValue(feedsResponse.body))) {
      final item = _asObject(value);
      feeds.add(
        RemoteFeedSubscription(
          remoteId: _integer(item['id']).toString(),
          feedUrl: Uri.parse(_string(item['feed_url'])),
          title: _string(item['title']),
        ),
      );
    }
    final entriesResponse = await _send(
      http,
      FeedServerHttpRequest(
        method: FeedServerHttpMethod.get,
        uri: _minifluxUri(account, 'entries', <String, String>{
          'order': 'id',
          'direction': 'asc',
          'limit': '10000',
          if (cursor > 0) 'changed_after': (cursor ~/ 1000000).toString(),
        }),
        headers: headers,
      ),
    );
    final entriesJson = _jsonObject(entriesResponse.body);
    var nextCursor = cursor;
    final states = <RemoteEntryState>[];
    for (final value in _jsonList(entriesJson['entries'])) {
      final item = _asObject(value);
      final entryId = _integer(item['id']);
      final feed = _asObject(item['feed']);
      final changedAt = _dateTime(item['changed_at']).microsecondsSinceEpoch;
      final state = RemoteEntryState(
        remoteEntryId: entryId.toString(),
        remoteFeedId: _integer(feed['id']).toString(),
        read: _string(item['status']) == 'read',
        starred: _boolean(item['starred']),
        changedAtMicros: changedAt,
      );
      if (changedAt > cursor) states.add(state);
      if (changedAt > nextCursor) nextCursor = changedAt;
    }
    return FeedServerPullResult(
      subscriptions: feeds,
      entryStates: states,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> pushEntryStates(
    FeedServerAccount account,
    List<RemoteEntryState> states,
  ) async {
    _requireKind(account);
    if (states.isEmpty) return;
    if (states.length > 10000) _invalidResponse();
    final groups = <(bool, bool), List<int>>{};
    for (final state in states) {
      final id = int.tryParse(state.remoteEntryId);
      if (id == null || id < 1) _invalidResponse();
      groups.putIfAbsent((state.read, state.starred), () => <int>[]).add(id);
    }
    for (final entry in groups.entries) {
      await _send(
        http,
        FeedServerHttpRequest(
          method: FeedServerHttpMethod.put,
          uri: _minifluxUri(account, 'entries'),
          headers: <String, String>{
            'X-Auth-Token': account.credential.value,
            'content-type': 'application/json',
          },
          body: utf8.encode(
            jsonEncode(<String, Object>{
              'entry_ids': entry.value,
              'status': entry.key.$1 ? 'read' : 'unread',
              'starred': entry.key.$2,
            }),
          ),
        ),
      );
    }
  }

  void _requireKind(FeedServerAccount account) {
    if (account.kind != kind) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidAccount,
        retryable: false,
      );
    }
  }
}

final class LocalFeedSource {
  const LocalFeedSource({
    required this.id,
    required this.canonicalUrl,
    required this.title,
  });

  final String id;
  final Uri canonicalUrl;
  final String title;
}

final class FeedAccountSourceMapping {
  const FeedAccountSourceMapping({
    required this.accountId,
    required this.remoteFeedId,
    required this.localSourceId,
  });

  final String accountId;
  final String remoteFeedId;
  final String localSourceId;
}

final class FeedAccountEntryState {
  const FeedAccountEntryState({
    required this.accountId,
    required this.remoteEntryId,
    required this.remoteFeedId,
    required this.localSourceId,
    required this.read,
    required this.starred,
    required this.changedAtMicros,
  });

  final String accountId;
  final String remoteEntryId;
  final String remoteFeedId;
  final String localSourceId;
  final bool read;
  final bool starred;
  final int changedAtMicros;
}

final class FeedAccountApplyResult {
  const FeedAccountApplyResult({
    required this.createdSources,
    required this.reusedSources,
    required this.mappings,
    required this.entryStates,
  });

  final int createdSources;
  final int reusedSources;
  final int mappings;
  final int entryStates;
}

final class FeedAccountRemovalResult {
  const FeedAccountRemovalResult({
    required this.removedMappings,
    required this.removedEntryStates,
    required this.removedOrphanSources,
  });

  final int removedMappings;
  final int removedEntryStates;
  final int removedOrphanSources;
}

abstract interface class FeedAccountMappingRepository {
  Future<int> cursorFor(String accountId);

  Future<FeedAccountApplyResult> applyPull({
    required String accountId,
    required List<RemoteFeedSubscription> subscriptions,
    required List<RemoteEntryState> entryStates,
    required int previousCursor,
    required int nextCursor,
  });

  Future<FeedAccountRemovalResult> removeAccount(String accountId);
}

abstract interface class FeedSourceIdGenerator {
  String next();
}

final class InMemoryFeedAccountMappingRepository
    implements FeedAccountMappingRepository {
  InMemoryFeedAccountMappingRepository(this.ids);

  final FeedSourceIdGenerator ids;
  final Map<String, LocalFeedSource> _sources = <String, LocalFeedSource>{};
  final Map<String, FeedAccountSourceMapping> _mappings =
      <String, FeedAccountSourceMapping>{};
  final Map<String, FeedAccountEntryState> _states =
      <String, FeedAccountEntryState>{};
  final Map<String, int> _cursors = <String, int>{};

  List<LocalFeedSource> get sources => List<LocalFeedSource>.unmodifiable(
        _sources.values,
      );
  List<FeedAccountSourceMapping> get mappings =>
      List<FeedAccountSourceMapping>.unmodifiable(_mappings.values);
  List<FeedAccountEntryState> get entryStates =>
      List<FeedAccountEntryState>.unmodifiable(_states.values);

  @override
  Future<int> cursorFor(String accountId) async => _cursors[accountId] ?? 0;

  @override
  Future<FeedAccountApplyResult> applyPull({
    required String accountId,
    required List<RemoteFeedSubscription> subscriptions,
    required List<RemoteEntryState> entryStates,
    required int previousCursor,
    required int nextCursor,
  }) async {
    if ((_cursors[accountId] ?? 0) != previousCursor ||
        nextCursor < previousCursor) {
      throw const FeedServerException(
        code: FeedServerFailureCode.cursorRegression,
        retryable: true,
      );
    }
    final subscriptionsById = <String, RemoteFeedSubscription>{};
    for (final subscription in subscriptions) {
      if (subscriptionsById.putIfAbsent(
            subscription.remoteId,
            () => subscription,
          ) !=
          subscription) {
        throw const FeedServerException(
          code: FeedServerFailureCode.mappingConflict,
          retryable: false,
        );
      }
    }
    if (entryStates.any(
      (state) => !subscriptionsById.containsKey(state.remoteFeedId),
    )) {
      throw const FeedServerException(
        code: FeedServerFailureCode.mappingConflict,
        retryable: false,
      );
    }
    final nextSources = Map<String, LocalFeedSource>.of(_sources);
    final nextMappings = Map<String, FeedAccountSourceMapping>.of(_mappings);
    final nextStates = Map<String, FeedAccountEntryState>.of(_states);
    var created = 0;
    var reused = 0;
    final newMappings = <String, FeedAccountSourceMapping>{};
    for (final subscription in subscriptions) {
      final canonicalUrl = _canonicalFeedUri(subscription.feedUrl);
      LocalFeedSource? source;
      for (final candidate in nextSources.values) {
        if (candidate.canonicalUrl == canonicalUrl) {
          source = candidate;
          break;
        }
      }
      if (source == null) {
        source = LocalFeedSource(
          id: ids.next(),
          canonicalUrl: canonicalUrl,
          title: subscription.title,
        );
        if (nextSources.containsKey(source.id)) {
          throw const FeedServerException(
            code: FeedServerFailureCode.mappingConflict,
            retryable: false,
          );
        }
        nextSources[source.id] = source;
        created++;
      } else {
        reused++;
      }
      final mapping = FeedAccountSourceMapping(
        accountId: accountId,
        remoteFeedId: subscription.remoteId,
        localSourceId: source.id,
      );
      newMappings[_mappingKey(accountId, subscription.remoteId)] = mapping;
    }
    nextMappings.removeWhere((_, value) => value.accountId == accountId);
    nextMappings.addAll(newMappings);
    nextStates.removeWhere(
      (_, value) =>
          value.accountId == accountId &&
          !newMappings.containsKey(
            _mappingKey(accountId, value.remoteFeedId),
          ),
    );
    for (final remote in entryStates) {
      final mapping = newMappings[_mappingKey(accountId, remote.remoteFeedId)];
      if (mapping == null) {
        throw const FeedServerException(
          code: FeedServerFailureCode.mappingConflict,
          retryable: false,
        );
      }
      final key = _entryKey(accountId, remote.remoteEntryId);
      final old = nextStates[key];
      if (old == null || remote.changedAtMicros >= old.changedAtMicros) {
        nextStates[key] = FeedAccountEntryState(
          accountId: accountId,
          remoteEntryId: remote.remoteEntryId,
          remoteFeedId: remote.remoteFeedId,
          localSourceId: mapping.localSourceId,
          read: remote.read,
          starred: remote.starred,
          changedAtMicros: remote.changedAtMicros,
        );
      }
    }
    final referenced =
        nextMappings.values.map((value) => value.localSourceId).toSet();
    nextSources.removeWhere((sourceId, _) => !referenced.contains(sourceId));
    _sources
      ..clear()
      ..addAll(nextSources);
    _mappings
      ..clear()
      ..addAll(nextMappings);
    _states
      ..clear()
      ..addAll(nextStates);
    _cursors[accountId] = nextCursor;
    return FeedAccountApplyResult(
      createdSources: created,
      reusedSources: reused,
      mappings: newMappings.length,
      entryStates: entryStates.length,
    );
  }

  @override
  Future<FeedAccountRemovalResult> removeAccount(String accountId) async {
    final mappings =
        _mappings.values.where((value) => value.accountId == accountId).length;
    final states =
        _states.values.where((value) => value.accountId == accountId).length;
    final before = _sources.length;
    _mappings.removeWhere((_, value) => value.accountId == accountId);
    _states.removeWhere((_, value) => value.accountId == accountId);
    _cursors.remove(accountId);
    _removeOrphans();
    return FeedAccountRemovalResult(
      removedMappings: mappings,
      removedEntryStates: states,
      removedOrphanSources: before - _sources.length,
    );
  }

  void _removeOrphans() {
    final referenced =
        _mappings.values.map((value) => value.localSourceId).toSet();
    _sources.removeWhere((id, _) => !referenced.contains(id));
  }
}

final class FeedAccountSyncResult {
  const FeedAccountSyncResult({
    required this.accountId,
    required this.previousCursor,
    required this.nextCursor,
    required this.applied,
  });

  final String accountId;
  final int previousCursor;
  final int nextCursor;
  final FeedAccountApplyResult applied;

  Map<String, Object> get diagnostic => <String, Object>{
        'accountId': accountId,
        'cursorAdvanced': nextCursor > previousCursor,
        'sourcesCreated': applied.createdSources,
        'sourcesReused': applied.reusedSources,
        'mappings': applied.mappings,
        'entryStates': applied.entryStates,
      };
}

final class FeedAccountSyncService {
  FeedAccountSyncService({
    required List<FeedServerAdapter> adapters,
    required this.repository,
  }) : _adapters = <FeedServerKind, FeedServerAdapter>{
          for (final adapter in adapters) adapter.kind: adapter,
        } {
    if (_adapters.length != adapters.length) {
      throw ArgumentError('Duplicate feed server adapter.');
    }
  }

  final Map<FeedServerKind, FeedServerAdapter> _adapters;
  final FeedAccountMappingRepository repository;

  Future<FeedAccountSyncResult> sync(FeedServerAccount account) async {
    final adapter = _adapters[account.kind];
    if (adapter == null) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidAccount,
        retryable: false,
      );
    }
    final previousCursor = await repository.cursorFor(account.id);
    final pulled = await adapter.pull(account, cursor: previousCursor);
    if (pulled.nextCursor < previousCursor) {
      throw const FeedServerException(
        code: FeedServerFailureCode.cursorRegression,
        retryable: true,
      );
    }
    final applied = await repository.applyPull(
      accountId: account.id,
      subscriptions: pulled.subscriptions,
      entryStates: pulled.entryStates,
      previousCursor: previousCursor,
      nextCursor: pulled.nextCursor,
    );
    return FeedAccountSyncResult(
      accountId: account.id,
      previousCursor: previousCursor,
      nextCursor: pulled.nextCursor,
      applied: applied,
    );
  }

  Future<void> pushEntryStates(
    FeedServerAccount account,
    List<RemoteEntryState> states,
  ) async {
    final adapter = _adapters[account.kind];
    if (adapter == null) {
      throw const FeedServerException(
        code: FeedServerFailureCode.invalidAccount,
        retryable: false,
      );
    }
    await adapter.pushEntryStates(account, states);
  }

  Future<FeedAccountRemovalResult> remove(FeedServerAccount account) =>
      repository.removeAccount(account.id);
}

final RegExp _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');

Uri _validateBaseUri(Uri value) {
  if (value.scheme.toLowerCase() != 'https' ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.query.isNotEmpty ||
      value.fragment.isNotEmpty) {
    throw ArgumentError(
      'Feed server base URL must be a credential-free HTTPS URL.',
    );
  }
  return value.replace(scheme: 'https', host: value.host.toLowerCase());
}

Uri _validateFeedUri(Uri value) {
  if ((value.scheme != 'https' && value.scheme != 'http') ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty) {
    _invalidResponse();
  }
  return value;
}

Uri _canonicalFeedUri(Uri value) {
  final checked = _validateFeedUri(value);
  final scheme = checked.scheme.toLowerCase();
  final port = (scheme == 'https' && checked.port == 443) ||
          (scheme == 'http' && checked.port == 80)
      ? null
      : checked.hasPort
          ? checked.port
          : null;
  return Uri(
    scheme: scheme,
    host: checked.host.toLowerCase(),
    port: port,
    path: checked.path,
    query: checked.hasQuery ? checked.query : null,
  );
}

Map<String, String> _freshRssHeaders(FeedServerAccount account) =>
    <String, String>{
      'Authorization': 'GoogleLogin auth=${account.credential.value}',
    };

Uri _freshRssUri(
  FeedServerAccount account,
  String suffix,
  Map<String, String> query,
) {
  var path = account.baseUri.path;
  if (!path.endsWith('/')) path = '$path/';
  if (!path.endsWith('api/greader.php/')) path = '${path}api/greader.php/';
  return account.baseUri.replace(
    path: '$path$suffix',
    queryParameters: query.isEmpty ? null : query,
  );
}

Uri _minifluxUri(
  FeedServerAccount account,
  String suffix, [
  Map<String, String> query = const <String, String>{},
]) {
  var path = account.baseUri.path;
  if (!path.endsWith('/')) path = '$path/';
  if (!path.endsWith('v1/')) path = '${path}v1/';
  return account.baseUri.replace(
    path: '$path$suffix',
    queryParameters: query.isEmpty ? null : query,
  );
}

String _freshRssFeedUrl(String remoteId) {
  if (!remoteId.startsWith('feed/')) _invalidResponse();
  return remoteId.substring(5);
}

Future<FeedServerHttpResponse> _send(
  FeedServerHttpPort http,
  FeedServerHttpRequest request,
) async {
  FeedServerHttpResponse response;
  try {
    response = await http.send(request);
  } on FeedServerException {
    rethrow;
  } on Object {
    throw const FeedServerException(
      code: FeedServerFailureCode.transportFailure,
      retryable: true,
    );
  }
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw const FeedServerException(
      code: FeedServerFailureCode.authenticationFailed,
      retryable: false,
    );
  }
  if (response.statusCode == 429) {
    throw const FeedServerException(
      code: FeedServerFailureCode.rateLimited,
      retryable: true,
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const FeedServerException(
      code: FeedServerFailureCode.transportFailure,
      retryable: true,
    );
  }
  if (response.body.length > 20 * 1024 * 1024) _invalidResponse();
  return response;
}

Object? _jsonValue(List<int> bytes) {
  try {
    return jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } on Object {
    _invalidResponse();
  }
}

Map<String, Object?> _jsonObject(List<int> bytes) =>
    _asObject(_jsonValue(bytes));

Map<String, Object?> _asObject(Object? value) {
  if (value is! Map<String, Object?>) _invalidResponse();
  return value;
}

List<Object?> _jsonList(Object? value) {
  if (value is! List<Object?>) _invalidResponse();
  return value;
}

String _string(Object? value) {
  if (value is! String) _invalidResponse();
  return value;
}

int _integer(Object? value) {
  if (value is! int) _invalidResponse();
  return value;
}

bool _boolean(Object? value) {
  if (value is! bool) _invalidResponse();
  return value;
}

DateTime _dateTime(Object? value) {
  final text = _string(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null) _invalidResponse();
  return parsed.toUtc();
}

String _mappingKey(String accountId, String remoteFeedId) =>
    '$accountId\u0000$remoteFeedId';
String _entryKey(String accountId, String remoteEntryId) =>
    '$accountId\u0000$remoteEntryId';

String _encodeForm(Iterable<MapEntry<String, String>> values) => values
    .map(
      (entry) =>
          '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
    )
    .join('&');

Never _invalidResponse() => throw const FeedServerException(
      code: FeedServerFailureCode.invalidResponse,
      retryable: false,
    );
