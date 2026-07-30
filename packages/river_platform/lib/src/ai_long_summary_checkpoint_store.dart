import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:river_ai/river_ai.dart';

enum AiLongSummaryStorageFailureCode { corruptValue, unavailable }

final class AiLongSummaryStorageException implements Exception {
  const AiLongSummaryStorageException(this.code);

  final AiLongSummaryStorageFailureCode code;

  @override
  String toString() => 'AiLongSummaryStorageException(${code.name})';
}

typedef AiCheckpointDirectoryProvider = Future<Directory> Function();

final class PlatformAiLongSummaryCheckpointStore
    implements AiLongSummaryCheckpointStore {
  PlatformAiLongSummaryCheckpointStore({
    AiCheckpointDirectoryProvider? directoryProvider,
    AiLongSummaryCheckpointCodec codec = const AiLongSummaryCheckpointCodec(),
  })  : _directoryProvider =
            directoryProvider ?? _applicationCheckpointDirectory,
        _codec = codec;

  final AiCheckpointDirectoryProvider _directoryProvider;
  final AiLongSummaryCheckpointCodec _codec;
  Future<void> _tail = Future<void>.value();

  @override
  Future<AiLongSummaryCheckpoint?> read(String articleId) =>
      _serialized(() async {
        try {
          final file = await _file(articleId);
          final backup = File('${file.path}.bak');
          if (!await file.exists() && await backup.exists()) {
            await backup.rename(file.path);
          }
          if (!await file.exists()) return null;
          final length = await file.length();
          if (length <= 0 ||
              length > AiLongSummaryCheckpointCodec.maxEncodedCharacters) {
            throw const AiLongSummaryStorageException(
              AiLongSummaryStorageFailureCode.corruptValue,
            );
          }
          final encoded = utf8.decode(
            await file.readAsBytes(),
            allowMalformed: false,
          );
          final checkpoint = _codec.decode(encoded);
          if (checkpoint.articleId != articleId) {
            throw const FormatException('Checkpoint article mismatch');
          }
          return checkpoint;
        } on AiLongSummaryStorageException {
          rethrow;
        } on FormatException {
          throw const AiLongSummaryStorageException(
            AiLongSummaryStorageFailureCode.corruptValue,
          );
        } on ArgumentError {
          rethrow;
        } on Object {
          throw const AiLongSummaryStorageException(
            AiLongSummaryStorageFailureCode.unavailable,
          );
        }
      });

  @override
  Future<void> write(AiLongSummaryCheckpoint checkpoint) =>
      _serialized(() async {
        try {
          final file = await _file(checkpoint.articleId);
          final temporary = File('${file.path}.tmp');
          final backup = File('${file.path}.bak');
          await file.parent.create(recursive: true);
          final bytes = utf8.encode(_codec.encode(checkpoint));
          if (bytes.length >
              AiLongSummaryCheckpointCodec.maxEncodedCharacters) {
            throw const AiLongSummaryStorageException(
              AiLongSummaryStorageFailureCode.corruptValue,
            );
          }
          await temporary.writeAsBytes(bytes, flush: true);
          if (await backup.exists()) await backup.delete();
          if (await file.exists()) await file.rename(backup.path);
          try {
            await temporary.rename(file.path);
            if (await backup.exists()) await backup.delete();
          } on Object {
            if (!await file.exists() && await backup.exists()) {
              await backup.rename(file.path);
            }
            rethrow;
          }
        } on AiLongSummaryStorageException {
          rethrow;
        } on ArgumentError {
          rethrow;
        } on Object {
          throw const AiLongSummaryStorageException(
            AiLongSummaryStorageFailureCode.unavailable,
          );
        }
      });

  @override
  Future<void> clear(String articleId) => _serialized(() async {
        try {
          final file = await _file(articleId);
          if (await file.exists()) await file.delete();
          final temporary = File('${file.path}.tmp');
          if (await temporary.exists()) await temporary.delete();
          final backup = File('${file.path}.bak');
          if (await backup.exists()) await backup.delete();
        } on ArgumentError {
          rethrow;
        } on Object {
          throw const AiLongSummaryStorageException(
            AiLongSummaryStorageFailureCode.unavailable,
          );
        }
      });

  Future<File> _file(String articleId) async {
    if (articleId.trim().isEmpty || articleId.length > 256) {
      throw ArgumentError.value(articleId, 'articleId');
    }
    final directory = await _directoryProvider();
    final name = sha256.convert(utf8.encode(articleId));
    return File(
      '${directory.path}${Platform.pathSeparator}$name.checkpoint.json',
    );
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}

Future<Directory> _applicationCheckpointDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(
    '${support.path}${Platform.pathSeparator}river-ai-checkpoints',
  );
}
