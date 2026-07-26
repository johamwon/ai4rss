import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_sync/river_sync.dart';

final class SyncAccountPage extends StatefulWidget {
  const SyncAccountPage({
    required this.experience,
    super.key,
  });

  final SyncAccountExperience experience;

  @override
  State<SyncAccountPage> createState() => _SyncAccountPageState();
}

final class _SyncAccountPageState extends State<SyncAccountPage> {
  StreamSubscription<SyncAccountState>? _subscription;
  late SyncAccountState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.experience.state;
    _listen();
    unawaited(widget.experience.load());
  }

  @override
  void didUpdateWidget(SyncAccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.experience, widget.experience)) {
      unawaited(_subscription?.cancel());
      _state = widget.experience.state;
      _listen();
      unawaited(widget.experience.load());
    }
  }

  void _listen() {
    _subscription = widget.experience.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步与账号')),
      body: switch (_state.phase) {
        SyncAccountPhase.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        SyncAccountPhase.signedOut => const _SignedOutView(),
        _ => _SignedInView(
            state: _state,
            onRetry: widget.experience.retryNow,
            onHistory: _openHistory,
            onSignOut: _signOut,
            onDeleteCloudData: _deleteCloudData,
          ),
      },
    );
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _ConflictHistoryPage(
          load: widget.experience.conflictHistory,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('退出账号？'),
            content: const Text('只会清除本机登录状态；已下载文章和本地阅读数据会保留。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('退出账号'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await widget.experience.signOut();
  }

  Future<void> _deleteCloudData() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => const _DeleteCloudDataDialog(),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final result = await widget.experience.deleteCloudData();
    if (!mounted || result is SyncAuthSuccess<CloudDataDeletionReceipt>) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('云端数据删除失败，本地数据与登录状态均未改变。')),
    );
  }
}

final class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, size: 48),
            SizedBox(height: 16),
            Text('尚未登录同步账号'),
            SizedBox(height: 8),
            Text('本地阅读、全文、TTS 和知识库仍可正常使用。'),
          ],
        ),
      ),
    );
  }
}

final class _SignedInView extends StatelessWidget {
  const _SignedInView({
    required this.state,
    required this.onRetry,
    required this.onHistory,
    required this.onSignOut,
    required this.onDeleteCloudData,
  });

  final SyncAccountState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onHistory;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteCloudData;

  @override
  Widget build(BuildContext context) {
    final storage = state.storage;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        ListTile(
          leading: Icon(
            state.phase == SyncAccountPhase.ready
                ? Icons.cloud_done_outlined
                : Icons.cloud_sync_outlined,
          ),
          title: Text(_statusLabel(state)),
          subtitle: Text('设备：${state.session?.deviceId ?? '未知'}'),
        ),
        if (state.phase == SyncAccountPhase.retryableFailure ||
            state.phase == SyncAccountPhase.blocked)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.sync_problem_outlined),
              title: Text(
                state.phase == SyncAccountPhase.retryableFailure
                    ? '同步暂时失败，可以安全重试'
                    : '同步已阻止，需要重新登录或检查设备授权',
              ),
              subtitle: Text(state.failureCode?.name ?? 'unknown'),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.outbox_outlined),
          title: const Text('待上传变更'),
          trailing: Text('${storage?.pendingMutations ?? 0}'),
        ),
        ListTile(
          leading: const Icon(Icons.history_outlined),
          title: const Text('冲突历史'),
          subtitle: Text('${storage?.unresolvedConflicts ?? 0} 个尚未解决'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onHistory,
        ),
        ListTile(
          leading: const Icon(Icons.commit_outlined),
          title: const Text('服务器游标'),
          trailing: Text('${storage?.serverSequence ?? 0}'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: state.phase == SyncAccountPhase.syncing ? null : onRetry,
          icon: state.phase == SyncAccountPhase.syncing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(
            state.phase == SyncAccountPhase.syncing ? '正在同步' : '立即重试同步',
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onSignOut,
          child: const Text('退出账号（保留本地数据）'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onDeleteCloudData,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('永久删除云端同步数据'),
        ),
      ],
    );
  }
}

String _statusLabel(SyncAccountState state) => switch (state.phase) {
      SyncAccountPhase.ready => '同步已就绪',
      SyncAccountPhase.syncing => '正在同步',
      SyncAccountPhase.retryableFailure => '等待重试',
      SyncAccountPhase.blocked => '同步已阻止',
      SyncAccountPhase.loading => '正在读取同步状态',
      SyncAccountPhase.signedOut => '尚未登录',
    };

final class _ConflictHistoryPage extends StatelessWidget {
  const _ConflictHistoryPage({required this.load});

  final Future<List<SyncConflictHistoryEntry>> Function({int limit}) load;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('冲突历史')),
      body: FutureBuilder<List<SyncConflictHistoryEntry>>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('无法读取冲突历史'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('没有冲突记录'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Icon(
                  entry.isResolved
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
                title: Text('${entry.objectKind.name} · ${entry.objectId}'),
                subtitle: Text(entry.resolutionKind),
              );
            },
          );
        },
      ),
    );
  }
}

final class _DeleteCloudDataDialog extends StatefulWidget {
  const _DeleteCloudDataDialog();

  @override
  State<_DeleteCloudDataDialog> createState() => _DeleteCloudDataDialogState();
}

final class _DeleteCloudDataDialogState extends State<_DeleteCloudDataDialog> {
  static const confirmation = '删除云端数据';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _controller.text.trim() == confirmation;
    return AlertDialog(
      title: const Text('永久删除云端同步数据？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '服务器上的加密副本、设备和同步历史将永久删除；本机文章不会删除。'
            '此操作不可撤销。',
          ),
          const SizedBox(height: 16),
          const Text('请输入“删除云端数据”以确认：'),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: enabled ? () => Navigator.of(context).pop(true) : null,
          child: const Text('永久删除'),
        ),
      ],
    );
  }
}
