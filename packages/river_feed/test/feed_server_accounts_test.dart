import 'dart:convert';

import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('accounts require credential-free HTTPS and redact secrets', () {
    final account = _account(
      id: 'fresh-main',
      kind: FeedServerKind.freshRss,
      token: 'secret-token',
    );

    expect(account.toString(), isNot(contains('secret-token')));
    expect(account.credential.toString(), isNot(contains('secret-token')));
    expect(account.diagnostic, <String, Object>{
      'accountId': 'fresh-main',
      'kind': 'freshRss',
      'secureTransport': true,
    });
    expect(
      () => FeedServerAccount(
        id: 'bad',
        kind: FeedServerKind.miniflux,
        baseUri: Uri.parse('http://reader.example'),
        credential: FeedServerCredential('token'),
      ),
      throwsArgumentError,
    );
    expect(
      () => FeedServerAccount(
        id: 'bad',
        kind: FeedServerKind.miniflux,
        baseUri: Uri.parse('https://token@reader.example'),
        credential: FeedServerCredential('token'),
      ),
      throwsArgumentError,
    );
  });

  test('FreshRSS pulls subscriptions and timestamped state after cursor',
      () async {
    final http = _Http(<FeedServerHttpResponse>[
      _json(<String, Object>{
        'subscriptions': <Object>[
          <String, Object>{
            'id': 'feed/https://news.example/feed.xml',
            'title': 'News',
          },
        ],
      }),
      _json(<String, Object>{
        'items': <Object>[
          <String, Object>{
            'id': 'tag:google.com,2005:reader/item/1',
            'timestampUsec': '2000001',
            'categories': <String>[
              'user/-/state/com.google/read',
              'user/-/state/com.google/starred',
            ],
            'origin': <String, Object>{
              'streamId': 'feed/https://news.example/feed.xml',
            },
          },
        ],
      }),
    ]);

    final result = await FreshRssGoogleReaderAdapter(http).pull(
      _account(id: 'fresh', kind: FeedServerKind.freshRss),
      cursor: 1000000,
    );

    expect(
      result.subscriptions.single.feedUrl.toString(),
      'https://news.example/feed.xml',
    );
    expect(result.entryStates.single.read, isTrue);
    expect(result.entryStates.single.starred, isTrue);
    expect(result.nextCursor, 2000001);
    expect(http.requests, hasLength(2));
    expect(
      http.requests.first.uri.path,
      '/api/greader.php/reader/api/0/subscription/list',
    );
    expect(http.requests.last.uri.queryParameters, isNot(contains('ot')));
    expect(
      http.requests.first.headers['Authorization'],
      'GoogleLogin auth=token',
    );
    expect(http.requests.first.toString(), isNot(contains('token')));
  });

  test('FreshRSS writes state through token and edit-tag without URL secrets',
      () async {
    final http = _Http(<FeedServerHttpResponse>[
      FeedServerHttpResponse(statusCode: 200, body: utf8.encode('csrf-token')),
      FeedServerHttpResponse(statusCode: 200),
    ]);
    final adapter = FreshRssGoogleReaderAdapter(http);

    await adapter.pushEntryStates(
      _account(id: 'fresh', kind: FeedServerKind.freshRss),
      <RemoteEntryState>[
        _state(id: 'remote-entry', feed: 'feed/https://news.example/feed.xml'),
      ],
    );

    expect(http.requests, hasLength(2));
    expect(
      http.requests.last.uri.path,
      '/api/greader.php/reader/api/0/edit-tag',
    );
    final form = utf8.decode(http.requests.last.body);
    expect(form, contains('T=csrf-token'));
    expect(form, contains('i=remote-entry'));
    expect(form, contains('a=user%2F-%2Fstate%2Fcom.google%2Fread'));
    expect(form, contains('r=user%2F-%2Fstate%2Fcom.google%2Fstarred'));
    expect(http.requests.last.uri.toString(), isNot(contains('csrf-token')));
  });

  test('Miniflux pulls ascending entries and batches matching state writes',
      () async {
    final http = _Http(<FeedServerHttpResponse>[
      _json(<Object>[
        <String, Object>{
          'id': 42,
          'feed_url': 'https://news.example/feed.xml',
          'title': 'News',
        },
      ]),
      _json(<String, Object>{
        'total': 1,
        'entries': <Object>[
          <String, Object>{
            'id': 888,
            'status': 'unread',
            'starred': true,
            'changed_at': '2026-08-06T00:00:02Z',
            'feed': <String, Object>{'id': 42},
          },
        ],
      }),
      FeedServerHttpResponse(statusCode: 204),
    ]);
    final account = _account(id: 'mini', kind: FeedServerKind.miniflux);
    final adapter = MinifluxAdapter(http);

    final cursor = DateTime.utc(2026, 8, 6).microsecondsSinceEpoch;
    final result = await adapter.pull(account, cursor: cursor);
    await adapter.pushEntryStates(account, result.entryStates);

    expect(
      result.nextCursor,
      DateTime.utc(2026, 8, 6, 0, 0, 2).microsecondsSinceEpoch,
    );
    expect(result.entryStates.single.starred, isTrue);
    expect(
      http.requests[1].uri.queryParameters['changed_after'],
      (cursor ~/ 1000000).toString(),
    );
    expect(http.requests[2].method, FeedServerHttpMethod.put);
    expect(jsonDecode(utf8.decode(http.requests[2].body)), <String, Object>{
      'entry_ids': <int>[888],
      'status': 'unread',
      'starred': true,
    });
  });

  test('adapters map authentication, rate limit, and malformed JSON safely',
      () async {
    for (final scenario in <(int, FeedServerFailureCode, bool)>[
      (401, FeedServerFailureCode.authenticationFailed, false),
      (429, FeedServerFailureCode.rateLimited, true),
    ]) {
      final adapter = MinifluxAdapter(
        _Http(<FeedServerHttpResponse>[
          FeedServerHttpResponse(statusCode: scenario.$1),
        ]),
      );
      await expectLater(
        adapter.pull(
          _account(id: 'mini', kind: FeedServerKind.miniflux),
          cursor: 0,
        ),
        throwsA(
          isA<FeedServerException>()
              .having((error) => error.code, 'code', scenario.$2)
              .having((error) => error.retryable, 'retryable', scenario.$3),
        ),
      );
    }
    final malformed = MinifluxAdapter(
      _Http(<FeedServerHttpResponse>[
        FeedServerHttpResponse(statusCode: 200, body: utf8.encode('{')),
      ]),
    );
    await expectLater(
      malformed.pull(
        _account(id: 'mini', kind: FeedServerKind.miniflux),
        cursor: 0,
      ),
      throwsA(
        isA<FeedServerException>().having(
          (error) => error.code,
          'code',
          FeedServerFailureCode.invalidResponse,
        ),
      ),
    );
  });

  test('multi-account mappings reuse one canonical local source', () async {
    final repository = InMemoryFeedAccountMappingRepository(_Ids());
    final service = FeedAccountSyncService(
      adapters: <FeedServerAdapter>[
        _Adapter(
          FeedServerKind.freshRss,
          _pull(
            feedId: 'remote-fresh',
            cursor: 10,
            feedUrl: 'https://NEWS.example:443/feed.xml',
          ),
        ),
        _Adapter(
          FeedServerKind.miniflux,
          _pull(
            feedId: '42',
            cursor: 20,
            feedUrl: 'https://news.example/feed.xml',
          ),
        ),
      ],
      repository: repository,
    );

    final fresh = await service.sync(
      _account(id: 'fresh', kind: FeedServerKind.freshRss),
    );
    final mini = await service.sync(
      _account(id: 'mini', kind: FeedServerKind.miniflux),
    );

    expect(fresh.applied.createdSources, 1);
    expect(mini.applied.createdSources, 0);
    expect(mini.applied.reusedSources, 1);
    expect(repository.sources, hasLength(1));
    expect(repository.mappings, hasLength(2));
    expect(
      repository.mappings.map((value) => value.localSourceId).toSet(),
      hasLength(1),
    );
  });

  test('cursor advances monotonically and stale remote state cannot overwrite',
      () async {
    final repository = InMemoryFeedAccountMappingRepository(_Ids());
    final adapter = _SequenceAdapter(<FeedServerPullResult>[
      _pull(feedId: '42', cursor: 20, read: true),
      _pull(feedId: '42', cursor: 30, read: false, changedAt: 10),
    ]);
    final service = FeedAccountSyncService(
      adapters: <FeedServerAdapter>[adapter],
      repository: repository,
    );
    final account = _account(id: 'mini', kind: FeedServerKind.miniflux);

    await service.sync(account);
    final second = await service.sync(account);

    expect(adapter.cursors, <int>[0, 20]);
    expect(second.nextCursor, 30);
    expect(repository.entryStates.single.read, isTrue);
  });

  test('cursor regression fails before mappings are modified', () async {
    final repository = InMemoryFeedAccountMappingRepository(_Ids());
    final adapter = _SequenceAdapter(<FeedServerPullResult>[
      _pull(feedId: '42', cursor: 20),
      _pull(feedId: 'other', cursor: 19),
    ]);
    final service = FeedAccountSyncService(
      adapters: <FeedServerAdapter>[adapter],
      repository: repository,
    );
    final account = _account(id: 'mini', kind: FeedServerKind.miniflux);
    await service.sync(account);

    await expectLater(
      service.sync(account),
      throwsA(
        isA<FeedServerException>().having(
          (error) => error.code,
          'code',
          FeedServerFailureCode.cursorRegression,
        ),
      ),
    );
    expect(repository.mappings.single.remoteFeedId, '42');
  });

  test('account removal retains shared source until its final mapping is gone',
      () async {
    final repository = InMemoryFeedAccountMappingRepository(_Ids());
    final service = FeedAccountSyncService(
      adapters: <FeedServerAdapter>[
        _Adapter(FeedServerKind.freshRss, _pull(feedId: 'fresh', cursor: 1)),
        _Adapter(FeedServerKind.miniflux, _pull(feedId: 'mini', cursor: 1)),
      ],
      repository: repository,
    );
    final fresh = _account(id: 'fresh', kind: FeedServerKind.freshRss);
    final mini = _account(id: 'mini', kind: FeedServerKind.miniflux);
    await service.sync(fresh);
    await service.sync(mini);

    final first = await service.remove(fresh);
    expect(first.removedOrphanSources, 0);
    expect(repository.sources, hasLength(1));
    expect(repository.entryStates.single.accountId, 'mini');

    final last = await service.remove(mini);
    expect(last.removedOrphanSources, 1);
    expect(repository.sources, isEmpty);
    expect(repository.mappings, isEmpty);
    expect(repository.entryStates, isEmpty);
  });
}

