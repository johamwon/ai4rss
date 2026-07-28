import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:river_knowledge/river_knowledge.dart';

typedef KnowledgeSaveFile = Future<String?> Function({
  required String fileName,
  required String dialogTitle,
  required String extension,
  required Uint8List bytes,
});

abstract interface class KnowledgeMarkdownFileGateway {
  Future<bool> save(KnowledgeMarkdownExportBundle bundle);
}

final class PlatformKnowledgeMarkdownFileGateway
    implements KnowledgeMarkdownFileGateway {
  const PlatformKnowledgeMarkdownFileGateway({
    KnowledgeSaveFile saveFile = _saveFile,
    KnowledgeZipEncoder zipEncoder = const KnowledgeZipEncoder(),
  })  : _saveFileCallback = saveFile,
        _zipEncoder = zipEncoder;

  final KnowledgeSaveFile _saveFileCallback;
  final KnowledgeZipEncoder _zipEncoder;

  @override
  Future<bool> save(KnowledgeMarkdownExportBundle bundle) async {
    if (bundle.canSaveAsSingleMarkdown) {
      final file = bundle.files.single;
      return await _saveFileCallback(
            fileName: file.relativePath,
            dialogTitle: '导出 River Markdown',
            extension: 'md',
            bytes: file.bytes,
          ) !=
          null;
    }
    final bytes = _zipEncoder.encode(bundle);
    return await _saveFileCallback(
          fileName: 'river-knowledge-${bundle.markdownFiles.length}.zip',
          dialogTitle: '导出 River 知识库',
          extension: 'zip',
          bytes: bytes,
        ) !=
        null;
  }
}

enum KnowledgeImageFetchFailureCode {
  unsafeUrl,
  redirect,
  response,
  tooLarge,
  timeout,
  unavailable,
}

final class KnowledgeImageFetchException implements Exception {
  const KnowledgeImageFetchException(this.code);

  final KnowledgeImageFetchFailureCode code;

  @override
  String toString() => 'KnowledgeImageFetchException(${code.name})';
}

final class IoKnowledgeImageFetcher implements KnowledgeImageFetcher {
  IoKnowledgeImageFetcher({
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 15),
    this.maxBytes = 10 * 1024 * 1024,
    this.maxRedirects = 5,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final Duration timeout;
  final int maxBytes;
  final int maxRedirects;

  @override
  Future<KnowledgeFetchedImage> fetch(Uri uri) async {
    _validate(uri);
    final client = _clientFactory()
      ..autoUncompress = true
      ..connectionTimeout = timeout;
    try {
      var current = uri;
      final visited = <Uri>{};
      for (var redirects = 0;; redirects += 1) {
        if (!visited.add(current)) {
          throw const KnowledgeImageFetchException(
            KnowledgeImageFetchFailureCode.redirect,
          );
        }
        final request = await client.getUrl(current).timeout(timeout)
          ..followRedirects = false
          ..headers.set(
            HttpHeaders.acceptHeader,
            'image/png,image/jpeg,image/gif,image/webp',
          )
          ..headers.set(HttpHeaders.userAgentHeader, 'River/0.1');
        final response = await request.close().timeout(timeout);
        if (_isRedirect(response.statusCode)) {
          await response.drain<void>();
          if (redirects >= maxRedirects) {
            throw const KnowledgeImageFetchException(
              KnowledgeImageFetchFailureCode.redirect,
            );
          }
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw const KnowledgeImageFetchException(
              KnowledgeImageFetchFailureCode.redirect,
            );
          }
          final next = current.resolve(location);
          _validate(next);
          if (current.scheme == 'https' && next.scheme != 'https') {
            throw const KnowledgeImageFetchException(
              KnowledgeImageFetchFailureCode.unsafeUrl,
            );
          }
          current = next;
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw const KnowledgeImageFetchException(
            KnowledgeImageFetchFailureCode.response,
          );
        }
        final declared = response.contentLength;
        if (declared > maxBytes) {
          await response.drain<void>();
          throw const KnowledgeImageFetchException(
            KnowledgeImageFetchFailureCode.tooLarge,
          );
        }
        final builder = BytesBuilder(copy: false);
        var total = 0;
        await for (final chunk in response.timeout(timeout)) {
          total += chunk.length;
          if (total > maxBytes) {
            throw const KnowledgeImageFetchException(
              KnowledgeImageFetchFailureCode.tooLarge,
            );
          }
          builder.add(chunk);
        }
        return KnowledgeFetchedImage(
          bytes: builder.takeBytes(),
          effectiveUri: current,
        );
      }
    } on KnowledgeImageFetchException {
      rethrow;
    } on TimeoutException {
      throw const KnowledgeImageFetchException(
        KnowledgeImageFetchFailureCode.timeout,
      );
    } on Object {
      throw const KnowledgeImageFetchException(
        KnowledgeImageFetchFailureCode.unavailable,
      );
    } finally {
      client.close(force: true);
    }
  }
}

Future<String?> _saveFile({
  required String fileName,
  required String dialogTitle,
  required String extension,
  required Uint8List bytes,
}) {
  return FilePicker.saveFile(
    allowedExtensions: <String>[extension],
    bytes: bytes,
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
  );
}

void _validate(Uri uri) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      _isLocalHost(uri.host)) {
    throw const KnowledgeImageFetchException(
      KnowledgeImageFetchFailureCode.unsafeUrl,
    );
  }
}

bool _isLocalHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
    return true;
  }
  final address = InternetAddress.tryParse(normalized);
  if (address == null) return false;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return _isPrivateIpv4(bytes);
  }
  final mappedIpv4 = bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xFF &&
      bytes[11] == 0xFF;
  return address.isLoopback ||
      address.isLinkLocal ||
      bytes.every((byte) => byte == 0) ||
      (bytes[0] & 0xFE) == 0xFC ||
      bytes[0] == 0xFF ||
      (mappedIpv4 && _isPrivateIpv4(bytes.sublist(12)));
}

bool _isPrivateIpv4(List<int> bytes) =>
    bytes[0] == 0 ||
    bytes[0] == 10 ||
    bytes[0] == 127 ||
    (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
    (bytes[0] == 169 && bytes[1] == 254) ||
    (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
    (bytes[0] == 192 && bytes[1] == 168) ||
    bytes[0] >= 224;

bool _isRedirect(int status) =>
    status == HttpStatus.movedPermanently ||
    status == HttpStatus.found ||
    status == HttpStatus.seeOther ||
    status == HttpStatus.temporaryRedirect ||
    status == HttpStatus.permanentRedirect;
