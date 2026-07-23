import 'dart:ui';

import 'package:river_domain/river_domain.dart';
import 'package:share_plus/share_plus.dart';

typedef PlatformShare = Future<ShareResult> Function(ShareParams params);

final class SharePlusGateway implements ShareGateway {
  SharePlusGateway({PlatformShare? share})
      : _share = share ?? SharePlus.instance.share;

  final PlatformShare _share;

  @override
  Future<ShareOutcome> share(ShareRequest request) async {
    final anchor = request.anchor;
    final result = await _share(
      ShareParams(
        text: request.text,
        title: request.title,
        subject: request.subject,
        sharePositionOrigin: anchor == null
            ? null
            : Rect.fromLTWH(
                anchor.left,
                anchor.top,
                anchor.width,
                anchor.height,
              ),
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.completed,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }
}
