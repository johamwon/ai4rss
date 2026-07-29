import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('data source create installs River ID and sends mapped page', () async {
    final transport = _SandboxTransport();
    final item = _item(
      markdown: List<String>.generate(
        120,
        (index) => 'Paragraph $index.',
      ).join('\n\n'),
    );
    var contentAppendCalls = 0;
    transport.handler = (request) {
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/data_sources/source-1')) {
        return _json(200, _schema(includeRiverId: false));
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/data_sources/source-1')) {
        final body = _body(request);
        expect(
          body['properties'],
          containsPair('River ID', isA<Map<String, Object?>>()),
        );
        return _json(200, _schema(includeRiverId: true));
      }
      if (request.uri.path.endsWith('/data_sources/source-1/query')) {
        final body = _body(request);
        expect(
          ((body['filter'] as Map)['rich_text'] as Map)['equals'],
          'knowledge-1',
        );
        return _json(200, <String, Object?>{
          'results': <Object?>[],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.method == 'POST' && request.uri.path.endsWith('/pages')) {
        final body = _body(request);
        expect(
          body['parent'],
          <String, Object?>{
            'type': 'data_source_id',
            'data_source_id': 'source-1',
          },
        );
        final properties = body['properties'] as Map<String, Object?>;
        expect(
          properties.keys,
          containsAll(<String>['Name', 'River ID', '来源']),
        );
        expect(body.containsKey('children'), isFalse);
        return _json(200, _page('notion-page-1'));
      }
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/blocks/notion-page-1/children')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/blocks/notion-page-1/children')) {
        final body = _body(request);
        expect((body['position'] as Map)['type'], 'start');
        expect(body.toString(), contains('River managed content'));
        return _json(200, <String, Object?>{
          'results': <Object?>[
            <String, Object?>{'id': 'managed-toggle-1'},
          ],
        });
      }
      if (request.uri.path.endsWith('/blocks/managed-toggle-1/children')) {
        contentAppendCalls += 1;
        final children = _body(request)['children'] as List<Object?>;
        expect(children.length, inInclusiveRange(1, 100));
        return _json(200, <String, Object?>{'results': <Object?>[]});
      }
      fail('Unexpected request ${request.method} ${request.uri.path}');
    };
    final connector = _connector(transport);

    final created = await connector.create(
      KnowledgeConnectorCreateRequest(
        item: item,
        destinationId: 'dataSource:source-1',
        idempotencyKey: 'create-key',
      ),
    );

    expect(created.externalObjectId, 'notion-page-1');
    expect(contentAppendCalls, 2);
  });

  test('remote River ID recovery replaces partial page without duplication',
      () async {
    final transport = _SandboxTransport();
    transport.handler = (request) {
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/data_sources/source-1')) {
        return _json(200, _schema(includeRiverId: true));
      }
      if (request.uri.path.endsWith('/query')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[
            _page('existing-page'),
            _page('z-duplicate-page'),
          ],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/pages/z-duplicate-page')) {
        expect(_body(request), <String, Object?>{'in_trash': true});
        return _json(200, _page('z-duplicate-page'));
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/pages/existing-page')) {
        expect(_body(request).containsKey('erase_content'), isFalse);
        expect(_body(request)['properties'], isA<Map<String, Object?>>());
        return _json(200, _page('existing-page'));
      }
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/blocks/existing-page/children')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'id': 'old-managed-toggle',
              'type': 'toggle',
              'in_trash': false,
              'toggle': <String, Object?>{
                'rich_text': _rich(
                  'River managed content · knowledge-1',
                ),
              },
            },
            <String, Object?>{
              'id': 'user-note',
              'type': 'paragraph',
              'paragraph': <String, Object?>{
                'rich_text': _rich('Keep my manual note'),
              },
            },
          ],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.uri.path.endsWith('/blocks/old-managed-toggle')) {
        expect(_body(request), <String, Object?>{'in_trash': true});
        return _json(200, <String, Object?>{'id': 'old-managed-toggle'});
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/blocks/existing-page/children')) {
        expect(
          (_body(request)['position'] as Map<String, Object?>)['type'],
          'start',
        );
        return _json(200, <String, Object?>{
          'results': <Object?>[
            <String, Object?>{'id': 'new-managed-toggle'},
          ],
        });
      }
      if (request.uri.path.endsWith('/blocks/new-managed-toggle/children')) {
        return _json(200, <String, Object?>{'results': <Object?>[]});
      }
      fail('Unexpected request ${request.method} ${request.uri.path}');
    };
    final connector = _connector(transport);

    final created = await connector.create(
      KnowledgeConnectorCreateRequest(
        item: _item(),
        destinationId: 'dataSource:source-1',
        idempotencyKey: 'create-key',
      ),
    );

    expect(created.externalObjectId, 'existing-page');
    expect(
      transport.requests.where(
        (request) =>
            request.method == 'POST' && request.uri.path.endsWith('/pages'),
      ),
      isEmpty,
    );
  });

  test('page parent uses deterministic River title for remote recovery',
      () async {
    final item = _item();
    final expectedTitle = const NotionPageMapper().pageTargetTitle(item);
    final transport = _SandboxTransport();
    transport.handler = (request) {
      if (request.uri.path.endsWith('/search')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              ..._page('existing-page'),
              'parent': <String, Object?>{
                'type': 'page_id',
                'page_id': 'parent-1',
              },
              'properties': <String, Object?>{
                'title': <String, Object?>{
                  'type': 'title',
                  'title': _rich(expectedTitle),
                },
              },
            },
          ],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.uri.path.endsWith('/pages/existing-page')) {
        final title = ((_body(request)['properties'] as Map)['title']
            as Map)['title'] as List<Object?>;
        expect(title.toString(), contains('[River:'));
        expect(title.toString(), isNot(contains('knowledge-1')));
        return _json(200, _page('existing-page'));
      }
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/blocks/existing-page/children')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/blocks/existing-page/children')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[
            <String, Object?>{'id': 'page-managed-toggle'},
          ],
        });
      }
      if (request.uri.path.endsWith('/blocks/page-managed-toggle/children')) {
        return _json(200, <String, Object?>{'results': <Object?>[]});
      }
      fail('Unexpected request ${request.method} ${request.uri.path}');
    };

    final object = await _connector(transport).create(
      KnowledgeConnectorCreateRequest(
        item: item,
        destinationId: 'page:parent-1',
        idempotencyKey: 'page-create',
      ),
    );

    expect(object.externalObjectId, 'existing-page');
  });

  test('update, status, and delete follow the connector contract', () async {
    final transport = _SandboxTransport();
    transport.handler = (request) {
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/data_sources/source-1')) {
        return _json(200, _schema(includeRiverId: true));
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/pages/notion-page-1')) {
        final body = _body(request);
        if (body.containsKey('properties')) {
          expect(body['properties'], isA<Map<String, Object?>>());
          expect(body.containsKey('erase_content'), isFalse);
        } else {
          expect(body, <String, Object?>{'in_trash': true});
        }
        return _json(200, _page('notion-page-1'));
      }
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/blocks/notion-page-1/children')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[],
          'has_more': false,
          'next_cursor': null,
        });
      }
      if (request.method == 'PATCH' &&
          request.uri.path.endsWith('/blocks/notion-page-1/children')) {
        return _json(200, <String, Object?>{
          'results': <Object?>[
            <String, Object?>{'id': 'update-managed-toggle'},
          ],
        });
      }
      if (request.uri.path.endsWith('/blocks/update-managed-toggle/children')) {
        return _json(200, <String, Object?>{'results': <Object?>[]});
      }
      if (request.method == 'GET' &&
          request.uri.path.endsWith('/pages/notion-page-1')) {
        return _json(200, _page('notion-page-1'));
      }
      fail('Unexpected request ${request.method} ${request.uri.path}');
    };
    final connector = _connector(transport);

    final updated = await connector.update(
      KnowledgeConnectorUpdateRequest(
        item: _item(),
        destinationId: 'dataSource:source-1',
        externalObjectId: 'notion-page-1',
        idempotencyKey: 'update-key',
      ),
    );
    final status = await connector.status(
      KnowledgeConnectorStatusRequest(
        destinationId: 'dataSource:source-1',
        externalObjectId: 'notion-page-1',
      ),
    );
    await connector.delete(
      KnowledgeConnectorDeleteRequest(
        knowledgeItemId: 'knowledge-1',
        destinationId: 'dataSource:source-1',
        externalObjectId: 'notion-page-1',
        idempotencyKey: 'delete-key',
      ),
    );

    expect(updated.externalObjectId, 'notion-page-1');
    expect(status.phase, KnowledgeConnectorObjectPhase.available);
  });

  test('target catalog paginates pages and data sources', () async {
    final transport = _SandboxTransport();
    var pageCalls = 0;
    transport.handler = (request) {
      final body = _body(request);
      final kind = (body['filter'] as Map)['value'];
      if (kind == 'page') {
        pageCalls += 1;
        if (pageCalls == 1) {
          return _json(200, <String, Object?>{
            'results': <Object?>[
              <String, Object?>{
                ..._page('page-1'),
                'properties': <String, Object?>{
                  'Name': <String, Object?>{
                    'type': 'title',
                    'title': _rich('Reading'),
                  },
                },
              },
            ],
            'has_more': true,
            'next_cursor': 'cursor-1',
          });
        }
        expect(body['start_cursor'], 'cursor-1');
        return _json(200, <String, Object?>{
          'results': <Object?>[],
          'has_more': false,
          'next_cursor': null,
        });
      }
      return _json(200, <String, Object?>{
        'results': <Object?>[
          <String, Object?>{
            'id': 'source-1',
            'title': _rich('Knowledge'),
            'url': 'https://www.notion.so/source-1',
          },
        ],
        'has_more': false,
        'next_cursor': null,
      });
    };

    final targets = await _connector(transport).list(query: 'know');

    expect(
      targets.map((target) => target.destinationId),
      <String>['dataSource:source-1', 'page:page-1'],
    );
  });

  test('401 refreshes once and updates the secure vault', () async {
    final transport = _SandboxTransport();
    var calls = 0;
    transport.handler = (request) {
      calls += 1;
      if (calls == 1) return _json(401, <String, Object?>{});
      expect(request.headers['authorization'], 'Bearer refreshed-access');
      return _json(200, <String, Object?>{'id': 'bot'});
    };
    final vault = _Vault()..value = _authorization();
    final broker = _Broker();
    final connector = NotionApiConnector(
      transport: transport,
      vault: vault,
      oauthBroker: broker,
    );

    final status = await connector.testConnection();

    expect(status.phase, KnowledgeConnectorConnectionPhase.connected);
    expect(broker.refreshes, 1);
    expect((await vault.read())!.accessToken.reveal(), 'refreshed-access');
  });

  test('429 is typed and Retry-After is bounded', () async {
    final transport = _SandboxTransport()
      ..handler = (_) => const NotionHttpResponse(
            statusCode: 429,
            body: '{}',
            headers: <String, String>{'retry-after': '99999'},
          );

    await expectLater(
      _connector(transport).create(
        KnowledgeConnectorCreateRequest(
          item: _item(),
          destinationId: 'dataSource:source-1',
          idempotencyKey: 'create-key',
        ),
      ),
      throwsA(
        isA<KnowledgeConnectorFailure>()
            .having(
              (failure) => failure.code,
              'code',
              KnowledgeConnectorFailureCode.rateLimited,
            )
            .having(
              (failure) => failure.retryAfter,
              'retryAfter',
              const Duration(hours: 1),
            ),
      ),
    );
  });

  test('mapper keeps rich text bounded and maps content structures', () {
    const mapper = NotionPageMapper(maxRichTextCharacters: 32);
    final item = _item(
      markdown: '''
# Heading

${List<String>.filled(100, '段').join()}

- bullet
> quote
```dart
void main() {}
```
''',
    );
    final blocks = mapper.blocks(item);
    final types = blocks.map((block) => block['type']);

    expect(
      types,
      containsAll(<String>[
        'heading_1',
        'bulleted_list_item',
        'quote',
        'code',
      ]),
    );
    for (final block in blocks) {
      final type = block['type'] as String;
      final value = block[type];
      if (value is! Map || value['rich_text'] is! List) continue;
      for (final rich in value['rich_text'] as List<Object?>) {
        final text = (rich as Map)['text'] as Map;
        expect((text['content'] as String).runes.length, lessThanOrEqualTo(32));
      }
    }
  });
}

