import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/ui/widgets/vertical_flip_ticker.dart';

void main() {
  testWidgets('VerticalFlipTicker displays first message and rotates after interval',
      (WidgetTester tester) async {
    const testMessages = [
      'TIP 1: WATCH YOUR STEP',
      'TIP 2: JUMP EARLY',
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerticalFlipTicker(
            messages: testMessages,
            interval: Duration(seconds: 2),
          ),
        ),
      ),
    );

    expect(find.text('TIP 1: WATCH YOUR STEP'), findsOneWidget);
    expect(find.text('TIP 2: JUMP EARLY'), findsNothing);

    // Fast forward past the interval
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 350)); // allow animation transition

    expect(find.text('TIP 2: JUMP EARLY'), findsOneWidget);
  });

  testWidgets('VerticalFlipTicker disposes cleanly without timer leaks',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerticalFlipTicker(
            messages: ['MSG 1', 'MSG 2'],
            interval: Duration(seconds: 1),
          ),
        ),
      ),
    );

    // Replace with empty container to trigger dispose
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('VerticalFlipTicker scales down long text without overflow',
      (WidgetTester tester) async {
    const longMessage = 'VERY LONG RETRO TIP STATEMENT THAT MUST FIT COMPLETELY';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerticalFlipTicker(
            messages: [longMessage],
            width: 200,
          ),
        ),
      ),
    );

    expect(find.text(longMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VerticalFlipTicker defaultMessages contain accurate Levels 1-5 trap mechanics',
      (WidgetTester tester) async {
    expect(VerticalFlipTicker.defaultMessages.length, greaterThanOrEqualTo(7));
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('TIP: FLOOR GAPS CHASE RUNNERS AND SNAP IF YOU HESITATE'),
    );
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('WARNING: SOME SPIKES LAUNCH UP ON JUMP — WALK UNDER THEM'),
    );
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('HINT: WATCH THE OVERHEAD ARROW WHEN CONTROLS INVERT'),
    );
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('PRO TIP: SOME WARP PORTALS ARM SPIKES BEHIND YOU'),
    );
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('MEMORIZE: PORTAL GAUNTLET PATTERN IS L - R - R - L - R'),
    );
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('FACT: RED BUTTONS SHUT DOWN CANNONS IN LEVEL 5'),
    );
    expect(
      VerticalFlipTicker.defaultMessages,
      contains('WARNING: GIANT SAW BLADES LEAP WHEN YOU GET CLOSE'),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerticalFlipTicker(),
        ),
      ),
    );

    expect(find.text(VerticalFlipTicker.defaultMessages.first), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
