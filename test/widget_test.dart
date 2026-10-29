import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/main.dart';
import 'package:trap_dash_arena/ui/main_menu_screen.dart';
import 'package:trap_dash_arena/ui/title_screen.dart';
import 'package:trap_dash_arena/ui/widgets/hazard_background.dart';
import 'package:trap_dash_arena/ui/widgets/vertical_flip_ticker.dart';

void main() {
  testWidgets('TrapDashApp launches and renders TitleScreen with title, ticker, and hazards',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TrapDashApp());

    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.byType(HazardBackground), findsWidgets);
    expect(find.byType(VerticalFlipTicker), findsOneWidget);
    expect(find.text('TRAP DASH ARENA'), findsOneWidget);
    expect(find.text('TAP TO START'), findsOneWidget);
  });

  testWidgets('Tapping TitleScreen navigates to MainMenuScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TrapDashApp());

    await tester.tap(find.text('TAP TO START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MainMenuScreen), findsOneWidget);
  });
}
