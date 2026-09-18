import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Server error envelope: `{"ok":false,"error":{"code","message"}}`.
/// Thrown for every non-2xx response (including 410 Gone and 429).
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  bool get unauthorized => status == 401;
  bool get forbidden => status == 403;
  bool get notFound => status == 404;
  bool get gone => status == 410;
  bool get rateLimited => status == 429;
  bool get unavailable => status == 503;

  @override
  String toString() => 'ApiException($status $code): $message';
}

/// A paged list: `{"ok":true,"data":[…],"meta":{total,limit,offset}}`.
class PagedList<T> {
  const PagedList({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;
}

/// Builds request headers per call (lets the session inject a fresh
/// bearer token on every request, including after rotation).
typedef HeaderProvider = Future<Map<String, String>> Function();

/// Typed-over-JSON client for the 1KM API.
///
/// Success envelopes return their `data` payload directly (`getPage`
/// keeps `meta`). Transport failures (`SocketException`,
/// `TimeoutException`) propagate raw so the retry layer can match on
/// them; HTTP failures arrive as [ApiException].
class OneKmApi {
  OneKmApi({
    required this.baseUrl,
    required this.headers,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final HeaderProvider headers;
  final http.Client _client;

  static const timeout = Duration(seconds: 30);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _data('GET', path, query: query);

  Future<dynamic> post(
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
  }) =>
      _data('POST', path,
          query: query, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> patch(
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
  }) =>
      _data('PATCH', path,
          query: query, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> put(
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
  }) =>
      _data('PUT', path,
          query: query, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> delete(
    String path, {
    Map<String, String>? query,
    String? idempotencyKey,
  }) =>
      _data('DELETE', path, query: query, idempotencyKey: idempotencyKey);

  /// GET with `meta{total,limit,offset}` parsed into a [Page] of raw maps.
  Future<PagedList<Map<String, dynamic>>> getPage(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _send('GET', path, query: query);
    final envelope = _envelope(res);
    final meta = (envelope['meta'] as Map?) ?? const {};
    final items = ((envelope['data'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return PagedList(
      items: items,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
      limit: (meta['limit'] as num?)?.toInt() ?? items.length,
      offset: (meta['offset'] as num?)?.toInt() ?? 0,
    );
  }

  Future<dynamic> _data(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
  }) async {
    final res = await _send(method, path,
        query: query, body: body, idempotencyKey: idempotencyKey);
    return _envelope(res)['data'];
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
  }) async {
    final uri = _uri(path, query);
    final headers = await _headers();
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        return _client
            .post(uri, headers: headers, body: encoded)
            .timeout(timeout);
      case 'PATCH':
        return _client
            .patch(uri, headers: headers, body: encoded)
            .timeout(timeout);
      case 'PUT':
        return _client
            .put(uri, headers: headers, body: encoded)
            .timeout(timeout);
      case 'DELETE':
        return _client.delete(uri, headers: headers).timeout(timeout);
      default:
        throw ArgumentError('unsupported method $method');
    }
  }

  Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        ...await headers(),
      };

  Uri _uri(String path, Map<String, String>? query) {
    final base = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
        queryParameters: {...base.queryParameters, ...query});
  }

  Map<String, dynamic> _envelope(http.Response res) {
    dynamic decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      decoded = null;
    }
    final map = decoded is Map<String, dynamic> ? decoded : null;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map ?? const {};
    }
    final error = map?['error'];
    throw ApiException(
      res.statusCode,
      error is Map ? '${error['code'] ?? 'HTTP_${res.statusCode}'}' : 'HTTP_${res.statusCode}',
      error is Map ? '${error['message'] ?? res.reasonPhrase ?? 'request failed'}' : (res.reasonPhrase ?? 'request failed'),
    );
  }
}
