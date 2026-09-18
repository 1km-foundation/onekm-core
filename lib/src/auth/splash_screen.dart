import 'package:flutter/material.dart';

import '../../onekm_core.dart';

/// Boot screen shared by all apps: warms the reference cache
/// (best-effort — offline first boot must still reach login), then flips
/// the controller ready so the router redirects.
///
/// Requires `Hive.initFlutter()` in the app's `main()` before `runApp`.
/// [cacheOpener] exists for tests: real Hive I/O never completes under
/// flutter_test's fake async, so widget tests inject a pre-opened box
/// (via `setUpAll`) or a throwing opener for the offline path.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.session,
    required this.controller,
    this.title,
    this.subtitle,
    this.logoVariant = OneKmLogoVariant.user,
    this.cacheOpener = ReferenceCache.open,
  });

  final Session session;
  final SessionController controller;

  /// Optional word under the logo; null skins it (the per-app wordmark
  /// already identifies the app).
  final String? title;
  final String? subtitle;

  /// Per-app wordmark shown above the title.
  final OneKmLogoVariant logoVariant;
  final Future<ReferenceCache> Function() cacheOpener;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final cache = await widget.cacheOpener();
      try {
        final api = OneKmApi(
          baseUrl: widget.session.baseUrl,
          headers: () async => {'x-api-key': widget.session.apiKey},
          client: widget.session.httpClient,
        );
        await cache.config(api);
      } catch (_) {
        // Offline or unreachable: cached values (or none) will do.
      }
    } catch (_) {
      // No local storage (first run): proceed regardless.
    } finally {
      await widget.controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OneKmLogo(height: 56, variant: widget.logoVariant),
              const SizedBox(height: 12),
              if (widget.title != null)
                Text(
                  widget.title!,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(widget.subtitle!),
              ],
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
