import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// Links to the public legal pages the backend serves.
///
/// Google Play requires the privacy policy and a data-deletion route to be
/// reachable, and reachable from inside the app -- not only from the store
/// listing. These open in a browser rather than an in-app WebView so the
/// address bar shows the real domain: a policy page that could be anything is
/// worth less than one the reader can verify.
class LegalLinks {
  /// The site root, derived rather than configured separately.
  ///
  /// `kApiBaseUrl` points at the API mount and normally ends in `/api`, while
  /// the legal pages are served from the root. Deriving it here means these
  /// links follow the backend automatically -- local machine, staging, or the
  /// production domain -- instead of being a second URL to remember to change.
  static String get siteRoot => siteRootFrom(kApiBaseUrl);

  /// Split out from [siteRoot] so it can be tested against the shapes
  /// `kApiBaseUrl` actually takes across environments -- with and without the
  /// `/api` suffix, with and without a trailing slash. A wrong root here is a
  /// 404 on the privacy policy, which is the one link a store reviewer clicks.
  static String siteRootFrom(String apiBase) {
    var base = apiBase.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - '/api'.length);
    }
    return base;
  }

  static String get privacy => '$siteRoot/privacy/';
  static String get terms => '$siteRoot/terms/';
  static String get dataDeletion => '$siteRoot/data-deletion/';

  /// Opens [url], telling the user if nothing can handle it.
  ///
  /// A silently dead "Privacy Policy" row is the failure a store reviewer
  /// finds, so the failure is surfaced rather than swallowed.
  static Future<void> open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!ok) throw Exception('no handler');
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}
