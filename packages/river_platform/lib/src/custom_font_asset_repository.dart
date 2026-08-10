import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

typedef CustomFontSelectionPicker = Future<CustomFontSelection?> Function();
typedef CustomFontDirectoryProvider = Future<Directory> Function();

final class CustomFontSelection {
  CustomFontSelection({required this.fileName, required Uint8List bytes})
      : bytes = Uint8List.fromList(bytes);

  final String fileName;
  final Uint8List bytes;
}

final class CustomFontAsset {
  CustomFontAsset({
    required this.displayName,
    required this.extension,
    required this.family,
    required this.sha256Hex,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String displayName;
  final String extension;
  final String family;
  final String sha256Hex;
  final Uint8List bytes;

  int get byteLength => bytes.length;

  @override
  String toString() {
    final safeHashPrefix =
        sha256Hex.length <= 12 ? sha256Hex : sha256Hex.substring(0, 12);
    return 'CustomFontAsset(displayName: <redacted>, extension: $extension, '
        'family: $family, sha256: $safeHashPrefix..., '
        'byteLength: $byteLength)';
  }
}

abstract interface class CustomFontAssetRepository {
  Future<CustomFontAsset?> pick();

  Future<CustomFontAsset?> loadActive();

  Future<void> saveActive(CustomFontAsset asset);

  Future<void> clearActive();
}

final class UnavailableCustomFontAssetRepository
    implements CustomFontAssetRepository {
  const UnavailableCustomFontAssetRepository();

  @override
  Future<void> clearActive() async {}

  @override
  Future<CustomFontAsset?> loadActive() async => null;

  @override
  Future<CustomFontAsset?> pick() async => null;

  @override
  Future<void> saveActive(CustomFontAsset asset) async {
    throw const CustomFontAssetException('当前环境不支持导入字体文件');
  }
}

final class PlatformCustomFontAssetRepository
    implements CustomFontAssetRepository {
  PlatformCustomFontAssetRepository({
    CustomFontSelectionPicker? picker,
    CustomFontDirectoryProvider? directoryProvider,
  })  : _picker = picker ?? _pickFont,
        _directoryProvider = directoryProvider ?? _fontDirectory;

  static const maximumBytes = 32 * 1024 * 1024;
  static const _schemaVersion = 1;

  final CustomFontSelectionPicker _picker;
  final CustomFontDirectoryProvider _directoryProvider;
  Future<void> _tail = Future<void>.value();

  @override
  Future<CustomFontAsset?> pick() async {
    final selection = await _picker();
    return selection == null ? null : _validateSelection(selection);
  }

  @override
  Future<CustomFontAsset?> loadActive() => _serialized(() async {
        final root = await _directoryProvider();
        final metadata = File(_join(root.path, 'active.json'));
        if (!await metadata.exists()) return null;
        final metadataLength = await metadata.length();
        if (metadataLength <= 0 || metadataLength > 16 * 1024) {
          throw const CustomFontAssetException(
            '已保存的字体配置损坏，请恢复默认字体后重新导入',
          );
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(await metadata.readAsString());
        } on FormatException catch (error) {
          throw CustomFontAssetException(
            '已保存的字体配置损坏，请恢复默认字体后重新导入。',
            cause: error,
          );
        }
        if (decoded is! Map<String, Object?>) {
          throw const CustomFontAssetException(
            '已保存的字体配置损坏，请恢复默认字体后重新导入',
          );
        }
        final schemaVersion = decoded['schemaVersion'];
        final displayName = decoded['displayName'];
        final extension = decoded['extension'];
        final family = decoded['family'];
        final sha = decoded['sha256'];
        final byteLength = decoded['byteLength'];
        final fileName = decoded['fileName'];
        if (schemaVersion != _schemaVersion ||
            displayName is! String ||
            extension is! String ||
            family is! String ||
            sha is! String ||
            byteLength is! int ||
            fileName is! String ||
            displayName.isEmpty ||
            displayName.length > 128 ||
            !_isSha256(sha) ||
            family != _familyFor(sha) ||
            fileName != 'font-$sha.$extension' ||
            !_validExtension(extension) ||
            byteLength <= 0 ||
            byteLength > maximumBytes) {
          throw const CustomFontAssetException(
            '已保存的字体配置损坏，请恢复默认字体后重新导入',
          );
        }
        final fontFile = File(_join(root.path, fileName));
        if (!await fontFile.exists() || await fontFile.length() != byteLength) {
          throw const CustomFontAssetException(
            '已保存的字体文件缺失或损坏，请恢复默认字体后重新导入',
          );
        }
        final bytes = await fontFile.readAsBytes();
        final asset = _validateSelection(
          CustomFontSelection(fileName: displayName, bytes: bytes),
        );
        if (asset.extension != extension ||
            asset.family != family ||
            asset.sha256Hex != sha) {
          throw const CustomFontAssetException(
            '已保存的字体文件校验失败，请恢复默认字体后重新导入',
          );
        }
        return asset;
      });

  @override
  Future<void> saveActive(CustomFontAsset asset) => _serialized(() async {
        final validated = _validateSelection(
          CustomFontSelection(fileName: asset.displayName, bytes: asset.bytes),
        );
        if (validated.extension != asset.extension ||
            validated.family != asset.family ||
            validated.sha256Hex != asset.sha256Hex) {
          throw const CustomFontAssetException('字体文件校验失败');
        }
        final root = await _directoryProvider();
        await root.create(recursive: true);
        final fontName = 'font-${asset.sha256Hex}.${asset.extension}';
        final font = File(_join(root.path, fontName));
        if (!await font.exists()) {
          final temporary = File('${font.path}.tmp');
          if (await temporary.exists()) await temporary.delete();
          await temporary.writeAsBytes(asset.bytes, flush: true);
          await temporary.rename(font.path);
        }
        final metadata = File(_join(root.path, 'active.json'));
        final temporaryMetadata = File('${metadata.path}.tmp');
        final backupMetadata = File('${metadata.path}.bak');
        if (await temporaryMetadata.exists()) {
          await temporaryMetadata.delete();
        }
        await temporaryMetadata.writeAsString(
          jsonEncode(<String, Object>{
            'schemaVersion': _schemaVersion,
            'displayName': asset.displayName,
            'extension': asset.extension,
            'family': asset.family,
            'sha256': asset.sha256Hex,
            'byteLength': asset.byteLength,
            'fileName': fontName,
          }),
          flush: true,
        );
        if (await backupMetadata.exists()) await backupMetadata.delete();
        if (await metadata.exists()) await metadata.rename(backupMetadata.path);
        try {
          await temporaryMetadata.rename(metadata.path);
          if (await backupMetadata.exists()) await backupMetadata.delete();
        } on Object {
          if (!await metadata.exists() && await backupMetadata.exists()) {
            await backupMetadata.rename(metadata.path);
          }
          rethrow;
        }
        await _removeInactiveFonts(root, activeName: fontName);
      });

  @override
  Future<void> clearActive() => _serialized(() async {
        final root = await _directoryProvider();
        if (!await root.exists()) return;
        await for (final entity in root.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = _leafName(entity.path);
          if (name == 'active.json' ||
              name == 'active.json.tmp' ||
              name == 'active.json.bak' ||
              _isManagedFontName(name) ||
              name.endsWith('.tmp')) {
            await entity.delete();
          }
        }
      });

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  static Future<void> _removeInactiveFonts(
    Directory root, {
    required String activeName,
  }) async {
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is File) {
          final name = _leafName(entity.path);
          if (_isManagedFontName(name) && name != activeName) {
            await entity.delete();
          }
        }
      }
    } on FileSystemException {
      // The active metadata is already durable. Orphan cleanup is best-effort.
    }
  }

  static CustomFontAsset _validateSelection(CustomFontSelection selection) {
    final bytes = selection.bytes;
    if (bytes.length < 12 || bytes.length > maximumBytes) {
      throw const CustomFontAssetException(
        '字体文件必须小于 32 MiB，且不能是空文件',
      );
    }
    final signature = ascii.decode(bytes.sublist(0, 4), allowInvalid: true);
    final extension = switch (signature) {
      'OTTO' => 'otf',
      'true' || 'typ1' => 'ttf',
      _ when bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0 =>
        'ttf',
      'ttcf' => throw const CustomFontAssetException(
          '暂不支持 TTC 字体集合，请选择单个 TTF 或 OTF 字体文件',
        ),
      _ => throw const CustomFontAssetException(
          '文件不是有效的 TTF 或 OTF 字体',
        ),
    };
    final requestedExtension = _extensionOf(selection.fileName);
    if (!_validExtension(requestedExtension)) {
      throw const CustomFontAssetException('仅支持 .ttf 和 .otf 字体文件');
    }
    final sha = sha256.convert(bytes).toString();
    return CustomFontAsset(
      displayName: _safeDisplayName(selection.fileName),
      extension: extension,
      family: _familyFor(sha),
      sha256Hex: sha,
      bytes: bytes,
    );
  }

  static bool _validExtension(String value) => value == 'ttf' || value == 'otf';

  static String _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    return index < 0 ? '' : name.substring(index + 1).toLowerCase();
  }

  static String _safeDisplayName(String value) {
    final leaf = _leafName(value)
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '')
        .trim();
    if (leaf.isEmpty) return '自定义字体';
    return leaf.length <= 128 ? leaf : leaf.substring(0, 128);
  }

  static String _familyFor(String sha) =>
      'RiverCustomFont_${sha.substring(0, 16)}';

  static bool _isSha256(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  static bool _isManagedFontName(String value) =>
      RegExp(r'^font-[0-9a-f]{64}\.(ttf|otf)$').hasMatch(value);
}

