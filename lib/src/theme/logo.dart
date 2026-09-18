import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The 1KM wordmark. Picks the light-on-dark / dark-on-light asset from
/// the ambient brightness unless [dark] is forced, so the same widget
/// works on splash screens, login headers and app bars in both themes.
///
/// Assets live in this package (`assets/logo_{light,dark}.svg`) and ship
/// to every app through the barrel export — no per-app copying.
class OneKmLogo extends StatelessWidget {
  const OneKmLogo({super.key, this.height = 48, this.dark});

  /// Logo height in logical pixels (aspect preserved from the SVG).
  final double height;

  /// Force a variant; `null` (default) follows the theme brightness.
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final isDark =
        dark ?? Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      isDark ? 'assets/logo_light.svg' : 'assets/logo_dark.svg',
      package: 'onekm_core',
      height: height,
      semanticsLabel: '1KM',
    );
  }
}
