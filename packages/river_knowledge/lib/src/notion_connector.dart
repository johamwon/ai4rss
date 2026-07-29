import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

import 'notion_models.dart';
import 'notion_oauth.dart';

final class NotionApiConnector
    implements KnowledgeConnector, NotionTargetCatalog {
  NotionApiConnector({
    required NotionHttpTransport transport,
    required NotionAuthorizationVault vault,
    required NotionOAuthBroker oauthBroker,
    NotionPageMapper mapper = const NotionPageMapper(),
    this.maxSearchPages = 20,
  })  : _transport = transport,
        _vault = vault,
        _oauthBroker = oauthBroker,
        _mapper = mapper;

  static const apiVersion = '2026-03-11';
  static final _apiBase = Uri.https('api.notion.com', '/v1/');

  final NotionHttpTransport _transport;
  final NotionAuthorizationVault _vault;
  final NotionOAuthBroker _oauthBroker;
  final NotionPageMapper _mapper;
  final int maxSearchPages;

  @override
  String get id => 'notion';

  @override
  Future<KnowledgeConnectorConnectionStatus> testConnection() async {
    if (await _vault.read() == null) {
      return const KnowledgeConnectorConnectionStatus(
        phase: KnowledgeConnectorConnectionPhase.authenticationRequired,
        code: KnowledgeConnectorFailureCode.authenticationRequired,
      );
    }
    try {
      await _request('GET', 'users/me');
      return const KnowledgeConnectorConnectionStatus(
        phase: KnowledgeConnectorConnectionPhase.connected,
      );
    } on KnowledgeConnectorFailure catch (failure) {
      return KnowledgeConnectorConnectionStatus(
        phase:
            failure.code == KnowledgeConnectorFailureCode.authenticationRequired
                ? KnowledgeConnectorConnectionPhase.authenticationRequired
                : KnowledgeConnectorConnectionPhase.unavailable,
        code: failure.code,
      );
    }
  }

  @override
  Future<List<NotionTarget>> list({String? query}) async {
    final targets = <NotionTarget>[];
    for (final kind in NotionTargetKind.values) {
      String? cursor;
      for (var page = 0; page < maxSearchPages; page += 1) {
        final body = <String, Object?>{
          'page_size': 100,
          'filter': <String, Object?>{
            'property': 'object',
            'value': kind == NotionTargetKind.page ? 'page' : 'data_source',
          },
          if (query?.trim() case final value? when value.isNotEmpty)
            'query': value,
          if (cursor != null) 'start_cursor': cursor,
        };
        final value = await _request('POST', 'search', body: body);
        for (final result in _list(value, 'results')) {
          final object = _object(result);
          final target = _target(object, kind);
          if (target != null) targets.add(target);
        }
        if (value['has_more'] != true) break;
        cursor = value['next_cursor'] as String?;
        if (cursor == null || cursor.isEmpty) break;
      }
    }
    targets.sort((left, right) {
      final title =
          left.title.toLowerCase().compareTo(right.title.toLowerCase());
      if (title != 0) return title;
      final kind = left.kind.index.compareTo(right.kind.index);
      return kind != 0 ? kind : left.id.compareTo(right.id);
    });
    return List<NotionTarget>.unmodifiable(targets);
  }

  @override
  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  ) async {
    final target = _destination(request.destinationId);
    final schema = target.kind == NotionTargetKind.dataSource
        ? await _dataSourceSchema(target.id)
        : null;
    final existing = await _findExisting(target, request.item, schema);
    if (existing != null) {
      return _replace(
        pageId: existing.externalObjectId,
        target: target,
        item: request.item,
        schema: schema,
      );
    }

    final body = <String, Object?>{
      'parent': target.kind == NotionTargetKind.page
          ? <String, Object?>{'type': 'page_id', 'page_id': target.id}
          : <String, Object?>{
              'type': 'data_source_id',
              'data_source_id': target.id,
            },
      'properties': _mapper.properties(
        request.item,
        target: target,
        schema: schema,
      ),
    };
    final value = await _request('POST', 'pages', body: body);
    final object = _pageObject(value);
    await _replaceManagedContent(object.externalObjectId, request.item);
    if (target.kind == NotionTargetKind.dataSource) {
      final canonical = await _findInDataSource(
        target.id,
        request.item.id,
        schema!,
      );
      if (canonical != null &&
          canonical.externalObjectId != object.externalObjectId) {
        return _replace(
          pageId: canonical.externalObjectId,
          target: target,
          item: request.item,
          schema: schema,
        );
      }
    }
    return object;
  }

  @override
  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  ) async {
    final target = _destination(request.destinationId);
    final schema = target.kind == NotionTargetKind.dataSource
        ? await _dataSourceSchema(target.id)
        : null;
    return _replace(
      pageId: request.externalObjectId,
      target: target,
      item: request.item,
      schema: schema,
    );
  }

  @override
  Future<void> delete(KnowledgeConnectorDeleteRequest request) async {
    final pageId = _requestNotionId(request.externalObjectId);
    await _request(
      'PATCH',
      'pages/$pageId',
      body: const <String, Object?>{'in_trash': true},
    );
  }

  @override
  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  ) async {
    final pageId = _requestNotionId(request.externalObjectId);
    try {
      final value = await _request('GET', 'pages/$pageId');
      if (value['in_trash'] == true) {
        return KnowledgeConnectorObjectStatus(
          phase: KnowledgeConnectorObjectPhase.missing,
        );
      }
      return KnowledgeConnectorObjectStatus(
        phase: KnowledgeConnectorObjectPhase.available,
        externalUrl: _optionalPublicUri(value['url']),
      );
    } on KnowledgeConnectorFailure catch (failure) {
      if (failure.code == KnowledgeConnectorFailureCode.notFound) {
        return KnowledgeConnectorObjectStatus(
          phase: KnowledgeConnectorObjectPhase.missing,
        );
      }
      return KnowledgeConnectorObjectStatus(
        phase: KnowledgeConnectorObjectPhase.unavailable,
        code: failure.code,
      );
    }
  }

  Future<KnowledgeConnectorObject> _replace({
    required String pageId,
    required NotionTargetReference target,
    required KnowledgeItem item,
    required NotionDataSourceSchema? schema,
  }) async {
    pageId = _requestNotionId(pageId);
    final value = await _request(
      'PATCH',
      'pages/$pageId',
      body: <String, Object?>{
        'properties': _mapper.properties(
          item,
          target: target,
          schema: schema,
        ),
      },
    );
    await _replaceManagedContent(pageId, item);
    return _pageObject(value);
  }

  Future<void> _replaceManagedContent(
    String pageId,
    KnowledgeItem item,
  ) async {
    final existing = await _managedContainerIds(pageId, item.id);
    for (final blockId in existing) {
      await _request(
        'PATCH',
        'blocks/$blockId',
        body: const <String, Object?>{'in_trash': true},
      );
    }
    final value = await _request(
      'PATCH',
      'blocks/$pageId/children',
      body: <String, Object?>{
        'children': <Map<String, Object?>>[_mapper.managedContainer(item)],
        'position': const <String, String>{'type': 'start'},
      },
    );
    final results = _list(value, 'results');
    if (results.isEmpty) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.unavailable,
        retryable: true,
      );
    }
    final container = _object(results.first);
    final containerId = container['id'];
    if (containerId is! String) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.unavailable,
        retryable: true,
      );
    }
    await _appendBlocks(_remoteNotionId(containerId), _mapper.blocks(item));
  }

  Future<List<String>> _managedContainerIds(
    String pageId,
    String riverId,
  ) async {
    final expectedTitle = _mapper.managedContainerTitle(riverId);
    final result = <String>[];
    String? cursor;
    for (var page = 0; page < maxSearchPages; page += 1) {
      final path = Uri(
        path: 'blocks/$pageId/children',
        queryParameters: <String, String>{
          'page_size': '100',
          if (cursor != null) 'start_cursor': cursor,
        },
      ).toString();
      final value = await _request('GET', path);
      for (final raw in _list(value, 'results')) {
        final block = _object(raw);
        if (block['type'] != 'toggle') continue;
        final toggle = block['toggle'];
        if (toggle is! Map ||
            _plainText(toggle['rich_text']) != expectedTitle ||
            block['in_trash'] == true) {
          continue;
        }
        final id = block['id'];
        if (id is String) result.add(_remoteNotionId(id));
      }
      if (value['has_more'] != true) break;
      cursor = value['next_cursor'] as String?;
      if (cursor == null || cursor.isEmpty) break;
    }
    return result;
  }

  Future<void> _appendBlocks(
    String pageId,
    List<Map<String, Object?>> blocks,
  ) async {
    for (var offset = 0; offset < blocks.length; offset += 100) {
      final end = (offset + 100).clamp(0, blocks.length);
      await _request(
        'PATCH',
        'blocks/$pageId/children',
        body: <String, Object?>{
          'children': blocks.sublist(offset, end),
          'position': const <String, String>{'type': 'end'},
        },
      );
    }
  }

  Future<KnowledgeConnectorObject?> _findExisting(
    NotionTargetReference target,
    KnowledgeItem item,
    NotionDataSourceSchema? schema,
  ) {
    if (target.kind == NotionTargetKind.dataSource) {
      return _findInDataSource(target.id, item.id, schema!);
    }
    return _findUnderPage(target.id, item);
  }

  Future<KnowledgeConnectorObject?> _findInDataSource(
    String dataSourceId,
    String riverId,
    NotionDataSourceSchema schema,
  ) async {
    final value = await _request(
      'POST',
      'data_sources/$dataSourceId/query',
      body: <String, Object?>{
        'page_size': 100,
        'filter': <String, Object?>{
          'property': schema.riverIdName,
          'rich_text': <String, Object?>{'equals': riverId},
        },
      },
    );
    final pages = _list(value, 'results')
        .map(_object)
        .where((page) => page['in_trash'] != true)
        .toList()
      ..sort(
        (left, right) =>
            _remoteNotionId(left['id']).compareTo(_remoteNotionId(right['id'])),
      );
    if (pages.isEmpty) return null;
    final canonical = _pageObject(pages.first);
    for (final duplicate in pages.skip(1)) {
      final duplicateId = _remoteNotionId(duplicate['id']);
      await _request(
        'PATCH',
        'pages/$duplicateId',
        body: const <String, Object?>{'in_trash': true},
      );
    }
    return canonical;
  }

  Future<KnowledgeConnectorObject?> _findUnderPage(
    String parentPageId,
    KnowledgeItem item,
  ) async {
    final expectedTitle = _mapper.pageTargetTitle(item);
    String? cursor;
    for (var page = 0; page < maxSearchPages; page += 1) {
      final value = await _request(
        'POST',
        'search',
        body: <String, Object?>{
          'query': expectedTitle,
          'page_size': 100,
          'filter': const <String, Object?>{
            'property': 'object',
            'value': 'page',
          },
          if (cursor != null) 'start_cursor': cursor,
        },
      );
      for (final result in _list(value, 'results')) {
        final object = _object(result);
        final parent = object['parent'];
        if (parent is Map &&
            parent['type'] == 'page_id' &&
            parent['page_id'] == parentPageId &&
            _pageTitle(object) == expectedTitle &&
            object['in_trash'] != true) {
          return _pageObject(object);
        }
      }
      if (value['has_more'] != true) return null;
      cursor = value['next_cursor'] as String?;
      if (cursor == null || cursor.isEmpty) return null;
    }
    return null;
  }

  Future<NotionDataSourceSchema> _dataSourceSchema(String id) async {
    var value = await _request('GET', 'data_sources/$id');
    var schema = NotionDataSourceSchema.fromJson(value);
    if (schema.riverIdName == null) {
      value = await _request(
        'PATCH',
        'data_sources/$id',
        body: const <String, Object?>{
          'properties': <String, Object?>{
            'River ID': <String, Object?>{'rich_text': <String, Object?>{}},
          },
        },
      );
      schema = NotionDataSourceSchema.fromJson(value);
    }
    if (schema.riverIdName == null) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.invalidRequest,
        retryable: false,
      );
    }
    return schema;
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    var authorization = await _vault.read();
    if (authorization == null) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.authenticationRequired,
        retryable: false,
      );
    }
    var response = await _send(method, path, authorization, body);
    if (response.statusCode == 401) {
      try {
        authorization = await _oauthBroker.refresh(authorization.refreshToken);
        await _vault.write(authorization);
        response = await _send(method, path, authorization, body);
      } on NotionOAuthFailure catch (failure) {
        if (failure.code == NotionOAuthFailureCode.invalidGrant) {
          await _vault.clear();
        }
        throw const KnowledgeConnectorFailure(
          code: KnowledgeConnectorFailureCode.authenticationRequired,
          retryable: false,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiFailure(response);
    }
    if (response.body.isEmpty) return <String, Object?>{};
    try {
      return Map<String, Object?>.from(jsonDecode(response.body) as Map);
    } on Object {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.unavailable,
        retryable: true,
      );
    }
  }

  Future<NotionHttpResponse> _send(
    String method,
    String path,
    NotionAuthorization authorization,
    Map<String, Object?>? body,
  ) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'authorization': 'Bearer ${authorization.accessToken.reveal()}',
      'notion-version': apiVersion,
    };
    try {
      return await _transport.send(
        body == null
            ? NotionHttpRequest(
                method: method,
                uri: _apiBase.resolve(path),
                headers: headers,
              )
            : NotionHttpRequest.json(
                method: method,
                uri: _apiBase.resolve(path),
                headers: headers,
                body: body,
              ),
      );
    } on NotionTransportFailure catch (failure) {
      throw KnowledgeConnectorFailure(
        code: switch (failure.code) {
          NotionTransportFailureCode.timeout =>
            KnowledgeConnectorFailureCode.timeout,
          NotionTransportFailureCode.offline =>
            KnowledgeConnectorFailureCode.offline,
          NotionTransportFailureCode.responseTooLarge ||
          NotionTransportFailureCode.invalid =>
            KnowledgeConnectorFailureCode.unavailable,
        },
        retryable: true,
      );
    }
  }
}