NotionApiConnector _connector(_SandboxTransport transport) =>
    NotionApiConnector(
      transport: transport,
      vault: _Vault()..value = _authorization(),
      oauthBroker: _Broker(),
    );

final class _SandboxTransport implements NotionHttpTransport {
  late NotionHttpResponse Function(NotionHttpRequest request) handler;
  final List<NotionHttpRequest> requests = <NotionHttpRequest>[];

  @override
  Future<NotionHttpResponse> send(NotionHttpRequest request) async {
    requests.add(request);
    return handler(request);
  }
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

final class _Broker implements NotionOAuthBroker {
  var refreshes = 0;

  @override
  Future<NotionOAuthFlow> start({required Uri appRedirectUri}) =>
      throw UnimplementedError();

  @override
  Future<NotionAuthorization> complete({
    required String flowId,
    required String completionCode,
  }) =>
      throw UnimplementedError();

  @override
  Future<NotionAuthorization> refresh(OpaqueNotionToken refreshToken) async {
    refreshes += 1;
    return NotionAuthorization(
      accessToken: OpaqueNotionToken('refreshed-access'),
      refreshToken: OpaqueNotionToken('refreshed-refresh'),
      botId: 'bot-1',
      workspaceId: 'workspace-1',
      workspaceName: 'River Lab',
    );
  }

