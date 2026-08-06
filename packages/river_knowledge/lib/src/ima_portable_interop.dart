import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

import 'knowledge_markdown_export.dart';

enum ImaPortableOutcome { completed, dismissed, unavailable }

enum ImaPortableFailureCode {
  exportRejected,
  packageTooLarge,
  transferUnavailable,
  launchUnavailable,
}

final class ImaPortableFailure implements Exception {
  const ImaPortableFailure(this.code);

  final ImaPortableFailureCode code;

  @override
  String toString() => 'ImaPortableFailure(${code.name})';
}

final class ImaPortablePackage {
  ImaPortablePackage({
    required this.fileName,
    required this.mediaType,
    required Uint8List bytes,
    required this.knowledgeItemCount,
  }) : bytes = Uint8List.fromList(bytes) {
    if (!_isSafeFileName(fileName) ||
        (mediaType != 'text/markdown' && mediaType != 'application/zip') ||
        this.bytes.isEmpty ||
        knowledgeItemCount <= 0) {
      throw ArgumentError('Invalid portable IMA package.');
    }
    contentHash = sha256.convert(this.bytes).toString();
  }

  final String fileName;
  final String mediaType;
  final Uint8List bytes;
  final int knowledgeItemCount;
  late final String contentHash;
}

abstract interface class ImaPortableTransferGateway {
  Future<ImaPortableOutcome> share(
    ImaPortablePackage package, {
    ShareAnchor? anchor,
  });

  Future<ImaPortableOutcome> save(ImaPortablePackage package);
}

final class ImaPortableDiagnostic {
  const ImaPortableDiagnostic({
    required this.operation,
    required this.outcome,
    required this.knowledgeItemCount,
    required this.byteLength,
  });

  final String operation;
  final String outcome;
  final int knowledgeItemCount;
  final int byteLength;

  Map<String, Object> toJson() => <String, Object>{
        'operation': operation,
        'outcome': outcome,
        'knowledgeItemCount': knowledgeItemCount,
        'byteLength': byteLength,
      };
}

final class ImaPortableResult {
  const ImaPortableResult({
    required this.outcome,
    required this.diagnostic,
  });

  final ImaPortableOutcome outcome;
  final ImaPortableDiagnostic diagnostic;
}

/// User-assisted IMA interoperability that only uses public OS/file surfaces.
///
/// No IMA token, private endpoint, knowledge identifier, or undocumented URI
/// scheme is accepted by this contract. A native connector can replace this
/// service only after IMA publishes a stable public API.
final class ImaPortableInterop {
  ImaPortableInterop({
    required ImaPortableTransferGateway transfer,
    required ExternalUriGateway externalUri,
    KnowledgeMarkdownExportBuilder builder =
        const KnowledgeMarkdownExportBuilder(),
    KnowledgeZipEncoder zipEncoder = const KnowledgeZipEncoder(),
    Uri? publicEntryUri,
    this.maxPackageBytes = 200 * 1024 * 1024,
  })  : _transfer = transfer,
        _externalUri = externalUri,
        _builder = builder,
        _zipEncoder = zipEncoder,
        publicEntryUri = _validatePublicEntry(
          publicEntryUri ?? Uri.parse('https://ima.qq.com/'),
        ) {
    if (maxPackageBytes <= 0 || maxPackageBytes > 200 * 1024 * 1024) {
      throw ArgumentError.value(maxPackageBytes, 'maxPackageBytes');
    }
  }

  final ImaPortableTransferGateway _transfer;
  final ExternalUriGateway _externalUri;
  final KnowledgeMarkdownExportBuilder _builder;
  final KnowledgeZipEncoder _zipEncoder;
  final Uri publicEntryUri;
  final int maxPackageBytes;

  bool get usesNativePrivateApi => false;

  Future<ImaPortablePackage> prepare(
    Iterable<KnowledgeItem> items, {
    KnowledgeImageExportStrategy imageStrategy =
        KnowledgeImageExportStrategy.keepRemote,
  }) async {
    final ordered = items.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    try {
      final bundle = await _builder.build(
        ordered,
        imageStrategy: imageStrategy,
      );
      final package = bundle.canSaveAsSingleMarkdown
          ? ImaPortablePackage(
              fileName: bundle.files.single.relativePath,
              mediaType: 'text/markdown',
              bytes: bundle.files.single.bytes,
              knowledgeItemCount: ordered.length,
            )
          : ImaPortablePackage(
              fileName: 'river-knowledge-${ordered.length}.zip',
              mediaType: 'application/zip',
              bytes: _zipEncoder.encode(bundle),
              knowledgeItemCount: ordered.length,
            );
      if (package.bytes.length > maxPackageBytes) {
        throw const ImaPortableFailure(
          ImaPortableFailureCode.packageTooLarge,
        );
      }
      return package;
    } on ImaPortableFailure {
      rethrow;
    } on KnowledgeMarkdownExportException {
      throw const ImaPortableFailure(ImaPortableFailureCode.exportRejected);
    }
  }

  Future<ImaPortableResult> share(
    Iterable<KnowledgeItem> items, {
    ShareAnchor? anchor,
  }) async {
    final package = await prepare(items);
    return _transferPackage(
      operation: 'share',
      package: package,
      action: () => _transfer.share(package, anchor: anchor),
    );
  }

  Future<ImaPortableResult> save(Iterable<KnowledgeItem> items) async {
    final package = await prepare(items);
    return _transferPackage(
      operation: 'save',
      package: package,
      action: () => _transfer.save(package),
    );
  }

  Future<ImaPortableResult> openPublicEntry() async {
    ImaPortableOutcome outcome;
    try {
      outcome = await _externalUri.open(publicEntryUri) ==
              ExternalUriOpenOutcome.opened
          ? ImaPortableOutcome.completed
          : ImaPortableOutcome.unavailable;
    } on Object {
      outcome = ImaPortableOutcome.unavailable;
    }
    return ImaPortableResult(
      outcome: outcome,
      diagnostic: ImaPortableDiagnostic(
        operation: 'openPublicEntry',
        outcome: outcome.name,
        knowledgeItemCount: 0,
        byteLength: 0,
      ),
    );
  }

  Future<ImaPortableResult> _transferPackage({
    required String operation,
    required ImaPortablePackage package,
    required Future<ImaPortableOutcome> Function() action,
  }) async {
    ImaPortableOutcome outcome;
    try {
      outcome = await action();
    } on Object {
      outcome = ImaPortableOutcome.unavailable;
    }
    return ImaPortableResult(
      outcome: outcome,
      diagnostic: ImaPortableDiagnostic(
        operation: operation,
        outcome: outcome.name,
        knowledgeItemCount: package.knowledgeItemCount,
        byteLength: package.bytes.length,
      ),
    );
  }
}

Uri _validatePublicEntry(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'ima.qq.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port != 443 ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError.value(uri, 'publicEntryUri');
  }
  return uri;
}

bool _isSafeFileName(String value) =>
    value.isNotEmpty &&
    value.length <= 160 &&
    !value.contains('/') &&
    !value.contains(r'\') &&
    value != '.' &&
    value != '..';
