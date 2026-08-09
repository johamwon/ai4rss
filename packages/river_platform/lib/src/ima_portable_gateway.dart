import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:share_plus/share_plus.dart';

typedef ImaPlatformShare = Future<ShareResult> Function(ShareParams params);

typedef ImaSaveFile = Future<String?> Function({
  required String fileName,
  required String dialogTitle,
  required String extension,
  required Uint8List bytes,
});

final class PlatformImaPortableTransferGateway
    implements ImaPortableTransferGateway {
  PlatformImaPortableTransferGateway({
    ImaPlatformShare? share,
    ImaSaveFile? saveFile,
  })  : _share = share ?? SharePlus.instance.share,
        _saveFile = saveFile ?? _saveImaFile;

  final ImaPlatformShare _share;
  final ImaSaveFile _saveFile;

  @override
  Future<ImaPortableOutcome> share(
    ImaPortablePackage package, {
    ShareAnchor? anchor,
  }) async {
    try {
      final result = await _share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              package.bytes,
              name: package.fileName,
              mimeType: package.mediaType,
            ),
          ],
          fileNameOverrides: <String>[package.fileName],
          title: '导入到 ima',
          subject: 'River 知识文件',
          text: '请选择 ima 导入此 River 知识文件。',
          downloadFallbackEnabled: true,
          sharePositionOrigin: anchor == null
              ? null
              : Rect.fromLTWH(
                  anchor.left,
                  anchor.top,
                  anchor.width,
                  anchor.height,
                ),
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ImaPortableOutcome.completed,
        ShareResultStatus.dismissed => ImaPortableOutcome.dismissed,
        ShareResultStatus.unavailable => ImaPortableOutcome.unavailable,
      };
    } on Object {
      return ImaPortableOutcome.unavailable;
    }
  }

  @override
  Future<ImaPortableOutcome> save(ImaPortablePackage package) async {
    try {
      final extension = package.mediaType == 'application/zip' ? 'zip' : 'md';
      final path = await _saveFile(
        fileName: package.fileName,
        dialogTitle: '导出供 ima 导入的知识文件',
        extension: extension,
        bytes: package.bytes,
      );
      return path == null
          ? ImaPortableOutcome.dismissed
          : ImaPortableOutcome.completed;
    } on Object {
      return ImaPortableOutcome.unavailable;
    }
  }
}

Future<String?> _saveImaFile({
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
