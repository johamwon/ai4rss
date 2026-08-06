import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_preferences/river_preferences.dart';

final class RankingExperimentPage extends StatefulWidget {
  const RankingExperimentPage({
    required this.experiment,
    required this.clock,
    required this.entropy,
    this.copyExport,
    super.key,
  });

  final LocalRankingExperiment experiment;
  final Clock clock;
  final String Function() entropy;
  final Future<void> Function(String contents)? copyExport;

  @override
  State<RankingExperimentPage> createState() => _RankingExperimentPageState();
}

final class _RankingExperimentPageState extends State<RankingExperimentPage> {
  RankingExperimentEnrollment? _enrollment;
  RankingExperimentReport? _report;
  Object? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final now = widget.clock.now();
      final report = await widget.experiment.buildReport(
        startDay: rankingExperimentLocalDayKey(
          now.subtract(const Duration(days: 29)),
        ),
        endDay: rankingExperimentLocalDayKey(now),
      );
      final enrollment = await widget.experiment.readEnrollment();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _report = report;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy || enabled == (_enrollment != null)) return;
    if (enabled) {
      final accepted = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('参加本地排序对照实验？'),
              content: const Text(
                'River 会把本机稳定分到“时间排序”或“个性化排序”之一，并只记录按天汇总的曝光数、'
                '完成率、快速退出率、来源多样性及自动摘要的命中、延迟和成本。'
                '不会记录或上传文章、来源、标题、网址、正文和 AI 输出。',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('仅在本机参加'),
                ),
              ],
            ),
          ) ??
          false;
      if (!accepted || !mounted) return;
    }
    await _run(() async {
      if (enabled) {
        await widget.experiment.enable(
          entropy: widget.entropy(),
          now: widget.clock.now(),
        );
      } else {
        await widget.experiment.disable(now: widget.clock.now());
      }
    });
  }

  Future<void> _copyAggregate() async {
    final report = _report;
    if (report == null) return;
    await _run(
      () async {
        final contents = report.exportAggregateJson();
        final copy = widget.copyExport;
        if (copy == null) {
          await Clipboard.setData(ClipboardData(text: contents));
        } else {
          await copy(contents);
        }
        if (mounted) _message('匿名聚合结果已复制');
      },
      reload: false,
    );
  }

  Future<void> _clear() async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空实验指标？'),
            content: const Text('将删除本机全部排序实验聚合指标；不会改变当前实验分组。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('清空指标'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;
    await _run(() async {
      await widget.experiment.clearMetrics();
    });
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool reload = true,
  }) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (reload) await _reload();
    } on Object {
      if (mounted) _message('操作失败，请重试');
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
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('本地排序对照实验')),
      body: _error != null && report == null
          ? Center(
              child: FilledButton.tonal(
                onPressed: _reload,
                child: const Text('重新加载'),
              ),
            )
          : report == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: <Widget>[
                    const Text(
                      '默认关闭，数据只保存在本机，不会自动上传。指标账本只含按天聚合值，'
                      '不含任何文章或来源标识及内容。',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('参加实验'),
                      subtitle: Text(
                        _enrollment == null
                            ? '未参加；现有智能排序行为不变'
                            : '当前分组：${_armLabel(_enrollment!.arm)}（本机稳定分组）',
                      ),
                      value: _enrollment != null,
                      onChanged: _busy
                          ? null
                          : (value) => unawaited(_setEnabled(value)),
                    ),
                    const Divider(),
                    Text(
                      '最近 30 天',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _ArmCard(metrics: report.chronological),
                    _ArmCard(metrics: report.personalized),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('本机判定'),
                      subtitle: Text(_decisionLabel(report.decision)),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy ||
                              report.decision ==
                                  RankingExperimentDecision.insufficientData
                          ? null
                          : _copyAggregate,
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('复制匿名聚合结果'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _clear,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('清空本机实验指标'),
                    ),
                  ],
                ),
    );
  }
}

final class _ArmCard extends StatelessWidget {
  const _ArmCard({required this.metrics});

  final RankingExperimentArmMetrics metrics;

  @override
  Widget build(BuildContext context) => Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _armLabel(metrics.arm),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '曝光 ${metrics.exposures} · 打开 ${metrics.opens} · '
                '完成率 ${_percent(metrics.completionRate)} · '
                '快速退出 ${_percent(metrics.quickExitRate)}',
              ),
              Text(
                '来源多样性 ${metrics.sourceDiversityMean.toStringAsFixed(2)} · '
                '摘要命中 ${_percent(metrics.summaryCacheHitRate)} · '
                '平均延迟 ${metrics.averageSummaryLatencyMilliseconds.toStringAsFixed(0)} ms · '
                '成本 \$${metrics.summaryCostUsd.toStringAsFixed(4)}',
              ),
            ],
          ),
        ),
      );
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _armLabel(RankingExperimentArm arm) => switch (arm) {
      RankingExperimentArm.chronological => '时间排序组',
      RankingExperimentArm.personalized => '个性化排序组',
    };

String _decisionLabel(RankingExperimentDecision decision) => switch (decision) {
      RankingExperimentDecision.insufficientData =>
        '样本不足：每组至少需要 100 次打开和 20 次列表曝光，暂不导出或下结论。',
      RankingExperimentDecision.ship =>
        '通过：完成率提升的 95% 区间大于 0，且快速退出与来源多样性护栏均通过。',
      RankingExperimentDecision.hold => '暂缓：至少一项效果或安全护栏未通过。',
    };
