import 'package:river_domain/river_domain.dart';

final class ArticleSpeechSegmenter {
  const ArticleSpeechSegmenter({
    this.maxSegmentCharacters = 280,
  }) : assert(maxSegmentCharacters >= 16 && maxSegmentCharacters <= 1000);

  final int maxSegmentCharacters;

  List<SpeechSegment> segment(String source) {
    if (source.trim().isEmpty) return const <SpeechSegment>[];

    final segments = <SpeechSegment>[];
    var proseStart = 0;
    var cursor = 0;
    while (cursor < source.length) {
      final line = _lineAt(source, cursor);
      final fence = _fenceMarker(line.text);
      if (fence == null) {
        cursor = line.next;
        continue;
      }

      _appendProse(segments, source, proseStart, line.start);
      final codeStart = line.start;
      cursor = line.next;
      var codeEnd = source.length;
      while (cursor < source.length) {
        final candidate = _lineAt(source, cursor);
        cursor = candidate.next;
        if (_closesFence(candidate.text, fence)) {
          codeEnd = candidate.next;
          break;
        }
      }
      _appendCodePlaceholder(segments, source, codeStart, codeEnd);
      proseStart = codeEnd;
    }
    _appendProse(segments, source, proseStart, source.length);
    return List<SpeechSegment>.unmodifiable(segments);
  }

  void _appendProse(
    List<SpeechSegment> segments,
    String source,
    int rangeStart,
    int rangeEnd,
  ) {
    var start = _skipWhitespace(source, rangeStart, rangeEnd);
    var cursor = start;
    var softBreak = -1;

    while (cursor < rangeEnd) {
      final width = _codePointWidth(source, cursor);
      final next = cursor + width;
      final codePoint = _codePointAt(source, cursor);
      if (_isSoftBoundary(codePoint) &&
          next - start >= maxSegmentCharacters ~/ 2) {
        softBreak = next;
      }

      if (_isHardBoundary(source, cursor, codePoint, rangeEnd)) {
        final boundary = _consumeClosingPunctuation(source, next, rangeEnd);
        _appendProseSegment(segments, source, start, boundary);
        start = _skipWhitespace(source, boundary, rangeEnd);
        cursor = start;
        softBreak = -1;
        continue;
      }

      if (next - start >= maxSegmentCharacters) {
        final preferred = softBreak > start
            ? softBreak
            : _safeCodeUnitBoundary(
                source,
                start + maxSegmentCharacters,
                start,
                rangeEnd,
              );
        _appendProseSegment(segments, source, start, preferred);
        start = _skipWhitespace(source, preferred, rangeEnd);
        cursor = start;
        softBreak = -1;
        continue;
      }
      cursor = next;
    }
    _appendProseSegment(segments, source, start, rangeEnd);
  }

  void _appendProseSegment(
    List<SpeechSegment> segments,
    String source,
    int start,
    int end,
  ) {
    final trimmedStart = _skipWhitespace(source, start, end);
    final trimmedEnd = _trimWhitespaceEnd(source, trimmedStart, end);
    if (trimmedStart >= trimmedEnd) return;
    final raw = source.substring(trimmedStart, trimmedEnd);
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return;
    segments.add(
      SpeechSegment(
        index: segments.length,
        text: text,
        sourceStart: trimmedStart,
        sourceEnd: trimmedEnd,
        languageTag: _languageTag(text),
      ),
    );
  }

  void _appendCodePlaceholder(
    List<SpeechSegment> segments,
    String source,
    int start,
    int end,
  ) {
    final contextStart = (start - 400).clamp(0, start).toInt();
    final contextEnd = (end + 400).clamp(end, source.length).toInt();
    final surroundingLanguage = segments.isEmpty
        ? _languageTag(source.substring(end, contextEnd))
        : segments.last.languageTag ??
            _languageTag(
              '${source.substring(contextStart, start)} '
              '${source.substring(end, contextEnd)}',
            );
    final useChinese = surroundingLanguage == 'zh-CN';
    segments.add(
      SpeechSegment(
        index: segments.length,
        text: useChinese ? '代码块已跳过。' : 'Code block skipped.',
        sourceStart: start,
        sourceEnd: end,
        kind: SpeechSegmentKind.codePlaceholder,
        languageTag: useChinese ? 'zh-CN' : 'en-US',
      ),
    );
  }
}

final class _SourceLine {
  const _SourceLine({
    required this.start,
    required this.next,
    required this.text,
  });

  final int start;
  final int next;
  final String text;
}

_SourceLine _lineAt(String source, int start) {
  final newline = source.indexOf('\n', start);
  final next = newline == -1 ? source.length : newline + 1;
  var contentEnd = newline == -1 ? source.length : newline;
  if (contentEnd > start && source.codeUnitAt(contentEnd - 1) == 0x0D) {
    contentEnd -= 1;
  }
  return _SourceLine(
    start: start,
    next: next,
    text: source.substring(start, contentEnd),
  );
}

String? _fenceMarker(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('```')) return '```';
  if (trimmed.startsWith('~~~')) return '~~~';
  return null;
}

bool _closesFence(String line, String marker) =>
    line.trimLeft().startsWith(marker);

int _skipWhitespace(String source, int start, int end) {
  var cursor = start;
  while (cursor < end) {
    final codePoint = _codePointAt(source, cursor);
    if (!_isWhitespace(codePoint)) break;
    cursor += _codePointWidth(source, cursor);
  }
  return cursor;
}