final class CustomFontAssetException implements Exception {
  const CustomFontAssetException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

Future<CustomFontSelection?> _pickFont() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: false,
    allowedExtensions: const <String>['ttf', 'otf'],
    dialogTitle: '选择自定义字体',
    lockParentWindow: true,
    type: FileType.custom,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final selected = result.files.single;
  if (selected.size <= 0 ||
      selected.size > PlatformCustomFontAssetRepository.maximumBytes) {
    throw const CustomFontAssetException(
      '字体文件必须小于 32 MiB，且不能是空文件',
    );
  }
  final bytes = selected.bytes ?? await _readSelectedFont(selected.path);
  return CustomFontSelection(fileName: selected.name, bytes: bytes);
}

Future<Uint8List> _readSelectedFont(String? path) async {
  if (path == null) {
    throw const CustomFontAssetException('无法读取所选字体文件');
  }
  final file = File(path);
  final length = await file.length();
  if (length <= 0 || length > PlatformCustomFontAssetRepository.maximumBytes) {
    throw const CustomFontAssetException(
      '字体文件必须小于 32 MiB，且不能是空文件',
    );
  }
  return file.readAsBytes();
}

Future<Directory> _fontDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(_join(_join(support.path, 'custom-fonts'), 'v1'));
}

String _join(String parent, String child) =>
    '$parent${Platform.pathSeparator}$child';

String _leafName(String path) {
  final segments = path
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  return segments.isEmpty ? '' : segments.last;
}