final class NotionDataSourceSchema {
  NotionDataSourceSchema(this.properties) {
    if (titleName == null) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.invalidRequest,
        retryable: false,
      );
    }
    final configuredRiverIds = properties.entries.where(
      (entry) => const <String>{'River ID', 'RiverID'}.contains(entry.key),
    );
    if (configuredRiverIds.any((entry) => entry.value != 'rich_text')) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.invalidRequest,
        retryable: false,
      );
    }
  }

  factory NotionDataSourceSchema.fromJson(Map<String, Object?> value) {
    final source = value['properties'];
    if (source is! Map) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.unavailable,
        retryable: true,
      );
    }
    final properties = <String, String>{};
    for (final entry in source.entries) {
      final property = entry.value;
      if (entry.key is String &&
          property is Map &&
          property['type'] is String) {
        properties[entry.key as String] = property['type'] as String;
      }
    }
    return NotionDataSourceSchema(Map<String, String>.unmodifiable(properties));
  }

  final Map<String, String> properties;

  String? get titleName => _firstType('title');

  String? get riverIdName => _alias(
        const <String>['River ID', 'RiverID'],
        'rich_text',
      );

  String? property(Iterable<String> aliases, String type) =>
      _alias(aliases, type);

  String? _firstType(String type) {
    for (final entry in properties.entries) {
      if (entry.value == type) return entry.key;
    }
    return null;
  }

  String? _alias(Iterable<String> aliases, String type) {
    for (final alias in aliases) {
      if (properties[alias] == type) return alias;
    }
    return null;
  }
}

