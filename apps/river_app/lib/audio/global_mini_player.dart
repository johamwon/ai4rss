import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';

final class GlobalMiniPlayer extends StatelessWidget {
  const GlobalMiniPlayer({
    required this.queue,
    required this.player,
    required this.playback,
    required this.onOpenPlayer,
    required this.onOpenQueue,
    super.key,
  });

  final PersistentAudioQueue queue;
  final AudioQueuePlaybackCoordinator player;
  final AudioPlaybackController playback;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioQueueSnapshot>(
      stream: queue.snapshots,
      builder: (context, queueSnapshot) => StreamBuilder<AudioPlaybackState>(
        stream: playback.states,
        initialData: playback.state,
        builder: (context, playbackSnapshot) {
          final snapshot =
              queueSnapshot.data ?? const AudioQueueSnapshot.empty();
          final audio =
              playbackSnapshot.data ?? const AudioPlaybackState.initial();
          final item = audio.item ?? snapshot.current?.item;
          if (item == null) return const SizedBox.shrink();

          final currentIndex = snapshot.currentIndex;
          final playing = audio.item?.id == item.id &&
              audio.phase == AudioEnginePhase.playing;
          final busy =
              audio.phase == AudioEnginePhase.loading || audio.restoring;
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: '${_kindLabel(item.kind)}，${item.title}，'
                    '${_phaseLabel(audio, item.id)}',
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: currentIndex > 0 && !busy
                            ? () => unawaited(player.playPrevious())
                            : null,
                        icon: const Icon(Icons.skip_previous),
                        tooltip: '播放队列上一项',
                      ),
                      IconButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(_toggle(item, playing)),
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                              ),
                        iconSize: 36,
                        tooltip: playing ? '暂停' : '播放',
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: onOpenPlayer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_kindLabel(item.kind)} · '
                                  '${_phaseLabel(audio, item.id)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: currentIndex >= 0 &&
                                currentIndex + 1 < snapshot.entries.length &&
                                !busy
                            ? () => unawaited(player.playNext())
                            : null,
                        icon: const Icon(Icons.skip_next),
                        tooltip: '播放队列下一项',
                      ),
                      IconButton(
                        onPressed: onOpenQueue,
                        icon: const Icon(Icons.queue_music),
                        tooltip: '打开收听队列',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(AudioItem item, bool playing) async {
    if (playing) {
      await playback.pause();
      return;
    }
    if (playback.state.item?.id == item.id &&
        playback.state.phase != AudioEnginePhase.completed &&
        playback.state.phase != AudioEnginePhase.failed) {
      await playback.play();
      return;
    }
    await player.play(item.id);
  }
}

String _kindLabel(AudioKind kind) => switch (kind) {
      AudioKind.articleTts => '文章朗读',
      AudioKind.podcastEpisode => 'Podcast',
    };

String _phaseLabel(AudioPlaybackState audio, String itemId) {
  if (audio.item?.id != itemId) return '等待播放';
  if (audio.restoring) return '正在恢复';
  return switch (audio.phase) {
    AudioEnginePhase.idle => '等待播放',
    AudioEnginePhase.loading => '正在加载',
    AudioEnginePhase.ready => '已就绪',
    AudioEnginePhase.playing => '正在播放',
    AudioEnginePhase.paused => '已暂停',
    AudioEnginePhase.stopped => '已停止',
    AudioEnginePhase.completed => '已完成',
    AudioEnginePhase.interrupted => '播放中断',
    AudioEnginePhase.failed => '播放失败',
  };
}
