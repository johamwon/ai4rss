import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

final class PodcastLibraryPage extends StatefulWidget {
  const PodcastLibraryPage({
    required this.repository,
    required this.refresh,
    required this.policies,
    required this.downloads,
    required this.audio,
    required this.clock,
    this.queue,
    this.chapterLoader,
    this.externalUri,
    super.key,
  });

  final PodcastCatalogRepository repository;
  final PodcastRefreshService refresh;
  final PodcastDownloadPolicyService policies;
  final PodcastDownloadManager downloads;
  final AudioPlaybackController audio;
  final Clock clock;
  final PersistentAudioQueue? queue;
  final PodcastChapterLoader? chapterLoader;
  final ExternalUriGateway? externalUri;

  @override
  State<PodcastLibraryPage> createState() => _PodcastLibraryPageState();
}

final class _PodcastLibraryPageState extends State<PodcastLibraryPage> {
  var _busy = false;

  Future<void> _addPodcast() async {
    final uri = await showDialog<Uri>(
      context: context,
      builder: (context) => const _PodcastAddressDialog(),
    );
    if (uri == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.refresh.subscribeOrRefresh(uri);
      await widget.policies.applyAfterRefresh(result);
      if (mounted) _message('播客已添加');
    } on PodcastParseException {
      if (mounted) _message('这个地址不是可播放的 Podcast RSS');
    } on Object {
      if (mounted) _message('暂时无法添加播客，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePodcast(PodcastShowRecord show) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播客'),
        content: Text('确认删除“${show.title}”及其本地下载吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final episodes = await widget.repository.listEpisodes(show.id);
      for (final episode in episodes) {
        await widget.downloads.remove(episode.id);
      }
      await widget.repository.deleteShow(show.id);
      if (mounted) _message('播客已删除');
    } on Object {
      if (mounted) _message('删除播客失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播客'),
        actions: <Widget>[
          IconButton(
            onPressed: _busy ? null : _addPodcast,
            icon: const Icon(Icons.add),
            tooltip: '添加播客 RSS',
          ),
        ],
      ),
      body: StreamBuilder<List<PodcastShowRecord>>(
        stream: widget.repository.watchShows(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _PodcastEmptyState(
              icon: Icons.error_outline,
              message: '播客库暂时无法读取',
            );
          }
          final shows = snapshot.data;
          if (shows == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (shows.isEmpty) {
            return _PodcastEmptyState(
              icon: Icons.podcasts_outlined,
              message: '还没有播客\n添加 Podcast RSS 后即可收听和离线下载',
              actionLabel: '添加播客',
              onAction: _busy ? null : _addPodcast,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: shows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final show = shows[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.podcasts_outlined),
                ),
                title: Text(show.title, maxLines: 2),
                subtitle: Text(
                  show.author?.trim().isNotEmpty == true
                      ? show.author!
                      : _policyLabel(show.downloadPolicy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<_PodcastShowAction>(
                  enabled: !_busy,
                  tooltip: '${show.title} 更多操作',
                  onSelected: (action) {
                    if (action == _PodcastShowAction.delete) {
                      unawaited(_deletePodcast(show));
                    }
                  },
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_PodcastShowAction>>[
                    PopupMenuItem<_PodcastShowAction>(
                      value: _PodcastShowAction.delete,
                      child: Text('删除播客'),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => PodcastShowPage(
                      initialShow: show,
                      repository: widget.repository,
                      refresh: widget.refresh,
                      policies: widget.policies,
                      downloads: widget.downloads,
                      audio: widget.audio,
                      clock: widget.clock,
                      queue: widget.queue,
                      chapterLoader: widget.chapterLoader,
                      externalUri: widget.externalUri,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _PodcastShowAction { delete }

final class PodcastShowPage extends StatefulWidget {
  const PodcastShowPage({
    required this.initialShow,
    required this.repository,
    required this.refresh,
    required this.policies,
    required this.downloads,
    required this.audio,
    required this.clock,
    this.queue,
    this.chapterLoader,
    this.externalUri,
    super.key,
  });

  final PodcastShowRecord initialShow;
  final PodcastCatalogRepository repository;
  final PodcastRefreshService refresh;
  final PodcastDownloadPolicyService policies;
  final PodcastDownloadManager downloads;
  final AudioPlaybackController audio;
  final Clock clock;
  final PersistentAudioQueue? queue;
  final PodcastChapterLoader? chapterLoader;
  final ExternalUriGateway? externalUri;

  @override
  State<PodcastShowPage> createState() => _PodcastShowPageState();
}

final class _PodcastShowPageState extends State<PodcastShowPage> {
  late PodcastShowRecord _show = widget.initialShow;
  var _busy = false;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.refresh.subscribeOrRefresh(
        _show.canonicalFeedUrl,
      );
      await widget.policies.applyAfterRefresh(result);
      final refreshed = await widget.repository.findShowById(_show.id);
      if (mounted && refreshed != null) {
        setState(() => _show = refreshed);
        _message(
          result.notModified
              ? '已经是最新内容'
              : '新增 ${result.insertedEpisodes}，更新 ${result.updatedEpisodes}',
        );
      }
    } on Object {
      if (mounted) _message('刷新播客失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPolicy() async {
    final selected = await showDialog<_PodcastPolicySelection>(
      context: context,
      builder: (context) => _PodcastPolicyDialog(show: _show),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.policies.updatePolicy(
        showId: _show.id,
        defaultPlaybackRate: selected.rate,
        downloadPolicy: selected.policy,
        updatedAt: widget.clock.now().toUtc(),
      );
      final updated = await widget.repository.findShowById(_show.id);
      if (mounted && updated != null) {
        setState(() => _show = updated);
        _message('节目设置已保存');
      }
    } on Object {
      if (mounted) _message('节目设置保存失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePlayback(
    PodcastEpisodeRecord episode,
    AudioPlaybackState playback,
  ) async {
    if (playback.item?.id == episode.id &&
        playback.phase == AudioEnginePhase.playing) {
      await widget.audio.pause();
      return;
    }
    try {
      final download = await widget.downloads.status(episode.id);
      final source = download.playbackUri ?? episode.mediaUrl;
      await widget.audio.load(
        AudioLoadRequest(
          item: AudioItem(
            id: episode.id,
            kind: AudioKind.podcastEpisode,
            title: episode.title,
            sourceUri: source,
          ),
        ),
      );
      final current = widget.audio.state.settings;
      await widget.audio.updateSettings(
        AudioPlaybackSettings(
          rate: _show.defaultPlaybackRate,
          pitch: current.pitch,
          voiceId: current.voiceId,
          languageTag: current.languageTag,
        ),
      );
      await widget.audio.play();
    } on Object {
      if (mounted) _message('暂时无法播放这一集');
    }
  }

  Future<void> _enqueueEpisode(PodcastEpisodeRecord episode) async {
    final queue = widget.queue;
    if (queue == null) return;
    final added = await queue.enqueue(
      AudioItem(
        id: episode.id,
        kind: AudioKind.podcastEpisode,
        title: episode.title,
        sourceUri: episode.mediaUrl,
      ),
    );
    if (mounted) {
      _message(added ? '已加入收听队列' : '已在收听队列中');
    }
  }

  Future<void> _openEpisodeMetadata(PodcastEpisodeRecord episode) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EpisodeMetadataSheet(
        episode: episode,
        chapterLoader: widget.chapterLoader,
        onChapterSelected: (chapter) => _seekChapter(episode, chapter),
        onTranscriptSelected: _openTranscript,
      ),
    );
  }

  Future<void> _seekChapter(
    PodcastEpisodeRecord episode,
    PodcastChapter chapter,
  ) async {
    if (widget.audio.state.item?.id != episode.id) {
      await _togglePlayback(episode, widget.audio.state);
    }
    if (widget.audio.state.item?.id == episode.id) {
      await widget.audio.seekToMedia(chapter.start);
    }
  }

  Future<void> _openTranscript(PodcastTranscriptReference transcript) async {
    final gateway = widget.externalUri;
    if (gateway == null) {
      if (mounted) _message('当前平台无法打开文字稿');
      return;
    }
    final outcome = await gateway.open(transcript.url);
    if (mounted && outcome != ExternalUriOpenOutcome.opened) {
      _message('当前平台无法打开文字稿');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioPlaybackState>(
      stream: widget.audio.states,
      initialData: widget.audio.state,
      builder: (context, playbackSnapshot) {
        final playback =
            playbackSnapshot.data ?? const AudioPlaybackState.initial();
        return Scaffold(
          appBar: AppBar(
            title: Text(_show.title),
            actions: <Widget>[
              IconButton(
                onPressed: _busy ? null : _editPolicy,
                icon: const Icon(Icons.tune),
                tooltip: '节目播放与下载设置',
              ),
              IconButton(
                onPressed: _busy ? null : _refresh,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: '刷新节目',
              ),
            ],
          ),
          body: StreamBuilder<List<PodcastEpisodeRecord>>(
            stream: widget.repository.watchEpisodes(_show.id),
            builder: (context, snapshot) {
              final episodes = snapshot.data;
              if (episodes == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (episodes.isEmpty) {
                return const _PodcastEmptyState(
                  icon: Icons.queue_music,
                  message: '还没有可播放的分集',
                );
              }
              return ListView.separated(
                itemCount: episodes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  final isPlaying = playback.item?.id == episode.id &&
                      playback.phase == AudioEnginePhase.playing;
                  return ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    leading: IconButton(
                      onPressed: () => _togglePlayback(episode, playback),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
                      iconSize: 40,
                      tooltip: isPlaying ? '暂停' : '播放 ${episode.title}',
                    ),
                    title: Text(episode.title, maxLines: 2),
                    subtitle: Text(
                      _episodeSubtitle(episode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: <Widget>[
                        if (episode.chapterSource != null ||
                            episode.transcripts.isNotEmpty)
                          IconButton(
                            onPressed: () => _openEpisodeMetadata(episode),
                            icon: const Icon(Icons.menu_book_outlined),
                            tooltip: '章节与文字稿',
                          ),
                        IconButton(
                          onPressed: widget.queue == null
                              ? null
                              : () => _enqueueEpisode(episode),
                          icon: const Icon(Icons.playlist_add),
                          tooltip: '加入收听队列',
                        ),
                        PodcastDownloadButton(
                          episodeId: episode.id,
                          downloads: widget.downloads,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

final class _EpisodeMetadataSheet extends StatelessWidget {
  const _EpisodeMetadataSheet({
    required this.episode,
    required this.chapterLoader,
    required this.onChapterSelected,
    required this.onTranscriptSelected,
  });

  final PodcastEpisodeRecord episode;
  final PodcastChapterLoader? chapterLoader;
  final ValueChanged<PodcastChapter> onChapterSelected;
  final ValueChanged<PodcastTranscriptReference> onTranscriptSelected;

  @override
  Widget build(BuildContext context) {
    final source = episode.chapterSource;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            Text(
              episode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (source != null) ...<Widget>[
              const SizedBox(height: 20),
              Text('章节', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (chapterLoader case final loader?)
                FutureBuilder<List<PodcastChapter>>(
                  future: loader.load(source),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final chapters = snapshot.data;
                    if (snapshot.hasError || chapters == null) {
                      return const ListTile(
                        leading: Icon(Icons.error_outline),
                        title: Text('章节暂时无法读取'),
                        subtitle: Text('稍后可以重新打开重试'),
                      );
                    }
                    if (chapters.isEmpty) {
                      return const ListTile(title: Text('这一集没有可显示章节'));
                    }
                    return Column(
                      children: chapters
                          .map(
                            (chapter) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Text(_chapterTime(chapter.start)),
                              title: Text(chapter.title),
                              trailing: const Icon(Icons.play_arrow),
                              onTap: () => onChapterSelected(chapter),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                )
              else
                const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('章节读取服务不可用'),
                ),
            ],
            if (episode.transcripts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Text('文字稿', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...episode.transcripts.map(
                (transcript) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    transcript.isCaptions
                        ? Icons.closed_caption_outlined
                        : Icons.description_outlined,
                  ),
                  title: Text(
                    transcript.language == null
                        ? _transcriptType(transcript.mimeType)
                        : '${transcript.language} · '
                            '${_transcriptType(transcript.mimeType)}',
                  ),
                  subtitle: Text(
                    transcript.isCaptions ? '带时间轴字幕' : '官方文字稿',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => onTranscriptSelected(transcript),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class PodcastDownloadButton extends StatelessWidget {
  const PodcastDownloadButton({
    required this.episodeId,
    required this.downloads,
    super.key,
  });

  final String episodeId;
  final PodcastDownloadManager downloads;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PodcastDownloadState>(
      stream: downloads.watch(episodeId),
      builder: (context, snapshot) {
        final state =
            snapshot.data ?? PodcastDownloadState.notDownloaded(episodeId);
        return switch (state.phase) {
          PodcastDownloadPhase.notDownloaded => IconButton(
              onPressed: () => downloads.enqueue(episodeId),
              icon: const Icon(Icons.download_outlined),
              tooltip: '下载这一集',
            ),
          PodcastDownloadPhase.queued ||
          PodcastDownloadPhase.downloading =>
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                onPressed: () => downloads.remove(episodeId),
                icon: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: _progress(state),
                      strokeWidth: 3,
                    ),
                    const Icon(Icons.close, size: 16),
                  ],
                ),
                tooltip: '取消下载',
              ),
            ),
          PodcastDownloadPhase.available => IconButton(
              onPressed: () => _confirmRemove(context),
              icon: const Icon(Icons.download_done),
              tooltip: '已下载；点击删除本地文件',
            ),
          PodcastDownloadPhase.failed => IconButton(
              onPressed: () => downloads.retry(episodeId),
              icon: const Icon(Icons.refresh),
              tooltip: _failureLabel(state.failureCode),
            ),
        };
      },
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除本地音频'),
        content: const Text('删除后仍可在线播放或再次下载。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await downloads.remove(episodeId);
  }
}

final class _PodcastAddressDialog extends StatefulWidget {
  const _PodcastAddressDialog();

  @override
  State<_PodcastAddressDialog> createState() => _PodcastAddressDialogState();
}

final class _PodcastAddressDialogState extends State<_PodcastAddressDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = Uri.tryParse(_controller.text.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      setState(() => _error = '请输入有效的 HTTP(S) Podcast RSS 地址');
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加播客'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'Podcast RSS 地址',
          hintText: 'https://example.com/podcast.xml',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}

final class _PodcastPolicyDialog extends StatefulWidget {
  const _PodcastPolicyDialog({required this.show});

  final PodcastShowRecord show;

  @override
  State<_PodcastPolicyDialog> createState() => _PodcastPolicyDialogState();
}

final class _PodcastPolicyDialogState extends State<_PodcastPolicyDialog> {
  late var _rate = widget.show.defaultPlaybackRate;
  late var _policy = widget.show.downloadPolicy;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('节目设置'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('默认倍速 ${_rate.toStringAsFixed(2)}×'),
            Slider(
              value: _rate,
              min: 0.5,
              max: 3,
              divisions: 10,
              label: '${_rate.toStringAsFixed(2)}×',
              onChanged: (value) => setState(() => _rate = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PodcastDownloadPolicy>(
              initialValue: _policy,
              decoration: const InputDecoration(labelText: '自动下载'),
              items: PodcastDownloadPolicy.values
                  .map(
                    (policy) => DropdownMenuItem<PodcastDownloadPolicy>(
                      value: policy,
                      child: Text(_policyLabel(policy)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _policy = value);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _PodcastPolicySelection(rate: _rate, policy: _policy),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

final class _PodcastPolicySelection {
  const _PodcastPolicySelection({required this.rate, required this.policy});

  final double rate;
  final PodcastDownloadPolicy policy;
}

final class _PodcastEmptyState extends StatelessWidget {
  const _PodcastEmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

double? _progress(PodcastDownloadState state) {
  final total = state.totalBytes;
  if (total == null || total <= 0) return null;
  return (state.downloadedBytes / total).clamp(0, 1);
}

String _policyLabel(PodcastDownloadPolicy policy) => switch (policy) {
      PodcastDownloadPolicy.manual => '手动下载',
      PodcastDownloadPolicy.newestOnly => '自动下载最新一集',
      PodcastDownloadPolicy.all => '自动下载所有新分集',
    };

String _failureLabel(String? code) => switch (code) {
      PodcastDownloadFailureCode.storageFull => '存储空间不足；点击重试',
      PodcastDownloadFailureCode.corruptMedia => '音频文件损坏；点击重试',
      PodcastDownloadFailureCode.network ||
      PodcastDownloadFailureCode.timeout =>
        '网络中断；点击重试',
      _ => '下载失败；点击重试',
    };

String _episodeSubtitle(PodcastEpisodeRecord episode) {
  final parts = <String>[];
  final published = episode.publishedAt?.toLocal();
  if (published != null) {
    parts.add(
      '${published.year}-${published.month.toString().padLeft(2, '0')}-'
      '${published.day.toString().padLeft(2, '0')}',
    );
  }
  final duration = episode.duration;
  if (duration != null) {
    final minutes = duration.inMinutes;
    parts.add(
      minutes >= 60 ? '${minutes ~/ 60} 小时 ${minutes % 60} 分' : '$minutes 分钟',
    );
  }
  return parts.isEmpty ? episode.author ?? 'Podcast' : parts.join(' · ');
}

String _chapterTime(Duration position) {
  final hours = position.inHours;
  final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
}

String _transcriptType(String mimeType) => switch (mimeType) {
      'text/vtt' => 'WebVTT',
      'application/x-subrip' => 'SRT',
      'text/plain' => '纯文本',
      'text/html' => '网页',
      'application/json' => 'JSON 字幕',
      _ => mimeType,
    };