final class NotionPageMapper {
  const NotionPageMapper({
    this.maxRichTextCharacters = 1800,
    this.maxBlocks = 3000,
  });

  final int maxRichTextCharacters;
  final int maxBlocks;

  String managedContainerTitle(String riverId) =>
      _truncateRunes('River managed content · $riverId', 2000);

  Map<String, Object?> managedContainer(KnowledgeItem item) => _block(
        'toggle',
        managedContainerTitle(item.id),
        extra: const <String, Object?>{'color': 'blue_background'},
      );

  String pageTargetTitle(KnowledgeItem item) {
    final digest = sha256.convert(utf8.encode(item.id)).toString();
    final marker = ' [River:${digest.substring(0, 32)}]';
    return '${_truncateRunes(item.title, 2000 - marker.runes.length)}$marker';
  }

  Map<String, Object?> properties(
    KnowledgeItem item, {
    required NotionTargetReference target,
    required NotionDataSourceSchema? schema,
  }) {
    if (target.kind == NotionTargetKind.page) {
      return <String, Object?>{
        'title': _richProperty('title', pageTargetTitle(item)),
      };
    }
    final actual = schema!;
    final result = <String, Object?>{
      actual.titleName!: _richProperty('title', item.title),
      actual.riverIdName!: _richProperty('rich_text', item.id),
    };
    _putRich(
      result,
      actual,
      const <String>['来源', 'Source'],
      item.source.sourceTitle,
    );
    _putUrl(
      result,
      actual,
      const <String>['原文', 'Original URL'],
      item.source.originalUrl,
    );
    if (item.source.author case final author?) {
      _putRich(
        result,
        actual,
        const <String>['作者', 'Author'],
        author,
      );
    }
    if (item.source.publishedAt case final publishedAt?) {
      _putDate(
        result,
        actual,
        const <String>['发布时间', 'Published'],
        publishedAt,
      );
    }
    _putDate(
      result,
      actual,
      const <String>['保存时间', 'Saved'],
      item.savedAt,
    );
    final topics = <String>{...item.topics, ...item.tags}.toList()..sort();
    final topicsName = actual.property(
      const <String>['主题', 'Topics', 'Tags'],
      'multi_select',
    );
    if (topicsName != null) {
      result[topicsName] = <String, Object?>{
        'multi_select': topics
            .take(100)
            .map(
              (topic) => <String, String>{
                'name': _truncateRunes(topic, 100),
              },
            )
            .toList(growable: false),
      };
    }
    if (item.summary case final summary?) {
      _putRich(
        result,
        actual,
        const <String>['AI 摘要', 'AI Summary'],
        summary.oneLine,
      );
    }
    return result;
  }

