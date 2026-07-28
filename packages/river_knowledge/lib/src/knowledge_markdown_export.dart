import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

import 'knowledge_markdown.dart';

enum KnowledgeImageExportStrategy { keepRemote, download }

final class KnowledgeFetchedImage {
  KnowledgeFetchedImage({
    required Uint8List bytes,
    required this.effectiveUri,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final Uri effectiveUri;
}

abstract interface class KnowledgeImageFetcher {
  Future<KnowledgeFetchedImage> fetch(Uri uri);
}

enum KnowledgeMarkdownExportFailureCode {
  tooManyItems,
  tooManyImages,
  imageUnavailable,
  imageTooLarge,
  unsupportedImage,
  fileNameConflict,
  exportTooLarge,
}

final class KnowledgeMarkdownExportException implements Exception {
  const KnowledgeMarkdownExportException(this.code);

  final KnowledgeMarkdownExportFailureCode code;

  @override
  String toString() => 'KnowledgeMarkdownExportException(${code.name})';
}

final class KnowledgeExportFile {
  KnowledgeExportFile({
    required this.relativePath,
    required Uint8List bytes,
    required this.mediaType,
  }) : bytes = Uint8List.fromList(bytes) {
    _validateRelativePath(relativePath);
  }

  final String relativePath;
  final Uint8List bytes;
  final String mediaType;
}

final class KnowledgeMarkdownExportBundle {
  KnowledgeMarkdownExportBundle({
    required Iterable<KnowledgeExportFile> files,
    required Iterable<String> markdownFiles,
  })  : files = List<KnowledgeExportFile>.unmodifiable(
          files.toList()
            ..sort(
              (left, right) => left.relativePath.compareTo(right.relativePath),
            ),
        ),
        markdownFiles = List<String>.unmodifiable(markdownFiles) {
    if (this.files.isEmpty || this.markdownFiles.isEmpty) {
      throw ArgumentError('An export bundle must contain Markdown.');
    }
    final paths = this.files.map((file) => file.relativePath).toSet();
    if (paths.length != this.files.length ||
        !this.markdownFiles.every(paths.contains)) {
      throw ArgumentError('Export bundle paths must be unique and complete.');
    }
  }

  final List<KnowledgeExportFile> files;
  final List<String> markdownFiles;

  bool get canSaveAsSingleMarkdown =>
      files.length == 1 &&
      markdownFiles.length == 1 &&
      files.single.relativePath == markdownFiles.single;
}

final class KnowledgeMarkdownExportBuilder {
  const KnowledgeMarkdownExportBuilder({
    KnowledgeMarkdownRenderer renderer = const KnowledgeMarkdownRenderer(),
    this.imageFetcher,
    this.maxItems = 5000,
    this.maxImages = 5000,
    this.maxImageBytes = 10 * 1024 * 1024,
    this.maxTotalBytes = 200 * 1024 * 1024,
    this.fetchTimeout = const Duration(seconds: 20),
  }) : _renderer = renderer;

  final KnowledgeMarkdownRenderer _renderer;
  final KnowledgeImageFetcher? imageFetcher;
  final int maxItems;
  final int maxImages;
  final int maxImageBytes;
  final int maxTotalBytes;
  final Duration fetchTimeout;

  Future<KnowledgeMarkdownExportBundle> build(
    Iterable<KnowledgeItem> items, {
    KnowledgeImageExportStrategy imageStrategy =
        KnowledgeImageExportStrategy.keepRemote,
  }) async {
    final ordered = items.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    if (ordered.isEmpty || ordered.length > maxItems) {
      throw const KnowledgeMarkdownExportException(
        KnowledgeMarkdownExportFailureCode.tooManyItems,
      );
    }
    final rendered = <String, String>{};
    for (final item in ordered) {
      final document = _renderer.render(item);
      if (rendered.containsKey(document.fileName)) {
        throw const KnowledgeMarkdownExportException(
          KnowledgeMarkdownExportFailureCode.fileNameConflict,
        );
      }
      rendered[document.fileName] = document.contents;
    }

    final assets = <String, KnowledgeExportFile>{};
    if (imageStrategy == KnowledgeImageExportStrategy.download) {
      final fetcher = imageFetcher;
      if (fetcher == null) {
        throw const KnowledgeMarkdownExportException(
          KnowledgeMarkdownExportFailureCode.imageUnavailable,
        );
      }
      final sourceAssets = <Uri, String>{};
      for (final entry in rendered.entries.toList()) {
        final references = _imageReferences(entry.value);
        final newSources = references
            .map((reference) => reference.uri)
            .where((uri) => !sourceAssets.containsKey(uri))
            .toSet();
        if (sourceAssets.length + newSources.length > maxImages) {
          throw const KnowledgeMarkdownExportException(
            KnowledgeMarkdownExportFailureCode.tooManyImages,
          );
        }
        var contents = entry.value;
        for (final reference in references) {
          final source = reference.uri;
          var assetPath = sourceAssets[source];
          if (assetPath == null) {
            final fetched = await _fetch(fetcher, source);
            if (fetched.bytes.length > maxImageBytes) {
              throw const KnowledgeMarkdownExportException(
                KnowledgeMarkdownExportFailureCode.imageTooLarge,
              );
            }
            final type = _imageType(fetched.bytes);
            if (type == null) {
              throw const KnowledgeMarkdownExportException(
                KnowledgeMarkdownExportFailureCode.unsupportedImage,
              );
            }
            final digest = sha256.convert(fetched.bytes).toString();
            assetPath = 'assets/$digest.${type.extension}';
            assets.putIfAbsent(
              assetPath,
              () => KnowledgeExportFile(
                relativePath: assetPath!,
                bytes: fetched.bytes,
                mediaType: type.mediaType,
              ),
            );
            sourceAssets[source] = assetPath;
          }
          contents = contents.replaceRange(
            reference.destinationStart,
            reference.destinationEnd,
            assetPath,
          );
          final delta = assetPath.length -
              (reference.destinationEnd - reference.destinationStart);
          for (final later in references) {
            if (later.destinationStart > reference.destinationStart) {
              later.shift(delta);
            }
          }
        }
        rendered[entry.key] = contents;
      }
    }

    final files = <KnowledgeExportFile>[
      for (final entry in rendered.entries)
        KnowledgeExportFile(
          relativePath: entry.key,
          bytes: Uint8List.fromList(utf8.encode(entry.value)),
          mediaType: 'text/markdown; charset=utf-8',
        ),
      ...assets.values,
    ];
    final total = files.fold<int>(
      0,
      (sum, file) => sum + file.bytes.length,
    );
    if (total > maxTotalBytes) {
      throw const KnowledgeMarkdownExportException(
        KnowledgeMarkdownExportFailureCode.exportTooLarge,
      );
    }
    return KnowledgeMarkdownExportBundle(
      files: files,
      markdownFiles: rendered.keys,
    );
  }

  Future<KnowledgeFetchedImage> _fetch(
    KnowledgeImageFetcher fetcher,
    Uri uri,
  ) async {
    try {
      final result = await fetcher.fetch(uri).timeout(fetchTimeout);
      if (!_isPublicWebUri(result.effectiveUri)) {
        throw const KnowledgeMarkdownExportException(
          KnowledgeMarkdownExportFailureCode.imageUnavailable,
        );
      }
      if (uri.scheme == 'https' && result.effectiveUri.scheme != 'https') {
        throw const KnowledgeMarkdownExportException(
          KnowledgeMarkdownExportFailureCode.imageUnavailable,
        );
      }
      return result;
    } on KnowledgeMarkdownExportException {
      rethrow;
    } on Object {
      throw const KnowledgeMarkdownExportException(
        KnowledgeMarkdownExportFailureCode.imageUnavailable,
      );
    }
  }
}

final class KnowledgeZipEncoder {
  const KnowledgeZipEncoder();

  Uint8List encode(KnowledgeMarkdownExportBundle bundle) {
    final output = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var offset = 0;
    for (final file in bundle.files) {
      final name = utf8.encode(file.relativePath);
      final crc = _crc32(file.bytes);
      final local = BytesBuilder(copy: false)
        ..add(_u32(0x04034b50))
        ..add(_u16(20))
        ..add(_u16(0x0800))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0x0021))
        ..add(_u32(crc))
        ..add(_u32(file.bytes.length))
        ..add(_u32(file.bytes.length))
        ..add(_u16(name.length))
        ..add(_u16(0))
        ..add(name)
        ..add(file.bytes);
      final localBytes = local.takeBytes();
      output.add(localBytes);
      central
        ..add(_u32(0x02014b50))
        ..add(_u16(20))
        ..add(_u16(20))
        ..add(_u16(0x0800))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0x0021))
        ..add(_u32(crc))
        ..add(_u32(file.bytes.length))
        ..add(_u32(file.bytes.length))
        ..add(_u16(name.length))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u32(0))
        ..add(_u32(offset))
        ..add(name);
      offset += localBytes.length;
    }
    final centralBytes = central.takeBytes();
    output
      ..add(centralBytes)
      ..add(_u32(0x06054b50))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(bundle.files.length))
      ..add(_u16(bundle.files.length))
      ..add(_u32(centralBytes.length))
      ..add(_u32(offset))
      ..add(_u16(0));
    return output.takeBytes();
  }
}

