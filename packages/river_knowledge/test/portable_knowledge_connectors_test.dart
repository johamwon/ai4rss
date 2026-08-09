import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('Obsidian create is idempotent and uses canonical Markdown', () async {
    final store = _Store();
    final connector = _obsidian(store);
    final request = _create(_item());

    final first = await connector.create(request);
    final second = await connector.create(request);

    expect(second.externalObjectId, first.externalObjectId);
    expect(store.writes, 1);
    expect(
      utf8.decode(store.values.values.single.bytes),
      contains('river_schema: 1'),
    );
  });

  test('Obsidian update preserves stable path across title changes', () async {
    final store = _Store();
    final connector = _obsidian(store);
    final created = await connector.create(_create(_item()));

    final updated = await connector.update(
      KnowledgeConnectorUpdateRequest(
        item: _item(title: 'Renamed knowledge', body: 'Changed body'),
        destinationId: 'vault',
        externalObjectId: created.externalObjectId,
        idempotencyKey: 'update-1',
      ),
    );

    expect(updated.externalObjectId, created.externalObjectId);
    expect(
      utf8.decode(store.values.values.single.bytes),
      contains('Changed body'),
    );
  });

  test('Obsidian revision conflict maps to retryable connector conflict',
      () async {
    final store = _Store();
    final connector = _obsidian(store);
    final created = await connector.create(_create(_item()));
    store.conflictNextWrite = true;

    await expectLater(
      connector.update(
        KnowledgeConnectorUpdateRequest(
          item: _item(body: 'Changed body'),
          destinationId: 'vault',
          externalObjectId: created.externalObjectId,
          idempotencyKey: 'update-conflict',
        ),
      ),
      throwsA(
        isA<KnowledgeConnectorFailure>()
            .having(
              (failure) => failure.code,
              'code',
              KnowledgeConnectorFailureCode.conflict,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('Obsidian delete and status never escape configured directory',
      () async {
    final store = _Store();
    final connector = _obsidian(store);
    final created = await connector.create(_create(_item()));

    await connector.delete(
      KnowledgeConnectorDeleteRequest(
        knowledgeItemId: 'knowledge-1',
        destinationId: 'vault',
        externalObjectId: created.externalObjectId,
        idempotencyKey: 'delete-1',
      ),
    );
    final status = await connector.status(
      KnowledgeConnectorStatusRequest(
        destinationId: 'vault',
        externalObjectId: created.externalObjectId,
      ),
    );

    expect(status.phase, KnowledgeConnectorObjectPhase.missing);
    await expectLater(
      connector.status(
        KnowledgeConnectorStatusRequest(
          destinationId: 'vault',
          externalObjectId: '../outside.md',
        ),
      ),
      throwsA(isA<KnowledgeConnectorFailure>()),
    );
  });

  test('WebDAV create and update use conditional ETag writes', () async {
    final transport = _WebDav();
    final connector = _webdav(transport);
    final created = await connector.create(
      _create(_item(), destinationId: 'remote'),
    );

    await connector.update(
      KnowledgeConnectorUpdateRequest(
        item: _item(title: 'Renamed', body: 'Changed WebDAV body'),
        destinationId: 'remote',
        externalObjectId: created.externalObjectId,
        idempotencyKey: 'update-webdav',
      ),
    );

    final puts = transport.requests
        .where((request) => request.method == WebDavMethod.put)
        .toList();
    expect(puts.first.headers['If-None-Match'], '*');
    expect(puts.last.headers['If-Match'], '"1"');
    expect(
      utf8.decode(transport.values.values.single.body),
      contains('Changed WebDAV body'),
    );
  });

  test('WebDAV repeated create compares canonical bytes after precondition',
      () async {
    final transport = _WebDav();
    final connector = _webdav(transport);
    final request = _create(_item(), destinationId: 'remote');
    final first = await connector.create(request);

    final second = await connector.create(request);

    expect(second.externalObjectId, first.externalObjectId);
    expect(
      transport.requests.where((value) => value.method == WebDavMethod.get),
      hasLength(1),
    );
  });

  test('WebDAV maps rate limits and offline failures without response bodies',
      () async {
    final transport = _WebDav()
      ..nextResponse = WebDavResponse(
        statusCode: 429,
        headers: const <String, String>{'Retry-After': '9000'},
        body: utf8.encode('PRIVATE ERROR BODY'),
      );
    final connector = _webdav(transport);

    await expectLater(
      connector.create(_create(_item(), destinationId: 'remote')),
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
    transport
      ..nextResponse = null
      ..failure = const WebDavTransportFailure(
        WebDavTransportFailureCode.offline,
      );
    await expectLater(
      connector.create(_create(_item(), destinationId: 'remote')),
      throwsA(
        isA<KnowledgeConnectorFailure>().having(
          (failure) => failure.code,
          'code',
          KnowledgeConnectorFailureCode.offline,
        ),
      ),
    );
  });
}

ObsidianKnowledgeConnector _obsidian(_Store store) =>
    ObsidianKnowledgeConnector(
      store: store,
      destinations: const <String, String>{'vault': 'River/Knowledge'},
    );

WebDavKnowledgeConnector _webdav(_WebDav transport) => WebDavKnowledgeConnector(
      transport: transport,
      destinations: <String, Uri>{
        'remote': Uri.parse('https://dav.example.test/knowledge/'),
      },
    );

KnowledgeConnectorCreateRequest _create(
  KnowledgeItem item, {
  String destinationId = 'vault',
}) =>
    KnowledgeConnectorCreateRequest(
      item: item,
      destinationId: destinationId,
      idempotencyKey: 'create-1',
    );

KnowledgeItem _item({
  String title = 'Portable knowledge',
  String body = 'Original body',
}) {
  const id = 'knowledge-1';
  final html = '<p>$body</p>';
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/article'),
      sourceTitle: 'River',
    ),
    title: title,
    markdown: body,
    sanitizedHtml: html,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: body,
      sanitizedHtml: html,
    ),
    savedAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );
}

final class _Store implements KnowledgeDocumentStore {
  final Map<String, KnowledgeStoredDocument> values =
      <String, KnowledgeStoredDocument>{};
  var writes = 0;
  var revision = 0;
  var conflictNextWrite = false;

  @override
  Future<void> delete(String path, {required String expectedRevision}) async {
    final current = values[path];
    if (current == null) {
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.notFound,
      );
    }
    if (current.revision != expectedRevision) {
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.conflict,
      );
    }
    values.remove(path);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<KnowledgeStoredDocument?> read(String path) async => values[path];

  @override
  Future<KnowledgeStoredDocument> write(
    String path,
    List<int> bytes, {
    required String? expectedRevision,
    required bool createOnly,
  }) async {
    final current = values[path];
    if (conflictNextWrite) {
      conflictNextWrite = false;
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.conflict,
      );
    }
    if ((createOnly && current != null) ||
        (!createOnly && current?.revision != expectedRevision)) {
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.conflict,
      );
    }
    revision += 1;
    writes += 1;
    final stored = KnowledgeStoredDocument(
      path: path,
      bytes: bytes,
      revision: '$revision',
    );
    values[path] = stored;
    return stored;
  }
}