  List<Map<String, Object?>> blocks(KnowledgeItem item) {
    final result = <Map<String, Object?>>[
      _block(
        'callout',
        'River ID: ${item.id}',
        extra: const <String, Object?>{
          'icon': <String, String>{'type': 'emoji', 'emoji': '🌊'},
        },
      ),
      _block('heading_2', 'Source'),
      _block('paragraph', item.source.sourceTitle),
      <String, Object?>{
        'object': 'block',
        'type': 'bookmark',
        'bookmark': <String, Object?>{
          'url': item.source.originalUrl.toString(),
        },
      },
    ];
    if (item.summary case final summary?) {
      result.add(_block('heading_2', 'AI Summary'));
      result.addAll(_paragraphs(summary.oneLine));
      for (final point in summary.keyPoints) {
        result.addAll(_textBlocks('bulleted_list_item', point));
      }
    }
    result.add(_block('heading_2', 'Article'));
    result.addAll(_markdownBlocks(item.markdown));
    if (item.excerpts.isNotEmpty) {
      result.add(_block('heading_2', 'Highlights'));
      for (final excerpt in item.excerpts) {
        result.addAll(_textBlocks('quote', excerpt.quote));
        if (excerpt.note case final note?) {
          result.addAll(_paragraphs(note));
        }
      }
    }
    if (item.notes.isNotEmpty) {
      result.add(_block('heading_2', 'Notes'));
      for (final note in item.notes) {
        result.addAll(_textBlocks('bulleted_list_item', note));
      }
    }
    if (result.length > maxBlocks) {
      throw const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.invalidRequest,
        retryable: false,
      );
    }
    return List<Map<String, Object?>>.unmodifiable(result);
  }

  List<Map<String, Object?>> _markdownBlocks(String markdown) {
    final result = <Map<String, Object?>>[];
    final paragraph = <String>[];
    final code = <String>[];
    var inCode = false;

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      result.addAll(_paragraphs(paragraph.join('\n')));
      paragraph.clear();
    }

    void flushCode() {
      if (code.isEmpty) return;
      result.addAll(
        _chunks(code.join('\n')).map(
          (chunk) => _block(
            'code',
            chunk,
            extra: const <String, Object?>{'language': 'plain text'},
          ),
        ),
      );
      code.clear();
    }

    for (final line in const LineSplitter().convert(markdown)) {
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          flushCode();
        } else {
          flushParagraph();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(line);
        continue;
      }
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (heading != null) {
        flushParagraph();
        result.addAll(
          _textBlocks(
            'heading_${heading.group(1)!.length}',
            heading.group(2)!,
          ),
        );
        continue;
      }
      final bullet = RegExp(r'^\s*[-*+]\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        result.addAll(_textBlocks('bulleted_list_item', bullet.group(1)!));
        continue;
      }
      final numbered = RegExp(r'^\s*\d+[.)]\s+(.+)$').firstMatch(line);
      if (numbered != null) {
        flushParagraph();
        result.addAll(
          _textBlocks('numbered_list_item', numbered.group(1)!),
        );
        continue;
      }
      final quote = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        flushParagraph();
        result.addAll(_textBlocks('quote', quote.group(1)!));
        continue;
      }
      paragraph.add(line);
    }
    flushParagraph();
    flushCode();
    if (result.isEmpty) result.add(_block('paragraph', ''));
    return result;
  }

  List<Map<String, Object?>> _paragraphs(String value) =>
      _textBlocks('paragraph', value);

  List<Map<String, Object?>> _textBlocks(String type, String value) =>
      _chunks(value).map((chunk) => _block(type, chunk)).toList();

  Iterable<String> _chunks(String value) sync* {
    final runes = value.runes.toList(growable: false);
    if (runes.isEmpty) {
      yield '';
      return;
    }
    for (var offset = 0;
        offset < runes.length;
        offset += maxRichTextCharacters) {
      final end = (offset + maxRichTextCharacters).clamp(0, runes.length);
      yield String.fromCharCodes(runes.sublist(offset, end));
    }
  }

  Map<String, Object?> _block(
    String type,
    String text, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) =>
      <String, Object?>{
        'object': 'block',
        'type': type,
        type: <String, Object?>{
          'rich_text': _richText(text),
          ...extra,
        },
      };

  Map<String, Object?> _richProperty(String type, String text) =>
      <String, Object?>{type: _richText(_truncateRunes(text, 2000))};

  List<Map<String, Object?>> _richText(String text) => text.isEmpty
      ? const <Map<String, Object?>>[]
      : <Map<String, Object?>>[
          <String, Object?>{
            'type': 'text',
            'text': <String, Object?>{'content': text},
          },
        ];

  void _putRich(
    Map<String, Object?> result,
    NotionDataSourceSchema schema,
    Iterable<String> aliases,
    String value,
  ) {
    final name = schema.property(aliases, 'rich_text');
    if (name != null) result[name] = _richProperty('rich_text', value);
  }

  void _putUrl(
    Map<String, Object?> result,
    NotionDataSourceSchema schema,
    Iterable<String> aliases,
    Uri value,
  ) {
    final name = schema.property(aliases, 'url');
    if (name != null) {
      result[name] = <String, Object?>{'url': value.toString()};
    }
  }

  void _putDate(
    Map<String, Object?> result,
    NotionDataSourceSchema schema,
    Iterable<String> aliases,
    DateTime value,
  ) {
    final name = schema.property(aliases, 'date');
    if (name != null) {
      result[name] = <String, Object?>{
        'date': <String, Object?>{'start': value.toUtc().toIso8601String()},
      };
    }
  }
}

