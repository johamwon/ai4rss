import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('article and podcast share one deduplicated queue', () {
    final queue = AudioQueue();
    final item = AudioItem(
      id: 'audio-1',
      kind: AudioKind.articleTts,
      title: 'Article',
      sourceUri: Uri.parse('river://article/1'),
    );
    queue
      ..add(item)
      ..add(item);

    expect(queue.items, hasLength(1));
  });
}
