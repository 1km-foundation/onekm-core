import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onekm_core/onekm_core.dart';

void main() {
  group('buildMapUrl', () {
    test('pins encode with labels and zoom', () {
      final url = buildMapUrl('https://api.example', const [
        MapPin(lat: 12.97, lng: 77.59, label: 'Bus stand'),
        MapPin(lat: 12.93, lng: 77.61, label: 'Mandi gate'),
      ], zoom: 13);
      expect(
        url,
        'https://api.example/map'
        '?pin=12.97,77.59,Bus%20stand'
        '&pin=12.93,77.61,Mandi%20gate'
        '&z=13',
      );
    });

    test('coordinate-less pins drop out, empty list has no query', () {
      expect(
        buildMapUrl('https://api.example', const [
          MapPin(label: 'Nowhere'),
        ]),
        'https://api.example/map',
      );
    });
  });

  group('launchExternalMaps', () {
    final launched = <String>[];

    setUp(() {
      launched.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launched.add('${call.arguments['url']}');
          return true;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'), null);
    });

    test('coordinates win over text', () async {
      final ok = await launchExternalMaps(
          lat: 12.97, lng: 77.59, label: 'Bus stand');
      expect(ok, isTrue);
      expect(
        launched.single,
        contains('destination=12.97,77.59(Bus%20stand)'),
      );
    });

    test('falls back to text query', () async {
      final ok = await launchExternalMaps(query: 'bus stand');
      expect(ok, isTrue);
      expect(launched.single, contains('destination=bus%20stand'));
    });

    test('nothing to navigate returns false without launching', () async {
      expect(await launchExternalMaps(), isFalse);
      expect(launched, isEmpty);
    });
  });

  group('MapView', () {
    testWidgets('test seam renders the URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            url: 'https://api.example/map?pin=1,2',
            viewBuilder: (url) => Text('stub:$url'),
          ),
        ),
      );
      expect(find.text('stub:https://api.example/map?pin=1,2'),
          findsOneWidget);
    });
  });
}
