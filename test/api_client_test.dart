import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onekm_core/onekm_core.dart';

MockClient client(Future<http.Response> Function(http.Request) fn) =>
    MockClient(fn);

OneKmApi api(Future<http.Response> Function(http.Request) fn) =>
    OneKmApi(
      baseUrl: 'http://x.test',
      headers: () async => {'x-api-key': 'k', 'Authorization': 'Bearer t'},
      client: client(fn),
    );

http.Response json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'Content-Type': 'application/json'},
    );

void main() {
  test('GET returns data and sends identity headers', () async {
    http.Request? seen;
    final a = api((req) async {
      seen = req;
      return json({'ok': true, 'data': {'a': 1}}, 200);
    });
    final data = await a.get('/config') as Map;
    expect(data['a'], 1);
    expect(seen!.headers['x-api-key'], 'k');
    expect(seen!.headers['Authorization'], 'Bearer t');
    expect(seen!.headers['Content-Type'], 'application/json');
  });

  test('POST sends idempotency key', () async {
    http.Request? seen;
    final a = api((req) async {
      seen = req;
      return json({'ok': true, 'data': {}}, 201);
    });
    await a.post('/bookings', body: {}, idempotencyKey: 'abc');
    expect(seen!.headers['Idempotency-Key'], 'abc');
  });

  test('error envelope maps to flags', () async {
    for (final status in [400, 401, 403, 404, 409, 410, 422, 429, 503]) {
      final a = api((_) async => json(
          {
            'ok': false,
            'error': {'code': 'X', 'message': 'nope'}
          },
          status));
      try {
        await a.get('/x');
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.status, status);
        expect(e.code, 'X');
        expect(e.message, 'nope');
      }
    }
    final gone = api((_) async => json(
        {
          'ok': false,
          'error': {'code': 'GONE', 'message': 'retired'}
        },
        410));
    try {
      await gone.get('/sms/inbound');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.gone, isTrue);
    }
  });

  test('non-JSON errors still throw ApiException', () async {
    final a = api((_) async => http.Response('boom', 500));
    try {
      await a.get('/x');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 500);
      expect(e.code, 'HTTP_500');
    }
  });

  test('getPage parses items + meta', () async {
    final a = api((_) async => json({
          'ok': true,
          'data': [
            {'id': '1'},
            {'id': '2'}
          ],
          'meta': {'total': 5, 'limit': 2, 'offset': 0},
        }, 200));
    final page = await a.getPage('/bookings');
    expect(page.items.map((e) => e['id']), ['1', '2']);
    expect(page.total, 5);
    expect(page.hasMore, isTrue);
  });

  test('getPage without meta degrades sanely', () async {
    final a = api(
        (_) async => json({'ok': true, 'data': <dynamic>[]}, 200));
    final page = await a.getPage('/bookings');
    expect(page.total, 0);
    expect(page.hasMore, isFalse);
  });
}
