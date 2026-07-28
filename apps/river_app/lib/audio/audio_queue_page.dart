import 'package:flutter/material.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';

final class AudioQueuePage extends StatelessWidget {
  const AudioQueuePage({
    required this.queue,
    required this.player,
    required this.playback,
    super.key,
  });

  final PersistentAudioQueue queue;
  final AudioQueuePlaybackCoordinator player;
  final AudioPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收听队列'),
        actions: <Widget>[
          StreamBuilder<AudioQueueSnapshot>(
            stream: queue.snapshots,
            builder: (context, snapshot) => IconButton(
              onPressed: snapshot.data?.entries.isNotEmpty == true
                  ? () => _confirmClear(context)
                  : null,
              icon: const Icon(Icons.playlist_remove),
              tooltip: '清空收听队列',
            ),
          ),
        ],
      ),
      body: StreamBuilder<AudioQueueSnapshot>(
        stream: queue.snapshots,
        builder: (context, queueSnapshot) {
          final snapshot =
              queueSnapshot.data ?? const AudioQueueSnapshot.empty();
          if (snapshot.entries.isEmpty) {
            return const _EmptyAudioQueue();
          }
          return StreamBuilder<AudioPlaybackState>(
            stream: playback.states,
            initialData: playback.state,
            builder: (context, playbackSnapshot) {
              final audio =
                  playbackSnapshot.data ?? const AudioPlaybackState.initial();
              return ListView.separated(
                itemCount: snapshot.entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = snapshot.entries[index];
                  final playing = audio.item?.id == entry.item.id &&
                      audio.phase == AudioEnginePhase.playing;
                  return Semantics(
                    selected: entry.isCurrent,
                    child: ListTile(
                      leading: IconButton(
                        onPressed: () => _toggle(entry, playing),
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                        tooltip: playing
                            ? '暂停 ${entry.item.title}'
                            : '播放 ${entry.item.title}',
                      ),
                      title: Text(entry.item.title, maxLines: 2),
                      subtitle: Text(
                        entry.item.kind == AudioKind.articleTts
                            ? '文章朗读${entry.isCurrent ? ' · 当前' : ''}'
                            : 'Podcast 分集${entry.isCurrent ? ' · 当前' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 0,
                        children: <Widget>[
                          IconButton(
                            onPressed: index == 0
                                ? null
                                : () => queue.move(entry.item.id, index - 1),
                            icon: const Icon(Icons.arrow_upward),
                            tooltip: '上移',
                          ),
                          IconButton(
                            onPressed: index + 1 == snapshot.entries.length
                                ? null
                                : () => queue.move(entry.item.id, index + 1),
                            icon: const Icon(Icons.arrow_downward),
                            tooltip: '下移',
                          ),
                          IconButton(
                            onPressed: () => queue.remove(entry.item.id),
                            icon: const Icon(Icons.close),
                            tooltip: '从队列移除',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggle(AudioQueueEntry entry, bool playing) async {
    if (playing) {
      await playback.pause();
    } else {
      await player.play(entry.item.id);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空收听队列'),
        content: const Text('播放断点会保留，之后仍可重新加入。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await queue.clear();
  }
}

final class _EmptyAudioQueue extends StatelessWidget {
  const _EmptyAudioQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '收听队列为空',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.queue_music, size: 56),
            SizedBox(height: 12),
            Text('收听队列为空'),
            SizedBox(height: 4),
            Text('可从文章或 Podcast 分集加入'),
          ],
        ),
      ),
    );
  }
}
