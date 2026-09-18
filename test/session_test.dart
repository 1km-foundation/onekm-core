import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onekm_core/onekm_core.dart';

/// Unsigned JWT with a chosen expiry (client never verifies signatures —
/// it only reads `exp` to refresh proactively).
String fakeJwt({required int expInSeconds}) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp =
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expInSeconds;
  return '${part({'alg': 'HS256'})}.${part({'sub': '1', 'exp': exp})}.sig';
}

http.Response envelope(Object data, [int status = 200]) => http.Response(
      jsonEncode({'ok': true, 'data': data}),
      status,
      headers: {'Content-Type': 'application/json'},
    );

http.Response denied() => http.Response(
      jsonEncode({
        'ok': false,
        'error': {'code': 'UNAUTHORIZED', 'message': 'no'}
      }),
      401,
      headers: {'Content-Type': 'application/json'},
    );

Object reqBody(http.Request req) => jsonDecode(req.body) as Object;

/// Full happy-path backend: OTP request/verify + refresh rotation.
MockClient happyBackend() => MockClient((req) async {
      final path = req.url.path;
      if (path == '/auth/otp/request') return envelope({'sent': true});
      if (path == '/auth/otp/verify') {
        expect(reqBody(req), containsPair('code', '123456'));
        return envelope({
          'access_token': fakeJwt(expInSeconds: 3600),
          'refresh_token': 'r1',
          'expires_in': 3600,
        });
      }
      if (path == '/auth/refresh') {
        final b = reqBody(req) as Map;
        if (b['refresh_token'] == 'r1') {
          return envelope({
            'access_token': fakeJwt(expInSeconds: 3600),
            'refresh_token': 'r2',
            'expires_in': 3600,
          });
        }
        return denied();
      }
      return http.Response('not found', 404);
    });

Session session({
  required MockClient client,
  MemoryTokenStore? store,
  Future<void> Function()? onLoss,
}) =>
    Session(
      baseUrl: 'http://x.test',
      apiKey: 'k',
      role: AuthRole.user,
      store: store ?? MemoryTokenStore(),
      client: client,
      onAuthLoss: onLoss,
    );

void main() {
  test('otp login stores the pair', () async {
    final s = session(client: happyBackend());
    expect(await s.signedIn, isFalse);
    await s.requestOtp('9876543210');
    await s.verifyOtp('9876543210', '123456');
    expect(await s.signedIn, isTrue);
    final token = await s.accessToken();
    expect(token.split('.'), hasLength(3));
  });

  test('expiring access triggers rotation', () async {
    var refreshCalls = 0;
    final store = MemoryTokenStore();
    await store.write('access', fakeJwt(expInSeconds: -10));
    await store.write('refresh', 'r1');
    final s = session(
      client: MockClient((req) async {
        if (req.url.path == '/auth/refresh') {
          refreshCalls++;
          return envelope({
            'access_token': fakeJwt(expInSeconds: 3600),
            'refresh_token': 'r2',
            'expires_in': 3600,
          });
        }
        return http.Response('not found', 404);
      }),
      store: store,
    );
    final token = await s.accessToken();
    expect(token.split('.'), hasLength(3));
    expect(refreshCalls, 1);
    // Rotated pair persisted.
    expect(await store.read('refresh'), 'r2');
  });

  test('dead refresh clears state and fires onAuthLoss', () async {
    var lost = 0;
    final store = MemoryTokenStore();
    await store.write('access', fakeJwt(expInSeconds: -10));
    await store.write('refresh', 'bogus');
    final s = session(
        client: MockClient((_) async => denied()),
        store: store,
        onLoss: () async { lost++; });
    try {
      await s.accessToken();
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.unauthorized, isTrue);
    }
    expect(await s.signedIn, isFalse);
    expect(lost, 1);
  });

  test('signOut clears everything', () async {
    final s = session(client: happyBackend());
    await s.requestOtp('9876543210');
    await s.verifyOtp('9876543210', '123456');
    await s.signOut();
    expect(await s.signedIn, isFalse);
  });
}
