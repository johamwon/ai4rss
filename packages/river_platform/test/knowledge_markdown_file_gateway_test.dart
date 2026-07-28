import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('single Markdown uses a native md save request', () async {
    late String savedFileName;
    late String savedExtension;
    late Uint8List saved;
    final gateway = PlatformKnowledgeMarkdownFileGateway(
      saveFile: ({
        required String fileName,
        required String dialogTitle,
        required String extension,
        required Uint8List bytes,
      }) async {
        savedFileName = fileName;
        savedExtension = extension;
        saved = bytes;
        return 'saved';
      },
    );
    final bundle = KnowledgeMarkdownExportBundle(
      files: <KnowledgeExportFile>[
        KnowledgeExportFile(
          relativePath: 'article.md',
          bytes: Uint8List.fromList(utf8.encode('# Article\n')),
          mediaType: 'text/markdown; charset=utf-8',
        ),
      ],
      markdownFiles: const <String>['article.md'],
    );

    expect(await gateway.save(bundle), isTrue);
    expect(savedFileName, 'article.md');
    expect(savedExtension, 'md');
    expect(utf8.decode(saved), '# Article\n');
  });

  test('multi-file export uses a deterministic ZIP save request', () async {
    late String savedFileName;
    late String savedExtension;
    late Uint8List saved;
    final gateway = PlatformKnowledgeMarkdownFileGateway(
      saveFile: ({
        required String fileName,
        required String dialogTitle,
        required String extension,
        required Uint8List bytes,
      }) async {
        savedFileName = fileName;
        savedExtension = extension;
        saved = bytes;
        return 'saved';
      },
    );
    final bundle = KnowledgeMarkdownExportBundle(
      files: <KnowledgeExportFile>[
        KnowledgeExportFile(
          relativePath: 'a.md',
          bytes: Uint8List.fromList(<int>[65]),
          mediaType: 'text/markdown',
        ),
        KnowledgeExportFile(
          relativePath: 'b.md',
          bytes: Uint8List.fromList(<int>[66]),
          mediaType: 'text/markdown',
        ),
      ],
      markdownFiles: const <String>['a.md', 'b.md'],
    );

    expect(await gateway.save(bundle), isTrue);
    expect(savedFileName, 'river-knowledge-2.zip');
    expect(savedExtension, 'zip');
    expect(ByteData.sublistView(saved).getUint32(0, Endian.little), 0x04034b50);
  });

  test('image fetcher rejects local addresses before opening a client', () {
    var clients = 0;
    final fetcher = IoKnowledgeImageFetcher(
      clientFactory: () {
        clients += 1;
        throw StateError('must not be reached');
      },
    );

    expect(
      fetcher.fetch(Uri.parse('http://127.0.0.1/image.png')),
      throwsA(isA<KnowledgeImageFetchException>()),
    );
    expect(clients, 0);
  });
}
