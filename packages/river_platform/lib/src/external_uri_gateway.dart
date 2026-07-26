import 'package:river_domain/river_domain.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

final class UrlLauncherExternalUriGateway implements ExternalUriGateway {
  UrlLauncherExternalUriGateway({ExternalUriLauncher? launch})
      : _launch = launch ?? _launchExternally;

  final ExternalUriLauncher _launch;

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async {
    if (!_isSafePublicWebUri(uri)) {
      return ExternalUriOpenOutcome.unavailable;
    }
    try {
      return await _launch(uri)
          ? ExternalUriOpenOutcome.opened
          : ExternalUriOpenOutcome.unavailable;
    } on Object {
      return ExternalUriOpenOutcome.unavailable;
    }
  }
}

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

bool _isSafePublicWebUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.hasAuthority &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;
