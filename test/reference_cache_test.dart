import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onekm_core/onekm_core.dart';

import 'dart:convert';

http.Response envelope(Object data) => http.Response(
      jsonEncode({'ok': true, 'data': data}),
      200,
      headers: {'Content-Type': 'application/json'},
    );

Future<ReferenceCache> openCache() async {
  final dir = await Directory.systemTemp.createTemp('onekm_cache_test');
  Hive.init(dir.path);
  return ReferenceCache.open('test_${dir.path.hashCode}');
}

void main() {
  test('put/get round-trips JSON', () async {
    final cache = await openCache();
    await cache.putJson('k', {'a': 1});
    expect(cache.getJson('k'), {'a': 1});
    await Hive.close();
  });

  test('expired entries read as missing', () async {
    final cache = await openCache();
    await cache.putJson('k', {'a': 1}, ttl: Duration.zero);
    // A zero TTL expires on the next read.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(cache.getJson('k'), isNull);
    await Hive.close();
  });

  test('rateCard caches after first fetch', () async {
    var calls = 0;
    final cache = await openCache();
    final api = OneKmApi(
      baseUrl: 'http://x.test',
      headers: () async => {},
      client: MockClient((req) async {
        calls++;
        return envelope([
          {'kind': 'passenger', 'vehicle_type': 'auto'}
        ]);
      }),
    );
    final first = await cache.rateCard(api);
    final second = await cache.rateCard(api);
    expect(first.length, 1);
    expect(second.length, 1);
    expect(calls, 1);
    await Hive.close();
  });
}
