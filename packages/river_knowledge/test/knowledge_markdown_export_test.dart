import 'dart:convert';
import 'dart:typed_data';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('remote-image single export remains one portable Markdown file',
      () async {
    const builder = KnowledgeMarkdownExportBuilder();
    final bundle = await builder.build(<KnowledgeItem>[
      _item('knowledge-1', markdown: '![Cover](https://img.test/cover.png)'),
    ]);

    expect(bundle.canSaveAsSingleMarkdown, isTrue);
    expect(bundle.files, hasLength(1));
    expect(
      utf8.decode(bundle.files.single.bytes),
      contains('![Cover](https://img.test/cover.png)'),
    );
  });

  test(
      'download mode rewrites and content-deduplicates Markdown and HTML images',
      () async {
    final fetcher = _Fetcher();
    final first = Uri.parse('https://img.test/first.png');
    final second = Uri.parse('https://img.test/second.png');
    fetcher.responses[first] = _png;
    fetcher.responses[second] = _png;
    final builder = KnowledgeMarkdownExportBuilder(imageFetcher: fetcher);

    final bundle = await builder.build(
      <KnowledgeItem>[
        _item(
          'knowledge-1',
          markdown: '![First]($first)\n\n<img alt="Second" src="$second">',
        ),
      ],
      imageStrategy: KnowledgeImageExportStrategy.download,
    );

    final markdown = utf8.decode(
      bundle.files
          .singleWhere((file) => file.relativePath.endsWith('.md'))
          .bytes,
    );
    final asset = bundle.files.singleWhere(
      (file) => file.relativePath.startsWith('assets/'),
    );
    expect(fetcher.requests, <Uri>[first, second]);
    expect(bundle.files, hasLength(2));
    expect(asset.relativePath, matches(RegExp(r'^assets/[0-9a-f]{64}\.png$')));
    expect(markdown, contains('![First](${asset.relativePath})'));
    expect(markdown, contains('src="${asset.relativePath}"'));
  });

  test('unsupported image bytes and HTTPS downgrade fail closed', () async {
    final uri = Uri.parse('https://img.test/image.svg');
    final unsupported = _Fetcher()
      ..responses[uri] = Uint8List.fromList(utf8.encode('<svg/>'));
    final downgraded = _Fetcher()
      ..responses[uri] = _png
      ..effectiveUris[uri] = Uri.parse('http://img.test/image.png');

    expect(
      KnowledgeMarkdownExportBuilder(imageFetcher: unsupported).build(
        <KnowledgeItem>[_item('knowledge-1', markdown: '![]($uri)')],
        imageStrategy: KnowledgeImageExportStrategy.download,
      ),
      throwsA(
        isA<KnowledgeMarkdownExportException>().having(
          (error) => error.code,
          'code',
          KnowledgeMarkdownExportFailureCode.unsupportedImage,
        ),
      ),
    );
    expect(
      KnowledgeMarkdownExportBuilder(imageFetcher: downgraded).build(
        <KnowledgeItem>[_item('knowledge-1', markdown: '![]($uri)')],
        imageStrategy: KnowledgeImageExportStrategy.download,
      ),
      throwsA(
        isA<KnowledgeMarkdownExportException>().having(
          (error) => error.code,
          'code',
          KnowledgeMarkdownExportFailureCode.imageUnavailable,
        ),
      ),
    );
  });

  test('one thousand same-title items retain unique deterministic files',
      () async {
    const builder = KnowledgeMarkdownExportBuilder(maxItems: 1000);
    final items = List<KnowledgeItem>.generate(
      1000,
      (index) => _item('knowledge-$index'),
      growable: false,
    );

    final first = await builder.build(items.reversed);
    final second = await builder.build(items);

    expect(first.markdownFiles, hasLength(1000));
    expect(first.markdownFiles.toSet(), hasLength(1000));
    expect(
      first.files.map((file) => file.relativePath),
      second.files.map((file) => file.relativePath),
    );
  });

  test('ZIP output is deterministic and stored entries round trip', () async {
    const builder = KnowledgeMarkdownExportBuilder();
    const encoder = KnowledgeZipEncoder();
    final bundle = await builder.build(<KnowledgeItem>[
      _item('knowledge-2'),
      _item('knowledge-1'),
    ]);

    final first = encoder.encode(bundle);
    final second = encoder.encode(bundle);
    final decoded = _storedZipFiles(first);

    expect(second, first);
    expect(decoded.keys, bundle.files.map((file) => file.relativePath).toSet());
    for (final file in bundle.files) {
      expect(decoded[file.relativePath], file.bytes);
    }
  });

  test('ZIP stores the standard CRC-32 value', () {
    final bundle = KnowledgeMarkdownExportBundle(
      files: <KnowledgeExportFile>[
        KnowledgeExportFile(
          relativePath: 'check.md',
          bytes: Uint8List.fromList(ascii.encode('123456789')),
          mediaType: 'text/markdown',
        ),
      ],
      markdownFiles: const <String>['check.md'],
    );

    final encoded = const KnowledgeZipEncoder().encode(bundle);

    expect(_uint32(encoded, 14), 0xCBF43926);
  });
}

final class _Fetcher implements KnowledgeImageFetcher {
  final Map<Uri, Uint8List> responses = <Uri, Uint8List>{};
  final Map<Uri, Uri> effectiveUris = <Uri, Uri>{};
  final List<Uri> requests = <Uri>[];

  @override
  Future<KnowledgeFetchedImage> fetch(Uri uri) async {
    requests.add(uri);
    return KnowledgeFetchedImage(
      bytes: responses[uri]!,
      effectiveUri: effectiveUris[uri] ?? uri,
    );
  }
}

final _png = Uint8List.fromList(
  <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
);

KnowledgeItem _item(String id, {String markdown = 'Body'}) {
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-$id',
      originalUrl: Uri.parse('https://example.test/$id'),
      sourceTitle: 'River',
    ),
    title: 'Same title',
    markdown: markdown,
    sanitizedHtml: '<p>Body</p>',
    contentHash:
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    savedAt: DateTime.utc(2026, 7, 28),
    updatedAt: DateTime.utc(2026, 7, 28),
  );
}

Map<String, Uint8List> _storedZipFiles(Uint8List bytes) {
  final result = <String, Uint8List>{};
  var offset = 0;
  while (_uint32(bytes, offset) == 0x04034b50) {
    final size = _uint32(bytes, offset + 18);
    final nameLength = _uint16(bytes, offset + 26);
    final extraLength = _uint16(bytes, offset + 28);
    final nameStart = offset + 30;
    final dataStart = nameStart + nameLength + extraLength;
    final name = utf8.decode(bytes.sublist(nameStart, nameStart + nameLength));
    result[name] =
        Uint8List.fromList(bytes.sublist(dataStart, dataStart + size));
    offset = dataStart + size;
  }
  expect(_uint32(bytes, offset), 0x02014b50);
  return result;
}

int _uint16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.little);

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);
