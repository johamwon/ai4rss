library;

import 'package:flutter/services.dart';

export 'src/dynamic_page_renderer.dart';
export 'src/opml_file_gateway.dart';
export 'src/share_gateway.dart';

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
