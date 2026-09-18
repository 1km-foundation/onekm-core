import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onekm_core/onekm_core.dart';

String fakeJwt() {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp =
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
  return '${part({'alg': 'HS256'})}.${part({'sub': '1', 'exp': exp})}.sig';
}

http.Response envelope(Object data, [int status = 200]) => http.Response(
      jsonEncode({'ok': true, 'data': data}),
      status,
      headers: {'Content-Type': 'application/json'},
    );

MockClient backend() => MockClient((req) async {
      if (req.url.path == '/auth/otp/request') {
        return envelope({'sent': true});
      }
      if (req.url.path == '/auth/otp/verify') {
        final b = jsonDecode(req.body) as Map;
        if (b['code'] == '123456') {
          return envelope({
            'access_token': fakeJwt(),
            'refresh_token': 'r1',
            'expires_in': 3600,
          });
        }
        return http.Response(
          jsonEncode({
            'ok': false,
            'error': {'code': 'UNAUTHORIZED', 'message': 'no'}
          }),
          401,
          headers: {'Content-Type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

Session testSession() => Session(
      baseUrl: 'http://x.test',
      apiKey: 'k',
      role: AuthRole.user,
      store: MemoryTokenStore(),
      client: backend(),
    );

Future<void> pumpFlow(WidgetTester tester, Session session,
    SessionController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OtpFlow(session: session, controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('happy path signs in', (tester) async {
    final session = testSession();
    final controller = SessionController(session);
    await pumpFlow(tester, session, controller);

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Code sent'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.signedIn, isTrue);
  });

  testWidgets('wrong code stays put with an error', (tester) async {
    final session = testSession();
    final controller = SessionController(session);
    await pumpFlow(tester, session, controller);

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.signedIn, isFalse);
    // Still on the code step (can retry).
    expect(find.textContaining('Code sent'), findsOneWidget);
  });

  testWidgets('short number is rejected inline', (tester) async {
    final session = testSession();
    final controller = SessionController(session);
    await pumpFlow(tester, session, controller);

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
  });

  testWidgets('country code is shown and accepted', (tester) async {
    final session = testSession();
    final controller = SessionController(session);
    await pumpFlow(tester, session, controller);

    // The +91 affordance is visible before typing.
    expect(find.text('+91 '), findsOneWidget);
    // A pasted +91 number passes validation and requests a code.
    await tester.enterText(find.byType(TextField), '+91 98765 43210');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Code sent'), findsOneWidget);
  });

  group('splash', () {
    late ReferenceCache cache;

    setUpAll(() async {
      // Real zone: Hive I/O never completes under fake async.
      final dir = await Directory.systemTemp.createTemp('onekm_splash');
      Hive.init(dir.path);
      cache = await ReferenceCache.open('splash_test');
    });

    testWidgets('warmed cache boots to ready', (tester) async {
      // NOTE: explicit pumps — the spinner never settles by design.
      final session = testSession();
      final controller = SessionController(session);
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            session: session,
            controller: controller,
            title: 'Test',
            cacheOpener: () async => cache,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.ready, isTrue);
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('offline boot still reaches ready', (tester) async {
      final session = testSession();
      final controller = SessionController(session);
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            session: session,
            controller: controller,
            title: 'Test',
            cacheOpener: () => throw const SocketException('offline'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.ready, isTrue);
    });
  });
}
