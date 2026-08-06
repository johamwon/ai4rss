import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('single item prepares deterministic Markdown package', () async {
    final transfer = _Transfer();
    final interop = ImaPortableInterop(
      transfer: transfer,
      externalUri: _ExternalUri(),
    );

    final first = await interop.prepare(<KnowledgeItem>[_item('one')]);
    final second = await interop.prepare(<KnowledgeItem>[_item('one')]);

    expect(first.mediaType, 'text/markdown');
    expect(first.fileName, endsWith('.md'));
    expect(first.bytes, second.bytes);
    expect(first.contentHash, second.contentHash);
  });

  test('multiple items prepare one portable ZIP package', () async {
    final interop = ImaPortableInterop(
      transfer: _Transfer(),
      externalUri: _ExternalUri(),
    );

    final package = await interop.prepare(<KnowledgeItem>[
      _item('two'),
      _item('one'),
    ]);

    expect(package.fileName, 'river-knowledge-2.zip');
    expect(package.mediaType, 'application/zip');
    expect(package.knowledgeItemCount, 2);
    expect(package.bytes.take(4), <int>[0x50, 0x4b, 0x03, 0x04]);
  });

  test('package size is bounded after encoding', () async {
    final interop = ImaPortableInterop(
      transfer: _Transfer(),
      externalUri: _ExternalUri(),
      maxPackageBytes: 1,
    );

    expect(
      interop.prepare(<KnowledgeItem>[_item('one')]),
      throwsA(
        isA<ImaPortableFailure>().having(
          (error) => error.code,
          'code',
          ImaPortableFailureCode.packageTooLarge,
        ),
      ),
    );
  });

  test('share and save preserve explicit user outcomes', () async {
    final transfer = _Transfer()
      ..shareOutcome = ImaPortableOutcome.completed
      ..saveOutcome = ImaPortableOutcome.dismissed;
    final interop = ImaPortableInterop(
      transfer: transfer,
      externalUri: _ExternalUri(),
    );

    final shared = await interop.share(<KnowledgeItem>[_item('one')]);
    final saved = await interop.save(<KnowledgeItem>[_item('one')]);

    expect(shared.outcome, ImaPortableOutcome.completed);
    expect(saved.outcome, ImaPortableOutcome.dismissed);
    expect(transfer.shared!.mediaType, 'text/markdown');
    expect(transfer.saved!.contentHash, transfer.shared!.contentHash);
  });

  test('gateway exceptions degrade without leaking private content', () async {
    final transfer = _Transfer()..throwOnShare = true;
    final interop = ImaPortableInterop(
      transfer: transfer,
      externalUri: _ExternalUri(),
    );

    final result = await interop.share(<KnowledgeItem>[
      _item('secret', markdown: 'PRIVATE BODY SENTINEL'),
    ]);

    expect(result.outcome, ImaPortableOutcome.unavailable);
    expect(result.diagnostic.toJson().toString(), isNot(contains('PRIVATE')));
    expect(result.diagnostic.toJson().keys, <String>{
      'operation',
      'outcome',
      'knowledgeItemCount',
      'byteLength',
    });
  });

  test('public entry is fixed HTTPS and has no private API path', () async {
    final external = _ExternalUri();
    final interop = ImaPortableInterop(
      transfer: _Transfer(),
      externalUri: external,
    );

    final result = await interop.openPublicEntry();

    expect(result.outcome, ImaPortableOutcome.completed);
    expect(external.opened, Uri.parse('https://ima.qq.com/'));
    expect(interop.usesNativePrivateApi, isFalse);
  });

  test('undocumented or credentialed entry URIs are rejected', () {
    for (final uri in <Uri>[
      Uri.parse('ima://knowledge/import'),
      Uri.parse('https://user:secret@ima.qq.com/'),
      Uri.parse('https://ima.qq.com/private/import'),
      Uri.parse('https://example.test/'),
    ]) {
      expect(
        () => ImaPortableInterop(
          transfer: _Transfer(),
          externalUri: _ExternalUri(),
          publicEntryUri: uri,
        ),
        throwsArgumentError,
      );
    }
  });
}

final class _Transfer implements ImaPortableTransferGateway {
  ImaPortableOutcome shareOutcome = ImaPortableOutcome.unavailable;
  ImaPortableOutcome saveOutcome = ImaPortableOutcome.unavailable;
  bool throwOnShare = false;
  ImaPortablePackage? shared;
  ImaPortablePackage? saved;

  @override
  Future<ImaPortableOutcome> save(ImaPortablePackage package) async {
    saved = package;
    return saveOutcome;
  }

  @override
  Future<ImaPortableOutcome> share(
    ImaPortablePackage package, {
    ShareAnchor? anchor,
  }) async {
    if (throwOnShare) throw StateError('PRIVATE REMOTE ERROR BODY');
    shared = package;
    return shareOutcome;
  }
}

final class _ExternalUri implements ExternalUriGateway {
  Uri? opened;

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async {
    opened = uri;
    return ExternalUriOpenOutcome.opened;
  }
}

KnowledgeItem _item(String id, {String markdown = 'Body'}) => KnowledgeItem(
      id: id,
      source: KnowledgeSourceReference(
        kind: KnowledgeSourceKind.article,
        sourceId: 'article-$id',
        originalUrl: Uri.parse('https://example.test/$id'),
        sourceTitle: 'River',
      ),
      title: 'Knowledge $id',
      markdown: markdown,
      sanitizedHtml: '<p>Body</p>',
      contentHash:
          'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      savedAt: DateTime.utc(2026, 8, 6),
      updatedAt: DateTime.utc(2026, 8, 6),
    );
