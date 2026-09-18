import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../api/api_client.dart';

/// Caller role, mirroring the server `AuthRole`.
enum AuthRole { user, provider, staff, service }

/// Token persistence. [SecureTokenStore] for production,
/// [MemoryTokenStore] for tests.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage, this.prefix = 'onekm.'})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String prefix;

  @override
  Future<String?> read(String key) => _storage.read(key: '$prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$prefix$key');

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class MemoryTokenStore implements TokenStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _map.clear();
  }
}

/// Authenticated session for one role in one app.
///
/// Flow: [requestOtp] → user reads the SMS → [verifyOtp] stores the pair.
/// [accessToken] refreshes proactively (60s margin); a dead refresh
/// clears state and fires [onAuthLoss] (UI routes to login). A 401 from
/// any API call means the same: sign out and re-login.
class Session {
  Session({
    required this.baseUrl,
    required this.apiKey,
    required this.role,
    TokenStore? store,
    http.Client? client,
    this.onAuthLoss,
  })  : _store = store ?? SecureTokenStore(),
        _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final AuthRole role;
  final TokenStore _store;
  final http.Client _client;

  /// Shared HTTP client (connection pooling; also lets screens reuse the
  /// session's client — including test doubles).
  http.Client get httpClient => _client;

  /// Called (once per loss) when stored credentials stop working.
  final Future<void> Function()? onAuthLoss;

  static const _accessKey = 'access';
  static const _refreshKey = 'refresh';

  OneKmApi get _api => OneKmApi(
        baseUrl: baseUrl,
        headers: () async => {'x-api-key': apiKey},
        client: _client,
      );

  /// Authenticated client: injects the current bearer alongside the key.
  /// Throws [ApiException.unauthorized] when signed out.
  Future<OneKmApi> get api async {
    final token = await accessToken();
    return OneKmApi(
      baseUrl: baseUrl,
      headers: () async => {
        'x-api-key': apiKey,
        'Authorization': 'Bearer $token',
      },
      client: _client,
    );
  }

  Future<bool> get signedIn async => await _store.read(_accessKey) != null;

  Future<void> requestOtp(String phone) async {
    await _api.post('/auth/otp/request', body: {
      'phone': phone,
      'role': role.name,
    });
  }

  Future<void> verifyOtp(String phone, String code) async {
    final data = await _api.post('/auth/otp/verify', body: {
      'phone': phone,
      'role': role.name,
      'code': code,
    }) as Map<String, dynamic>;
    await _store.write(_accessKey, '${data['access_token']}');
    await _store.write(_refreshKey, '${data['refresh_token']}');
  }

  /// Staff/service login (teams app): username or email + password.
  /// Same token pair shape as OTP verify.
  Future<void> loginWithPassword(String identity, String password) async {
    final data = await _api.post('/admin/auth/login', body: {
      'identity': identity,
      'password': password,
    }) as Map<String, dynamic>;
    await _store.write(_accessKey, '${data['access_token']}');
    await _store.write(_refreshKey, '${data['refresh_token']}');
  }

  /// Login subject (`sub` claim: phone for apps, username for staff),
  /// or null when signed out / undecodable.
  Future<String?> subject() async {
    final token = await _store.read(_accessKey);
    if (token == null) return null;
    try {
      final payload = JwtDecoder.decode(token);
      final sub = payload['sub'];
      return sub is String && sub.isNotEmpty ? sub : null;
    } catch (_) {
      return null;
    }
  }

  /// Provider registry id (`pid` claim) for provider tokens, else null.
  /// Duty screens use this to scope every call to the caller's own record.
  Future<String?> providerId() async {
    final token = await _store.read(_accessKey);
    if (token == null) return null;
    try {
      final payload = JwtDecoder.decode(token);
      final pid = payload['pid'];
      return pid is String && pid.isNotEmpty ? pid : null;
    } catch (_) {
      return null;
    }
  }

  /// Valid access token, refreshing first when under 60s of life.
  Future<String> accessToken() async {
    final current = await _store.read(_accessKey);
    if (current != null && !_expiringSoon(current)) return current;
    final refresh = await _store.read(_refreshKey);
    if (refresh == null) {
      await signOut();
      throw ApiException(401, 'UNAUTHORIZED', 'signed out');
    }
    try {
      final data = await _api.post('/auth/refresh', body: {
        'refresh_token': refresh,
      }) as Map<String, dynamic>;
      final access = '${data['access_token']}';
      await _store.write(_accessKey, access);
      await _store.write(_refreshKey, '${data['refresh_token']}');
      return access;
    } on ApiException {
      await signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _store.deleteAll();
    await onAuthLoss?.call();
  }

  bool _expiringSoon(String token) {
    try {
      return JwtDecoder.getRemainingTime(token) <
          const Duration(seconds: 60);
    } catch (_) {
      return true;
    }
  }
}