final class _DavValue {
  _DavValue(this.body, this.etag);

  List<int> body;
  String etag;
}

final class _WebDav implements WebDavTransport {
  final Map<String, _DavValue> values = <String, _DavValue>{};
  final List<WebDavRequest> requests = <WebDavRequest>[];
  WebDavResponse? nextResponse;
  WebDavTransportFailure? failure;
  var revision = 0;

  @override
  Future<WebDavResponse> send(WebDavRequest request) async {
    requests.add(request);
    final transportFailure = failure;
    if (transportFailure != null) throw transportFailure;
    final scripted = nextResponse;
    if (scripted != null) {
      nextResponse = null;
      return scripted;
    }
    final key = request.uri.toString();
    final current = values[key];
    switch (request.method) {
      case WebDavMethod.head:
        if (request.uri.path.endsWith('/')) {
          return WebDavResponse(statusCode: 200);
        }
        return current == null
            ? WebDavResponse(statusCode: 404)
            : WebDavResponse(
                statusCode: 200,
                headers: <String, String>{'ETag': current.etag},
              );
      case WebDavMethod.get:
        return current == null
            ? WebDavResponse(statusCode: 404)
            : WebDavResponse(
                statusCode: 200,
                headers: <String, String>{'ETag': current.etag},
                body: current.body,
              );
      case WebDavMethod.put:
        if (request.headers['If-None-Match'] == '*' && current != null) {
          return WebDavResponse(statusCode: 412);
        }
        if (request.headers['If-Match'] != null &&
            request.headers['If-Match'] != current?.etag) {
          return WebDavResponse(statusCode: 412);
        }
        revision += 1;
        values[key] = _DavValue(request.body, '"$revision"');
        return WebDavResponse(statusCode: current == null ? 201 : 204);
      case WebDavMethod.delete:
        if (current == null) return WebDavResponse(statusCode: 404);
        if (request.headers['If-Match'] != current.etag) {
          return WebDavResponse(statusCode: 412);
        }
        values.remove(key);
        return WebDavResponse(statusCode: 204);
    }
  }
}
