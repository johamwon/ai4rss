library;

import 'package:river_domain/river_domain.dart';

export 'src/article_speech_segmenter.dart';

final class AudioQueue {
  final List<AudioItem> _items = <AudioItem>[];

  List<AudioItem> get items => List<AudioItem>.unmodifiable(_items);

  void add(AudioItem item) {
    if (_items.any((existing) => existing.id == item.id)) return;
    _items.add(item);
  }

  AudioItem removeAt(int index) => _items.removeAt(index);

  void move(int from, int to) {
    final item = _items.removeAt(from);
    _items.insert(to, item);
  }
}