int _trimWhitespaceEnd(String source, int start, int end) {
  var cursor = end;
  while (cursor > start) {
    final previous = _previousCodePointStart(source, cursor);
    if (!_isWhitespace(_codePointAt(source, previous))) break;
    cursor = previous;
  }
  return cursor;
}

int _previousCodePointStart(String source, int end) {
  var cursor = end - 1;
  if (cursor > 0 &&
      _isLowSurrogate(source.codeUnitAt(cursor)) &&
      _isHighSurrogate(source.codeUnitAt(cursor - 1))) {
    cursor -= 1;
  }
  return cursor;
}

int _codePointWidth(String source, int offset) =>
    _isHighSurrogate(source.codeUnitAt(offset)) &&
            offset + 1 < source.length &&
            _isLowSurrogate(source.codeUnitAt(offset + 1))
        ? 2
        : 1;

int _codePointAt(String source, int offset) {
  final first = source.codeUnitAt(offset);
  if (!_isHighSurrogate(first) ||
      offset + 1 >= source.length ||
      !_isLowSurrogate(source.codeUnitAt(offset + 1))) {
    return first;
  }
  return 0x10000 +
      ((first - 0xD800) << 10) +
      (source.codeUnitAt(offset + 1) - 0xDC00);
}

int _safeCodeUnitBoundary(
  String source,
  int preferred,
  int start,
  int end,
) {
  var boundary = preferred.clamp(start + 1, end);
  if (boundary < end &&
      boundary > start &&
      _isHighSurrogate(source.codeUnitAt(boundary - 1)) &&
      _isLowSurrogate(source.codeUnitAt(boundary))) {
    boundary -= 1;
  }
  return boundary;
}

bool _isHighSurrogate(int value) => value >= 0xD800 && value <= 0xDBFF;

bool _isLowSurrogate(int value) => value >= 0xDC00 && value <= 0xDFFF;

bool _isWhitespace(int codePoint) =>
    codePoint == 0x20 ||
    codePoint == 0x09 ||
    codePoint == 0x0A ||
    codePoint == 0x0D ||
    codePoint == 0x3000;

bool _isSoftBoundary(int codePoint) =>
    _isWhitespace(codePoint) ||
    codePoint == 0x2C ||
    codePoint == 0x3A ||
    codePoint == 0x3001 ||
    codePoint == 0xFF0C ||
    codePoint == 0xFF1A;

bool _isHardBoundary(
  String source,
  int offset,
  int codePoint,
  int end,
) {
  if (codePoint == 0x0A ||
      codePoint == 0x21 ||
      codePoint == 0x3F ||
      codePoint == 0x3B ||
      codePoint == 0x2026 ||
      codePoint == 0x3002 ||
      codePoint == 0xFF01 ||
      codePoint == 0xFF1F ||
      codePoint == 0xFF1B) {
    return true;
  }
  if (codePoint != 0x2E) return false;
  return _isSentencePeriod(source, offset, end);
}

bool _isSentencePeriod(String source, int offset, int end) {
  final previous = offset > 0 ? source.codeUnitAt(offset - 1) : null;
  final next = offset + 1 < end ? source.codeUnitAt(offset + 1) : null;
  if (previous != null &&
      next != null &&
      _isAsciiDigit(previous) &&
      _isAsciiDigit(next)) {
    return false;
  }

  var wordStart = offset;
  while (wordStart > 0 && _isAsciiLetter(source.codeUnitAt(wordStart - 1))) {
    wordStart -= 1;
  }
  final word = source.substring(wordStart, offset).toLowerCase();
  const abbreviations = <String>{
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'vs',
    'etc',
    'e',
    'g',
    'i',
  };
  if (abbreviations.contains(word)) return false;
  if (word.length == 1 &&
      next != null &&
      (_isAsciiLetter(next) || _isWhitespace(next))) {
    return false;
  }
  return true;
}

int _consumeClosingPunctuation(String source, int start, int end) {
  var cursor = start;
  while (cursor < end) {
    final codePoint = _codePointAt(source, cursor);
    if (!_isClosingPunctuation(codePoint)) break;
    cursor += _codePointWidth(source, cursor);
  }
  return cursor;
}

bool _isClosingPunctuation(int codePoint) =>
    codePoint == 0x22 ||
    codePoint == 0x27 ||
    codePoint == 0x29 ||
    codePoint == 0x5D ||
    codePoint == 0x2019 ||
    codePoint == 0x201D ||
    codePoint == 0x3009 ||
    codePoint == 0x300B ||
    codePoint == 0x3011 ||
    codePoint == 0x3015;

bool _isAsciiDigit(int value) => value >= 0x30 && value <= 0x39;

bool _isAsciiLetter(int value) =>
    (value >= 0x41 && value <= 0x5A) || (value >= 0x61 && value <= 0x7A);

String? _languageTag(String text) {
  var han = 0;
  var latin = 0;
  for (final codePoint in text.runes) {
    if ((codePoint >= 0x3400 && codePoint <= 0x4DBF) ||
        (codePoint >= 0x4E00 && codePoint <= 0x9FFF) ||
        (codePoint >= 0xF900 && codePoint <= 0xFAFF)) {
      han += 1;
    } else if ((codePoint >= 0x41 && codePoint <= 0x5A) ||
        (codePoint >= 0x61 && codePoint <= 0x7A)) {
      latin += 1;
    }
  }
  if (han == 0 && latin == 0) return null;
  if (han > 0 && latin == 0) return 'zh-CN';
  if (latin > 0 && han == 0) return 'en-US';
  if (han >= latin * 2) return 'zh-CN';
  if (latin >= han * 3) return 'en-US';
  return null;
}
