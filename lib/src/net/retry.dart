import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';

/// Fresh idempotency key per POST: safe retries on flaky networks are a
/// first-class flow (the server replays instead of duplicating).
String newIdempotencyKey() => const Uuid().v4();

/// Retry transport blips and 503s with exponential backoff. Business
/// errors (400/401/403/404/409/410/422) and 429 cooldowns fail fast —
/// retrying those is either wrong or rude.
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int retries = 3,
  Duration base = const Duration(milliseconds: 500),
}) async {
  Object? last;
  for (var attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } on SocketException catch (e) {
      last = e;
    } on TimeoutException catch (e) {
      last = e;
    } on HttpException catch (e) {
      last = e;
    } on ApiException catch (e) {
      if (!e.unavailable) rethrow;
      last = e;
    }
    if (attempt < retries) {
      await Future.delayed(base * (1 << attempt));
    }
  }
  throw last!;
}

/// Reactive connectivity for offline banners. Emits current state first.
class ConnectivityStatus {
  static Future<bool> check() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  static Stream<bool> get stream async* {
    yield await check();
    yield* Connectivity()
        .onConnectivityChanged
        .map((r) => !r.contains(ConnectivityResult.none))
        .distinct();
  }
}
