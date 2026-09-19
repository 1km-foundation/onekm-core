import 'api_client.dart';

/// Push-device registry (`POST /devices`). The server fans out lifecycle
/// + SOS alerts here (FCM v1 when `FCM_*` are set, server log otherwise).
/// Call after login with the platform push token when available; with no
/// Firebase plugin the caller passes a stable install id so the registry
/// still exercises end-to-end in log mode.
Future<void> registerDevice(
  OneKmApi api, {
  required String token,
  required String platform,
}) {
  return api.post('/devices', body: {'token': token, 'platform': platform});
}

Future<void> unregisterDevice(OneKmApi api, String token) {
  return api.delete('/devices/$token');
}

Future<List<Map<String, dynamic>>> listDevices(OneKmApi api) async {
  final data = await api.get('/devices') as List;
  return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
}
