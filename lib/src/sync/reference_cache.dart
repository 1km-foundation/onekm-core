import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_client.dart';

/// Cached reference data (rate card, client config): stale-while-revalidate
/// so fare quotes survive short outages. Plain maps only — no codegen,
/// no adapters.
class ReferenceCache {
  ReferenceCache(this._box);

  /// Call `Hive.initFlutter()` in the app before opening.
  static Future<ReferenceCache> open([String name = 'onekm_ref']) async {
    return ReferenceCache(await Hive.openBox(name));
  }

  final Box _box;

  Future<void> putJson(String key, Object value,
      {Duration ttl = const Duration(hours: 6)}) async {
    await _box.put(key, {
      'at': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl.inSeconds,
      'value': value,
    });
  }

  /// Cached value, or null when missing/expired.
  Object? getJson(String key) {
    final entry = _box.get(key);
    if (entry is! Map) return null;
    final at = (entry['at'] as num?)?.toInt() ?? 0;
    final ttl = (entry['ttl'] as num?)?.toInt() ?? 0;
    final age =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    if (age > Duration(seconds: ttl)) return null;
    return entry['value'];
  }

  Future<void> invalidate() => _box.clear();

  /// Published fares, cached 6h. Returns raw entry maps.
  Future<List<Map<String, dynamic>>> rateCard(OneKmApi api) async {
    final cached = getJson('rate_card');
    if (cached is List) {
      return cached.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    final data = await api.get('/rate-card') as List;
    final entries =
        data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    await putJson('rate_card', entries);
    return entries;
  }

  /// Client bootstrap (`GET /config`), cached 24h.
  Future<Map<String, dynamic>> config(OneKmApi api) async {
    final cached = getJson('app_config');
    if (cached is Map) return Map<String, dynamic>.from(cached);
    final data = await api.get('/config') as Map<String, dynamic>;
    await putJson('app_config', data,
        ttl: const Duration(hours: 24));
    return data;
  }
}
