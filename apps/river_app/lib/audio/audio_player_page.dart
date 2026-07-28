import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';

final class AudioPlayerPage extends StatelessWidget {
  const AudioPlayerPage({
    required this.queue,
    required this.player,
    required this.playback,
    required this.onOpenQueue,
    super.key,
  });

  final PersistentAudioQueue queue;
  final AudioQueuePlaybackCoordinator player;
  final AudioPlaybackController playback;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('正在收听'),
        actions: <Widget>[
          IconButton(
            onPressed: onOpenQueue,
            icon: const Icon(Icons.queue_music),
            tooltip: '打开收听队列',
          ),
        ],
      ),
      body: StreamBuilder<AudioQueueSnapshot>(
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
            if (item == null) return const _EmptyPlayer();
            return _PlayerBody(
              item: item,
              queue: snapshot,
              audio: audio,
              player: player,
              playback: playback,
            );
          },
        ),
      ),
    );
  }
}

final class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.item,
    required this.queue,
    required this.audio,
    required this.player,
    required this.playback,
  });

  final AudioItem item;
  final AudioQueueSnapshot queue;
  final AudioPlaybackState audio;
  final AudioQueuePlaybackCoordinator player;
  final AudioPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final currentIndex = queue.currentIndex;
    final playing =
        audio.item?.id == item.id && audio.phase == AudioEnginePhase.playing;
    final busy = audio.phase == AudioEnginePhase.loading || audio.restoring;
    final status = _phaseLabel(audio, item.id);
    final progress = _progressLabel(audio, item.id);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${_kindLabel(item.kind)}，${item.title}，$status',
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        item.kind == AudioKind.articleTts
                            ? Icons.article_outlined
                            : Icons.podcasts,
                        color: colors.primary,
                        size: 104,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_kindLabel(item.kind)} · $status',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                      if (progress != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          progress,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          IconButton.filledTonal(
                            onPressed: currentIndex > 0 && !busy
                                ? () => unawaited(player.playPrevious())
                                : null,
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 32,
                            tooltip: '播放队列上一项',
                          ),
                          const SizedBox(width: 18),
                          IconButton.filled(
                            onPressed:
                                busy ? null : () => unawaited(_toggle(playing)),
                            icon: busy
                                ? const SizedBox.square(
                                    dimension: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                  ),
                            iconSize: 42,
                            padding: const EdgeInsets.all(14),
                            tooltip: playing ? '暂停' : '播放',
                          ),
                          const SizedBox(width: 18),
                          IconButton.filledTonal(
                            onPressed: currentIndex >= 0 &&
                                    currentIndex + 1 < queue.entries.length &&
                                    !busy
                                ? () => unawaited(player.playNext())
                                : null,
                            icon: const Icon(Icons.skip_next),
                            iconSize: 32,
                            tooltip: '播放队列下一项',
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: <Widget>[
                          PopupMenuButton<double>(
                            enabled: audio.item?.id == item.id && !busy,
                            onSelected: (rate) => unawaited(_updateRate(rate)),
                            itemBuilder: (context) => <double>[
                              0.75,
                              1,
                              1.25,
                              1.5,
                              2,
                            ]
                                .map(
                                  (rate) => CheckedPopupMenuItem<double>(
                                    value: rate,
                                    checked: audio.settings.rate == rate,
                                    child: Text('${_number(rate)} 倍速'),
                                  ),
                                )
                                .toList(growable: false),
                            tooltip: '播放速度',
                            child: Chip(
                              avatar: const Icon(Icons.speed, size: 18),
                              label: Text(
                                '${_number(audio.settings.rate)}×',
                              ),
                            ),
                          ),
                          PopupMenuButton<int>(
                            enabled: audio.item?.id == item.id && !busy,
                            onSelected: (minutes) => playback.setSleepTimer(
                              minutes == 0 ? null : Duration(minutes: minutes),
                            ),
                            itemBuilder: (context) => <int>[0, 10, 20, 30, 60]
                                .map(
                                  (minutes) => PopupMenuItem<int>(
                                    value: minutes,
                                    child: Text(
                                      minutes == 0 ? '关闭定时' : '$minutes 分钟后停止',
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            tooltip: '定时停止',
                            child: Chip(
                              avatar: const Icon(
                                Icons.timer_outlined,
                                size: 18,
                              ),
                              label: Text(_sleepLabel(audio.sleepDeadline)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(bool playing) async {
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

  Future<void> _updateRate(double rate) => playback.updateSettings(
        AudioPlaybackSettings(
          rate: rate,
          pitch: audio.settings.pitch,
          voiceId: audio.settings.voiceId,
          languageTag: audio.settings.languageTag,
        ),
      );
}

final class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '当前没有可播放内容',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.headphones_outlined, size: 64),
            SizedBox(height: 12),
            Text('当前没有可播放内容'),
            SizedBox(height: 4),
            Text('请先从文章或 Podcast 分集加入收听队列'),
          ],
        ),
      ),
    );
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

String? _progressLabel(AudioPlaybackState audio, String itemId) {
  if (audio.item?.id != itemId) return null;
  final position = audio.position;
  if (position == null) return null;
  if (position.isSpeech) {
    final total = audio.request?.speechSegments.length ?? 0;
    return total == 0
        ? null
        : '第 ${(position.segmentIndex ?? 0) + 1} / $total 段';
  }
  final elapsed = position.mediaPosition ?? Duration.zero;
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _sleepLabel(DateTime? deadline) => deadline == null ? '定时停止' : '定时已开启';

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
