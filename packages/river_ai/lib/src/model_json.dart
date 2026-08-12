import 'dart:convert';

/// Decodes the JSON object carried by a model response while accepting the
/// harmless wrappers emitted by otherwise OpenAI-compatible providers.
///
/// Validation of the object remains the responsibility of the capability
/// schema. This function only removes Markdown fences, surrounding prose and
/// one of a small allow-list of transport wrappers; it never invents fields.
Map<String, Object?> decodeModelJsonObject(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) throw const FormatException('empty model output');

  Object? decoded = _tryDecode(trimmed);
  decoded ??= _tryDecode(_withoutFence(trimmed));
  decoded ??= _tryDecode(_firstJsonObject(trimmed));
  if (decoded is! Map) throw const FormatException('model output is not JSON');

  var value = Map<String, Object?>.from(decoded);
  for (var depth = 0; depth < 2; depth += 1) {
    if (value.length != 1) break;
    final wrapped = value.entries.single;
    if (!const <String>{'data', 'result', 'summary', 'output'}
        .contains(wrapped.key)) {
      break;
    }
    final child = wrapped.value;
    if (child is Map) {
      value = Map<String, Object?>.from(child);
      continue;
    }
    if (child is String) {
      final nested = _tryDecode(_withoutFence(child.trim())) ??
          _tryDecode(_firstJsonObject(child));
      if (nested is Map) {
        value = Map<String, Object?>.from(nested);
        continue;
      }
    }
    break;
  }
  return value;
}

Object? _tryDecode(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

String _withoutFence(String value) {
  final match = RegExp(
    r'^\s*```(?:json)?\s*([\s\S]*?)\s*```\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  return match?.group(1)?.trim() ?? value;
}

String? _firstJsonObject(String value) {
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = 0; index < value.length; index += 1) {
    final character = value.codeUnitAt(index);
    if (start < 0) {
      if (character == 0x7b) {
        start = index;
        depth = 1;
      }
      continue;
    }
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == 0x5c) {
        escaped = true;
      } else if (character == 0x22) {
        inString = false;
      }
      continue;
    }
    if (character == 0x22) {
      inString = true;
    } else if (character == 0x7b) {
      depth += 1;
    } else if (character == 0x7d) {
      depth -= 1;
      if (depth == 0) return value.substring(start, index + 1);
    }
  }
  return null;
}
