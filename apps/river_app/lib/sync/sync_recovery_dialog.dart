import 'package:flutter/material.dart';
import 'package:river_sync/river_sync.dart';

final class SyncRecoveryCodeDialog extends StatefulWidget {
  const SyncRecoveryCodeDialog({
    required this.secret,
    required this.onConfirmed,
    super.key,
  });

  final SyncRecoverySecret secret;
  final VoidCallback onConfirmed;

  @override
  State<SyncRecoveryCodeDialog> createState() => _SyncRecoveryCodeDialogState();
}

final class _SyncRecoveryCodeDialogState extends State<SyncRecoveryCodeDialog> {
  var _saved = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('保存同步恢复码'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '恢复码是重新获得端到端加密数据的唯一方式。River 服务端无法'
              '查看或找回它；请离线保存，不要发送给任何人。',
            ),
            const SizedBox(height: 16),
            Semantics(
              label: '同步恢复码',
              textField: true,
              readOnly: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    widget.secret.revealCode(),
                    key: const ValueKey<String>('sync-recovery-code'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saved,
              onChanged: (value) {
                setState(() => _saved = value ?? false);
              },
              title: const Text('我已将恢复码离线保存在安全位置'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('稍后设置'),
        ),
        FilledButton(
          onPressed: _saved ? widget.onConfirmed : null,
          child: const Text('已安全保存'),
        ),
      ],
    );
  }
}
