import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  test('maps sanitized source semantics without changing canonical text', () {
    const text = '一级标题\n普通强调和链接。\n引用内容\n代码片段\n列表项目';
    final document = parseReaderSemanticDocument(
      sanitizedHtml: '<h1>一级标题</h1><p>普通<strong>强调</strong>和'
          '<a href="https://example.test">链接</a>。</p>'
          '<blockquote>引用内容</blockquote><pre><code>代码片段</code></pre>'
          '<ul><li>列表项目</li></ul>',
      plainText: text,
    );

    expect(document.text, text);
    expect(
      document.ranges
          .where((range) => range.kind == ReaderSemanticKind.heading1)
          .map((range) => text.substring(range.start, range.end)),
      contains('一级标题'),
    );
    expect(
      document.ranges
          .where((range) => range.kind == ReaderSemanticKind.strong)
          .map((range) => text.substring(range.start, range.end)),
      contains('强调'),
    );
    expect(
      document.ranges
          .where((range) => range.kind == ReaderSemanticKind.code)
          .map((range) => text.substring(range.start, range.end)),
      contains('代码片段'),
    );
  });

  test('malformed or mismatched HTML fails open to readable plain text', () {
    final document = parseReaderSemanticDocument(
      sanitizedHtml: '<h2>different',
      plainText: 'canonical text',
    );

    expect(document.text, 'canonical text');
    expect(document.ranges, isEmpty);
  });
}
