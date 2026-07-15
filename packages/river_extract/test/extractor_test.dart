import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  test('sanitizer removes executable HTML', () {
    final result = sanitizeRemoteHtml(
      '<article onclick="steal()">Safe<script>alert(1)</script></article>',
    );

    expect(result, contains('Safe'));
    expect(result, isNot(contains('<script')));
    expect(result, isNot(contains('onclick')));
  });
}
