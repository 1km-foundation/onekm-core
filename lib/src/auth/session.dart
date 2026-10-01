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
    required this.clientId,
    required this.role,
    TokenStore? store,
    http.Client? client,
    this.onAuthLoss,
  }) : _store = store ?? SecureTokenStore(),
       _client = client ?? http.Client();

  final String baseUrl;

  /// Registry client id (`user-android`, `provider-android`,
  /// `teams-android`): stamped into `aud`/`client_id` on verify, login
  /// and refresh so the server's platform gate can tell callers apart.
  /// Absent in legacy builds = legacy-shaped tokens.
  final String clientId;
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

  // No shared-key header: caller identity is the Bearer token (plus
  // `Authorization: ApiKey` static keys for machines). The legacy
  // `x-api-key` header was never verified server-side.
  OneKmApi get _api => OneKmApi(
    baseUrl: baseUrl,
    headers: () async => <String, String>{},
    client: _client,
  );

  /// Authenticated client: injects the current bearer.
  /// Throws [ApiException.unauthorized] when signed out.
  Future<OneKmApi> get api async {
    final token = await accessToken();
    return OneKmApi(
      baseUrl: baseUrl,
      headers: () async => {'Authorization': 'Bearer $token'},
      client: _client,
    );
  }

  Future<bool> get signedIn async => await _store.read(_accessKey) != null;

  Future<void> requestOtp(String phone) async {
    await _api.post(
      '/auth/otp/request',
      body: {'phone': phone, 'role': role.name},
    );
  }

  Future<void> verifyOtp(String phone, String code) async {
    final data = await _api.post(
      '/auth/otp/verify',
      body: {
        'phone': phone,
        'role': role.name,
        'code': code,
        'client_id': clientId,
      },
    ) as Map<String, dynamic>;
    await _store.write(_accessKey, '${data['access_token']}');
    await _store.write(_refreshKey, '${data['refresh_token']}');
    // Best-effort push registration so the server fan-out has tokens.
    // Real FCM tokens need firebase_messaging; until wired, register a
    // stable install id (log-mode dispatch still exercises end-to-end).
    await _registerInstall();
  }

  /// Staff/service login (teams app): username or email + password.
  /// Same token pair shape as OTP verify. Hits the canonical
  /// `/auth/login` (the `/admin/auth/*` aliases are deprecated).
  Future<void> loginWithPassword(String identity, String password) async {
    final data = await _api.post(
      '/auth/login',
      body: {'identity': identity, 'password': password, 'client_id': clientId},
    ) as Map<String, dynamic>;
    await _store.write(_accessKey, '${data['access_token']}');
    await _store.write(_refreshKey, '${data['refresh_token']}');
    await _registerInstall();
  }

  /// Stable install id for the push registry (no Firebase plugin yet).
  Future<void> _registerInstall() async {
    try {
      var install = await _store.read('install');
      if (install == null || install.length < 10) {
        install =
            'install-${DateTime.now().millisecondsSinceEpoch}-${role.name}';
        await _store.write('install', install);
      }
      final api = await this.api;
      await api.post(
        '/devices',
        body: {'token': install, 'platform': 'android'},
      );
    } catch (_) {}
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

  /// Zone writ (`zones` claim) for staff tokens: empty = global.
  Future<List<String>> zones() async {
    final token = await _store.read(_accessKey);
    if (token == null) return const [];
    try {
      final payload = JwtDecoder.decode(token);
      final zones = payload['zones'];
      if (zones is List) return zones.whereType<String>().toList();
      return const [];
    } catch (_) {
      return const [];
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
      // Re-stamp client_id on rotation so the fresh access token keeps
      // the caller's aud (absent = legacy-shaped token).
      final data = await _api.post(
        '/auth/refresh',
        body: {'refresh_token': refresh, 'client_id': clientId},
      ) as Map<String, dynamic>;
      final access = '${data['access_token']}';
      await _store.write(_accessKey, access);
      await _store.write(_refreshKey, '${data['refresh_token']}');
      return access;
    } on ApiException {
      await signOut();
      rethrow;
    }
  }

  /// Server-side logout: revoke the refresh token (best-effort — a
  /// dead network still clears locally), then drop both tokens.
  Future<void> signOut() async {
    final refresh = await _store.read(_refreshKey);
    if (refresh != null) {
      try {
        await _api.post('/auth/logout', body: {'refresh_token': refresh});
      } catch (_) {
        // Logout never blocks on transport: the refresh stays valid
        // until expiry, but the client has already dropped it.
      }
    }
    await _store.deleteAll();
    await onAuthLoss?.call();
  }

  /// Register the current device for push fan-out (best-effort).
  /// Call after login; failures never block the session.
  Future<void> registerDevice(String token, String platform) async {
    try {
      final api = await this.api;
      await api.post('/devices', body: {'token': token, 'platform': platform});
    } catch (_) {}
  }

  bool _expiringSoon(String token) {
    try {
      return JwtDecoder.getRemainingTime(token) < const Duration(seconds: 60);
    } catch (_) {
      return true;
    }
  }
}
