import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:river_feed/river_feed.dart';

abstract interface class OpmlFileGateway {
  Future<String?> pickImport();

  Future<bool> saveExport(String contents);
}

final class PlatformOpmlFileGateway implements OpmlFileGateway {
  const PlatformOpmlFileGateway();

  @override
  Future<String?> pickImport() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      allowedExtensions: const <String>['opml', 'xml'],
      type: FileType.custom,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final selected = result.files.single;
    if (selected.size > OpmlCodec.defaultMaxInputBytes) {
      throw const OpmlFileException('OPML 文件超过 5 MiB 限制');
    }
    final bytes = selected.bytes ?? await _readPath(selected.path);
    if (bytes.length > OpmlCodec.defaultMaxInputBytes) {
      throw const OpmlFileException('OPML 文件超过 5 MiB 限制');
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException catch (error) {
      throw OpmlFileException('OPML 文件不是有效的 UTF-8 文本', cause: error);
    }
  }

  @override
  Future<bool> saveExport(String contents) async {
    final path = await FilePicker.saveFile(
      allowedExtensions: const <String>['opml'],
      bytes: Uint8List.fromList(utf8.encode(contents)),
      dialogTitle: '导出 River 订阅',
      fileName: 'river-subscriptions.opml',
      type: FileType.custom,
    );
    return path != null;
  }
}

final class OpmlFileException implements Exception {
  const OpmlFileException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

Future<Uint8List> _readPath(String? path) async {
  if (path == null) {
    throw const OpmlFileException('无法读取所选 OPML 文件');
  }
  return File(path).readAsBytes();
}