KnowledgeConnectorFailure _apiFailure(NotionHttpResponse response) {
  final retryAfterSeconds = int.tryParse(response.headers['retry-after'] ?? '');
  final retryAfter = retryAfterSeconds == null
      ? null
      : Duration(seconds: retryAfterSeconds.clamp(0, 3600));
  return switch (response.statusCode) {
    400 => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.invalidRequest,
        retryable: false,
      ),
    401 => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.authenticationRequired,
        retryable: false,
      ),
    403 => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.forbidden,
        retryable: false,
      ),
    404 => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.notFound,
        retryable: false,
      ),
    409 => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.conflict,
        retryable: true,
      ),
    429 => KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.rateLimited,
        retryable: true,
        retryAfter: retryAfter,
      ),
    >= 500 => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.unavailable,
        retryable: true,
      ),
    _ => const KnowledgeConnectorFailure(
        code: KnowledgeConnectorFailureCode.unexpected,
        retryable: false,
      ),
  };
}

NotionTargetReference _destination(String destinationId) {
  try {
    final target = NotionTarget.parseDestination(destinationId);
    _requestNotionId(target.id);
    return target;
  } on Object {
    throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.invalidRequest,
      retryable: false,
    );
  }
}

KnowledgeConnectorObject _pageObject(Map<String, Object?> value) {
  final id = value['id'];
  if (id is! String) {
    throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.unavailable,
      retryable: true,
    );
  }
  return KnowledgeConnectorObject(
    externalObjectId: _remoteNotionId(id),
    externalUrl: _optionalPublicUri(value['url']),
  );
}