FeedServerAccount _account({
  required String id,
  required FeedServerKind kind,
  String token = 'token',
}) =>
    FeedServerAccount(
      id: id,
      kind: kind,
      baseUri: Uri.parse('https://reader.example'),
      credential: FeedServerCredential(token),
    );

RemoteEntryState _state({
  required String id,
  required String feed,
  bool read = true,
  bool starred = false,
  int changedAt = 20,
}) =>
    RemoteEntryState(
      remoteEntryId: id,
      remoteFeedId: feed,
      read: read,
      starred: starred,
      changedAtMicros: changedAt,
    );

FeedServerPullResult _pull({
  required String feedId,
  required int cursor,
  bool read = true,
  int changedAt = 20,
  String feedUrl = 'https://news.example/feed.xml',
}) =>
    FeedServerPullResult(
      subscriptions: <RemoteFeedSubscription>[
        RemoteFeedSubscription(
          remoteId: feedId,
          feedUrl: Uri.parse(feedUrl),
          title: 'News',
        ),
      ],
      entryStates: <RemoteEntryState>[
        _state(
          id: 'entry-$feedId',
          feed: feedId,
          read: read,
          changedAt: changedAt,
        ),
      ],
      nextCursor: cursor,
    );

FeedServerHttpResponse _json(Object value) => FeedServerHttpResponse(
      statusCode: 200,
      body: utf8.encode(jsonEncode(value)),
    );

