import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app, telling the user when nothing can handle it.
///
/// External rather than an in-app WebView: the address bar showing the real
/// domain is the whole point for a legal page, and for the vendor site it is
/// what lets somebody see they are being handed to a different app before
/// they type a password into it.
///
/// A row that silently does nothing when tapped is worse than one that says
/// it failed -- the reader just concludes the app is broken -- so the failure
/// is surfaced instead of swallowed.
Future<void> openExternalUrl(BuildContext context, String url) async {
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
