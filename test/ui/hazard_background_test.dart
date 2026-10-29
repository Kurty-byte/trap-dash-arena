import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/ui/widgets/hazard_background.dart';

void main() {
  testWidgets('HazardBackground renders child widget and asset images with low opacity',
      (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardBackground(
            opacity: 0.13,
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('TAP_ME'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('TAP_ME'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    // Verify touch events pass through to child
    await tester.tap(find.text('TAP_ME'));
    await tester.pump();
    expect(tapped, isTrue);

    // Verify animation ticks smoothly
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