final class _ImageReference {
  _ImageReference({
    required this.uri,
    required this.destinationStart,
    required this.destinationEnd,
  });

  final Uri uri;
  int destinationStart;
  int destinationEnd;

  void shift(int delta) {
    destinationStart += delta;
    destinationEnd += delta;
  }
}

List<_ImageReference> _imageReferences(String markdown) {
  final references = <_ImageReference>[];
  final expression = RegExp(
    r'!\[[^\]\r\n]*\]\(\s*(?:<([^>\r\n]+)>|([^\s)\r\n]+))',
  );
  for (final match in expression.allMatches(markdown)) {
    final raw = match.group(1) ?? match.group(2);
    if (raw == null) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null || !_isPublicWebUri(uri)) continue;
    final start = match.start + match.group(0)!.indexOf(raw);
    references.add(
      _ImageReference(
        uri: uri,
        destinationStart: start,
        destinationEnd: start + raw.length,
      ),
    );
  }
  final htmlExpression = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*(["'])([^"']+)\1''',
    caseSensitive: false,
  );
  for (final match in htmlExpression.allMatches(markdown)) {
    final raw = match.group(2);
    if (raw == null) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null || !_isPublicWebUri(uri)) continue;
    final start = match.start + match.group(0)!.lastIndexOf(raw);
    references.add(
      _ImageReference(
        uri: uri,
        destinationStart: start,
        destinationEnd: start + raw.length,
      ),
    );
  }
  references.sort(
    (left, right) => left.destinationStart.compareTo(right.destinationStart),
  );
  return references;
}

enum _ImageType {
  png('png', 'image/png'),
  jpeg('jpg', 'image/jpeg'),
  gif('gif', 'image/gif'),
  webp('webp', 'image/webp');

  const _ImageType(this.extension, this.mediaType);

  final String extension;
  final String mediaType;
}

_ImageType? _imageType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return _ImageType.png;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return _ImageType.jpeg;
  }
  if (bytes.length >= 6 &&
      ascii
          .decode(bytes.sublist(0, 6), allowInvalid: true)
          .startsWith('GIF8')) {
    return _ImageType.gif;
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return _ImageType.webp;
  }
  return null;
}

void _validateRelativePath(String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.startsWith(r'\') ||
      path.contains(r'\') ||
      path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw ArgumentError.value(path, 'relativePath');
  }
}

bool _isPublicWebUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

Uint8List _u16(int value) {
  final data = ByteData(2)..setUint16(0, value, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _u32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit += 1) {
      crc = (crc & 1) == 1 ? 0xEDB88320 ^ (crc >>> 1) : crc >>> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
