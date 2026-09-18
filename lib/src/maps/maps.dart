import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A pin on the server-rendered map (`GET /map`).
class MapPin {
  const MapPin({this.lat, this.lng, this.label = ''});

  /// Coordinates when known; text-only pins fall back to the label list.
  final double? lat;
  final double? lng;
  final String label;
}

/// Build a `/map` URL: `?pin=LAT,LNG[,LABEL]&…&z=`. Pins without
/// coordinates are skipped (the caller renders them as text).
String buildMapUrl(String baseUrl, List<MapPin> pins, {int? zoom}) {
  final params = <String>[];
  for (final p in pins) {
    if (p.lat == null || p.lng == null) continue;
    final label = p.label.trim();
    params.add(
      'pin=${p.lat},${p.lng}${label.isEmpty ? '' : ',${Uri.encodeComponent(label)}'}',
    );
  }
  if (zoom != null) params.add('z=$zoom');
  final query = params.join('&');
  return '$baseUrl/map${query.isEmpty ? '' : '?$query'}';
}

/// Open on-device navigation (Google Maps app when present, else the
/// browser — both via https universal links, so no API keys, no SDK,
/// no plist/manifest entries). Returns false when nothing handled it.
Future<bool> launchExternalMaps({
  double? lat,
  double? lng,
  String? query,
  String? label,
}) {
  final q = StringBuffer();
  if (lat != null && lng != null) {
    q.write('$lat,$lng');
    if (label != null && label.trim().isNotEmpty) {
      q.write('(${Uri.encodeComponent(label.trim())})');
    }
  } else if (query != null && query.trim().isNotEmpty) {
    q.write(Uri.encodeComponent(query.trim()));
  } else {
    return Future.value(false);
  }
  final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$q');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Open the dialer for a phone number (call-driver / call-customer
/// cards, shown only while the ride is active). Returns false when the
/// number has nothing dialable.
Future<bool> launchPhoneCall(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^+\d]'), '');
  if (digits.replaceAll(RegExp(r'\D'), '').isEmpty) {
    return Future.value(false);
  }
  return launchUrl(Uri.parse('tel:$digits'));
}

/// Leaflet-in-WebView for the server map page. [viewBuilder] is a test
/// seam (real WebViews need platform channels, unavailable in widget
/// tests): production omits it, tests inject a stub.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.url,
    this.viewBuilder,
  });

  final String url;
  final Widget Function(String url)? viewBuilder;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  WebViewController? _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    // The platform controller needs native channels: only build it on
    // the real path (tests inject viewBuilder and never touch this).
    if (widget.viewBuilder == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _ready = true);
            },
            onWebResourceError: (_) {
              if (mounted) setState(() => _ready = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else {
      _ready = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stub = widget.viewBuilder;
    if (stub != null) return stub(widget.url);
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (!_ready) Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