  @override
  Future<void> revoke(OpaqueNotionToken accessToken) async {}
}

NotionAuthorization _authorization() => NotionAuthorization(
      accessToken: OpaqueNotionToken('access-token-value'),
      refreshToken: OpaqueNotionToken('refresh-token-value'),
      botId: 'bot-1',
      workspaceId: 'workspace-1',
      workspaceName: 'River Lab',
    );

KnowledgeItem _item({String? markdown}) => KnowledgeItem(
      id: 'knowledge-1',
      source: KnowledgeSourceReference(
        kind: KnowledgeSourceKind.article,
        sourceId: 'article-1',
        originalUrl: Uri.parse('https://example.com/article'),
        sourceTitle: 'Example Feed',
        author: 'River Author',
        publishedAt: DateTime.utc(2026, 7, 28),
      ),
      title: 'Knowledge title',
      markdown: markdown ?? 'Article body.',
      sanitizedHtml: '<p>Article body.</p>',
      contentHash: 'sha256:${List<String>.filled(64, 'a').join()}',
      savedAt: DateTime.utc(2026, 7, 29),
      updatedAt: DateTime.utc(2026, 7, 29),
      summary: ArticleSummary(
        oneLine: 'One line summary.',
        keyPoints: const <String>['Point one', 'Point two'],
        language: 'en',
        model: 'fixture',
        promptVersion: 'v1',
      ),
      tags: const <String>['RSS'],
      topics: const <String>['Reading'],
      notes: const <String>['Remember this.'],
      excerpts: <KnowledgeExcerpt>[
        KnowledgeExcerpt(quote: 'Important quote.', note: 'Why it matters.'),
      ],
    );

Map<String, Object?> _schema({required bool includeRiverId}) =>
    <String, Object?>{
      'object': 'data_source',
      'id': 'source-1',
      'properties': <String, Object?>{
        'Name': <String, Object?>{
          'type': 'title',
          'title': <String, Object?>{},
        },
        '来源': <String, Object?>{
          'type': 'rich_text',
          'rich_text': <String, Object?>{},
        },
        if (includeRiverId)
          'River ID': <String, Object?>{
            'type': 'rich_text',
            'rich_text': <String, Object?>{},
          },
      },
    };

Map<String, Object?> _page(String id) => <String, Object?>{
      'object': 'page',
      'id': id,
      'url': 'https://www.notion.so/$id',
      'in_trash': false,
    };

List<Map<String, Object?>> _rich(String text) => <Map<String, Object?>>[
      <String, Object?>{
        'type': 'text',
        'plain_text': text,
        'text': <String, Object?>{'content': text},
      },
    ];

Map<String, Object?> _body(NotionHttpRequest request) =>
    Map<String, Object?>.from(jsonDecode(request.body!) as Map);

NotionHttpResponse _json(int status, Map<String, Object?> body) =>
    NotionHttpResponse(statusCode: status, body: jsonEncode(body));
