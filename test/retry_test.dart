import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onekm_core/onekm_core.dart';

void main() {
  test('succeeds after transient blips', () async {
    var attempts = 0;
    final result = await withRetry(() async {
      attempts++;
      if (attempts < 3) throw const SocketException('down');
      return 'ok';
    });
    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('gives up after retries', () async {
    var attempts = 0;
    try {
      await withRetry<String>(
        () async {
          attempts++;
          throw const SocketException('down');
        },
        retries: 2,
        base: const Duration(milliseconds: 1),
      );
      fail('should throw');
    } on SocketException {
      expect(attempts, 3); // 1 initial + 2 retries
    }
  });

  test('business errors fail fast', () async {
    var attempts = 0;
    try {
      await withRetry<String>(() async {
        attempts++;
        throw ApiException(409, 'CONFLICT', 'taken');
      });
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 409);
      expect(attempts, 1);
    }
  });

  test('503 is retried', () async {
    var attempts = 0;
    try {
      await withRetry<String>(
        () async {
          attempts++;
          throw ApiException(503, 'UNAVAILABLE', 'down');
        },
        retries: 1,
        base: const Duration(milliseconds: 1),
      );
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.unavailable, isTrue);
      expect(attempts, 2);
    }
  });

  test('idempotency keys are unique v4s', () {
    final a = newIdempotencyKey();
    final b = newIdempotencyKey();
    expect(a, isNot(equals(b)));
    expect(a.length, 36);
  });
}