final class _Http implements FeedServerHttpPort {
  _Http(this.responses);

  final List<FeedServerHttpResponse> responses;
  final List<FeedServerHttpRequest> requests = <FeedServerHttpRequest>[];

  @override
  Future<FeedServerHttpResponse> send(FeedServerHttpRequest request) async {
    requests.add(request);
    if (responses.isEmpty) throw StateError('No response.');
    return responses.removeAt(0);
  }
}

final class _Ids implements FeedSourceIdGenerator {
  var value = 0;

  @override
  String next() => 'source-${++value}';
}

final class _Adapter implements FeedServerAdapter {
  const _Adapter(this.kind, this.result);

  @override
  final FeedServerKind kind;
  final FeedServerPullResult result;

  @override
  Future<FeedServerPullResult> pull(
    FeedServerAccount account, {
    required int cursor,
  }) async =>
      result;

  @override
  Future<void> pushEntryStates(
    FeedServerAccount account,
    List<RemoteEntryState> states,
  ) async {}
}

final class _SequenceAdapter implements FeedServerAdapter {
  _SequenceAdapter(this.results);

  final List<FeedServerPullResult> results;
  final List<int> cursors = <int>[];

  @override
  FeedServerKind get kind => FeedServerKind.miniflux;

  @override
  Future<FeedServerPullResult> pull(
    FeedServerAccount account, {
    required int cursor,
  }) async {
    cursors.add(cursor);
    return results.removeAt(0);
  }

  @override
  Future<void> pushEntryStates(
    FeedServerAccount account,
    List<RemoteEntryState> states,
  ) async {}
}
