import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which app's wordmark to show. Each variant bundles its own caption
/// ("Provider", "Teams") so screens never need an explicit "who is
/// this for" title next to the logo.
enum OneKmLogoVariant { user, provider, teams }

/// The 1KM wordmark. Picks the light-on-dark / dark-on-light asset from
/// the ambient brightness unless [dark] is forced, so the same widget
/// works on splash screens, login headers and app bars in both themes.
///
/// Assets live in this package (`assets/logo_{light,dark}[_variant].svg`)
/// and ship to every app through the barrel export — no per-app copying.
class OneKmLogo extends StatelessWidget {
  const OneKmLogo(
      {super.key,
      this.height = 48,
      this.dark,
      this.variant = OneKmLogoVariant.user});

  /// Logo height in logical pixels (aspect preserved from the SVG).
  final double height;

  /// Force a variant; `null` (default) follows the theme brightness.
  final bool? dark;

  /// App wordmark variant (user/provider/teams).
  final OneKmLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final suffix = switch (variant) {
      OneKmLogoVariant.user => '',
      OneKmLogoVariant.provider => '_provider',
      OneKmLogoVariant.teams => '_teams',
    };
    return SvgPicture.asset(
      isDark ? 'assets/logo_light$suffix.svg' : 'assets/logo_dark$suffix.svg',
      package: 'onekm_core',
      height: height,
      semanticsLabel: '1KM',
    );
  }
}
