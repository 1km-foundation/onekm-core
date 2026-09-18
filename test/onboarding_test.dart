import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onekm_core/onekm_core.dart';

const _pages = [
  OnboardingPage(icon: Icons.directions_car, title: 'One', subtitle: 'First'),
  OnboardingPage(icon: Icons.payments, title: 'Two', subtitle: 'Second'),
];

Future<void> pumpOnboarding(
  WidgetTester tester, {
  required VoidCallback onDone,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingScreen(pages: _pages, onDone: onDone),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pages advance and finish calls onDone', (tester) async {
    var done = false;
    await pumpOnboarding(tester, onDone: () => done = true);

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('skip finishes immediately', (tester) async {
    var done = false;
    await pumpOnboarding(tester, onDone: () => done = true);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(done, isTrue);
  });
}
