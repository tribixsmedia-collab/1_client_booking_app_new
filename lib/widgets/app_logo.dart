import 'package:flutter/material.dart';

import '../services/branding_service.dart';

/// Rebuilds its subtree whenever the branding lands from the backend, so a
/// screen already on-screen picks up the new logo or name without a restart.
class BrandingBuilder extends StatelessWidget {
  final WidgetBuilder builder;

  const BrandingBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BrandingService.revision,
      builder: (context, _, __) => builder(context),
    );
  }
}

/// The app's logo, admin-managed where one has been uploaded and falling back
/// to the bundled asset otherwise — including when the upload fails to load,
/// so a broken URL never leaves a blank space where the logo should be.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 300});

  @override
  Widget build(BuildContext context) {
    return BrandingBuilder(
      builder: (context) {
        final url = BrandingService.logoUrl;

        if (url == null || url.isEmpty) return _bundled();

        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _bundled(),
          // Hold the bundled logo in place while the remote one loads, so the
          // layout never jumps.
          frameBuilder: (context, child, frame, wasSynchronous) {
            if (wasSynchronous || frame != null) return child;
            return _bundled();
          },
        );
      },
    );
  }

  Widget _bundled() =>
      Image.asset('assets/logo.png', width: size, height: size);
}
