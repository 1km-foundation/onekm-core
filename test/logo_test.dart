import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onekm_core/onekm_core.dart';

Future<void> pumpLogo(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: OneKmLogo()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logo follows brightness', (tester) async {
    await pumpLogo(tester, buildLightTheme());
    var svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.bytesLoader, isA<SvgAssetLoader>());
    expect((svg.bytesLoader as SvgAssetLoader).assetName,
        contains('logo_dark.svg'));

    await pumpLogo(tester, buildDarkTheme());
    svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((svg.bytesLoader as SvgAssetLoader).assetName,
        contains('logo_light.svg'));
  });

  testWidgets('variants resolve their own assets', (tester) async {
    for (final entry in {
      OneKmLogoVariant.user: 'logo_dark.svg',
      OneKmLogoVariant.provider: 'logo_dark_provider.svg',
      OneKmLogoVariant.teams: 'logo_dark_teams.svg',
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OneKmLogo(variant: entry.key)),
        ),
      );
      await tester.pumpAndSettle();
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect((svg.bytesLoader as SvgAssetLoader).assetName,
          contains(entry.value));
    }
  });

  testWidgets('logo renders on splash and login', (tester) async {
    // Splash shows the mark above the title.
    final session = Session(
      baseUrl: 'http://x.test',
      apiKey: 'k',
      role: AuthRole.user,
      store: MemoryTokenStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          session: session,
          controller: SessionController(session),
          cacheOpener: () => throw Exception('offline'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OneKmLogo), findsOneWidget);
  });
}