NotionTarget? _target(
  Map<String, Object?> value,
  NotionTargetKind expectedKind,
) {
  final id = value['id'];
  if (id is! String || id.isEmpty) return null;
  final title = expectedKind == NotionTargetKind.page
      ? _pageTitle(value)
      : _plainText(value['title']);
  if (title.isEmpty) return null;
  try {
    return NotionTarget(
      kind: expectedKind,
      id: id,
      title: title,
      url: _optionalPublicUri(value['url']),
    );
  } on ArgumentError {
    return null;
  }
}

String _pageTitle(Map<String, Object?> page) {
  final properties = page['properties'];
  if (properties is! Map) return '';
  for (final property in properties.values) {
    if (property is Map && property['type'] == 'title') {
      return _plainText(property['title']);
    }
  }
  return '';
}

String _plainText(Object? value) {
  if (value is! List) return '';
  final buffer = StringBuffer();
  for (final part in value) {
    if (part is Map) {
      final plain = part['plain_text'];
      if (plain is String) {
        buffer.write(plain);
        continue;
      }
      final text = part['text'];
      if (text is Map && text['content'] is String) {
        buffer.write(text['content']);
      }
    }
  }
  return buffer.toString();
}

Uri? _optionalPublicUri(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

List<Object?> _list(Map<String, Object?> value, String key) {
  final list = value[key];
  if (list is! List) {
    throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.unavailable,
      retryable: true,
    );
  }
  return list;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map) {
    throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.unavailable,
      retryable: true,
    );
  }
  return Map<String, Object?>.from(value);
}

String _truncateRunes(String value, int maxRunes) {
  final runes = value.runes;
  if (runes.length <= maxRunes) return value;
  return String.fromCharCodes(runes.take(maxRunes));
}

String _requestNotionId(String value) {
  if (!RegExp(r'^[A-Za-z0-9-]{1,128}$').hasMatch(value)) {
    throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.invalidRequest,
      retryable: false,
    );
  }
  return value;
}

String _remoteNotionId(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9-]{1,128}$').hasMatch(value)) {
    throw const KnowledgeConnectorFailure(
      code: KnowledgeConnectorFailureCode.unavailable,
      retryable: true,
    );
  }
  return value;
}
