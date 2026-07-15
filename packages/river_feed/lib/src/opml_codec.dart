import 'dart:convert';

import 'package:xml/xml.dart';

import 'feed_refresh_service.dart';

final class OpmlFeedEntry {
  const OpmlFeedEntry({
    required this.title,
    required this.xmlUrl,
    this.folderPath = const <String>[],
    this.htmlUrl,
  });

  final String title;
  final Uri xmlUrl;
  final Uri? htmlUrl;
  final List<String> folderPath;
}

final class OpmlDocument {
  const OpmlDocument({
    required this.title,
    required this.feeds,
    this.skippedInvalidEntries = 0,
    this.skippedDuplicateEntries = 0,
  });

  final String title;
  final List<OpmlFeedEntry> feeds;
  final int skippedInvalidEntries;
  final int skippedDuplicateEntries;
}

enum OpmlFailure { invalidDocument, unsafeDocument, tooLarge, tooDeep }

final class OpmlException implements Exception {
  const OpmlException(this.failure, this.message, {this.cause});

  final OpmlFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class OpmlCodec {
  const OpmlCodec({
    this.maxInputBytes = defaultMaxInputBytes,
    this.maxFeeds = defaultMaxFeeds,
    this.maxDepth = defaultMaxDepth,
  })  : assert(maxInputBytes > 0),
        assert(maxFeeds > 0),
        assert(maxDepth > 0);

  static const defaultMaxInputBytes = 5 * 1024 * 1024;
  static const defaultMaxFeeds = 10000;
  static const defaultMaxDepth = 16;

  final int maxInputBytes;
  final int maxFeeds;
  final int maxDepth;

  OpmlDocument parse(String source) {
    if (utf8.encode(source).length > maxInputBytes) {
      throw OpmlException(
        OpmlFailure.tooLarge,
        'OPML 文件超过 ${maxInputBytes ~/ (1024 * 1024)} MiB 限制',
      );
    }
    if (RegExp(r'<!\s*(?:DOCTYPE|ENTITY)\b', caseSensitive: false)
        .hasMatch(source)) {
      throw const OpmlException(
        OpmlFailure.unsafeDocument,
        'OPML 文件包含不受支持的 DTD 或实体声明',
      );
    }

    late final XmlDocument xml;
    try {
      xml = XmlDocument.parse(source);
    } on Object catch (error) {
      throw OpmlException(
        OpmlFailure.invalidDocument,
        'OPML XML 格式无效',
        cause: error,
      );
    }
    final root = xml.rootElement;
    if (root.name.local.toLowerCase() != 'opml') {
      throw const OpmlException(
        OpmlFailure.invalidDocument,
        '文件根节点不是 OPML',
      );
    }
    final body = root.childElements.where(
      (element) => element.name.local.toLowerCase() == 'body',
    );
    if (body.isEmpty) {
      throw const OpmlException(
        OpmlFailure.invalidDocument,
        'OPML 文件缺少 body 节点',
      );
    }

    final feeds = <OpmlFeedEntry>[];
    final seen = <Uri>{};
    var invalid = 0;
    var duplicates = 0;

    void visit(XmlElement outline, List<String> folderPath, int depth) {
      if (depth > maxDepth) {
        throw OpmlException(
          OpmlFailure.tooDeep,
          'OPML 文件夹层级超过 $maxDepth 层限制',
        );
      }
      final rawXmlUrl = _attribute(outline, 'xmlUrl');
      if (rawXmlUrl != null) {
        if (feeds.length >= maxFeeds) {
          throw OpmlException(
            OpmlFailure.tooLarge,
            'OPML 来源数量超过 $maxFeeds 个限制',
          );
        }
        Uri canonicalUrl;
        try {
          canonicalUrl = canonicalizeFeedUrl(Uri.parse(rawXmlUrl.trim()));
        } on Object {
          invalid += 1;
          return;
        }
        if (!seen.add(canonicalUrl)) {
          duplicates += 1;
          return;
        }
        final title = _nonEmpty(_attribute(outline, 'title')) ??
            _nonEmpty(_attribute(outline, 'text')) ??
            canonicalUrl.host;
        feeds.add(
          OpmlFeedEntry(
            title: title,
            xmlUrl: canonicalUrl,
            htmlUrl: _webUri(_attribute(outline, 'htmlUrl')),
            folderPath: List<String>.unmodifiable(folderPath),
          ),
        );
        return;
      }

      final folderName = _nonEmpty(_attribute(outline, 'title')) ??
          _nonEmpty(_attribute(outline, 'text'));
      final nextPath = folderName == null
          ? folderPath
          : <String>[...folderPath, _limited(folderName, 256)];
      for (final child in outline.childElements.where(_isOutline)) {
        visit(child, nextPath, depth + 1);
      }
    }

    for (final outline in body.first.childElements.where(_isOutline)) {
      visit(outline, const <String>[], 1);
    }

    final head = root.childElements.where(
      (element) => element.name.local.toLowerCase() == 'head',
    );
    final title = head.isEmpty
        ? 'River subscriptions'
        : _childText(head.first, 'title') ?? 'River subscriptions';
    return OpmlDocument(
      title: title,
      feeds: List<OpmlFeedEntry>.unmodifiable(feeds),
      skippedInvalidEntries: invalid,
      skippedDuplicateEntries: duplicates,
    );
  }

  String encode(OpmlDocument document) {
    final root = _OpmlFolderNode();
    for (final feed in document.feeds) {
      var node = root;
      for (final segment in feed.folderPath) {
        final name = _nonEmpty(segment);
        if (name != null) {
          node = node.children.putIfAbsent(name, _OpmlFolderNode.new);
        }
      }
      node.feeds.add(feed);
    }

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'opml',
      attributes: const <String, String>{'version': '2.0'},
      nest: () {
        builder.element(
          'head',
          nest: () => builder.element(
            'title',
            nest: _nonEmpty(document.title) ?? 'River subscriptions',
          ),
        );
        builder.element('body', nest: () => _writeNode(builder, root));
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }
}

final class _OpmlFolderNode {
  final Map<String, _OpmlFolderNode> children = <String, _OpmlFolderNode>{};
  final List<OpmlFeedEntry> feeds = <OpmlFeedEntry>[];
}

void _writeNode(XmlBuilder builder, _OpmlFolderNode node) {
  for (final child in node.children.entries) {
    builder.element(
      'outline',
      attributes: <String, String>{'text': child.key, 'title': child.key},
      nest: () => _writeNode(builder, child.value),
    );
  }
  for (final feed in node.feeds) {
    builder.element(
      'outline',
      attributes: <String, String>{
        'type': 'rss',
        'text': feed.title,
        'title': feed.title,
        'xmlUrl': feed.xmlUrl.toString(),
        if (feed.htmlUrl case final htmlUrl?) 'htmlUrl': htmlUrl.toString(),
      },
    );
  }
}

bool _isOutline(XmlElement element) =>
    element.name.local.toLowerCase() == 'outline';

String? _attribute(XmlElement element, String name) {
  final lower = name.toLowerCase();
  for (final attribute in element.attributes) {
    if (attribute.name.local.toLowerCase() == lower) {
      return _nonEmpty(attribute.value);
    }
  }
  return null;
}

String? _childText(XmlElement element, String name) {
  final lower = name.toLowerCase();
  for (final child in element.childElements) {
    if (child.name.local.toLowerCase() == lower) {
      return _nonEmpty(child.innerText);
    }
  }
  return null;
}

Uri? _webUri(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _limited(String value, int maxLength) =>
    value.length <= maxLength ? value : value.substring(0, maxLength);
