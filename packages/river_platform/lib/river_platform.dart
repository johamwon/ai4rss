library;

import 'package:flutter/services.dart';

export 'src/ai_long_summary_checkpoint_store.dart';
export 'src/background_refresh_scheduler.dart';
export 'src/dynamic_page_renderer.dart';
export 'src/external_uri_gateway.dart';
export 'src/knowledge_markdown_file_gateway.dart';
export 'src/network_monitor.dart';
export 'src/opml_file_gateway.dart';
export 'src/podcast_audio_engine.dart';
export 'src/podcast_download_backend.dart';
export 'src/secure_ai_byok_configuration_vault.dart';
export 'src/secure_entitlement_snapshot_store.dart';
export 'src/secure_notion_authorization_vault.dart';
export 'src/secure_sync_vault.dart';
export 'src/share_gateway.dart';
export 'src/system_audio_session.dart';
export 'src/system_tts_audio_engine.dart';

abstract interface class RiverPlatformBridge {
  Future<String> platformVersion();
}

final class MethodChannelRiverPlatform implements RiverPlatformBridge {
  const MethodChannelRiverPlatform({
    MethodChannel channel = const MethodChannel('app.river/platform'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<String> platformVersion() async {
    return await _channel.invokeMethod<String>('platformVersion') ?? 'unknown';
  }
}
